import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/user/user_models.dart';
import '../../errors/app_error.dart';
import '../../extensions/list_extensions.dart';
import '../../storage/app_preferences.dart';
import '../../utils/constant/firestore_constant.dart';
import '../../utils/dummy_deactivated_account.dart';
import '../device/device_service.dart';

final userServiceProvider = Provider((ref) {
  final service = UserService(
    ref.read(currentUserPod),
    FirebaseFirestore.instance,
    ref.read(deviceServiceProvider),
  );

  ref.listen(currentUserPod, (_, next) => service._currentUser = next);
  return service;
});

class UserService {
  UserModel? _currentUser;

  final FirebaseFirestore firestore;
  final DeviceService deviceService;

  UserService(
    this._currentUser,
    this.firestore,
    this.deviceService,
  );

  CollectionReference<UserModel> get _userRef => firestore
      .collection(FireStoreConst.usersCollection)
      .withConverter<UserModel>(
        fromFirestore: UserModel.fromFireStore,
        toFirestore: (user, options) => user.toJson(),
      );

  CollectionReference _sessionRef(String userId) => _userRef
      .doc(userId)
      .collection(FireStoreConst.userSessionCollection)
      .withConverter<ApiSession>(
        fromFirestore: ApiSession.fromFireStore,
        toFirestore: (session, _) => session.toJson(),
      );

  CollectionReference<UserStat> _userStatsRef(String userId) => _userRef
      .doc(userId)
      .collection(FireStoreConst.userStatCollection)
      .withConverter(
        fromFirestore: UserStat.fromFireStore,
        toFirestore: (userStat, _) => userStat.toJson(),
      );

  Future<void> clearSession({
    required String uid,
    required String sessionId,
  }) async {
    await _sessionRef(uid).doc(sessionId).delete();
  }

  Future<ApiSession> _createSession(String userId) async {
    final sessionDocRef = _sessionRef(userId).doc();
    final session = ApiSession(
      id: sessionDocRef.id,
      user_id: userId,
      device_type: deviceService.currentPlatformType(),
      device_id: deviceService.deviceId,
      device_name: await deviceService.deviceName,
      app_version: await deviceService.appVersion,
      os_version: await deviceService.osVersion,
      created_at: DateTime.now(),
    );

    await sessionDocRef.set(session);
    return session;
  }

  /// Prefix for user docs created when adding by phone+name (no signup yet).
  static const String pendingUserIdPrefix = 'phone_';

  static String _pendingUserId(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[\s+]'), '');
    return '$pendingUserIdPrefix$normalized';
  }

  static bool isPendingUserId(String id) =>
      id.startsWith(pendingUserIdPrefix);

  Future<(UserModel, ApiSession)> upsertUser({
    required String uid,
    required String phone,
  }) async {
    var user = await getUser(uid);
    user ??= await _createUser(uid, phone);
    final session = await _createSession(uid);
    return (user, session);
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final snapshot = await _userRef
          .where(FireStoreConst.phone, isEqualTo: phone)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  /// Creates or returns a user profile for someone added by phone+name
  /// without signup. Doc id is [pendingUserIdPrefix]+normalized phone.
  /// When they later sign in with that phone, [upsertUser] migrates to auth UID.
  Future<UserModel> createOrGetPendingUser({
    required String phone,
    required String name,
  }) async {
    final id = _pendingUserId(phone);
    final existing = await getUser(id);
    if (existing != null) {
      if (existing.name != name) {
        final updated = existing.copyWith(
          name: name,
          name_lowercase: name.toLowerCase(),
          updated_at: DateTime.now(),
        );
        await updateUser(updated);
        return updated;
      }
      return existing;
    }
    final user = UserModel(
      id: id,
      phone: phone,
      name: name,
      name_lowercase: name.toLowerCase(),
      created_at: DateTime.now(),
    );
    await _userRef.doc(id).set(user);
    return user;
  }

  /// Creates a real user doc from a pending user (after auth). Call from auth
  /// flow before replacing pending id in teams and deleting pending doc.
  Future<UserModel> createUserFromPending({
    required UserModel pendingUser,
    required String authUid,
  }) async {
    final newUser = pendingUser.copyWith(
      id: authUid,
      updated_at: DateTime.now(),
    );
    await _userRef.doc(authUid).set(newUser);
    return newUser;
  }

  Future<void> deleteUserById(String userId) async {
    try {
      await _userRef.doc(userId).delete();
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<UserModel?> getUser(String id) async {
    try {
      final snapshot = await _userRef.doc(id).get();
      return (snapshot.exists) ? snapshot.data() : null;
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    final List<UserModel> users = [];
    try {
      if (ids.isEmpty) return [];
      for (final tenIds in ids.chunked(10)) {
        final snapshot =
            await _userRef.where(FireStoreConst.id, whereIn: tenIds).get();

        users.addAll(snapshot.docs.map((user) => user.data()).toList());

        final deactivatedUserIds =
            tenIds.where((id) => !users.map((user) => user.id).contains(id));
        users.addAll(
          deactivatedUserIds.map(
            (id) => deActiveDummyUserAccount(id),
          ),
        );
      }

      return users;
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Stream<UserModel> streamUserById(String id) {
    return _userRef.doc(id).snapshots().map((snapshot) {
      final userModel = snapshot.data();
      if (userModel == null) {
        return deActiveDummyUserAccount(id);
      }
      return userModel;
    }).handleError((error, stack) {
      throw AppError.fromError(error, stack);
    });
  }

  Stream<List<UserStat>?> streamUserStats(String userId) {
    return _userStatsRef(userId).snapshots().map((snapshot) {
      return snapshot.docs.isEmpty
          ? null
          : snapshot.docs.map((e) => e.data()).toList();
    }).handleError((error, stack) => throw AppError.fromError(error, stack));
  }

  Future<UserStat?> getUserStats(String userId, UserStatType type) async {
    try {
      final snapshot = await _userStatsRef(userId)
          .where(FireStoreConst.type, isEqualTo: type.name)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      final userRef = _userRef.doc(user.id);
      await userRef.set(user, SetOptions(merge: true));
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<void> updateUserStats(String userId, UserStat stats) async {
    try {
      final userStatsRef = _userStatsRef(userId);

      await userStatsRef
          .doc(stats.type?.name)
          .set(stats, SetOptions(merge: true));
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<UserModel> _createUser(String userId, String phone) async {
    final user = UserModel(
      id: userId,
      phone: phone,
      created_at: DateTime.now(),
    );
    await _userRef.doc(userId).set(user);
    return user;
  }

  Future<void> deleteUser() async {
    try {
      await _userRef.doc(_currentUser?.id).delete();
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<List<UserModel>> searchUser(
    String searchKey, {
    int limit = 20,
    String? lastUserId,
  }) async {
    try {
      var query = _userRef
          .where(
            FireStoreConst.nameLowercase,
            isGreaterThanOrEqualTo: searchKey.toLowerCase(),
          )
          .where(
            FireStoreConst.nameLowercase,
            isLessThan: '${searchKey.toLowerCase()}z',
          )
          .orderBy(FireStoreConst.id);

      if (lastUserId != null) {
        query = query.startAfter([lastUserId]);
      }

      query = query.limit(limit);
      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    } catch (error, stack) {
      throw AppError.fromError(error, stack);
    }
  }

  Future<void> registerDevice(
    String sessionId, {
    required String userId,
    required String deviceToken,
  }) async {
    await _sessionRef(userId).doc(sessionId).update({
      FireStoreConst.deviceFcmToken: deviceToken,
    });
  }

  Future<void> updateUserNotificationSettings(
    String id,
    bool notifications,
  ) async {
    await _userRef
        .doc(id)
        .update({FireStoreConst.notifications: notifications});
  }
}

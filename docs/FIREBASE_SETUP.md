# Firebase setup guide for Run Scorer

This app uses **Firebase Core**, **Authentication**, **Cloud Firestore**, **Storage**, **Crashlytics**, and **Cloud Messaging**. Follow these steps to set up Firebase for local development and builds.

---

## Prerequisites

- A **Google account**
- **Flutter** installed and working (`flutter doctor`)
- **Node.js** (optional, for FlutterFire CLI)

---

## Step 1: Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (or **Create a project**).
3. Enter a project name (e.g. **Run Scorer**).
4. Disable Google Analytics if you don’t need it (you can enable it later).
5. Click **Create project** and wait until it’s ready.

---

## Step 2: Register your Android app

1. In the project overview, click the **Android** icon to add an Android app.
2. Use this **Android package name** (must match exactly):
   ```text
   com.qayham.runscorer
   ```
   You can find it in `runscorer/android/app/build.gradle` under `applicationId`.
3. Optionally set **App nickname** (e.g. Run Scorer) and **Debug signing certificate SHA-1** (needed later for Auth; you can add it in Project settings).
4. Click **Register app**.

---

## Step 3: Download Android config file

1. On the next screen, click **Download google-services.json**.
2. Place the file here in your repo:
   ```text
   runscorer/android/app/google-services.json
   ```
   Replace any existing file. Do **not** commit this file if it contains secrets; it’s listed in `.gitignore`.

---

## Step 4: Register your iOS app (if you build for iOS)

1. In Firebase Console, click **Add app** → **iOS**.
2. Use the **iOS bundle ID** from Xcode (e.g. from `runscorer/ios/Runner.xcodeproj` or `Info.plist`). It’s often the same as the Android package name or similar (e.g. `com.qayham.runscorer`).
3. Register the app, then **Download GoogleService-Info.plist**.
4. Place it at:
   ```text
   runscorer/ios/Runner/GoogleService-Info.plist
   ```
   Add it to the Runner target in Xcode if it doesn’t appear automatically. This file is in `.gitignore`.

---

## Step 5: Generate `firebase_options.dart` (FlutterFire)

The app expects `lib/firebase_options.dart` with `DefaultFirebaseOptions.currentPlatform`. The recommended way to generate it is the **FlutterFire CLI**.

### 5.1 Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Ensure global bins are on your `PATH`. For example on Windows (PowerShell):

```powershell
$env:PATH += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
```

### 5.2 Configure Firebase in your app

1. Open a terminal and go to the **Flutter app** directory:
   ```bash
   cd runscorer
   ```
2. Log in to Firebase (opens browser):
   ```bash
   firebase login
   ```
3. Run the config command:
   ```bash
   flutterfire configure
   ```
   - Select your Firebase project.
   - Select the platforms you use (e.g. Android, iOS).
   - The CLI will create/update `lib/firebase_options.dart` and ensure Android/iOS config files are in place.

If you already have `google-services.json` and (for iOS) `GoogleService-Info.plist` in the right places, `flutterfire configure` will still generate `firebase_options.dart` and link the app to the project.

---

## Step 6: Enable Firebase services in the Console

Enable the services the app uses so they don’t throw errors at runtime.

### Authentication

1. In Firebase Console, go to **Build** → **Authentication**.
2. Click **Get started**.
3. Open the **Sign-in method** tab and enable:
   - **Phone** (the app uses phone sign-in).

### Cloud Firestore

1. Go to **Build** → **Firestore Database**.
2. Click **Create database**.
3. Choose **Start in test mode** for development (or **Production** and then set rules).
4. Pick a location close to your users and confirm.

**Important:** If you started in **test mode**, the default rules allow read/write for 30 days. If you used production mode or the test period expired, you must set rules. Otherwise you will see **PERMISSION_DENIED** when the app reads/writes (e.g. after phone sign-in when loading the user document).

**Rules for Run Scorer (development):** The same rules are in **`runscorer/firestore.rules`**. Deploy them with the Firebase CLI (see below) or paste the block into **Firestore Database** → **Rules** in the Firebase Console and click Publish. They allow any **authenticated** user to read and write the collections the app uses (users, matches, tournaments, teams, leaderboard, etc.).

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create, update, delete: if request.auth.uid == userId;
      match /user_sessions/{sessionId} {
        allow read, write: if request.auth.uid == userId;
      }
      match /user_stat/{statId} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    match /matches/{matchId} {
      allow read, write: if request.auth != null;
      match /match_settings/{docId} {
        allow read, write: if request.auth != null;
      }
    }
    match /tournaments/{tournamentId} {
      allow read, write: if request.auth != null;
      match /team_stats/{docId} {
        allow read, write: if request.auth != null;
      }
      match /player_key_stats/{docId} {
        allow read, write: if request.auth != null;
      }
    }
    match /teams/{teamId} {
      allow read, write: if request.auth != null;
      match /team_stat/{docId} {
        allow read, write: if request.auth != null;
      }
    }
    match /leaderboard/{typeDoc} {
      allow read, write: if request.auth != null;
      match /data/{docId} {
        allow read, write: if request.auth != null;
      }
    }
    match /innings/{inningId} {
      allow read, write: if request.auth != null;
    }
    match /ball_scores/{scoreId} {
      allow read, write: if request.auth != null;
    }
    match /match_events/{eventId} {
      allow read, write: if request.auth != null;
    }
    match /partnerships/{docId} {
      allow read, write: if request.auth != null;
    }
    match /contact_support/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Before production:** Tighten rules (e.g. only match creator can update/delete a match, only team members can read a team).

**Deploy rules from the repo (recommended):** The project includes `runscorer/firestore.rules` and `runscorer/firebase.json`. To deploy rules from the CLI:

1. Install [Firebase CLI](https://firebase.google.com/docs/cli) and run `firebase login`.
2. From the app directory, select your project (if not already set):
   ```bash
   cd runscorer
   firebase use <your-firebase-project-id>
   ```
   Or run `flutterfire configure` once; it sets the project in `.firebaserc`.
3. Deploy Firestore rules and indexes:
   ```bash
   firebase deploy --only firestore
   ```
   Or deploy only rules or only indexes:
   ```bash
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```

Edit `firestore.rules` and `firestore.indexes.json` locally, then run the deploy command to push changes. **Indexes** can take a few minutes to build in the Firebase Console after deployment; the app may show "The query requires an index" until they are ready.

Later, tighten security rules before production.

### Storage

1. Go to **Build** → **Storage**.
2. Click **Get started**.
3. Use test mode for dev or set your rules and confirm.

### Crashlytics

1. Go to **Build** → **Crashlytics**.
2. Click **Enable** and follow the steps (Android/iOS may need a rebuild).

### Cloud Messaging (FCM)

1. Go to **Build** → **Cloud Messaging**.
2. No extra switch to flip; it works once the app is registered and config files are in place.
3. For push notifications you may need to upload APNs key/certificate (iOS) and optionally set up a server.

---

## Step 7: (Optional) SHA-1 for Android Auth

For **phone sign-in** and some Auth features on Android, Firebase uses your app’s SHA-1.

1. Get your debug SHA-1:
   ```bash
   cd runscorer/android
   ./gradlew signingReport
   ```
   On Windows use `gradlew.bat signingReport`. Copy the **SHA-1** under `debug`.
2. In Firebase Console go to **Project settings** (gear) → **Your apps** → your Android app.
3. Click **Add fingerprint**, paste the SHA-1, and save.

---

## Step 8: Verify setup

1. Ensure these exist (and are not committed if they contain secrets):
   - `runscorer/lib/firebase_options.dart`
   - `runscorer/android/app/google-services.json`
   - `runscorer/ios/Runner/GoogleService-Info.plist` (only for iOS)
2. From the app directory:
   ```bash
   cd runscorer
   flutter pub get
   flutter run
   ```
3. If the app starts and you can open Auth/Firestore screens without Firebase errors, setup is correct.

---

## File summary

| File | Location | How you get it |
|------|----------|----------------|
| `google-services.json` | `runscorer/android/app/` | Firebase Console → Project settings → Your apps → Android → Download |
| `GoogleService-Info.plist` | `runscorer/ios/Runner/` | Firebase Console → Add iOS app → Download |
| `firebase_options.dart` | `runscorer/lib/` | `flutterfire configure` (FlutterFire CLI) |

---

## Troubleshooting

- **“DefaultFirebaseOptions not found”**  
  Run `flutterfire configure` from the `runscorer` directory and ensure `lib/firebase_options.dart` is generated.

- **“google-services.json is missing”**  
  Download it from Firebase Console and place it in `runscorer/android/app/`.

- **Auth / Firestore “permission denied” or “not enabled”**  
  Enable the service in Firebase Console and check Security Rules (test mode is permissive; lock rules for production).

- **Build fails with Firebase/Crashlytics errors**  
  Ensure `google-services.json` and `firebase_options.dart` are present and that you’ve run `flutter clean` then `flutter pub get` and rebuilt.

---

## CI (GitHub Actions)

For automated builds, store the contents of these files as **base64** in GitHub Actions secrets and decode them in the workflow (as in `.github/workflows/android_build.yml`):

- `FIREBASE_OPTIONS_BASE64` → decoded to `lib/firebase_options.dart`
- `GOOGLE_SERVICES_JSON_BASE64` → decoded to `android/app/google-services.json`

Generate base64 (example for PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("runscorer\lib\firebase_options.dart"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("runscorer\android\app\google-services.json"))
```

Then add those strings as repository secrets in **Settings → Secrets and variables → Actions**.

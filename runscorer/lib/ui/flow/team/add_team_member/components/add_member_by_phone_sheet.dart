import 'package:canopas_country_picker/canopas_country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:runscorer/components/country_code_view.dart';
import 'package:runscorer/domain/extensions/context_extensions.dart';
import 'package:runscorer/ui/flow/score_board/components/bottom_sheet_wrapper.dart';
import 'package:style/button/primary_button.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/text/app_text_field.dart';
import 'package:style/text/app_text_style.dart';

class AddMemberByPhoneSheet extends StatefulWidget {
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function({
      required String countryDialCode,
      required String phoneNumber,
      required String name,
    }) onAdd,
  }) {
    HapticFeedback.mediumImpact();

    return showModalBottomSheet(
      context: context,
      showDragHandle: false,
      enableDrag: false,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.colorScheme.surface,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddMemberByPhoneSheet(onAdd: onAdd),
      ),
    );
  }

  final Future<void> Function({
    required String countryDialCode,
    required String phoneNumber,
    required String name,
  }) onAdd;

  const AddMemberByPhoneSheet({super.key, required this.onAdd});

  @override
  State<AddMemberByPhoneSheet> createState() => _AddMemberByPhoneSheetState();
}

class _AddMemberByPhoneSheetState extends State<AddMemberByPhoneSheet> {
  late CountryCode _countryCode;
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _countryCode = CountryCode.getCountryCodeByAlpha2(
      countryAlpha2Code:
          WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
    _phoneController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty || name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await widget.onAdd(
        countryDialCode: _countryCode.dialCode,
        phoneNumber: phone,
        name: name,
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final canSubmit = phone.isNotEmpty && name.isNotEmpty && !_loading;

    return BottomSheetWrapper(
      contentBottomSpacing: 30,
      content: _content(context),
      action: [
        PrimaryButton(
          context.l10n.common_cancel_title,
          expanded: false,
          background: context.colorScheme.containerLow,
          foreground: context.colorScheme.primary,
          onPressed: _loading ? null : () => context.pop(),
        ),
        PrimaryButton(
          context.l10n.common_add_title,
          expanded: false,
          enabled: canSubmit,
          progress: _loading,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.add_team_member_add_by_phone_title,
          style: AppTextStyle.header3
              .copyWith(color: context.colorScheme.textPrimary),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CountryCodeView(
              countryCode: _countryCode,
              onCodeChange: (code) => setState(() => _countryCode = code),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _phoneController,
                onChanged: (_) => setState(() {}),
                borderType: AppTextFieldBorderType.outline,
                hintText: context.l10n.add_team_member_phone_hint,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          borderType: AppTextFieldBorderType.outline,
          hintText: context.l10n.add_team_member_name_hint,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

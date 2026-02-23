import 'package:flutter/material.dart';
import 'package:runscorer/l10n/app_localizations.dart';

extension BuildContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get is24HourFormat => MediaQuery.of(this).alwaysUse24HourFormat;
}

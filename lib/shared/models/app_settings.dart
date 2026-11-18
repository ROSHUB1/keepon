import 'package:flutter/material.dart';

class ApplicationSettings {
  const ApplicationSettings({
    this.themeMode = ThemeMode.system,
    this.notifySecurity = true,
    this.notifyAlarm = true,
    this.requireAuth = true,
    this.theftProtectionReviewed = false,
    this.onboardingDone = false,
  });

  final ThemeMode themeMode;
  final bool notifySecurity;
  final bool notifyAlarm;

  /// Ask for the device PIN/pattern/fingerprint before turning protection off or stopping the alarm.
  final bool requireAuth;

  /// The user opened Android's theft protection settings (KEEPON cannot read their state).
  final bool theftProtectionReviewed;

  /// The intro screens and permission guide were completed (or skipped).
  final bool onboardingDone;

  ApplicationSettings copyWith({
    ThemeMode? themeMode,
    bool? notifySecurity,
    bool? notifyAlarm,
    bool? requireAuth,
    bool? theftProtectionReviewed,
    bool? onboardingDone,
  }) =>
      ApplicationSettings(
        themeMode: themeMode ?? this.themeMode,
        notifySecurity: notifySecurity ?? this.notifySecurity,
        notifyAlarm: notifyAlarm ?? this.notifyAlarm,
        requireAuth: requireAuth ?? this.requireAuth,
        theftProtectionReviewed: theftProtectionReviewed ?? this.theftProtectionReviewed,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );

  Map<String, dynamic> toJson() => {
        'theme': themeMode.name,
        'notifySecurity': notifySecurity,
        'notifyAlarm': notifyAlarm,
        'requireAuth': requireAuth,
        'theftReviewed': theftProtectionReviewed,
        'onboardingDone': onboardingDone,
      };

  factory ApplicationSettings.fromJson(Map<String, dynamic> j) => ApplicationSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['theme'],
          orElse: () => ThemeMode.system,
        ),
        notifySecurity: j['notifySecurity'] as bool? ?? true,
        notifyAlarm: j['notifyAlarm'] as bool? ?? true,
        requireAuth: j['requireAuth'] as bool? ?? true,
        theftProtectionReviewed: j['theftReviewed'] as bool? ?? false,
        onboardingDone: j['onboardingDone'] as bool? ?? false,
      );
}

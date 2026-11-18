import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Distinct protection states. READY never means ACTIVE: ACTIVE is only shown
/// when the monitoring service is confirmed running.
enum ModuleStatus {
  off,
  ready,
  active,
  permissionRequired,
  unsupported,
  unavailable,
  error,
}

extension ModuleStatusX on ModuleStatus {
  String get label => switch (this) {
        ModuleStatus.off => 'Off',
        ModuleStatus.ready => 'Ready',
        ModuleStatus.active => 'Active',
        ModuleStatus.permissionRequired => 'Permission required',
        ModuleStatus.unsupported => 'Unsupported',
        ModuleStatus.unavailable => 'Unavailable',
        ModuleStatus.error => 'Error',
      };

  /// Base color (icons, tints).
  Color get color => switch (this) {
        ModuleStatus.off => AppColors.textSecondary,
        ModuleStatus.ready => AppColors.primary,
        ModuleStatus.active => AppColors.success,
        ModuleStatus.permissionRequired => AppColors.warning,
        ModuleStatus.unsupported => AppColors.textSecondary,
        ModuleStatus.unavailable => AppColors.textSecondary,
        ModuleStatus.error => AppColors.error,
      };

  /// Text color with enough contrast on a tinted background.
  Color foreground(bool dark) {
    if (dark) {
      return switch (this) {
        ModuleStatus.ready => const Color(0xFF8DB4F5),
        ModuleStatus.active => const Color(0xFF4CC38A),
        ModuleStatus.permissionRequired => const Color(0xFFE8B25A),
        ModuleStatus.error => const Color(0xFFEF8A8A),
        _ => const Color(0xFF9AA9BC),
      };
    }
    return switch (this) {
      ModuleStatus.ready => AppColors.primaryDeep,
      ModuleStatus.active => const Color(0xFF1B7A52),
      ModuleStatus.permissionRequired => const Color(0xFF9A6A12),
      ModuleStatus.error => const Color(0xFFB03F3F),
      _ => const Color(0xFF5D6B7E),
    };
  }
}

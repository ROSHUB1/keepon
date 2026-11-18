import 'package:flutter/material.dart';

/// KEEPON brand and semantic colors (light-theme values).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF246FE5);
  static const primaryDeep = Color(0xFF1758C7);
  static const primarySoft = Color(0xFFEAF2FF);
  static const background = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF172B45);
  static const textSecondary = Color(0xFF77869A);
  static const border = Color(0xFFE4EAF2);

  static const success = Color(0xFF269B69);
  static const warning = Color(0xFFD99A32);
  static const error = Color(0xFFD95353);

  // Aliases kept for existing call sites.
  static const critical = error;
  static const info = primary;
  static const slate = textSecondary;
}

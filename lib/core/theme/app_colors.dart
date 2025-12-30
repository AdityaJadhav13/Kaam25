import 'package:flutter/material.dart';

/// Centralized design tokens for the app's light theme.
abstract final class AppColors {
  // Light theme colors
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF111111);

  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF030213);
  static const primaryForeground = Color(0xFFFFFFFF);

  static const secondary = Color(0xFFF2F2F6);
  static const secondaryForeground = Color(0xFF030213);

  static const muted = Color(0xFFECECF0);
  static const mutedForeground = Color(0xFF717182);

  static const accent = Color(0xFFE9EBEF);
  static const accentForeground = Color(0xFF030213);

  static const destructive = Color(0xFFD4183D);
  static const destructiveForeground = Color(0xFFFFFFFF);

  static const border = Color(0x1A000000);
  static const inputBackground = Color(0xFFF3F3F5);

  // Status helper colors
  static const warning = Color(0xFFF59E0B);
  static const warningBackground = Color(0x1AF59E0B);
  static const danger = Color(0xFFDC2626);
  static const dangerBackground = Color(0x1ADC2626);
  static const success = Color(0xFF16A34A);
}

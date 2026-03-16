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

/// Premium dark theme design tokens.
/// Deep charcoal backgrounds, soft off-white text, same brand colors.
abstract final class DarkColors {
  // Core backgrounds - deep charcoal, not pure black
  static const background = Color(0xFF0A0A0B);
  static const foreground = Color(0xFFF4F4F5); // Soft off-white

  static const card = Color(0xFF141416);
  static const cardElevated = Color(0xFF1A1A1D); // For elevated cards/dialogs

  // Keep same primary brand color
  static const primary = Color(0xFF030213);
  static const primaryForeground = Color(0xFFFFFFFF);

  // Secondary uses muted dark tones
  static const secondary = Color(0xFF27272A);
  static const secondaryForeground = Color(0xFFF4F4F5);

  // Muted colors for subtle UI
  static const muted = Color(0xFF27272A);
  static const mutedForeground = Color(0xFFA1A1AA); // Zinc-400

  // Accent for hover/focus states
  static const accent = Color(0xFF27272A);
  static const accentForeground = Color(0xFFF4F4F5);

  // Status colors - slightly brighter for dark backgrounds
  static const destructive = Color(0xFFEF4444); // Red-500
  static const destructiveForeground = Color(0xFFFFFFFF);

  static const border = Color(0xFF27272A);
  static const inputBackground = Color(0xFF18181B);

  // Status helper colors
  static const warning = Color(0xFFFBBF24); // Amber-400
  static const warningBackground = Color(0x33FBBF24);
  static const danger = Color(0xFFEF4444); // Red-500
  static const dangerBackground = Color(0x33EF4444);
  static const success = Color(0xFF22C55E); // Green-500
  static const successBackground = Color(0x3322C55E);

  // Message bubbles
  static const ownMessageBackground = Color(0xFF030213);
  static const ownMessageForeground = Color(0xFFFFFFFF);
  static const otherMessageBackground = Color(0xFF27272A);
  static const otherMessageForeground = Color(0xFFF4F4F5);

  // Overlays and surfaces
  static const overlay = Color(0x80000000);
  static const surfaceDim = Color(0xFF09090B);
}

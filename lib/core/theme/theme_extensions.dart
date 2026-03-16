import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension on BuildContext for easy access to theme-aware colors.
/// This allows widgets to get the correct colors based on current theme mode.
extension ThemeColors on BuildContext {
  /// Whether the current theme is dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Get the appropriate colors based on current theme
  ThemeColorSet get colors =>
      isDarkMode ? const DarkColorSet() : const LightColorSet();

  /// Quick access to color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Quick access to text theme
  TextTheme get textTheme => Theme.of(this).textTheme;
}

/// Abstract base class for theme color sets
abstract class ThemeColorSet {
  const ThemeColorSet();

  Color get background;
  Color get foreground;
  Color get card;
  Color get cardElevated;
  Color get primary;
  Color get primaryForeground;
  Color get secondary;
  Color get secondaryForeground;
  Color get muted;
  Color get mutedForeground;
  Color get accent;
  Color get accentForeground;
  Color get destructive;
  Color get destructiveForeground;
  Color get border;
  Color get inputBackground;
  Color get warning;
  Color get warningBackground;
  Color get danger;
  Color get dangerBackground;
  Color get success;

  /// Colors for message bubbles
  Color get ownMessageBackground;
  Color get ownMessageForeground;
  Color get otherMessageBackground;
  Color get otherMessageForeground;
}

/// Light theme color set implementation
class LightColorSet extends ThemeColorSet {
  const LightColorSet();

  @override
  Color get background => AppColors.background;
  @override
  Color get foreground => AppColors.foreground;
  @override
  Color get card => AppColors.card;
  @override
  Color get cardElevated => AppColors.card;
  @override
  Color get primary => AppColors.primary;
  @override
  Color get primaryForeground => AppColors.primaryForeground;
  @override
  Color get secondary => AppColors.secondary;
  @override
  Color get secondaryForeground => AppColors.secondaryForeground;
  @override
  Color get muted => AppColors.muted;
  @override
  Color get mutedForeground => AppColors.mutedForeground;
  @override
  Color get accent => AppColors.accent;
  @override
  Color get accentForeground => AppColors.accentForeground;
  @override
  Color get destructive => AppColors.destructive;
  @override
  Color get destructiveForeground => AppColors.destructiveForeground;
  @override
  Color get border => AppColors.border;
  @override
  Color get inputBackground => AppColors.inputBackground;
  @override
  Color get warning => AppColors.warning;
  @override
  Color get warningBackground => AppColors.warningBackground;
  @override
  Color get danger => AppColors.danger;
  @override
  Color get dangerBackground => AppColors.dangerBackground;
  @override
  Color get success => AppColors.success;

  // Light mode message colors
  @override
  Color get ownMessageBackground => AppColors.primary;
  @override
  Color get ownMessageForeground => AppColors.primaryForeground;
  @override
  Color get otherMessageBackground => AppColors.muted;
  @override
  Color get otherMessageForeground => AppColors.foreground;
}

/// Dark theme color set implementation
class DarkColorSet extends ThemeColorSet {
  const DarkColorSet();

  @override
  Color get background => DarkColors.background;
  @override
  Color get foreground => DarkColors.foreground;
  @override
  Color get card => DarkColors.card;
  @override
  Color get cardElevated => DarkColors.cardElevated;
  @override
  Color get primary => DarkColors.primary;
  @override
  Color get primaryForeground => DarkColors.primaryForeground;
  @override
  Color get secondary => DarkColors.secondary;
  @override
  Color get secondaryForeground => DarkColors.secondaryForeground;
  @override
  Color get muted => DarkColors.muted;
  @override
  Color get mutedForeground => DarkColors.mutedForeground;
  @override
  Color get accent => DarkColors.accent;
  @override
  Color get accentForeground => DarkColors.accentForeground;
  @override
  Color get destructive => DarkColors.destructive;
  @override
  Color get destructiveForeground => DarkColors.destructiveForeground;
  @override
  Color get border => DarkColors.border;
  @override
  Color get inputBackground => DarkColors.inputBackground;
  @override
  Color get warning => DarkColors.warning;
  @override
  Color get warningBackground => DarkColors.warningBackground;
  @override
  Color get danger => DarkColors.danger;
  @override
  Color get dangerBackground => DarkColors.dangerBackground;
  @override
  Color get success => DarkColors.success;

  // Dark mode message colors
  @override
  Color get ownMessageBackground => DarkColors.ownMessageBackground;
  @override
  Color get ownMessageForeground => DarkColors.ownMessageForeground;
  @override
  Color get otherMessageBackground => DarkColors.otherMessageBackground;
  @override
  Color get otherMessageForeground => DarkColors.otherMessageForeground;
}

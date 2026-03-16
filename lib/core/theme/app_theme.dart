import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const double _radius = 10; // 0.625rem ≈ 10px

  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: Colors.transparent,
    );

    return base.copyWith(
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  /// Premium dark theme for KAAM25
  /// Deep charcoal backgrounds, soft off-white text, same brand identity
  static ThemeData dark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: DarkColors.primary,
      onPrimary: DarkColors.primaryForeground,
      secondary: DarkColors.secondary,
      onSecondary: DarkColors.secondaryForeground,
      error: DarkColors.destructive,
      onError: DarkColors.destructiveForeground,
      surface: DarkColors.background,
      onSurface: DarkColors.foreground,
      surfaceContainerHighest: DarkColors.cardElevated,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DarkColors.background,
      dividerColor: Colors.transparent,
    );

    return base.copyWith(
      // Dividers
      dividerTheme: const DividerThemeData(
        color: DarkColors.border,
        thickness: 1,
        space: 0,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkColors.background,
        foregroundColor: DarkColors.foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: DarkColors.foreground),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: DarkColors.card,
        surfaceTintColor: DarkColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: DarkColors.border, width: 1),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkColors.inputBackground,
        hintStyle: const TextStyle(color: DarkColors.mutedForeground),
        labelStyle: const TextStyle(color: DarkColors.mutedForeground),
        prefixIconColor: DarkColors.mutedForeground,
        suffixIconColor: DarkColors.mutedForeground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: DarkColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: DarkColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
            color: DarkColors.foreground,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: DarkColors.destructive, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
            color: DarkColors.destructive,
            width: 1.5,
          ),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkColors.foreground,
          foregroundColor: DarkColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarkColors.foreground,
          side: const BorderSide(color: DarkColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DarkColors.foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // Chips
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: DarkColors.secondary,
        selectedColor: DarkColors.primary,
        labelStyle: const TextStyle(color: DarkColors.foreground),
        side: const BorderSide(color: DarkColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      // List tiles
      listTileTheme: const ListTileThemeData(
        iconColor: DarkColors.mutedForeground,
        textColor: DarkColors.foreground,
        tileColor: Colors.transparent,
      ),

      // Icons
      iconTheme: const IconThemeData(color: DarkColors.mutedForeground),

      // Text
      textTheme: base.textTheme.apply(
        bodyColor: DarkColors.foreground,
        displayColor: DarkColors.foreground,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius * 1.5),
          side: const BorderSide(color: DarkColors.border, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: DarkColors.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: DarkColors.mutedForeground,
          fontSize: 14,
        ),
      ),

      // Bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DarkColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: DarkColors.muted,
        modalBarrierColor: DarkColors.overlay,
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DarkColors.cardElevated,
        contentTextStyle: const TextStyle(color: DarkColors.foreground),
        actionTextColor: DarkColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Popup menus
      popupMenuTheme: PopupMenuThemeData(
        color: DarkColors.cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: DarkColors.border, width: 1),
        ),
        textStyle: const TextStyle(color: DarkColors.foreground),
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DarkColors.foreground,
        foregroundColor: DarkColors.background,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DarkColors.foreground,
        linearTrackColor: DarkColors.muted,
        circularTrackColor: DarkColors.muted,
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DarkColors.foreground;
          }
          return DarkColors.mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DarkColors.primary;
          }
          return DarkColors.muted;
        }),
      ),

      // Checkboxes
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DarkColors.foreground;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(DarkColors.background),
        side: const BorderSide(color: DarkColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio buttons
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DarkColors.foreground;
          }
          return DarkColors.mutedForeground;
        }),
      ),

      // Slider
      sliderTheme: const SliderThemeData(
        activeTrackColor: DarkColors.foreground,
        inactiveTrackColor: DarkColors.muted,
        thumbColor: DarkColors.foreground,
        overlayColor: Color(0x33FFFFFF),
      ),

      // Tabs
      tabBarTheme: const TabBarThemeData(
        labelColor: DarkColors.foreground,
        unselectedLabelColor: DarkColors.mutedForeground,
        indicatorColor: DarkColors.foreground,
        dividerColor: DarkColors.border,
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DarkColors.card,
        indicatorColor: DarkColors.secondary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DarkColors.foreground);
          }
          return const IconThemeData(color: DarkColors.mutedForeground);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: DarkColors.foreground, fontSize: 12);
          }
          return const TextStyle(
            color: DarkColors.mutedForeground,
            fontSize: 12,
          );
        }),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: DarkColors.card,
        surfaceTintColor: Colors.transparent,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: DarkColors.cardElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DarkColors.border),
        ),
        textStyle: const TextStyle(color: DarkColors.foreground, fontSize: 12),
      ),
    );
  }
}

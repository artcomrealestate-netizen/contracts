import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors Material 3's ColorScheme doesn't define on its own (only
/// error/success-ish roles exist natively) — used for the "needs attention
/// but isn't an error" banners/badges (e.g. a rejected contract's note, a
/// clause flagged for revision). Defined as a ThemeExtension, the same way
/// ColorScheme itself works, so it lerps correctly and stays theme-aware
/// (light/dark) instead of a hardcoded Colors.orange.shadeNNN literal
/// scattered across screens.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  final Color warningContainer;
  final Color onWarningContainer;
  final Color warningBorder;
  // A "completed/positive" accent distinct from the primary brand color —
  // used only for Finalize, the one action that's intentionally visually
  // different from every other (reversible) button in the app.
  final Color success;
  final Color onSuccess;

  /// Falls back to the light palette if the app's theme isn't in the tree
  /// (e.g. a test harness that builds its own bare MaterialApp) — safer than
  /// a force-unwrapped `Theme.of(context).extension<AppStatusColors>()!`,
  /// which throws in exactly that situation.
  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>() ?? AppStatusColors.light;

  const AppStatusColors({
    required this.warningContainer,
    required this.onWarningContainer,
    required this.warningBorder,
    required this.success,
    required this.onSuccess,
  });

  static const light = AppStatusColors(
    warningContainer: Color(0xFFFFF2D6),
    onWarningContainer: Color(0xFF7A4A00),
    warningBorder: Color(0xFFF0C674),
    success: Color(0xFF1E8E5A),
    onSuccess: Color(0xFFFFFFFF),
  );

  static const dark = AppStatusColors(
    warningContainer: Color(0xFF4A3600),
    onWarningContainer: Color(0xFFFFDA9E),
    warningBorder: Color(0xFF8A6A1F),
    success: Color(0xFF1F7A50),
    onSuccess: Color(0xFFFFFFFF),
  );

  @override
  AppStatusColors copyWith({
    Color? warningContainer,
    Color? onWarningContainer,
    Color? warningBorder,
    Color? success,
    Color? onSuccess,
  }) {
    return AppStatusColors(
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      warningBorder: warningBorder ?? this.warningBorder,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    );
  }
}

/// App-wide spacing scale (4pt/8dp rhythm) — use these instead of ad-hoc
/// SizedBox/EdgeInsets numbers so spacing stays consistent across screens.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppTheme {
  AppTheme._();

  // iOS system blue — the most immediately recognizable "Apple" color,
  // and a safe seed: ColorScheme.fromSeed derives a full tonal palette from
  // it with guaranteed AA contrast pairs for both light and dark.
  static const _seedColor = Color(0xFF0A84FF);

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    // Inter reads as the closest widely-available match to San Francisco's
    // clean, neutral geometry — recommended for dashboards/admin/enterprise
    // apps specifically (vs. a display/marketing pairing) by the design
    // system this was chosen from.
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      extensions: [isDark ? AppStatusColors.dark : AppStatusColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

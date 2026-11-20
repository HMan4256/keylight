import 'package:material_ui/material_ui.dart';

abstract final class StudioColors {
  static const background = Color(0xFF000000);
  static const panel = Color(0xFF101214);
  static const raised = Color(0xFF202621);
  static const border = Color(0xFF414844);
  static const muted = Color(0xFF9AA8B5);
  static const ink = Color(0xFFF0F3EE);
  static const mint = Color(0xFF9DFF73);
  static const amber = Color(0xFFFFC55A);
  static const blue = Color(0xFFA8C9FF);
  static const violet = Color(0xFFCBB4FF);
}

ThemeData studioTheme() => ThemeData(
  fontFamily: 'Pixelify',
  fontFamilyFallback: const ['TheorySymbols'],
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(side: BorderSide(color: StudioColors.border)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(shape: const RoundedRectangleBorder()),
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: StudioColors.background,
  colorScheme: const ColorScheme.dark(
    primary: StudioColors.mint,
    onPrimary: StudioColors.background,
    surface: StudioColors.panel,
    onSurface: StudioColors.ink,
    secondary: StudioColors.amber,
    outline: StudioColors.border,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 38,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.5,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.6,
    ),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: StudioColors.muted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Pixelify',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  dividerColor: StudioColors.border,
);

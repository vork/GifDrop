import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/converter_screen.dart';

void main() {
  runApp(const GifConverterApp());
}

class GifConverterApp extends StatelessWidget {
  const GifConverterApp({super.key});

  static const _accent = Color(0xFFF59E0C);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF010817);
    final background = isDark ? const Color(0xFF010817) : const Color(0xFFFFFFFF);

    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final interactiveStyle = GoogleFonts.staatliches(color: textColor);

    final textTheme = GoogleFonts.dmSansTextTheme(baseTextTheme).copyWith(
      labelLarge: interactiveStyle,
      labelMedium: interactiveStyle,
      labelSmall: interactiveStyle,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: _accent,
              onPrimary: Colors.white,
              secondary: _accent,
              onSecondary: Colors.white,
              surface: background,
              onSurface: textColor,
            )
          : ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              secondary: _accent,
              onSecondary: Colors.white,
              surface: background,
              onSurface: textColor,
            ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.staatliches(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.staatliches(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: GoogleFonts.staatliches(),
        ),
      ),
      textTheme: textTheme,
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GifDrop',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const ConverterScreen(),
    );
  }
}

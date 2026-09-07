import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y estilos centrales de AgroTrade Direct.
///
/// Tomados del mockup de Figma: fondo café oscuro casi negro, acentos en
/// dorado (café/cacao), tarjetas ligeramente más claras que el fondo, y
/// colores de estado (verde = activo/confirmado, naranja = en negociación).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF1B0E10);
  static const Color surface = Color(0xFF2A1519);
  static const Color surfaceAlt = Color(0xFF241214);
  static const Color border = Color(0xFF3D2226);

  static const Color gold = Color(0xFFD9A929);
  static const Color goldDark = Color(0xFFB8891F);

  static const Color textPrimary = Color(0xFFF5EDE6);
  static const Color textSecondary = Color(0xFFB8A39B);
  static const Color textMuted = Color(0xFF8A7570);

  static const Color statusActive = Color(0xFF4CAF50);
  static const Color statusNegotiating = Color(0xFFE07856);
  static const Color statusTransit = Color(0xFFD9A929);

  static const Color priceUp = Color(0xFF4CAF50);
  static const Color priceDown = Color(0xFFE05C5C);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      // "Live Market", "AgroTrade Direct", nombres de ofertas -> serif elegante
      headlineLarge: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.gold,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        error: AppColors.priceDown,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}

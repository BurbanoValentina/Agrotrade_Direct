import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta dinámica de colores de AgroTrade Direct (ThemeExtension).
/// Permite transiciones fluidas entre el modo claro pastel y el modo oscuro cálido.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.gold,
    required this.goldDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.statusActive,
    required this.statusNegotiating,
    required this.statusTransit,
    required this.priceUp,
    required this.priceDown,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color gold;
  final Color goldDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color statusActive;
  final Color statusNegotiating;
  final Color statusTransit;
  final Color priceUp;
  final Color priceDown;
  final bool isDark;

  /// Paleta cálida oscura refinada: café tostado profundo, obsidiana y oro champaña.
  static const dark = AppThemeColors(
    background: Color(0xFF0F0B0C),
    surface: Color(0xFF1B1416),
    surfaceAlt: Color(0xFF261D20),
    border: Color(0xFF382A2E),
    gold: Color(0xFFE5B842),
    goldDark: Color(0xFFBF9325),
    textPrimary: Color(0xFFFAF6F2),
    textSecondary: Color(0xFFB8A69E),
    textMuted: Color(0xFF7D6C65),
    statusActive: Color(0xFF10B981),
    statusNegotiating: Color(0xFFF97316),
    statusTransit: Color(0xFF3B82F6),
    priceUp: Color(0xFF10B981),
    priceDown: Color(0xFFEF4444),
    isDark: true,
  );

  /// Paleta pastel clara refinada: marfil cálido, latte suave y ámbar caramelo.
  static const light = AppThemeColors(
    background: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3ECE2),
    border: Color(0xFFE4D9CD),
    gold: Color(0xFFB87D1B),
    goldDark: Color(0xFF8F5E0D),
    textPrimary: Color(0xFF1F140E),
    textSecondary: Color(0xFF6E5A51),
    textMuted: Color(0xFF9E8B82),
    statusActive: Color(0xFF059669),
    statusNegotiating: Color(0xFFEA580C),
    statusTransit: Color(0xFF2563EB),
    priceUp: Color(0xFF059669),
    priceDown: Color(0xFFDC2626),
    isDark: false,
  );

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? gold,
    Color? goldDark,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? statusActive,
    Color? statusNegotiating,
    Color? statusTransit,
    Color? priceUp,
    Color? priceDown,
    bool? isDark,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      gold: gold ?? this.gold,
      goldDark: goldDark ?? this.goldDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      statusActive: statusActive ?? this.statusActive,
      statusNegotiating: statusNegotiating ?? this.statusNegotiating,
      statusTransit: statusTransit ?? this.statusTransit,
      priceUp: priceUp ?? this.priceUp,
      priceDown: priceDown ?? this.priceDown,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldDark: Color.lerp(goldDark, other.goldDark, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      statusActive: Color.lerp(statusActive, other.statusActive, t)!,
      statusNegotiating:
          Color.lerp(statusNegotiating, other.statusNegotiating, t)!,
      statusTransit: Color.lerp(statusTransit, other.statusTransit, t)!,
      priceUp: Color.lerp(priceUp, other.priceUp, t)!,
      priceDown: Color.lerp(priceDown, other.priceDown, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Extensión para acceder cómodamente a los colores del tema actual desde el BuildContext.
extension AppThemeContext on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Compatibilidad hacia atrás con código existente que use AppColors directamente.
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

  /// Obtiene los colores correspondientes al contexto activo.
  static AppThemeColors of(BuildContext context) => context.colors;
}

class AppTheme {
  AppTheme._();

  /// Configuración del tema oscuro (obsidiana profundo, café cálido y oro champaña).
  static ThemeData get darkTheme {
    const palette = AppThemeColors.dark;
    final base = ThemeData.dark();

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: palette.textSecondary,
        fontSize: 13,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        color: Colors.black,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.gold,
      colorScheme: base.colorScheme.copyWith(
        primary: palette.gold,
        secondary: palette.gold,
        surface: palette.surface,
        error: palette.priceDown,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.gold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.priceDown),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.gold,
          foregroundColor: Colors.black,
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.gold,
        unselectedItemColor: palette.textMuted,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showUnselectedLabels: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.gold,
        unselectedLabelColor: palette.textMuted,
        indicatorColor: palette.gold,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      extensions: const [palette],
    );
  }

  /// Configuración del tema claro (marfil cálido, latte suave y ámbar caramelo).
  static ThemeData get lightTheme {
    const palette = AppThemeColors.light;
    final base = ThemeData.light();

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        color: palette.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: palette.textSecondary,
        fontSize: 13,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.gold,
      colorScheme: base.colorScheme.copyWith(
        primary: palette.gold,
        secondary: palette.gold,
        surface: palette.surface,
        error: palette.priceDown,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.gold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.priceDown),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.gold,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.gold,
        unselectedItemColor: palette.textMuted,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showUnselectedLabels: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.gold,
        unselectedLabelColor: palette.textMuted,
        indicatorColor: palette.gold,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: palette.textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      extensions: const [palette],
    );
  }
}

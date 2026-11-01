import 'package:flutter/material.dart';

class AppTheme {
  // Professional Premium Corporate Color Palette (VisaJob AI v3.2)
  // Primary: #0E7C66 (Deep Emerald / Teal)
  // Secondary: #D4A017 (Gold / Amber Luxury)
  // Accent: #16213E (Navy / Deep Blue)
  // Background: #1E1E24 (Charcoal Dark)
  // Cards: #2A2A35 (Slate Deep Card)

  static const Color primary = Color(0xFF0E7C66); // Emerald / Forest Teal
  static const Color primaryLight = Color(0xFF14B8A6); // Bright Teal
  static const Color primarySoft = Color(0xFF133E35); // Soft Dark Teal tint

  static const Color secondary = Color(0xFFD4A017); // Royal Gold / Amber
  static const Color secondarySoft = Color(0xFF382F15); // Soft Gold tint
  
  static const Color accent = Color(0xFF16213E); // Navy Dark
  static const Color scaffoldBg = Color(0xFF1E1E24); // Charcoal Dark Background
  static const Color surface = Color(0xFF2A2A35); // Deep Slate Card Surface
  static const Color card = Color(0xFF2A2A35); // Card Background
  static const Color border = Color(0xFF3A3A48); // Subtle border
  static const Color borderFocus = Color(0xFF0E7C66); // Teal Focus

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFD4A017); // Gold / Warning
  static const Color danger = Color(0xFFEF4444); // Error Red

  // High-Contrast Legible Typography
  static const Color textPrimary = Color(0xFFF8FAFC); // Crisp Off-White
  static const Color textSecondary = Color(0xFFCBD5E1); // Light Slate
  static const Color textMuted = Color(0xFF94A3B8); // Muted Slate

  // Backwards compatibility aliases
  static const Color bgDark = scaffoldBg;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: primaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: secondary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF23232C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Alias for backward compatibility
  static ThemeData get lightTheme => darkTheme;

  static BoxDecoration glassCardDecoration({double opacity = 1.0, double radius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: card.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

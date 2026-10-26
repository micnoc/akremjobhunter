import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette (V2 SaaS Spec)
  static const Color bgDark = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF111827);
  static const Color card = Color(0xFF111827);
  static const Color border = Color(0xFF1E293B);
  static const Color primary = Color(0xFF38BDF8); // Cyan
  static const Color secondary = Color(0xFF10B981); // Emerald / Success
  static const Color accent = Color(0xFF6366F1); // Indigo
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Error Red
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF162032),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: TextStyle(color: textMuted.withAlpha(140), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  // Glassmorphic Decoration for Auth and Hero Cards
  static BoxDecoration glassCardDecoration({
    double opacity = 0.82,
    double radius = 16,
    Color borderColor = border,
  }) {
    return BoxDecoration(
      color: surface.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// T[root]H App Theme Colors
final Color kPrimaryGold = const Color(0xFFD4AF37);
final Color troothGold = kPrimaryGold; // Alias for convenience
final Color kCharcoal = const Color(0xFF2C2C2C);
final Color kSurface = const Color(0xFFF5F5F5);
final Color kText = const Color(0xFF1A1A1A);
final Color kMutedText = const Color(0xFF666666);

ThemeData buildAppTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: kPrimaryGold,
      secondary: kCharcoal,
      surface: kSurface,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: kText,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: kText,
      displayColor: kText,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: kCharcoal,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 2,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryGold,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFF5F5F5),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}

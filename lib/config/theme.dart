/// Dino Browser Theme Configuration
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DinoColors {
  DinoColors._();
  static const Color cyberGreen = Color(0xFF00FFA3);
  static const Color deepJungle = Color(0xFF0D1F2D);
  static const Color fossilBeige = Color(0xFFE3D5CA);
  static const Color raptorPurple = Color(0xFF9D4EDD);
  static const Color meteorRed = Color(0xFFFF6B6B);
  static const Color pterodactylBlue = Color(0xFF4CC9F0);
  static const Color amberOrange = Color(0xFFFFB703);
  static const Color darkBg = Color(0xFF0A0E14);
  static const Color cardBg = Color(0xFF151D29);
  static const Color surfaceBg = Color(0xFF1A2332);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

class DinoGradients {
  DinoGradients._();
  static const LinearGradient primaryGradient = LinearGradient(colors: [DinoColors.cyberGreen, DinoColors.pterodactylBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient darkGradient = LinearGradient(colors: [DinoColors.deepJungle, DinoColors.darkBg], begin: Alignment.topCenter, end: Alignment.bottomCenter);
  static const LinearGradient accentGradient = LinearGradient(colors: [DinoColors.raptorPurple, DinoColors.meteorRed], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient glassGradient = LinearGradient(colors: [Color(0x20FFFFFF), Color(0x05FFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class DinoDimens {
  DinoDimens._();
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double iconSmall = 18.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double urlBarHeight = 48.0;
  static const double tabBarHeight = 40.0;
}

class DinoTheme {
  DinoTheme._();
  
  static final _cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusLarge), side: const BorderSide(color: DinoColors.glassBorder, width: 1));
  static final _buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusMedium));
  static final _dialogShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusLarge));
  static final _inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusLarge), borderSide: BorderSide.none);
  static final _inputEnabledBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusLarge), borderSide: const BorderSide(color: DinoColors.glassBorder, width: 1));
  static final _inputFocusedBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(DinoDimens.radiusLarge), borderSide: const BorderSide(color: DinoColors.cyberGreen, width: 2));

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DinoColors.darkBg,
      primaryColor: DinoColors.cyberGreen,
      colorScheme: const ColorScheme.dark(primary: DinoColors.cyberGreen, secondary: DinoColors.pterodactylBlue, tertiary: DinoColors.raptorPurple, surface: DinoColors.surfaceBg, error: DinoColors.error, onPrimary: DinoColors.deepJungle, onSecondary: DinoColors.textPrimary, onSurface: DinoColors.textPrimary),
      textTheme: GoogleFonts.spaceGroteskTextTheme(const TextTheme(displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: DinoColors.textPrimary), displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: DinoColors.textPrimary), headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: DinoColors.textPrimary), headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: DinoColors.textPrimary), titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: DinoColors.textPrimary), titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: DinoColors.textPrimary), bodyLarge: TextStyle(fontSize: 16, color: DinoColors.textPrimary), bodyMedium: TextStyle(fontSize: 14, color: DinoColors.textSecondary), bodySmall: TextStyle(fontSize: 12, color: DinoColors.textMuted), labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DinoColors.textPrimary))),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, iconTheme: IconThemeData(color: DinoColors.textPrimary), titleTextStyle: TextStyle(color: DinoColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      cardTheme: CardThemeData(color: DinoColors.cardBg, elevation: 0, shape: _cardShape),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: DinoColors.cyberGreen, foregroundColor: DinoColors.deepJungle, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: DinoDimens.spacingLg, vertical: DinoDimens.spacingMd), shape: _buttonShape, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: DinoColors.textPrimary, backgroundColor: DinoColors.glassWhite, shape: _buttonShape)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: DinoColors.cardBg, contentPadding: const EdgeInsets.symmetric(horizontal: DinoDimens.spacingMd, vertical: DinoDimens.spacingSm), border: _inputBorder, enabledBorder: _inputEnabledBorder, focusedBorder: _inputFocusedBorder, hintStyle: const TextStyle(color: DinoColors.textMuted), prefixIconColor: DinoColors.textMuted, suffixIconColor: DinoColors.textMuted),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: DinoColors.cardBg, selectedItemColor: DinoColors.cyberGreen, unselectedItemColor: DinoColors.textMuted, type: BottomNavigationBarType.fixed, elevation: 0),
      drawerTheme: const DrawerThemeData(backgroundColor: DinoColors.surfaceBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(backgroundColor: DinoColors.cardBg, contentTextStyle: const TextStyle(color: DinoColors.textPrimary), shape: _buttonShape, behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(backgroundColor: DinoColors.surfaceBg, shape: _dialogShape),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: DinoColors.cyberGreen, linearTrackColor: DinoColors.cardBg),
    );
  }
}

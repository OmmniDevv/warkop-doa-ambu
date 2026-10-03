import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'token_tipografi.dart';
import 'token_warna.dart';

/// Membangun [ThemeData] Vintage Glassmorphism untuk kedua mode.
///
/// [gelap] = false → Vintage Parchment, true → Roasted Espresso.
ThemeData bangunTema({required bool gelap}) {
  final skema = ColorScheme(
    brightness: gelap ? Brightness.dark : Brightness.light,
    primary: gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang,
    onPrimary: gelap ? WarnaWarkop.teksGelap : Colors.white,
    secondary: WarnaWarkop.emas,
    onSecondary: WarnaWarkop.teksTerang,
    error: WarnaWarkop.merahMenyala,
    onError: Colors.white,
    surface: gelap ? WarnaWarkop.kertasGelap : WarnaWarkop.kertasTerang,
    onSurface: gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang,
    surfaceContainerHighest:
        gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang,
  );

  final warnaTeks = gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang;
  final warnaBorder =
      gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang;

  return ThemeData(
    useMaterial3: true,
    colorScheme: skema,
    scaffoldBackgroundColor: skema.surface,
    fontFamily: TipografiWarkop.sans,
    textTheme: TextTheme(
      displayLarge: TipografiWarkop.judulBrand.copyWith(
        fontSize: 28,
        color: warnaTeks,
      ),
      displayMedium: TipografiWarkop.judulBrand.copyWith(
        fontSize: 22,
        color: warnaTeks,
      ),
      titleLarge: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: warnaTeks,
      ),
      bodyLarge: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontSize: 15,
        color: warnaTeks,
      ),
      bodyMedium: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontSize: 13,
        color: warnaTeks.withValues(alpha: 0.75),
      ),
      labelLarge: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: warnaTeks,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: skema.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: warnaBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: warnaBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: skema.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WarnaWarkop.merahMenyala),
      ),
      hintStyle: TextStyle(
        color: warnaTeks.withValues(alpha: 0.4),
        fontSize: 14,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            gelap ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: TipografiWarkop.judulBrand.copyWith(
        fontSize: 18,
        color: warnaTeks,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

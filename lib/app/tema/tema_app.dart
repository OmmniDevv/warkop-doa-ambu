import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'token_tipografi.dart';
import 'token_warna.dart';

/// Membangun [ThemeData] Gojek/GoPay-inspired Warkop Doa Ambu.
///
/// [gelap] = false → mode terang (off-white kehijauan), true → mode gelap.
/// Token warna kanonis ada di [WarnaWarkop]; warna pendukung di bawah ini
/// DITURUNKAN dari token kanonis (bukan token baru).
ThemeData bangunTema({required bool gelap}) {
  final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
  final diAtasAksen =
      gelap ? WarnaWarkop.diAtasAksenGelap : WarnaWarkop.diAtasAksenTerang;
  final latar = gelap ? WarnaWarkop.latarGelap : WarnaWarkop.latarTerang;
  final kartu = gelap ? WarnaWarkop.kartuGelap : WarnaWarkop.kartuTerang;
  final teks = gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang;
  final teksSekunder =
      gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
  final garis = gelap ? WarnaWarkop.garisGelap : WarnaWarkop.garisTerang;
  final sukses = gelap ? WarnaWarkop.suksesGelap : WarnaWarkop.suksesTerang;
  final bahaya = gelap ? WarnaWarkop.bahayaGelap : WarnaWarkop.bahayaTerang;
  final peringatanStokTeks = gelap
      ? WarnaWarkop.peringatanStokTeksGelap
      : WarnaWarkop.peringatanStokTeksTerang;

  // Warna pendukung — diturunkan dari token kanonis via lerp.
  final wadahAksen = Color.lerp(kartu, aksen, 0.14)!;
  final wadahBahaya = Color.lerp(kartu, bahaya, 0.12)!;
  final wadahSukses = Color.lerp(kartu, sukses, 0.12)!;

  final skema = ColorScheme(
    brightness: gelap ? Brightness.dark : Brightness.light,
    primary: aksen,
    onPrimary: diAtasAksen,
    primaryContainer: wadahAksen,
    onPrimaryContainer: teks,
    secondary: sukses,
    onSecondary: gelap ? WarnaWarkop.latarGelap : Colors.white,
    secondaryContainer: wadahSukses,
    onSecondaryContainer: teks,
    tertiary: peringatanStokTeks,
    onTertiary: gelap ? WarnaWarkop.latarGelap : Colors.white,
    tertiaryContainer: gelap
        ? WarnaWarkop.peringatanStokLatarGelap
        : WarnaWarkop.peringatanStokLatarTerang,
    onTertiaryContainer: peringatanStokTeks,
    error: bahaya,
    onError: gelap ? WarnaWarkop.latarGelap : Colors.white,
    errorContainer: wadahBahaya,
    onErrorContainer: teks,
    surface: latar,
    onSurface: teks,
    surfaceDim: latar,
    surfaceBright: kartu,
    surfaceContainerLowest: latar,
    surfaceContainerLow: kartu,
    surfaceContainer: kartu,
    surfaceContainerHigh: kartu,
    surfaceContainerHighest: kartu,
    onSurfaceVariant: teksSekunder,
    outline: garis,
    outlineVariant: garis,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: teks,
    onInverseSurface: latar,
    inversePrimary: aksen,
    surfaceTint: Colors.transparent,
  );

  // Skala teks: tepat 5 ukuran (DESIGN.md §2) — 32 / 20 / 16 / 14 / 12.
  // displayLarge = nominal rupiah (JetBrainsMono, tabular) untuk total.
  final temaTeks = TextTheme(
    displayLarge: TipografiWarkop.nominal.copyWith(
      fontSize: 32,
      color: teks,
    ),
    titleLarge: TextStyle(
      fontFamily: TipografiWarkop.sans,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      color: teks,
    ),
    bodyLarge: TextStyle(
      fontFamily: TipografiWarkop.sans,
      fontSize: 16,
      color: teks,
    ),
    labelLarge: TextStyle(
      fontFamily: TipografiWarkop.sans,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: teks,
    ),
    bodySmall: TextStyle(
      fontFamily: TipografiWarkop.sans,
      fontSize: 12,
      color: teksSekunder,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: skema,
    scaffoldBackgroundColor: skema.surface,
    fontFamily: TipografiWarkop.sans,
    textTheme: temaTeks,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kartu,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: garis),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: garis),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: aksen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bahaya),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bahaya, width: 1.5),
      ),
      hintStyle: TextStyle(
        color: teksSekunder,
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: teksSekunder,
        fontSize: 14,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: latar,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            gelap ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: teks,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: teks,
      contentTextStyle: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontSize: 14,
        color: latar,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: aksen,
        foregroundColor: diAtasAksen,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: TipografiWarkop.sans,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: aksen,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: TipografiWarkop.sans,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kartu,
      labelStyle: TextStyle(
        fontFamily: TipografiWarkop.sans,
        fontSize: 14,
        color: teks,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: garis),
      ),
    ),
    cardTheme: CardThemeData(
      color: kartu,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      // Blur latar ditangani manual di LembarWarkop (step 4b) —
      // di sini hanya bentuk & elevasi yang konsisten.
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

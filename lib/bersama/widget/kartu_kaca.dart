import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';

/// Tingkat kekuatan kaca — sesuai spec glassmorphism.
///
/// - [kuat]: kartu hero/panel utama (blur 20px)
/// - [sedang]: kartu fitur/panel statistik (blur 16px)
/// - [ringan]: elemen nested/sekunder (blur 10px)
enum TingkatKaca { kuat, sedang, ringan }

/// Kartu kaca (glassmorphism) 3-tier — fondasi visual Warkop Doa Ambu.
///
/// Setiap kartu punya 4 komponen: fill semi-transparan + border 1px +
/// top-edge highlight (inset) + blur optik. Tanpa top-edge highlight,
/// kartu terlihat seperti kotak semi-transparan biasa.
///
/// [tanpaBlur] untuk kartu di dalam scroll cepat (hemat GPU); blur hanya
/// untuk elemen mengambang & bottom sheet. JANGAN pakai BackdropFilter
/// di setiap kartu grid.
class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.tingkat = TingkatKaca.sedang,
    this.tanpaBlur = false,
    this.border,
    this.bayangan = true,
    this.warnaLatar,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final TingkatKaca tingkat;
  final bool tanpaBlur;
  final Color? border;
  final bool bayangan;
  final Color? warnaLatar;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    // Pilih token sesuai tingkat & mode.
    final Color warnaKaca;
    final double blur;
    switch (tingkat) {
      case TingkatKaca.kuat:
        warnaKaca = gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;
        blur = 20;
      case TingkatKaca.sedang:
        warnaKaca =
            gelap ? WarnaWarkop.kacaGelapSedang : WarnaWarkop.kacaTerangSedang;
        blur = 16;
      case TingkatKaca.ringan:
        warnaKaca =
            gelap ? WarnaWarkop.kacaGelapRingan : WarnaWarkop.kacaTerangRingan;
        blur = 10;
    }

    final warnaBorder = border ??
        (gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang);

    final kartu = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: warnaLatar ?? warnaKaca,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: warnaBorder, width: 1),
        boxShadow: bayangan
            ? [
                // Top-edge highlight: cahaya di bibir atas kaca.
                BoxShadow(
                  color: Colors.white.withValues(alpha: gelap ? 0.08 : 0.9),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
                // Bayangan lembut di bawah.
                BoxShadow(
                  color: Colors.black.withValues(alpha: gelap ? 0.3 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (tanpaBlur) return kartu;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: kartu,
      ),
    );
  }
}


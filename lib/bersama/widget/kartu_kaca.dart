import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';

/// Kartu kaca (glassmorphism) reusable — fondasi visual Warkop Doa Ambu.
///
/// Kombinasi lapisan semi-transparan + border 1px marun/emas + blur optik.
/// [pakaiBlur] dimatikan untuk kartu di dalam scroll cepat (hemat GPU —
/// target 60 FPS); blur hanya untuk elemen mengambang & bottom sheet.
class KartuKaca extends StatelessWidget {
  const KartuKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.pakaiBlur = true,
    this.kekuatanBlur = 14,
    this.border,
    this.bayangan = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool pakaiBlur;
  final double kekuatanBlur;
  final Color? border;
  final bool bayangan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final warnaKaca =
        gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;
    final warnaBorder =
        border ?? (gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang);
    final warnaAksen =
        gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    final kartu = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: warnaKaca,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: warnaBorder, width: 1),
        boxShadow: bayangan
            ? [
                BoxShadow(
                  color: warnaAksen.withValues(alpha: gelap ? 0.12 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (!pakaiBlur) return kartu;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kekuatanBlur,
          sigmaY: kekuatanBlur,
        ),
        child: kartu,
      ),
    );
  }
}

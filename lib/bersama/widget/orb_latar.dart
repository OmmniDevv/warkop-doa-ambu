import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';

/// Latar animasi orb kaca — 2-3 bola warna yang melayang SANGAT pelan.
///
/// Filosofi: "hidup tapi tenang". Orb bergerak 20-30 detik per siklus,
/// blur tebal, opacity rendah. Bukan nightclub.
///
/// Untuk hemat baterai, animasi dijeda saat widget tidak terlihat
/// (via [TickerMode] oleh pemanggil bila perlu).
class OrbLatar extends StatefulWidget {
  const OrbLatar({
    super.key,
    this.jumlahOrb = 3,
    this.durasiSiklus = const Duration(seconds: 25),
    this.child,
  });

  final int jumlahOrb;
  final Duration durasiSiklus;
  final Widget? child;

  @override
  State<OrbLatar> createState() => _OrbLatarState();
}

class _OrbLatarState extends State<OrbLatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pengendali;

  @override
  void initState() {
    super.initState();
    _pengendali = AnimationController(
      vsync: this,
      duration: widget.durasiSiklus,
    )..repeat();
  }

  @override
  void dispose() {
    _pengendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final ukuran = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Lapisan 1: gradien atmosfer dasar.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gelap
                  ? const [
                      Color(0xFF1A1530),
                      Color(0xFF12101D),
                      Color(0xFF0D0B16),
                    ]
                  : const [
                      Color(0xFFE9D5FF),
                      Color(0xFFF1EAFF),
                      Color(0xFFFDE8FF),
                    ],
            ),
          ),
        ),
        // Lapisan 2: orb warna yang melayang pelan.
        AnimatedBuilder(
          animation: _pengendali,
          builder: (context, _) {
            final t = _pengendali.value * 2 * math.pi;
            return Stack(
              children: [
                _orb(
                  ukuran,
                  warna: WarnaWarkop.orbViolet,
                  // Kanan atas — sumber cahaya utama.
                  x: 0.75 + 0.08 * math.sin(t),
                  y: 0.15 + 0.06 * math.cos(t * 0.8),
                  diameter: ukuran.width * 0.7,
                  opacity: gelap ? 0.25 : 0.45,
                ),
                _orb(
                  ukuran,
                  warna: WarnaWarkop.orbPink,
                  // Kiri bawah — fill.
                  x: 0.15 + 0.06 * math.cos(t * 0.7 + 1),
                  y: 0.8 + 0.08 * math.sin(t * 0.9 + 2),
                  diameter: ukuran.width * 0.55,
                  opacity: gelap ? 0.18 : 0.35,
                ),
                if (widget.jumlahOrb >= 3)
                  _orb(
                    ukuran,
                    warna: WarnaWarkop.orbOranye,
                    // Tengah kanan — aksen hangat hemat.
                    x: 0.85 + 0.05 * math.sin(t * 0.6 + 3),
                    y: 0.55 + 0.07 * math.cos(t * 0.75 + 1),
                    diameter: ukuran.width * 0.4,
                    opacity: gelap ? 0.12 : 0.22,
                  ),
              ],
            );
          },
        ),
        // Lapisan 3: konten di atas kaca.
        if (widget.child != null) widget.child!,
      ],
    );
  }

  /// Satu orb: lingkaran radial dengan blur tebal.
  Widget _orb(
    Size ukuran, {
    required Color warna,
    required double x,
    required double y,
    required double diameter,
    required double opacity,
  }) {
    return Positioned(
      left: ukuran.width * x - diameter / 2,
      top: ukuran.height * y - diameter / 2,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              warna.withValues(alpha: opacity),
              warna.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}


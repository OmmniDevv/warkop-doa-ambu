import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';

/// Cincin data animasi — signature element dashboard.
///
/// Lingkaran SVG yang menggambar dirinya sendiri saat halaman dimuat,
/// menampilkan persentase (misal: pencapaian omzet). Animasi 1.4 detik
/// dengan easing, delay 0.4 detik setelah halaman muncul.
class CincinData extends StatefulWidget {
  const CincinData({
    super.key,
    required this.persen,
    this.diameter = 160,
    this.tebalGaris = 12,
    this.warna,
    this.labelTengah,
    this.sublabel,
  });

  /// Nilai 0.0 – 1.0.
  final double persen;
  final double diameter;
  final double tebalGaris;
  final Color? warna;
  final String? labelTengah;
  final String? sublabel;

  @override
  State<CincinData> createState() => _CincinDataState();
}

class _CincinDataState extends State<CincinData>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pengendali;
  late final Animation<double> _animasi;

  @override
  void initState() {
    super.initState();
    _pengendali = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animasi = CurvedAnimation(
      parent: _pengendali,
      curve: Curves.easeInOut,
    );
    // Delay 400ms setelah halaman muncul.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _pengendali.forward();
    });
  }

  @override
  void didUpdateWidget(CincinData oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persen != widget.persen) {
      _pengendali.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pengendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final warnaAksen =
        widget.warna ?? (gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang);

    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedBuilder(
        animation: _animasi,
        builder: (context, _) {
          final persenTampil = (widget.persen * _animasi.value).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _PelukisCincin(
              persen: persenTampil,
              tebalGaris: widget.tebalGaris,
              warnaAksen: warnaAksen,
              warnaTrek: gelap
                  ? Colors.white.withValues(alpha: 0.1)
                  : WarnaWarkop.teksTerang.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.labelTengah != null)
                    Text(
                      widget.labelTengah!,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: gelap
                                    ? WarnaWarkop.teksGelap
                                    : WarnaWarkop.teksTerang,
                              ),
                    ),
                  if (widget.sublabel != null)
                    Text(
                      widget.sublabel!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: gelap
                                ? WarnaWarkop.teksSekunderGelap
                                : WarnaWarkop.teksSekunderTerang,
                          ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pelukis cincin: trek + busur animasi.
class _PelukisCincin extends CustomPainter {
  _PelukisCincin({
    required this.persen,
    required this.tebalGaris,
    required this.warnaAksen,
    required this.warnaTrek,
  });

  final double persen;
  final double tebalGaris;
  final Color warnaAksen;
  final Color warnaTrek;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - tebalGaris) / 2;

    // Trek latar.
    canvas.drawCircle(
      pusat,
      radius,
      Paint()
        ..color = warnaTrek
        ..style = PaintingStyle.stroke
        ..strokeWidth = tebalGaris,
    );

    // Busur animasi — mulai dari atas (-90°).
    canvas.drawArc(
      Rect.fromCircle(center: pusat, radius: radius),
      -math.pi / 2,
      2 * math.pi * persen,
      false,
      Paint()
        ..color = warnaAksen
        ..style = PaintingStyle.stroke
        ..strokeWidth = tebalGaris
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PelukisCincin old) => old.persen != persen;
}

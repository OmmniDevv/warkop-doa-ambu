import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema/token_warna.dart';
import 'kartu_kaca.dart';

/// Tombol kaca dengan efek tekan membal (spring scale 0.95) + haptik ringan.
///
/// Seluruh feedback interaksi aplikasi memakai visual + getaran —
/// dilarang efek suara.
class TombolKaca extends StatefulWidget {
  const TombolKaca({
    super.key,
    required this.label,
    required this.saatDitekan,
    this.ikon,
    this.lebarPenuh = true,
    this.memuat = false,
    this.aktif = true,
  });

  final String label;
  final VoidCallback? saatDitekan;
  final IconData? ikon;
  final bool lebarPenuh;
  final bool memuat;
  final bool aktif;

  @override
  State<TombolKaca> createState() => _TombolKacaState();
}

class _TombolKacaState extends State<TombolKaca>
    with SingleTickerProviderStateMixin {
  double _skala = 1.0;

  void _saatBawah(TapDownDetails _) {
    setState(() => _skala = 0.95);
    HapticFeedback.lightImpact();
  }

  void _saatLepas() => setState(() => _skala = 1.0);

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final dapatDitekan = widget.aktif && !widget.memuat && widget.saatDitekan != null;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 180),
      curve: Curves.elasticOut,
      child: GestureDetector(
        onTapDown: dapatDitekan ? _saatBawah : null,
        onTapUp: (_) => _saatLepas(),
        onTapCancel: _saatLepas,
        onTap: dapatDitekan ? widget.saatDitekan : null,
        child: Opacity(
          opacity: dapatDitekan ? 1.0 : 0.55,
          child: KartuKaca(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            radius: 16,
            pakaiBlur: false,
            border: aksen.withValues(alpha: 0.45),
            child: SizedBox(
              width: widget.lebarPenuh ? double.infinity : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.memuat)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else ...[
                    if (widget.ikon != null) ...[
                      Icon(widget.ikon, color: aksen, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: aksen,
                              fontSize: 15,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

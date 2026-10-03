import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema/token_warna.dart';

/// Keypad angka virtual in-app — dilarang memanggil keyboard bawaan OS.
///
/// Dipakai untuk input PIN dan nominal tunai agar tidak menutupi antarmuka.
/// Setiap ketukan: [HapticFeedback.lightImpact].
class KeypadAngka extends StatelessWidget {
  const KeypadAngka({
    super.key,
    required this.saatAngka,
    required this.saatHapus,
    this.tampilkanTitik = false,
    this.saatTitik,
  });

  final ValueChanged<String> saatAngka;
  final VoidCallback saatHapus;
  final bool tampilkanTitik;
  final VoidCallback? saatTitik;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    Widget tombol(String label, {VoidCallback? aksi, bool sorot = false}) {
      return _TombolKeypad(
        label: label,
        aksen: aksen,
        gelap: gelap,
        sorot: sorot,
        aksi: aksi,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final baris in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final angka in baris)
                  tombol(angka, aksi: () => saatAngka(angka)),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            tampilkanTitik
                ? tombol('.', aksi: saatTitik)
                : const SizedBox(width: 76, height: 76),
            tombol('0', aksi: () => saatAngka('0')),
            tombol(
              '⌫',
              sorot: true,
              aksi: saatHapus,
            ),
          ],
        ),
      ],
    );
  }
}

class _TombolKeypad extends StatefulWidget {
  const _TombolKeypad({
    required this.label,
    required this.aksen,
    required this.gelap,
    required this.aksi,
    required this.sorot,
  });

  final String label;
  final Color aksen;
  final bool gelap;
  final VoidCallback? aksi;
  final bool sorot;

  @override
  State<_TombolKeypad> createState() => _TombolKeypadState();
}

class _TombolKeypadState extends State<_TombolKeypad> {
  double _skala = 1.0;

  @override
  Widget build(BuildContext context) {
    final warnaKaca =
        widget.gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;
    final warnaBorder = widget.gelap
        ? WarnaWarkop.borderKacaGelap
        : WarnaWarkop.borderKacaTerang;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.9),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.aksi?.call();
        },
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: warnaKaca,
            shape: BoxShape.circle,
            border: Border.all(color: warnaBorder),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: widget.sorot
                  ? widget.aksen
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

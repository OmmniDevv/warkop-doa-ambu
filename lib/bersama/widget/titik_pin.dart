import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';

/// Indikator 6 lingkaran kaca untuk input PIN.
///
/// [terisi] = jumlah digit yang sudah dimasukkan (0–6).
/// [tampilkanError] = border merah menyala sekejap saat PIN salah.
class TitikPin extends StatelessWidget {
  const TitikPin({
    super.key,
    required this.terisi,
    this.jumlah = 6,
    this.tampilkanError = false,
  });

  final int terisi;
  final int jumlah;
  final bool tampilkanError;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final borderNormal =
        gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(jumlah, (i) {
        final aktif = i < terisi;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedScale(
            scale: aktif ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: aktif
                    ? aksen
                    : (gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang),
                border: Border.all(
                  color: tampilkanError
                      ? WarnaWarkop.merahMenyala
                      : (aktif ? aksen : borderNormal),
                  width: tampilkanError ? 2 : 1.2,
                ),
                boxShadow: aktif
                    ? [
                        BoxShadow(
                          color: aksen.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

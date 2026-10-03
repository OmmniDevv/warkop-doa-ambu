import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema/token_warna.dart';

/// Item navigasi bawah.
class ItemNavBawah {
  const ItemNavBawah({
    required this.ikon,
    required this.label,
    this.ikonAktif,
  });

  final IconData ikon;
  final IconData? ikonAktif;
  final String label;
}

/// Bottom navigation pill ngambang ala referensi gambar 1.
///
/// 5 slot: 2 kiri, tombol tengah BESAR menonjol, 2 kanan.
/// Tombol tengah memakai gradien violet + elevated — untuk aksi utama (Kasir).
class NavPillBawah extends StatelessWidget {
  const NavPillBawah({
    super.key,
    required this.item,
    required this.indeksAktif,
    required this.saatDipilih,
    required this.ikonTengah,
    required this.labelTengah,
    required this.saatTengahDipilih,
  }) : assert(item.length == 4, 'Harus 4 item: 2 kiri + 2 kanan');

  final List<ItemNavBawah> item;
  final int indeksAktif;
  final ValueChanged<int> saatDipilih;
  final IconData ikonTengah;
  final String labelTengah;
  final VoidCallback saatTengahDipilih;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Pill kaca utama.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: gelap
                        ? WarnaWarkop.kacaGelap
                        : const Color(0xD6FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: gelap
                          ? WarnaWarkop.borderKacaGelap
                          : WarnaWarkop.borderKacaTerang,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 2 kiri.
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tombolItem(context, 0, aksen, teksRedup),
                            _tombolItem(context, 1, aksen, teksRedup),
                          ],
                        ),
                      ),
                      // Ruang tombol tengah.
                      const SizedBox(width: 72),
                      // 2 kanan.
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tombolItem(context, 2, aksen, teksRedup),
                            _tombolItem(context, 3, aksen, teksRedup),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tombol tengah BESAR menonjol.
            Positioned(
              bottom: 10,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  saatTengahDipilih();
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        aksen,
                        WarnaWarkop.aksenGelapHover,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: aksen.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(ikonTengah, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolItem(
    BuildContext context,
    int indeks,
    Color aksen,
    Color teksRedup,
  ) {
    // Mapping: item[0,1] kiri, item[2,3] kanan.
    final data = item[indeks];
    final aktif = indeksAktif == indeks ||
        (indeks >= 2 && indeksAktif == indeks + 1);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Indeks 2,3 di kanan memetakan ke tab 3,4 (lewati tengah).
        saatDipilih(indeks >= 2 ? indeks + 1 : indeks);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? aksen.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aktif ? (data.ikonAktif ?? data.ikon) : data.ikon,
              color: aktif ? aksen : teksRedup,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                color: aktif ? aksen : teksRedup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


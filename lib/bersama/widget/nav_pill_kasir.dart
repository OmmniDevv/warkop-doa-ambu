import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema/token_warna.dart';
import 'nav_pill_bawah.dart';

/// Bottom navigation pill khusus kasir.
///
/// 4 sentuhan: tombol tengah BESAR = Kasir (POS, aksi utama),
/// 1 kiri = Tagihan, 2 kanan = Statistik + Akun.
/// Gaya kaca sama dengan [NavPillBawah] agar konsisten.
class NavPillKasir extends StatelessWidget {
  const NavPillKasir({
    super.key,
    required this.indeksAktif,
    required this.saatDipilih,
    required this.saatTengahDipilih,
  });

  /// Indeks cabang aktif: 0=Kasir(POS) · 1=Tagihan · 2=Statistik · 3=Akun.
  final int indeksAktif;

  /// Dipanggil dengan indeks cabang (1=Tagihan, 2=Statistik, 3=Akun).
  final ValueChanged<int> saatDipilih;

  /// Dipanggil saat tombol tengah (Kasir/POS) ditekan.
  final VoidCallback saatTengahDipilih;

  static const _kiri = <ItemNavBawah>[
    ItemNavBawah(
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long_rounded,
      label: 'Tagihan',
    ),
  ];

  static const _kanan = <ItemNavBawah>[
    ItemNavBawah(
      ikon: Icons.bar_chart_outlined,
      ikonAktif: Icons.bar_chart_rounded,
      label: 'Statistik',
    ),
    ItemNavBawah(
      ikon: Icons.person_outline,
      ikonAktif: Icons.person_rounded,
      label: 'Akun',
    ),
  ];

  /// Petakan posisi item ke indeks cabang: kiri[0]→1, kanan[0]→2, kanan[1]→3.
  int _cabangUntuk(bool kiri, int i) => kiri ? 1 : i + 2;

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
                      // 1 kiri: Tagihan.
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < _kiri.length; i++)
                              _tombolItem(context, true, i, aksen, teksRedup),
                          ],
                        ),
                      ),
                      // Ruang tombol tengah.
                      const SizedBox(width: 72),
                      // 2 kanan: Statistik + Akun.
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < _kanan.length; i++)
                              _tombolItem(context, false, i, aksen, teksRedup),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tombol tengah BESAR: Kasir (POS).
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
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
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
    bool kiri,
    int i,
    Color aksen,
    Color teksRedup,
  ) {
    final data = kiri ? _kiri[i] : _kanan[i];
    final cabang = _cabangUntuk(kiri, i);
    final aktif = indeksAktif == cabang;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        saatDipilih(cabang);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
            // FittedBox: label tidak boleh kepotong di layar sempit.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                  color: aktif ? aksen : teksRedup,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

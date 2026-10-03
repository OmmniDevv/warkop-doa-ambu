import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bersama/widget/nav_pill_bawah.dart';

/// Cangkang navigasi bawah aplikasi.
///
/// Membungkus 5 cabang tab [StatefulNavigationShell] dengan [NavPillBawah]:
/// Beranda (0) · Stok (1) · [Kasir tengah] (2) · Tagihan (3) · Lainnya (4).
///
/// Ketuk ulang tab yang sedang aktif → kembali ke akar cabang
/// (mis. dari detail tagihan kembali ke daftar).
class CangkangNav extends StatelessWidget {
  const CangkangNav({super.key, required this.cangkang});

  /// Navigation shell dari `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell cangkang;

  static const _item = <ItemNavBawah>[
    ItemNavBawah(
      ikon: Icons.home_outlined,
      ikonAktif: Icons.home_rounded,
      label: 'Beranda',
    ),
    ItemNavBawah(
      ikon: Icons.inventory_2_outlined,
      ikonAktif: Icons.inventory_2_rounded,
      label: 'Stok',
    ),
    ItemNavBawah(
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long_rounded,
      label: 'Tagihan',
    ),
    ItemNavBawah(
      ikon: Icons.menu_rounded,
      ikonAktif: Icons.menu_rounded,
      label: 'Lainnya',
    ),
  ];

  void _keCabang(int indeks) {
    cangkang.goBranch(
      indeks,
      initialLocation: indeks == cangkang.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Biarkan tiap layar tab mengatur latarnya sendiri (OrbLatar).
      body: cangkang,
      bottomNavigationBar: NavPillBawah(
        item: _item,
        indeksAktif: cangkang.currentIndex,
        saatDipilih: _keCabang,
        ikonTengah: Icons.point_of_sale_rounded,
        labelTengah: 'Kasir',
        saatTengahDipilih: () => _keCabang(2),
      ),
    );
  }
}

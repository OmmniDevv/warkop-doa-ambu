import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bersama/widget/nav_pill_bawah.dart';

/// Cangkang navigasi bawah owner.
///
/// Cabang: Stok (0) · Kelola Kasir (1) · [Beranda tengah] (2) ·
/// Laporan (3) · Lainnya (4).
/// Beranda jadi tombol tengah yang menonjol — pusat kendali owner.
/// Owner adalah manajer, bukan kasir: tidak ada akses POS/pembayaran.
///
/// Ketuk ulang tab yang sedang aktif → kembali ke akar cabang.
class CangkangNav extends StatelessWidget {
  const CangkangNav({super.key, required this.cangkang});

  /// Navigation shell dari `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell cangkang;

  static const _item = <ItemNavBawah>[
    ItemNavBawah(
      ikon: Icons.inventory_2_outlined,
      ikonAktif: Icons.inventory_2_rounded,
      label: 'Stok',
    ),
    ItemNavBawah(
      ikon: Icons.manage_accounts_outlined,
      ikonAktif: Icons.manage_accounts_rounded,
      label: 'Kasir',
    ),
    ItemNavBawah(
      ikon: Icons.assessment_outlined,
      ikonAktif: Icons.assessment_rounded,
      label: 'Laporan',
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
        ikonTengah: Icons.home_rounded,
        labelTengah: 'Beranda',
        saatTengahDipilih: () => _keCabang(2),
      ),
    );
  }
}

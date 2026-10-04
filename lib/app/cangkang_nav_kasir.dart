import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bersama/widget/nav_pill_kasir.dart';

/// Cangkang navigasi bawah khusus kasir.
///
/// Cabang: Kasir/POS (0, tombol tengah besar) · Tagihan (1) ·
/// Statistik (2) · Akun (3).
/// Terpisah dari [CangkangNav] owner agar kasir tidak bisa
/// mengakses layar owner (dasbor, stok, laporan, kelola kasir).
class CangkangNavKasir extends StatelessWidget {
  const CangkangNavKasir({super.key, required this.cangkang});

  /// Navigation shell dari `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell cangkang;

  void _keCabang(int indeks) {
    cangkang.goBranch(
      indeks,
      initialLocation: indeks == cangkang.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: cangkang,
      bottomNavigationBar: NavPillKasir(
        indeksAktif: cangkang.currentIndex,
        saatDipilih: _keCabang,
        saatTengahDipilih: () => _keCabang(0),
      ),
    );
  }
}

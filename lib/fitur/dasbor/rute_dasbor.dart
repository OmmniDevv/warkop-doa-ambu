import 'package:go_router/go_router.dart';

import 'layar_akun_kasir.dart';
import 'layar_audit.dart';
import 'layar_kategori.dart';
import 'layar_laporan.dart';
import 'layar_menu.dart';

/// Kumpulan rute modul dasbor owner (fase 8).
///
/// Akar tab `/dasbor` didaftarkan sebagai cabang [StatefulShellRoute] di
/// `lib/app/router.dart` — daftar ini hanya berisi rute detail yang
/// didorong di atas cangkang navigasi.
///
/// Didaftarkan ke GoRouter pusat oleh orchestrator/parent —
/// file ini TIDAK menyentuh `lib/app/router.dart`.
final List<GoRoute> ruteDasbor = <GoRoute>[
  GoRoute(
    path: '/kategori',
    builder: (context, state) => const LayarKategori(),
  ),
  GoRoute(
    path: '/menu',
    builder: (context, state) => const LayarMenu(),
  ),
  GoRoute(
    path: '/laporan',
    builder: (context, state) => const LayarLaporan(),
  ),
  GoRoute(
    path: '/audit',
    builder: (context, state) => const LayarAudit(),
  ),
  GoRoute(
    path: '/akun-kasir',
    builder: (context, state) => const LayarAkunKasir(),
  ),
];

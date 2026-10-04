import 'package:go_router/go_router.dart';

import 'layar_audit.dart';
import 'layar_kategori.dart';
import 'layar_menu.dart';
import 'layar_riwayat_shift.dart';

/// Kumpulan rute modul dasbor owner (fase 8).
///
/// `/laporan` dan `/akun-kasir` adalah cabang shell owner
/// (didaftarkan di `lib/app/router.dart`) — bukan di sini.
/// Daftar ini hanya berisi rute detail yang didorong di atas cangkang.
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
    path: '/audit',
    builder: (context, state) => const LayarAudit(),
  ),
  GoRoute(
    path: '/riwayat-shift',
    builder: (context, state) => const LayarRiwayatShift(),
  ),
];

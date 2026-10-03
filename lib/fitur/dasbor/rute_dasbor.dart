import 'package:go_router/go_router.dart';

import 'layar_akun_kasir.dart';
import 'layar_audit.dart';
import 'layar_dasbor.dart';
import 'layar_katalog.dart';
import 'layar_laporan.dart';

/// Kumpulan rute modul dasbor owner (fase 8).
///
/// Didaftarkan ke GoRouter pusat oleh orchestrator/parent —
/// file ini TIDAK menyentuh `lib/app/router.dart`.
final List<GoRoute> ruteDasbor = <GoRoute>[
  GoRoute(
    path: '/dasbor',
    builder: (context, state) => const LayarDasbor(),
  ),
  GoRoute(
    path: '/katalog',
    builder: (context, state) => const LayarKatalog(),
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

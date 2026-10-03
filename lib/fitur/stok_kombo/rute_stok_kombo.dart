import 'package:go_router/go_router.dart';

import 'layar_bahan.dart';
import 'layar_belanja.dart';
import 'layar_kombo.dart';
import 'layar_riwayat_opname.dart';
import 'layar_stok_opname.dart';

/// Route modul stok & kombo (Fase 7 + redesign stok).
///
/// Akar tab `/stok` didaftarkan sebagai cabang [StatefulShellRoute] di
/// `lib/app/router.dart`.
///
/// Didaftarkan koordinator ke router utama — file ini hanya mengekspor
/// daftarnya, tanpa mengubah `lib/app/router.dart`.
final List<GoRoute> ruteStokKombo = [
  GoRoute(
    path: '/kombo',
    builder: (context, state) => const LayarKombo(),
  ),
  GoRoute(
    path: '/bahan',
    builder: (context, state) => const LayarBahan(),
  ),
  GoRoute(
    path: '/stok-opname',
    builder: (context, state) => const LayarStokOpname(),
  ),
  GoRoute(
    path: '/riwayat-opname',
    builder: (context, state) => const LayarRiwayatOpname(),
  ),
  GoRoute(
    path: '/belanja',
    builder: (context, state) => const LayarBelanja(),
  ),
];

import 'package:go_router/go_router.dart';

import 'layar_kombo.dart';
import 'layar_stok.dart';

/// Route modul stok & kombo (Fase 7).
///
/// Didaftarkan koordinator ke router utama — file ini hanya mengekspor
/// daftarnya, tanpa mengubah `lib/app/router.dart`.
final List<GoRoute> ruteStokKombo = [
  GoRoute(
    path: '/stok',
    builder: (context, state) => const LayarStok(),
  ),
  GoRoute(
    path: '/kombo',
    builder: (context, state) => const LayarKombo(),
  ),
];

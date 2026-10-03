import 'package:go_router/go_router.dart';

import 'layar_kas_keluar.dart';
import 'layar_kasbon.dart';

/// Rute modul void & kasbon & kas keluar (Fase 6).
///
/// Didaftarkan ke [GoRouter] utama oleh koordinator — file ini hanya
/// mengekspor daftarnya. Path final:
///
/// - `/kasbon` → [LayarKasbon]
/// - `/kas-keluar` → [LayarKasKeluar]
final List<GoRoute> ruteVoidKasbon = [
  GoRoute(
    path: '/kasbon',
    builder: (context, state) => const LayarKasbon(),
  ),
  GoRoute(
    path: '/kas-keluar',
    builder: (context, state) => const LayarKasKeluar(),
  ),
];

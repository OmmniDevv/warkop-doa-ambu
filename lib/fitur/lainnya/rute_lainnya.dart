import 'package:go_router/go_router.dart';

import 'layar_daftar_belanja.dart';
import 'layar_pengaturan.dart';

/// Rute modul Lainnya: daftar belanja dan pengaturan.
///
/// Akar tab `/lainnya` didaftarkan sebagai cabang [StatefulShellRoute] di
/// `lib/app/router.dart`.
///
/// Didaftarkan ke [GoRouter] utama oleh koordinator — berkas ini TIDAK
/// mengubah `lib/app/router.dart`.
final List<GoRoute> ruteLainnya = <GoRoute>[
  GoRoute(
    path: '/daftar-belanja',
    builder: (context, state) => const LayarDaftarBelanja(),
  ),
  GoRoute(
    path: '/pengaturan',
    builder: (context, state) => const LayarPengaturan(),
  ),
];

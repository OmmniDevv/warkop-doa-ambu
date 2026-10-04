import 'package:go_router/go_router.dart';

import 'layar_pengaturan.dart';

/// Rute modul Lainnya: pengaturan.
///
/// Daftar belanja digabung ke `/belanja` (layar_stok_kombo) agar tidak ada
/// dua layar berjudul sama dengan rumus saran berbeda.
final List<GoRoute> ruteLainnya = <GoRoute>[
  GoRoute(
    path: '/pengaturan',
    builder: (context, state) => const LayarPengaturan(),
  ),
];

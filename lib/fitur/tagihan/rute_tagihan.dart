import 'package:go_router/go_router.dart';

import 'layar_daftar_tagihan.dart';
import 'layar_detail_tagihan.dart';
import 'layar_tagihan_baru.dart';

/// Rute modul Tagihan (open bill).
///
/// Didaftarkan ke [GoRouter] utama oleh koordinator — berkas ini TIDAK
/// mengubah `lib/app/router.dart`.
final List<GoRoute> ruteTagihan = <GoRoute>[
  GoRoute(
    path: '/tagihan',
    builder: (context, state) => const LayarDaftarTagihan(),
  ),
  GoRoute(
    path: '/tagihan/baru',
    builder: (context, state) => const LayarTagihanBaru(),
  ),
  GoRoute(
    path: '/tagihan/:idTagihan',
    builder: (context, state) => LayarDetailTagihan(
      idTagihan: state.pathParameters['idTagihan']!,
    ),
  ),
];

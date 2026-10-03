import 'package:go_router/go_router.dart';

import 'layar_bayar.dart';

/// Route modul pembayaran (Fase 5).
///
/// Didaftarkan oleh koordinator ke GoRouter aplikasi — berkas ini TIDAK
/// menyentuh `lib/app/router.dart` agar kepemilikan antar fase tetap terpisah.
final List<GoRoute> ruteBayar = [
  GoRoute(
    path: '/bayar/:idPesanan',
    builder: (context, state) => LayarBayar(
      idPesanan: state.pathParameters['idPesanan']!,
    ),
  ),
];

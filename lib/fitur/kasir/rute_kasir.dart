import 'package:go_router/go_router.dart';

import 'layar_buka_shift.dart';
import 'layar_pilih_kasir.dart';
import 'layar_pin_kasir.dart';
import 'layar_tutup_shift.dart';

/// Rute Fase 2 (kasir & shift).
///
/// Digabungkan koordinator ke router utama. Path string literal FINAL.
final List<GoRoute> ruteKasir = [
  GoRoute(
    path: '/kasir',
    builder: (context, state) => const LayarPilihKasir(),
  ),
  GoRoute(
    path: '/kasir/pin/:idAkun',
    builder: (context, state) =>
        LayarPinKasir(idAkun: state.pathParameters['idAkun']!),
  ),
  GoRoute(
    path: '/shift/buka',
    builder: (context, state) => const LayarBukaShift(),
  ),
  GoRoute(
    path: '/shift/tutup',
    builder: (context, state) => const LayarTutupShift(),
  ),
];

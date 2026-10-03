import 'package:go_router/go_router.dart';

import 'layar_pos.dart';

/// Rute fitur POS. Didaftarkan ke [bangunRouter] oleh koordinator fase.
final List<GoRoute> rutePos = [
  GoRoute(
    path: '/pos',
    builder: (context, state) => const LayarPos(),
  ),
  GoRoute(
    path: '/pos/tagihan/:idTagihan',
    builder: (context, state) =>
        LayarPos(idTagihan: state.pathParameters['idTagihan']!),
  ),
];

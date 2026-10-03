import 'package:go_router/go_router.dart';

import '../fitur/auth_owner/layar_beranda.dart';
import '../fitur/auth_owner/layar_daftar_owner.dart';
import '../fitur/auth_owner/layar_masuk_owner.dart';
import '../fitur/auth_owner/layar_setup_pin_owner.dart';

/// Nama route terpusat — jangan hardcode string path di widget.
abstract final class Rute {
  static const daftar = '/daftar';
  static const masuk = '/masuk';
  static const setupPin = '/setup-pin';
  static const beranda = '/beranda';
}

/// GoRouter aplikasi. Guard auth sederhana ditangani per-layar agar
/// alur pendaftaran tetap mulus saat offline.
GoRouter bangunRouter() {
  return GoRouter(
    initialLocation: Rute.daftar,
    routes: [
      GoRoute(
        path: Rute.daftar,
        builder: (context, state) => const LayarDaftarOwner(),
      ),
      GoRoute(
        path: Rute.masuk,
        builder: (context, state) => const LayarMasukOwner(),
      ),
      GoRoute(
        path: Rute.setupPin,
        builder: (context, state) => const LayarSetupPinOwner(),
      ),
      GoRoute(
        path: Rute.beranda,
        builder: (context, state) => const LayarBeranda(),
      ),
    ],
  );
}

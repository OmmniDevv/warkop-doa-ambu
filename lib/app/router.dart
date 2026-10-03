import 'package:go_router/go_router.dart';

import '../fitur/auth_owner/layar_beranda.dart';
import '../fitur/auth_owner/layar_daftar_owner.dart';
import '../fitur/auth_owner/layar_masuk_owner.dart';
import '../fitur/auth_owner/layar_setup_pin_owner.dart';
import '../fitur/bayar/rute_bayar.dart';
import '../fitur/dasbor/rute_dasbor.dart';
import '../fitur/kasir/rute_kasir.dart';
import '../fitur/pos/rute_pos.dart';
import '../fitur/stok_kombo/rute_stok_kombo.dart';
import '../fitur/tagihan/rute_tagihan.dart';
import '../fitur/void_kasbon/rute_void_kasbon.dart';

/// Nama route terpusat — jangan hardcode string path di widget.
abstract final class Rute {
  static const daftar = '/daftar';
  static const masuk = '/masuk';
  static const setupPin = '/setup-pin';
  static const beranda = '/beranda';

  // Kasir & shift (Fase 2)
  static const kasir = '/kasir';
  static const pinKasir = '/kasir/pin';
  static const bukaShift = '/shift/buka';
  static const tutupShift = '/shift/tutup';

  // POS (Fase 3)
  static const pos = '/pos';

  // Open bill & tagihan (Fase 4)
  static const tagihan = '/tagihan';

  // Pembayaran (Fase 5)
  static const bayar = '/bayar';

  // Kasbon & kas keluar (Fase 6)
  static const kasbon = '/kasbon';
  static const kasKeluar = '/kas-keluar';

  // Stok & kombo (Fase 7)
  static const stok = '/stok';
  static const kombo = '/kombo';

  // Dashboard owner (Fase 8)
  static const dasbor = '/dasbor';
  static const katalog = '/katalog';
  static const laporan = '/laporan';
  static const audit = '/audit';
  static const akunKasir = '/akun-kasir';
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
      ...ruteKasir,
      ...rutePos,
      ...ruteTagihan,
      ...ruteBayar,
      ...ruteVoidKasbon,
      ...ruteStokKombo,
      ...ruteDasbor,
    ],
  );
}

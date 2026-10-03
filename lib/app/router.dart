import 'package:go_router/go_router.dart';

import 'cangkang_nav.dart';
import '../fitur/auth_owner/layar_beranda.dart';
import '../fitur/auth_owner/layar_masuk_owner.dart';
import '../fitur/auth_owner/layar_setup_pin_owner.dart';
import '../fitur/dasbor/layar_dasbor.dart';
import '../fitur/lainnya/layar_lainnya.dart';
import '../fitur/lainnya/rute_lainnya.dart';
import '../fitur/pos/layar_pos.dart';
import '../fitur/selamat_datang/layar_selamat_datang.dart';
import '../fitur/stok_kombo/layar_stok.dart';
import '../fitur/tagihan/layar_daftar_tagihan.dart';
import '../fitur/bayar/rute_bayar.dart';
import '../fitur/dasbor/rute_dasbor.dart';
import '../fitur/kasir/rute_kasir.dart';
import '../fitur/pos/rute_pos.dart';
import '../fitur/stok_kombo/rute_stok_kombo.dart';
import '../fitur/tagihan/rute_tagihan.dart';
import '../fitur/void_kasbon/rute_void_kasbon.dart';

/// Nama route terpusat — jangan hardcode string path di widget.
abstract final class Rute {
  static const selamatDatang = '/';
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
  static const tagihanBaru = '/tagihan/baru';

  // Pembayaran (Fase 5)
  static const bayar = '/bayar';

  // Kasbon & kas keluar (Fase 6)
  static const kasbon = '/kasbon';
  static const kasKeluar = '/kas-keluar';

  // Stok & kombo (Fase 7) + redesign stok (bahan, opname, belanja)
  static const stok = '/stok';
  static const kombo = '/kombo';
  static const bahan = '/bahan';
  static const stokOpname = '/stok-opname';
  static const riwayatOpname = '/riwayat-opname';
  static const belanja = '/belanja';

  // Dashboard owner (Fase 8)
  static const dasbor = '/dasbor';
  static const katalog = '/katalog';
  static const laporan = '/laporan';
  static const audit = '/audit';
  static const akunKasir = '/akun-kasir';

  // Menu lainnya: grid modul + daftar belanja + pengaturan
  static const lainnya = '/lainnya';
  static const daftarBelanja = '/daftar-belanja';
  static const pengaturan = '/pengaturan';
}

/// GoRouter aplikasi. Guard auth sederhana ditangani per-layar agar
/// alur pendaftaran tetap mulus saat offline.
GoRouter bangunRouter() {
  return GoRouter(
    initialLocation: Rute.selamatDatang,
    routes: [
      GoRoute(
        path: Rute.selamatDatang,
        builder: (context, state) => const LayarSelamatDatang(),
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
      // Cangkang navigasi bawah: Beranda · Stok · [Kasir] · Tagihan · Lainnya.
      // Tiap cabang menjaga tumpukan navigasinya sendiri.
      StatefulShellRoute.indexedStack(
        builder: (context, state, cangkang) =>
            CangkangNav(cangkang: cangkang),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.dasbor,
                builder: (context, state) => const LayarDasbor(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.stok,
                builder: (context, state) => const LayarStok(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.pos,
                builder: (context, state) => const LayarPos(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.tagihan,
                builder: (context, state) => const LayarDaftarTagihan(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.lainnya,
                builder: (context, state) => const LayarLainnya(),
              ),
            ],
          ),
        ],
      ),
      ...ruteKasir,
      ...rutePos,
      ...ruteTagihan,
      ...ruteBayar,
      ...ruteVoidKasbon,
      ...ruteStokKombo,
      ...ruteDasbor,
      ...ruteLainnya,
    ],
  );
}

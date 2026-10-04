import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cangkang_nav.dart';
import 'cangkang_nav_kasir.dart';
import 'layar_akses_ditolak.dart';
import 'penyedia.dart';
import '../bersama/izin/layar_izin_awal.dart';
import '../fitur/auth_owner/layar_beranda.dart';
import '../fitur/auth_owner/layar_masuk_owner.dart';
import '../fitur/auth_owner/layar_setup_pin_owner.dart';
import '../fitur/dasbor/layar_akun_kasir.dart';
import '../fitur/dasbor/layar_dasbor.dart';
import '../fitur/dasbor/layar_laporan.dart';
import '../fitur/kasir/layar_profil_kasir.dart';
import '../fitur/kasir/layar_statistik_kasir.dart';
import '../fitur/kasir/penyedia_kasir.dart';
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
  static const aksesDitolak = '/akses-ditolak';
  static const izinAwal = '/izin-awal';

  // Kasir & shift (Fase 2)
  static const kasir = '/kasir';
  static const pinKasir = '/kasir/pin';
  static const bukaShift = '/shift/buka';
  static const tutupShift = '/shift/tutup';

  // Open bill & tagihan (kasir saja)
  static const tagihanBaru = '/tagihan/baru';

  // Pembayaran (kasir saja)
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
  static const kategori = '/kategori';
  static const menu = '/menu';
  static const laporan = '/laporan';
  static const audit = '/audit';
  static const akunKasir = '/akun-kasir';
  static const riwayatShift = '/riwayat-shift';

  // Menu lainnya: grid modul + pengaturan
  static const lainnya = '/lainnya';
  static const pengaturan = '/pengaturan';

  // Shell kasir (navbar khusus kasir, terpisah dari owner)
  static const kasirPos = '/k/pos';
  static const kasirTagihan = '/k/tagihan';
  static const kasirStatistik = '/k/statistik';
  static const kasirAkun = '/k/akun';

  /// Path yang hanya boleh dibuka kasir (selain /k/*).
  static bool adalahRuteKhususKasir(String path) {
    return path.startsWith('/bayar/') ||
        path == '/tagihan/baru' ||
        path.startsWith('/tagihan/') ||
        path.startsWith('/pos/');
  }

  /// Path yang hanya boleh dibuka owner.
  static bool adalahRuteKhususOwner(String path) {
    const awalanOwner = [
      '/dasbor',
      '/stok',
      '/laporan',
      '/lainnya',
      '/kategori',
      '/menu',
      '/audit',
      '/akun-kasir',
      '/riwayat-shift',
      '/masuk',
      '/setup-pin',
      '/beranda',
      '/pengaturan',
      '/bahan',
      '/kombo',
      '/stok-opname',
      '/riwayat-opname',
      '/belanja',
      '/kasbon',
      '/kas-keluar',
    ];
    for (final awalan in awalanOwner) {
      if (path == awalan || path.startsWith('$awalan/')) return true;
    }
    return false;
  }
}

/// Guard peran: kasir tidak boleh membuka rute owner, owner tidak boleh
/// membuka rute kasir (POS/pembayaran). Mengembalikan null bila boleh.
String? jagaPeran(Ref ref, GoRouterState state) {
  final path = state.uri.path;

  // Rute publik & alur login/shift kasir: selalu boleh.
  if (path == Rute.selamatDatang ||
      path == Rute.aksesDitolak ||
      path == Rute.izinAwal ||
      path == Rute.kasir ||
      path.startsWith('/kasir/pin') ||
      path == Rute.bukaShift ||
      path == Rute.tutupShift) {
    return null;
  }

  final adalahKasir = ref.read(sesiKasirProvider) != null;

  if (adalahKasir) {
    // Kasir dilarang membuka rute owner.
    if (Rute.adalahRuteKhususOwner(path)) {
      return '${Rute.aksesDitolak}?untuk=owner&kembali=${Rute.kasirPos}';
    }
    return null;
  }

  // Bukan kasir: rute kasir hanya untuk kasir.
  // Owner yang mencoba → halaman penolakan ramah.
  final profil = ref.read(penyediaProfilPemilik).maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );
  final adalahRuteKasir =
      path.startsWith('/k/') || Rute.adalahRuteKhususKasir(path);
  if (adalahRuteKasir) {
    if (profil != null) {
      return '${Rute.aksesDitolak}?untuk=kasir&kembali=${Rute.dasbor}';
    }
    // Belum login siapa pun → ke selamat datang.
    return Rute.selamatDatang;
  }
  return null;
}

/// GoRouter aplikasi.
///
/// Dua shell terpisah berdasarkan peran:
/// - Owner: Beranda · Stok · Laporan · Lainnya (tanpa POS/pembayaran).
/// - Kasir: [Kasir] · Tagihan · Statistik · Akun.
/// Guard auth sederhana ditangani per-layar; guard peran via [jagaPeran].
GoRouter bangunRouter(Ref ref) {
  return GoRouter(
    initialLocation: Rute.selamatDatang,
    redirect: (context, state) => jagaPeran(ref, state),
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
      GoRoute(
        path: Rute.aksesDitolak,
        builder: (context, state) => const LayarAksesDitolak(),
      ),
      GoRoute(
        path: Rute.izinAwal,
        builder: (context, state) => const LayarIzinAwal(),
      ),
      // Cangkang owner: Stok · Kelola Kasir · [Beranda] · Laporan · Lainnya.
      // Tiap cabang menjaga tumpukan navigasinya sendiri.
      StatefulShellRoute.indexedStack(
        builder: (context, state, cangkang) => CangkangNav(cangkang: cangkang),
        branches: [
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
                path: Rute.akunKasir,
                builder: (context, state) => const LayarAkunKasir(),
              ),
            ],
          ),
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
                path: Rute.laporan,
                builder: (context, state) => const LayarLaporan(),
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
      // Cangkang kasir: [Kasir] · Tagihan · Statistik · Akun.
      StatefulShellRoute.indexedStack(
        builder: (context, state, cangkang) =>
            CangkangNavKasir(cangkang: cangkang),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.kasirPos,
                builder: (context, state) => const LayarPos(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.kasirTagihan,
                builder: (context, state) => const LayarDaftarTagihan(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.kasirStatistik,
                builder: (context, state) => const LayarStatistikKasir(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.kasirAkun,
                builder: (context, state) => const LayarProfilKasir(),
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

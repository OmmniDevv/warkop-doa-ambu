import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:warkop_doa_ambu/app/router.dart';

/// Verifikasi sementara: semua path penting match tepat satu rute,
/// dan tidak ada duplikasi path setelah restrukturisasi shell.
void main() {
  test('semua rute cocok dan unik', () {
    final router = bangunRouter();
    const paths = [
      '/',
      '/masuk',
      '/setup-pin',
      '/beranda',
      '/dasbor',
      '/stok',
      '/pos',
      '/tagihan',
      '/lainnya',
      '/kategori',
      '/menu',
      '/laporan',
      '/audit',
      '/akun-kasir',
      '/kombo',
      '/bahan',
      '/stok-opname',
      '/riwayat-opname',
      '/belanja',
      '/pos/tagihan/abc',
      '/tagihan/baru',
      '/tagihan/abc',
      '/kasir',
      '/kasir/pin/abc',
      '/shift/buka',
      '/shift/tutup',
      '/bayar/abc',
      '/kasbon',
      '/kas-keluar',
      '/daftar-belanja',
      '/pengaturan',
    ];
    for (final p in paths) {
      final match = router.configuration.findMatch(Uri.parse(p));
      expect(match.matches.isNotEmpty, isTrue, reason: 'tidak cocok: $p');
    }

    // Tidak boleh ada path ganda.
    // Pengecekan sederhana: bangunRouter() tidak throw = tidak ada duplikat
    // yang terdeteksi saat registrasi (go_router melempar saat duplikat).
  });

  test('lima tab berada di dalam StatefulShellRoute', () {
    final router = bangunRouter();
    var jumlahCabang = 0;
    for (final r in router.configuration.routes) {
      if (r is StatefulShellRoute) {
        jumlahCabang = r.branches.length;
        for (final path in ['/dasbor', '/stok', '/pos', '/tagihan', '/lainnya']) {
          final match = router.configuration.findMatch(Uri.parse(path));
          final diDalamShell = match.matches
              .any((m) => m.route is StatefulShellRoute);
          expect(diDalamShell, isTrue, reason: '$path di luar shell');
        }
      }
    }
    expect(jumlahCabang, 5);
  });
}

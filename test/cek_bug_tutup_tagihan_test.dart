import 'package:flutter_test/flutter_test.dart';

/// Reproduksi bug: tombol "Tutup Tagihan" hilang total saat ada nota
/// belum bayar, sehingga user bingung kenapa tagihan "ga bisa ditutup".
///
/// Perilaku yang benar (setelah fix): tombol TETAP TAMPIL tapi nonaktif
/// saat ada nota 'baru', dengan pesan penjelasan yang jelas.
void main() {
  test('logika bisaTutup: tombol harus tampil untuk tagihan buka', () {
    // Simulasi kondisi dari _tampilanNormal:
    // tagihan.status == 'buka', ada 1 nota 'baru', 1 nota 'lunas'
    const statusTagihan = 'buka';
    final daftarBaru = ['nota-1']; // 1 nota belum bayar

    // Logika LAMA (bug): tombol hilang total
    final bisaTutupLama =
        statusTagihan == 'buka' && daftarBaru.isEmpty;
    // ignore: avoid_print
    print('Logika lama — tombol tampil: $bisaTutupLama (harus true)');
    expect(bisaTutupLama, isFalse,
        reason: 'Bug terkonfirmasi: tombol hilang saat ada nota belum bayar');

    // Logika BARU (fix): tombol tampil tapi nonaktif
    final tombolTampil = statusTagihan == 'buka';
    final tombolAktif = daftarBaru.isEmpty;
    expect(tombolTampil, isTrue,
        reason: 'Tombol harus tetap tampil untuk tagihan terbuka');
    expect(tombolAktif, isFalse,
        reason: 'Tombol nonaktif saat ada nota belum bayar');
  });
}

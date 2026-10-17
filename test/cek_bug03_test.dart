import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/bersama/util/stok_aman.dart';

/// BUG-03: kegagalan kurangiStok()/kurangiStokBahanResep() di _selesaikan()
/// saat ini diabaikan diam-diam (catch kosong).
///
/// Perilaku yang diharapkan:
/// - pembayaran TIDAK boleh gagal karena stok gagal dikurangi
/// - nama item yang gagal HARUS dikembalikan agar bisa dicatat ke log audit
///   dan ditampilkan di dialog sukses ("Stok X gagal diperbarui, koreksi manual")
void main() {
  group('kurangiStokAman', () {
    test('mengembalikan null bila operasi berhasil', () async {
      final hasil = await kurangiStokAman('Kopi Tubruk', () async {});
      expect(hasil, isNull);
    });

    test('mengembalikan nama item bila operasi melempar', () async {
      final hasil = await kurangiStokAman('Kopi Tubruk', () async {
        throw Exception('db terkunci');
      });
      expect(hasil, 'Kopi Tubruk');
    });

    test('tidak melempar walau operasi gagal (pembayaran jalan terus)',
        () async {
      await expectLater(
        kurangiStokAman('Indomie Goreng', () async {
          throw StateError('koneksi putus');
        }),
        completes,
      );
    });
  });
}

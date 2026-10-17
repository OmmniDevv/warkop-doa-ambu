import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/fitur/stok_kombo/mesin_sinkron.dart';

/// BUG-07: kegagalan upload foto bukti di _unggahBukti() saat ini
/// diabaikan diam-diam — foto hanya ada di device, tidak pernah di-retry.
///
/// Perilaku yang diharapkan:
/// - MesinSinkron harus bisa mendeteksi pesanan yang butuh upload ulang
///   foto (punya foto_bukti_lokal tapi foto_bukti_remote masih null)
/// - Upload ulang dilakukan di sinkronkan() agar foto tidak hilang
void main() {
  group('perluUnggahUlangBukti — deteksi foto yang gagal terunggah', () {
    test('true bila ada lokal tapi belum ada remote', () {
      final baris = {
        'id': 'psn-001',
        'foto_bukti_lokal': '/data/bukti.jpg',
        'foto_bukti_remote': null,
      };
      expect(MesinSinkron.perluUnggahUlangBukti(baris), isTrue);
    });

    test('false bila sudah ada remote', () {
      final baris = {
        'id': 'psn-001',
        'foto_bukti_lokal': '/data/bukti.jpg',
        'foto_bukti_remote': 'bukti/psn-001_123.jpg',
      };
      expect(MesinSinkron.perluUnggahUlangBukti(baris), isFalse);
    });

    test('false bila tidak ada foto lokal', () {
      final baris = {
        'id': 'psn-001',
        'foto_bukti_lokal': null,
        'foto_bukti_remote': null,
      };
      expect(MesinSinkron.perluUnggahUlangBukti(baris), isFalse);
    });

    test('false bila path lokal kosong', () {
      final baris = {
        'id': 'psn-001',
        'foto_bukti_lokal': '',
        'foto_bukti_remote': null,
      };
      expect(MesinSinkron.perluUnggahUlangBukti(baris), isFalse);
    });
  });
}

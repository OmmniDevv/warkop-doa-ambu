import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/data/model/pesanan.dart';
import 'package:warkop_doa_ambu/fitur/void_kasbon/layanan_void.dart';

Pesanan _pesananUji({required String status}) => Pesanan(
      id: 'psn-001',
      nomorNota: 'WDA-20261017-0001',
      idAkun: 'akun-001',
      idShift: 'shift-001',
      metodeBayar: 'tunai',
      status: status,
      total: 25000,
      bayar: 25000,
      kembalian: 0,
      statusSinkron: 'tertunda',
      diperbaruiPada: DateTime.utc(2026, 10, 17),
      apakahDihapus: false,
    );

void main() {
  group('BUG-05: void ganda ditolak', () {
    test('pesanan lunas boleh di-void (null = lolos validasi)', () {
      final pesanan = _pesananUji(status: 'lunas');
      expect(validasiBolehVoid(pesanan), isNull);
    });

    test('pesanan baru boleh di-void (null = lolos validasi)', () {
      final pesanan = _pesananUji(status: 'baru');
      expect(validasiBolehVoid(pesanan), isNull);
    });

    test('pesanan yang sudah void DITOLAK dengan pesan jelas', () {
      final pesanan = _pesananUji(status: 'void');
      expect(validasiBolehVoid(pesanan), 'Pesanan sudah di-void.');
    });

    test('pesanan null DITOLAK (tidak ditemukan)', () {
      expect(validasiBolehVoid(null), isNotNull);
    });
  });
}

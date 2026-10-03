import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/bersama/format/format_uang.dart';
import 'package:warkop_doa_ambu/bersama/util/id_unik.dart';
import 'package:warkop_doa_ambu/data/model/akun.dart';
import 'package:warkop_doa_ambu/data/model/kasbon.dart';
import 'package:warkop_doa_ambu/data/model/menu.dart';
import 'package:warkop_doa_ambu/data/model/pesanan.dart';
import 'package:warkop_doa_ambu/data/model/pesanan_rincian.dart';
import 'package:warkop_doa_ambu/fitur/kasir/keamanan_pin_kasir.dart';
import 'package:warkop_doa_ambu/fitur/pos/model_keranjang.dart';
import 'package:warkop_doa_ambu/fitur/printer/pembangun_nota.dart';

void main() {
  group('formatRupiah', () {
    test('nol', () => expect(formatRupiah(0), 'Rp0'));
    test('ribuan', () => expect(formatRupiah(15000), 'Rp15.000'));
    test('jutaan', () => expect(formatRupiah(1000000), 'Rp1.000.000'));
    test('negatif', () => expect(formatRupiah(-5000), '-Rp5.000'));
  });

  group('idBaru', () {
    test('unik dan format UUID', () {
      final a = idBaru();
      final b = idBaru();
      expect(a, isNot(equals(b)));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
                r'[0-9a-f]{12}$')
            .hasMatch(a),
        isTrue,
      );
    });
  });

  group('keamanan PIN kasir', () {
    test('hash deterministik per akun', () {
      final h1 = buatHashPinKasir(idAkun: 'akun-1', pin: '123456');
      final h2 = buatHashPinKasir(idAkun: 'akun-1', pin: '123456');
      expect(h1, equals(h2));
      expect(h1.length, 64);
    });

    test('akun berbeda menghasilkan hash berbeda', () {
      expect(
        buatHashPinKasir(idAkun: 'akun-1', pin: '123456'),
        isNot(equals(buatHashPinKasir(idAkun: 'akun-2', pin: '123456'))),
      );
    });

    test('verifikasi benar/salah', () {
      const id = 'akun-1';
      final hash = buatHashPinKasir(idAkun: id, pin: '123456');
      expect(
        cocokHashPinKasir(pin: '123456', idAkun: id, hashTersimpan: hash),
        isTrue,
      );
      expect(
        cocokHashPinKasir(pin: '654321', idAkun: id, hashTersimpan: hash),
        isFalse,
      );
      expect(
        cocokHashPinKasir(pin: '123456', idAkun: id, hashTersimpan: ''),
        isFalse,
      );
    });
  });

  group('model roundtrip keMap/dariMap', () {
    test('Akun', () {
      final akun = Akun(
        id: 'a1',
        nama: 'Kasir Budi',
        pinHash: 'hash',
        peran: 'kasir',
        aktif: true,
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.utc(2026, 10, 4, 1, 2, 3),
        apakahDihapus: false,
      );
      final balik = Akun.dariMap(akun.keMap());
      expect(balik.id, 'a1');
      expect(balik.nama, 'Kasir Budi');
      expect(balik.aktif, isTrue);
      expect(balik.pinHash, 'hash');
    });

    test('Menu', () {
      final menu = Menu(
        id: 'm1',
        idKategori: 'k1',
        nama: 'Kopi Tubruk',
        hargaSatuan: 8000,
        stok: 50,
        stokMinimum: 10,
        tersedia: true,
        statusSinkron: 'tersinkron',
        diperbaruiPada: DateTime.utc(2026, 10, 4),
        apakahDihapus: false,
      );
      final balik = Menu.dariMap(menu.keMap());
      expect(balik.nama, 'Kopi Tubruk');
      expect(balik.hargaSatuan, 8000);
      expect(balik.fotoUrl, isNull);
    });

    test('Pesanan copyWith', () {
      final p = Pesanan(
        id: 'p1',
        nomorNota: 'WDA-20261004-0001',
        idAkun: 'a1',
        metodeBayar: 'tunai',
        status: 'baru',
        total: 20000,
        bayar: 0,
        kembalian: 0,
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.utc(2026, 10, 4),
        apakahDihapus: false,
      );
      final lunas = p.copyWith(status: 'lunas', bayar: 20000);
      expect(lunas.status, 'lunas');
      expect(lunas.nomorNota, 'WDA-20261004-0001');
      expect(Pesanan.dariMap(lunas.keMap()).bayar, 20000);
    });

    test('Kasbon sisa bayar', () {
      final k = Kasbon(
        id: 'k1',
        namaPelanggan: 'Pak RT',
        nominal: 50000,
        sudahBayar: 20000,
        status: 'belum_lunas',
        idAkun: 'a1',
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.utc(2026, 10, 4),
        apakahDihapus: false,
      );
      expect(k.nominal - k.sudahBayar, 30000);
      expect(Kasbon.dariMap(k.keMap()).status, 'belum_lunas');
    });
  });

  group('BarisKeranjang', () {
    test('subtotal', () {
      final b = BarisKeranjang(
        idBaris: idBaru(),
        idMenu: 'm1',
        nama: 'Kopi Tubruk',
        hargaSatuan: 8000,
        jumlah: 3,
      );
      expect(b.subtotal, 24000);
      final salinan = b.salin();
      expect(salinan.subtotal, 24000);
      expect(identical(salinan, b), isFalse);
    });
  });

  group('bangunTeksNota', () {
    test('semua baris maksimal 32 kolom', () {
      final teks = bangunTeksNota(
        namaWarkop: 'WARKOP DOA AMBU',
        nomorNota: 'WDA-20261004-0001',
        namaKasir: 'Budi',
        rincian: [
          PesananRincian(
            id: 'r1',
            idPesanan: 'p1',
            idMenu: 'm1',
            namaSnapshot: 'Kopi Tubruk Panas Spesial',
            hargaSnapshot: 8000,
            jumlah: 2,
            subtotal: 16000,
            statusSinkron: 'tertunda',
            diperbaruiPada: DateTime.utc(2026, 10, 4),
            apakahDihapus: false,
          ),
        ],
        total: 16000,
        bayar: 20000,
        kembalian: 4000,
        metodeBayar: 'tunai',
        waktu: DateTime(2026, 10, 4, 10, 30),
      );
      expect(teks, contains('WARKOP DOA AMBU'));
      expect(teks, contains('Terima kasih'));
      for (final baris in teks.split('\n')) {
        expect(baris.length, lessThanOrEqualTo(32), reason: 'baris: $baris');
      }
    });
  });
}

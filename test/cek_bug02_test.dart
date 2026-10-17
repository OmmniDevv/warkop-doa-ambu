import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warkop_doa_ambu/data/lokal/database_lokal.dart';
import 'package:warkop_doa_ambu/data/model/menu.dart';
import 'package:warkop_doa_ambu/data/model/pesanan.dart';
import 'package:warkop_doa_ambu/data/model/pesanan_rincian.dart';
import 'package:warkop_doa_ambu/fitur/void_kasbon/layanan_void.dart';

/// Test BUG-02: void harus mengembalikan stok menu + bahan.
///
/// Alur: buat menu (stok 10) → buat pesanan lunas dengan 2 rincian →
/// kurangi stok (simulasi pembayaran) → jalankanVoid → stok kembali 10.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('jalankanVoid mengembalikan stok menu yang sudah dikurangi',
      () async {
    final db = DatabaseLokal.instance;

    // Siapkan menu dengan stok 10.
    await db.simpanMenu(Menu(
      id: 'm-uji-01',
      idKategori: 'k-uji-01',
      nama: 'Kopi Tubruk Uji',
      hargaSatuan: 8000,
      stok: 10,
      stokMinimum: 2,
      tersedia: true,
      statusSinkron: 'tersinkron',
      diperbaruiPada: DateTime.utc(2026, 10, 17),
      apakahDihapus: false,
    ));

    // Buat pesanan lunas.
    const idPesanan = 'psn-uji-01';
    await db.simpanPesanan(Pesanan(
      id: idPesanan,
      nomorNota: 'WDA-20261017-UJI1',
      idAkun: 'akun-uji-01',
      metodeBayar: 'tunai',
      status: 'lunas',
      total: 16000,
      bayar: 16000,
      kembalian: 0,
      statusSinkron: 'tertunda',
      diperbaruiPada: DateTime.utc(2026, 10, 17),
      apakahDihapus: false,
    ));
    await db.simpanRincian(PesananRincian(
      id: 'rnc-uji-01',
      idPesanan: idPesanan,
      idMenu: 'm-uji-01',
      namaSnapshot: 'Kopi Tubruk Uji',
      hargaSnapshot: 8000,
      jumlah: 2,
      subtotal: 16000,
      statusSinkron: 'tertunda',
      diperbaruiPada: DateTime.utc(2026, 10, 17),
      apakahDihapus: false,
    ));

    // Simulasi pembayaran: kurangi stok 2.
    await db.kurangiStok('m-uji-01', 2);
    var menu = await db.ambilMenu('m-uji-01');
    expect(menu?.stok, 8);

    // Jalankan void → stok harus kembali 10.
    final galat = await jalankanVoid(
      db,
      idPesanan: idPesanan,
      alasan: 'uji void kembalikan stok',
      idAkun: 'akun-uji-01',
    );
    expect(galat, isNull);

    menu = await db.ambilMenu('m-uji-01');
    expect(menu?.stok, 10);

    final pesanan = await db.ambilPesanan(idPesanan);
    expect(pesanan?.status, 'void');
  });

  test('jalankanVoid menolak pesanan yang sudah void (BUG-05)', () async {
    final db = DatabaseLokal.instance;
    const idPesanan = 'psn-uji-02';
    await db.simpanPesanan(Pesanan(
      id: idPesanan,
      nomorNota: 'WDA-20261017-UJI2',
      idAkun: 'akun-uji-01',
      metodeBayar: 'tunai',
      status: 'void',
      total: 8000,
      bayar: 8000,
      kembalian: 0,
      voidAlasan: 'sudah di-void sebelumnya',
      voidDisetujuiOwner: true,
      statusSinkron: 'tertunda',
      diperbaruiPada: DateTime.utc(2026, 10, 17),
      apakahDihapus: false,
    ));

    final galat = await jalankanVoid(
      db,
      idPesanan: idPesanan,
      alasan: 'coba void ganda',
      idAkun: 'akun-uji-01',
    );
    expect(galat, 'Pesanan sudah di-void.');
  });
}

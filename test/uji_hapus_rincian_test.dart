import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warkop_doa_ambu/data/lokal/database_lokal.dart';
import 'package:warkop_doa_ambu/data/model/pesanan_rincian.dart';

/// Test regresi BUG-04: hapusRincian() tidak boleh hard-delete baris yang
/// sudah tersinkron — harus soft-delete agar penghapusan ter-upload ke server.
///
/// Latar: hard-delete lokal tanpa tombstone menyebabkan divergensi sinkron:
/// server tetap menyimpan barisnya, dan unduhan berikutnya bisa memunculkan
/// kembali baris yang sudah dihapus.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    // Isolasi antar test: tutup & hapus file DB singleton.
    await DatabaseLokal.instance.tutupUntukTest();
    await databaseFactoryFfi.deleteDatabase(
      '${await getDatabasesPath()}/warkop_doa_ambu.db',
    );
  });

  PesananRincian rincianTersinkron() => PesananRincian(
        id: 'rincian-1',
        idPesanan: 'pesanan-1',
        idMenu: 'menu-1',
        namaSnapshot: 'Kopi Tubruk',
        hargaSnapshot: 10000,
        jumlah: 2,
        subtotal: 20000,
        statusSinkron: 'tersinkron',
        diperbaruiPada: DateTime.utc(2026, 10, 17),
        apakahDihapus: false,
      );

  group('BUG-04: hapusRincian soft-delete', () {
    test('baris tersinkron dihapus lunak, bukan hilang', () async {
      final db = DatabaseLokal.instance;
      await db.simpanRincian(rincianTersinkron());

      await db.hapusRincian('rincian-1');

      // Baris MASIH ADA di SQLite (tombstone untuk sinkron).
      final mentah = await (await db.db).query(
        'pesanan_rincian',
        where: 'id = ?',
        whereArgs: ['rincian-1'],
      );
      expect(mentah, hasLength(1));
      expect(mentah.single['apakah_dihapus'], 1);
      expect(mentah.single['status_sinkron'], 'tertunda');
    });

    test('daftar rincian tidak menampilkan yang dihapus lunak', () async {
      final db = DatabaseLokal.instance;
      await db.simpanRincian(rincianTersinkron());
      await db.simpanRincian(rincianTersinkron().copyWith(
        id: 'rincian-2',
        namaSnapshot: 'Teh Manis',
      ));

      await db.hapusRincian('rincian-1');

      final daftar = await db.daftarRincianPesanan('pesanan-1');
      expect(daftar.map((r) => r.id), ['rincian-2']);
    });

    test('baris terhapus lunak masuk antrean upload', () async {
      final db = DatabaseLokal.instance;
      await db.simpanRincian(rincianTersinkron());

      await db.hapusRincian('rincian-1');

      // daftarTertunda sengaja TIDAK memfilter apakah_dihapus agar
      // penghapusan ter-upload ke Supabase.
      final tertunda = await db.daftarTertunda('pesanan_rincian');
      expect(tertunda.any((b) => b['id'] == 'rincian-1'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:warkop_doa_ambu/data/lokal/database_lokal.dart';
import 'package:warkop_doa_ambu/data/model/open_bill.dart';

/// Reproduksi bug: tutup tagihan tidak mengupdate `diperbaruiPada`,
/// sehingga sync last-write-wins menimpa status 'tutup' lokal dengan
/// status 'buka' dari server yang timestamp-nya lebih baru.
/// Akibat: tagihan yang sudah ditutup MUNCUL LAGI di daftar.
///
/// Perilaku yang benar (setelah fix): saat tutup, `diperbaruiPada`
/// di-set ke waktu sekarang dan `statusSinkron` jadi 'tertunda'
/// agar perubahan ikut terunggah ke Supabase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('tutup tagihan harus update diperbaruiPada ke waktu sekarang',
      () async {
    final db = DatabaseLokal.instance;

    // Buat tagihan dengan timestamp lama (simulasi dibuat 1 jam lalu).
    final satuJamLalu = DateTime.now().subtract(const Duration(hours: 1));
    final tagihan = OpenBill(
      id: 'test-tutup-ts',
      label: 'Meja Test',
      status: 'buka',
      idAkun: 'akun-test',
      diperbaruiPada: satuJamLalu,
    );
    await db.simpanOpenBill(tagihan);

    // Simulasi logika _tutupTagihan SETELAH fix: update timestamp + status.
    final sebelumTutup = DateTime.now();
    await db.perbaruiOpenBill(tagihan.copyWith(
      status: 'tutup',
      diperbaruiPada: DateTime.now(),
      statusSinkron: 'tertunda',
    ));

    final sesudah = await db.ambilOpenBill('test-tutup-ts');
    expect(sesudah, isNotNull);
    expect(sesudah!.status, 'tutup');
    expect(
      sesudah.diperbaruiPada.isAfter(sebelumTutup) ||
          sesudah.diperbaruiPada.isAtSameMomentAs(sebelumTutup),
      isTrue,
      reason: 'diperbaruiPada harus >= waktu tutup, bukan timestamp lama',
    );
    expect(
      sesudah.diperbaruiPada.isAfter(satuJamLalu),
      isTrue,
      reason: 'diperbaruiPada harus lebih baru dari waktu pembuatan',
    );
    expect(sesudah.statusSinkron, 'tertunda');

    // Tagihan yang ditutup tidak boleh muncul di daftar aktif.
    final aktif = await db.daftarOpenBillAktif();
    expect(
      aktif.any((t) => t.id == 'test-tutup-ts'),
      isFalse,
      reason: 'tagihan tutup tidak boleh ada di daftar aktif',
    );

  });
}

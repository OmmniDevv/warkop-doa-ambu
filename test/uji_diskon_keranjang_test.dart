import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/data/model/menu.dart';
import 'package:warkop_doa_ambu/fitur/pos/penyedia_keranjang.dart';

Menu _menu() => Menu(
      id: 'menu-1',
      idKategori: 'kat-1',
      nama: 'Kopi Tubruk',
      hargaSatuan: 10000,
      diperbaruiPada: DateTime.utc(2026, 10, 17),
    );

/// Test regresi BUG-01: diskon baris keranjang tidak boleh hilang diam-diam
/// saat jumlah atau catatan diubah.
///
/// Latar: BarisKeranjang.salin() harus menyalin SEMUA field termasuk
/// diskonNominal dan diskonPersen, karena ubahJumlah() dan ubahCatatan()
/// memakai salin() untuk membangun state baru.
void main() {
  group('BUG-01: diskon bertahan saat keranjang dimutasi', () {
    test('ubahJumlah mempertahankan diskon nominal', () {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);
      final notif = wadah.read(penyediaKeranjang.notifier);

      notif.tambahMenu(_menu());
      final idBaris = wadah.read(penyediaKeranjang).single.idBaris;
      notif.ubahDiskonItem(idBaris, nominal: 3000);

      notif.ubahJumlah(idBaris, 3);

      final baris = wadah.read(penyediaKeranjang).single;
      expect(baris.diskonNominal, 3000);
      expect(baris.jumlah, 3);
      // 3 x 10000 - 3000 = 27000
      expect(baris.subtotal, 27000);
    });

    test('ubahJumlah mempertahankan diskon persen', () {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);
      final notif = wadah.read(penyediaKeranjang.notifier);

      notif.tambahMenu(_menu());
      final idBaris = wadah.read(penyediaKeranjang).single.idBaris;
      notif.ubahDiskonItem(idBaris, persen: 10);

      notif.ubahJumlah(idBaris, 2);

      final baris = wadah.read(penyediaKeranjang).single;
      expect(baris.diskonPersen, 10);
      // 2 x 10000 - 10% = 18000
      expect(baris.subtotal, 18000);
    });

    test('ubahCatatan mempertahankan diskon', () {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);
      final notif = wadah.read(penyediaKeranjang.notifier);

      notif.tambahMenu(_menu());
      final idBaris = wadah.read(penyediaKeranjang).single.idBaris;
      notif.ubahDiskonItem(idBaris, nominal: 2500);

      notif.ubahCatatan(idBaris, 'es sedikit');

      final baris = wadah.read(penyediaKeranjang).single;
      expect(baris.diskonNominal, 2500);
      expect(baris.catatan, 'es sedikit');
      expect(baris.subtotal, 7500);
    });

    test('ubahDiskonItem lalu ubahJumlah: diskon tetap', () {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);
      final notif = wadah.read(penyediaKeranjang.notifier);

      notif.tambahMenu(_menu());
      final idBaris = wadah.read(penyediaKeranjang).single.idBaris;

      notif.ubahDiskonItem(idBaris, persen: 20);
      notif.ubahJumlah(idBaris, 5);
      notif.ubahCatatan(idBaris, 'gula aren double');
      notif.ubahJumlah(idBaris, 4);

      final baris = wadah.read(penyediaKeranjang).single;
      expect(baris.diskonPersen, 20);
      expect(baris.jumlah, 4);
      // 4 x 10000 - 20% = 32000
      expect(baris.subtotal, 32000);
    });
  });
}

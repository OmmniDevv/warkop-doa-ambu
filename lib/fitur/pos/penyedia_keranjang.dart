import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bersama/util/id_unik.dart';
import '../../data/model/menu.dart';
import '../../data/model/paket_kombo.dart';
import 'model_keranjang.dart';

/// Penyedia keranjang belanja layar POS.
///
/// State selalu immutable: setiap mutasi membangun list baru supaya Riverpod
/// mendeteksi perubahan dengan benar.
final penyediaKeranjang =
    NotifierProvider<NotifikasiKeranjang, List<BarisKeranjang>>(
  NotifikasiKeranjang.new,
);

class NotifikasiKeranjang extends Notifier<List<BarisKeranjang>> {
  @override
  List<BarisKeranjang> build() => const [];

  /// Tambah satu [menu] ke keranjang.
  ///
  /// Digabung ke baris yang sama (tanpa catatan) bila ada; kalau baris yang
  /// ada sudah punya catatan, dibuat baris baru supaya catatannya tidak
  /// tercampur.
  void tambahMenu(Menu menu) {
    final indeks = state.indexWhere(
      (baris) => baris.idMenu == menu.id && baris.catatan == null,
    );
    if (indeks >= 0) {
      ubahJumlah(state[indeks].idBaris, state[indeks].jumlah + 1);
      return;
    }
    state = [
      ...state,
      BarisKeranjang(
        idBaris: idBaru(),
        idMenu: menu.id,
        nama: menu.nama,
        hargaSatuan: menu.hargaSatuan,
      ),
    ];
  }

  /// Tambah satu [paket] kombo ke keranjang (logika gabung sama seperti menu).
  void tambahPaket(PaketKombo paket) {
    final indeks = state.indexWhere(
      (baris) => baris.idPaket == paket.id && baris.catatan == null,
    );
    if (indeks >= 0) {
      ubahJumlah(state[indeks].idBaris, state[indeks].jumlah + 1);
      return;
    }
    state = [
      ...state,
      BarisKeranjang(
        idBaris: idBaru(),
        idPaket: paket.id,
        nama: paket.nama,
        hargaSatuan: paket.hargaPaket,
      ),
    ];
  }

  /// Ubah jumlah baris; jumlah 0 atau kurang menghapus baris.
  void ubahJumlah(String idBaris, int jumlah) {
    if (jumlah <= 0) {
      hapusBaris(idBaris);
      return;
    }
    state = [
      for (final baris in state)
        if (baris.idBaris == idBaris)
          baris.salin()..jumlah = jumlah
        else
          baris,
    ];
  }

  /// Hapus satu baris dari keranjang.
  void hapusBaris(String idBaris) {
    state = state.where((baris) => baris.idBaris != idBaris).toList();
  }

  /// Ubah catatan satu baris (catatan kosong disimpan sebagai null).
  void ubahCatatan(String idBaris, String catatan) {
    final bersih = catatan.trim();
    state = [
      for (final baris in state)
        if (baris.idBaris == idBaris)
          baris.salin()..catatan = bersih.isEmpty ? null : bersih
        else
          baris,
    ];
  }

  /// Ubah diskon satu baris (nominal rupiah untuk seluruh baris, atau
  /// persen 0–100). Keduanya dinolkan untuk menghapus diskon.
  void ubahDiskonItem(
    String idBaris, {
    int nominal = 0,
    double persen = 0,
  }) {
    state = [
      for (final baris in state)
        if (baris.idBaris == idBaris)
          baris.salin()
            ..diskonNominal = nominal < 0 ? 0 : nominal
            ..diskonPersen = persen.clamp(0, 100).toDouble()
        else
          baris,
    ];
  }

  /// Kosongkan seluruh keranjang.
  void kosongkan() {
    state = const [];
  }

  /// Jumlah seluruh item (total pcs, bukan jumlah baris).
  int get totalItem => state.totalItem;

  /// Total harga seluruh keranjang dalam rupiah.
  int get totalHarga => state.totalHarga;
}

/// Agregat praktis di atas list [BarisKeranjang].
extension EkstensiKeranjang on List<BarisKeranjang> {
  /// Jumlah seluruh item (total pcs, bukan jumlah baris).
  int get totalItem => fold(0, (total, baris) => total + baris.jumlah);

  /// Total harga seluruh baris dalam rupiah.
  int get totalHarga => fold(0, (total, baris) => total + baris.subtotal);
}

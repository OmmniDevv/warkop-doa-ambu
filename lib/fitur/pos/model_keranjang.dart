import '../../bersama/util/hitung_diskon.dart';

/// Satu baris item di keranjang belanja layar POS.
///
/// Satu [BarisKeranjang] bisa merujuk ke satu [Menu] (via [idMenu]) atau satu
/// [PaketKombo] (via [idPaket]) — salah satunya selalu terisi. Dua baris boleh
/// menunjuk item yang sama selama [catatan]-nya berbeda, misalnya "es sedikit"
/// dan "gula aren double".
///
/// Diskon per baris: [diskonNominal] (rupiah, untuk seluruh baris) atau
/// [diskonPersen] (0–100). Bila keduanya diisi, nominal yang dipakai.
class BarisKeranjang {
  /// Konstruktor tidak-const: [jumlah] dan [catatan] memang dirancang bisa
  /// diubah langsung, lalu [salin] dipakai untuk membangun state list baru
  /// (state keranjang tetap immutable di level list).
  BarisKeranjang({
    required this.idBaris,
    this.idMenu,
    this.idPaket,
    required this.nama,
    required this.hargaSatuan,
    this.jumlah = 1,
    this.catatan,
    this.diskonNominal = 0,
    this.diskonPersen = 0,
  });

  final String idBaris;
  final String? idMenu;
  final String? idPaket;
  final String nama;
  final int hargaSatuan;
  int jumlah;
  String? catatan;
  int diskonNominal;
  double diskonPersen;

  /// Harga kotor baris ini sebelum diskon.
  int get bruto => hargaSatuan * jumlah;

  /// Potongan diskon baris ini dalam rupiah.
  int get potonganDiskon => hitungPotongan(
        bruto,
        nominal: diskonNominal,
        persen: diskonPersen,
      );

  /// True bila baris ini punya diskon aktif.
  bool get adaDiskon => potonganDiskon > 0;

  /// Harga bersih baris ini setelah diskon (tidak pernah negatif).
  int get subtotal => bruto - potonganDiskon;

  /// Salinan baris ini (dengan [idBaris] yang sama) untuk mutasi immutable.
  BarisKeranjang salin() {
    return BarisKeranjang(
      idBaris: idBaris,
      idMenu: idMenu,
      idPaket: idPaket,
      nama: nama,
      hargaSatuan: hargaSatuan,
      jumlah: jumlah,
      catatan: catatan,
      diskonNominal: diskonNominal,
      diskonPersen: diskonPersen,
    );
  }
}

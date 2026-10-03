/// Satu baris item di keranjang belanja layar POS.
///
/// Satu [BarisKeranjang] bisa merujuk ke satu [Menu] (via [idMenu]) atau satu
/// [PaketKombo] (via [idPaket]) — salah satunya selalu terisi. Dua baris boleh
/// menunjuk item yang sama selama [catatan]-nya berbeda, misalnya "es sedikit"
/// dan "gula aren double".
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
  });

  final String idBaris;
  final String? idMenu;
  final String? idPaket;
  final String nama;
  final int hargaSatuan;
  int jumlah;
  String? catatan;

  int get subtotal => hargaSatuan * jumlah;

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
    );
  }
}

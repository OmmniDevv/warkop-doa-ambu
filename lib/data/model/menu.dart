/// Satu item menu yang dijual, misalnya "Kopi Tubruk".
///
/// Harga dalam rupiah (integer). [stok] dikurangi setiap ada penjualan;
/// [stokMinimum] dipakai untuk peringatan stok menipis.
class Menu {
  const Menu({
    required this.id,
    required this.idKategori,
    required this.nama,
    required this.hargaSatuan,
    this.stok = 0,
    this.stokMinimum = 0,
    this.tersedia = true,
    this.fotoUrl,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String idKategori;
  final String nama;
  final int hargaSatuan;
  final int stok;
  final int stokMinimum;
  final bool tersedia;
  final String? fotoUrl;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  Menu copyWith({
    String? id,
    String? idKategori,
    String? nama,
    int? hargaSatuan,
    int? stok,
    int? stokMinimum,
    bool? tersedia,
    String? fotoUrl,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return Menu(
      id: id ?? this.id,
      idKategori: idKategori ?? this.idKategori,
      nama: nama ?? this.nama,
      hargaSatuan: hargaSatuan ?? this.hargaSatuan,
      stok: stok ?? this.stok,
      stokMinimum: stokMinimum ?? this.stokMinimum,
      tersedia: tersedia ?? this.tersedia,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'id_kategori': idKategori,
        'nama': nama,
        'harga_satuan': hargaSatuan,
        'stok': stok,
        'stok_minimum': stokMinimum,
        'tersedia': tersedia ? 1 : 0,
        'foto_url': fotoUrl,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory Menu.dariMap(Map<String, Object?> map) {
    return Menu(
      id: map['id'] as String,
      idKategori: map['id_kategori'] as String,
      nama: map['nama'] as String,
      hargaSatuan: (map['harga_satuan'] as int?) ?? 0,
      stok: (map['stok'] as int?) ?? 0,
      stokMinimum: (map['stok_minimum'] as int?) ?? 0,
      tersedia: (map['tersedia'] as int? ?? 1) == 1,
      fotoUrl: map['foto_url'] as String?,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

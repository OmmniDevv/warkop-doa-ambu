/// Bahan baku untuk resep menu.
///
/// Bumbu TIDAK dicatat — hanya bahan utama yang memengaruhi stok.
/// [stok] dan [stokMinimum] memakai satuan [satuan].
class Bahan {
  const Bahan({
    required this.id,
    required this.nama,
    this.satuan = 'pcs',
    this.stok = 0,
    this.stokMinimum = 0,
    this.hargaBeli = 0,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String nama;
  final String satuan; // 'pcs' | 'gram' | 'kg' | 'ml' | 'liter' | 'bungkus' | 'ikat'
  final double stok;
  final double stokMinimum;
  final int hargaBeli;
  final String statusSinkron;
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  /// True bila stok sudah mencapai/masuk di bawah batas minimum.
  bool get menipis => stok <= stokMinimum;

  Bahan copyWith({
    String? id,
    String? nama,
    String? satuan,
    double? stok,
    double? stokMinimum,
    int? hargaBeli,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return Bahan(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      satuan: satuan ?? this.satuan,
      stok: stok ?? this.stok,
      stokMinimum: stokMinimum ?? this.stokMinimum,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, dynamic> keBaris() {
    return {
      'id': id,
      'nama': nama,
      'satuan': satuan,
      'stok': stok,
      'stok_minimum': stokMinimum,
      'harga_beli': hargaBeli,
      'status_sinkron': statusSinkron,
      'diperbarui_pada': diperbaruiPada.toIso8601String(),
      'apakah_dihapus': apakahDihapus ? 1 : 0,
    };
  }

  factory Bahan.dariBaris(Map<String, dynamic> baris) {
    return Bahan(
      id: baris['id'] as String,
      nama: baris['nama'] as String,
      satuan: baris['satuan'] as String? ?? 'pcs',
      stok: (baris['stok'] as num).toDouble(),
      stokMinimum: (baris['stok_minimum'] as num?)?.toDouble() ?? 0,
      hargaBeli: (baris['harga_beli'] as num?)?.toInt() ?? 0,
      statusSinkron: baris['status_sinkron'] as String? ?? 'tertunda',
      diperbaruiPada: DateTime.parse(baris['diperbarui_pada'] as String),
      apakahDihapus: (baris['apakah_dihapus'] as num? ?? 0) == 1,
    );
  }
}

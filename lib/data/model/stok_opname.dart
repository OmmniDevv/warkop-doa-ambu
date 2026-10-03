/// Catatan stok opname: perbandingan stok sistem vs stok fisik.
///
/// [tipeItem] 'menu' atau 'bahan'. [selisih] = [stokFisik] - [stokSistem]
/// (negatif berarti susut/hilang). Setelah dicatat, stok sistem
/// disesuaikan ke [stokFisik].
class StokOpname {
  const StokOpname({
    required this.id,
    required this.tipeItem,
    required this.idItem,
    required this.namaSnapshot,
    required this.stokSistem,
    required this.stokFisik,
    required this.selisih,
    this.catatan,
    required this.dibuatOleh,
    this.statusSinkron = 'tertunda',
    required this.dibuatPada,
  });

  final String id;
  final String tipeItem; // 'menu' | 'bahan'
  final String idItem;
  final String namaSnapshot;
  final double stokSistem;
  final double stokFisik;
  final double selisih;
  final String? catatan;
  final String dibuatOleh;
  final String statusSinkron;
  final DateTime dibuatPada;

  StokOpname copyWith({
    String? id,
    String? tipeItem,
    String? idItem,
    String? namaSnapshot,
    double? stokSistem,
    double? stokFisik,
    double? selisih,
    String? catatan,
    String? dibuatOleh,
    String? statusSinkron,
    DateTime? dibuatPada,
  }) {
    return StokOpname(
      id: id ?? this.id,
      tipeItem: tipeItem ?? this.tipeItem,
      idItem: idItem ?? this.idItem,
      namaSnapshot: namaSnapshot ?? this.namaSnapshot,
      stokSistem: stokSistem ?? this.stokSistem,
      stokFisik: stokFisik ?? this.stokFisik,
      selisih: selisih ?? this.selisih,
      catatan: catatan ?? this.catatan,
      dibuatOleh: dibuatOleh ?? this.dibuatOleh,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      dibuatPada: dibuatPada ?? this.dibuatPada,
    );
  }

  Map<String, dynamic> keBaris() {
    return {
      'id': id,
      'tipe_item': tipeItem,
      'id_item': idItem,
      'nama_snapshot': namaSnapshot,
      'stok_sistem': stokSistem,
      'stok_fisik': stokFisik,
      'selisih': selisih,
      'catatan': catatan,
      'dibuat_oleh': dibuatOleh,
      'status_sinkron': statusSinkron,
      'dibuat_pada': dibuatPada.toIso8601String(),
    };
  }

  factory StokOpname.dariBaris(Map<String, dynamic> baris) {
    return StokOpname(
      id: baris['id'] as String,
      tipeItem: baris['tipe_item'] as String,
      idItem: baris['id_item'] as String,
      namaSnapshot: baris['nama_snapshot'] as String,
      stokSistem: (baris['stok_sistem'] as num).toDouble(),
      stokFisik: (baris['stok_fisik'] as num).toDouble(),
      selisih: (baris['selisih'] as num).toDouble(),
      catatan: baris['catatan'] as String?,
      dibuatOleh: baris['dibuat_oleh'] as String,
      statusSinkron: baris['status_sinkron'] as String? ?? 'tertunda',
      dibuatPada: DateTime.parse(baris['dibuat_pada'] as String),
    );
  }
}

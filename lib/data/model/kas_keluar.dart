/// Pengeluaran kas di luar transaksi penjualan.
///
/// [kategori] bebas, misalnya "Belanja Bahan", "Gaji", "Lainnya".
class KasKeluar {
  const KasKeluar({
    required this.id,
    required this.idAkun,
    this.idShift,
    required this.kategori,
    required this.nominal,
    this.catatan,
    required this.terjadiPada,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String idAkun;
  final String? idShift;
  final String kategori;
  final int nominal;
  final String? catatan;
  final DateTime terjadiPada;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  KasKeluar copyWith({
    String? id,
    String? idAkun,
    String? idShift,
    String? kategori,
    int? nominal,
    String? catatan,
    DateTime? terjadiPada,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return KasKeluar(
      id: id ?? this.id,
      idAkun: idAkun ?? this.idAkun,
      idShift: idShift ?? this.idShift,
      kategori: kategori ?? this.kategori,
      nominal: nominal ?? this.nominal,
      catatan: catatan ?? this.catatan,
      terjadiPada: terjadiPada ?? this.terjadiPada,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'id_akun': idAkun,
        'id_shift': idShift,
        'kategori': kategori,
        'nominal': nominal,
        'catatan': catatan,
        'terjadi_pada': terjadiPada.toUtc().toIso8601String(),
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory KasKeluar.dariMap(Map<String, Object?> map) {
    return KasKeluar(
      id: map['id'] as String,
      idAkun: map['id_akun'] as String,
      idShift: map['id_shift'] as String?,
      kategori: map['kategori'] as String,
      nominal: (map['nominal'] as int?) ?? 0,
      catatan: map['catatan'] as String?,
      terjadiPada: DateTime.parse(map['terjadi_pada'] as String),
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

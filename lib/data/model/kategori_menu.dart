/// Kategori menu, misalnya "Kopi", "Snack".
///
/// [urutanTampil] menentukan urutan kategori di layar kasir.
class KategoriMenu {
  const KategoriMenu({
    required this.id,
    required this.nama,
    this.urutanTampil = 0,
    this.aktif = true,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String nama;
  final int urutanTampil;
  final bool aktif;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  KategoriMenu copyWith({
    String? id,
    String? nama,
    int? urutanTampil,
    bool? aktif,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return KategoriMenu(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      urutanTampil: urutanTampil ?? this.urutanTampil,
      aktif: aktif ?? this.aktif,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nama': nama,
        'urutan_tampil': urutanTampil,
        'aktif': aktif ? 1 : 0,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory KategoriMenu.dariMap(Map<String, Object?> map) {
    return KategoriMenu(
      id: map['id'] as String,
      nama: map['nama'] as String,
      urutanTampil: (map['urutan_tampil'] as int?) ?? 0,
      aktif: (map['aktif'] as int? ?? 1) == 1,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

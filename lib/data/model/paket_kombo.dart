/// Paket kombo (bundel beberapa menu dengan satu harga paket).
///
/// Isi paket disimpan di [PaketKomboRincian].
class PaketKombo {
  const PaketKombo({
    required this.id,
    required this.nama,
    required this.hargaPaket,
    this.aktif = true,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String nama;
  final int hargaPaket;
  final bool aktif;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  PaketKombo copyWith({
    String? id,
    String? nama,
    int? hargaPaket,
    bool? aktif,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return PaketKombo(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      hargaPaket: hargaPaket ?? this.hargaPaket,
      aktif: aktif ?? this.aktif,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nama': nama,
        'harga_paket': hargaPaket,
        'aktif': aktif ? 1 : 0,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory PaketKombo.dariMap(Map<String, Object?> map) {
    return PaketKombo(
      id: map['id'] as String,
      nama: map['nama'] as String,
      hargaPaket: (map['harga_paket'] as int?) ?? 0,
      aktif: (map['aktif'] as int? ?? 1) == 1,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

/// Satu baris isi paket kombo: [jumlah] porsi [Menu] dalam satu paket.
class PaketKomboRincian {
  const PaketKomboRincian({
    required this.id,
    required this.idPaket,
    required this.idMenu,
    this.jumlah = 1,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String idPaket;
  final String idMenu;
  final int jumlah;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  PaketKomboRincian copyWith({
    String? id,
    String? idPaket,
    String? idMenu,
    int? jumlah,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return PaketKomboRincian(
      id: id ?? this.id,
      idPaket: idPaket ?? this.idPaket,
      idMenu: idMenu ?? this.idMenu,
      jumlah: jumlah ?? this.jumlah,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'id_paket': idPaket,
        'id_menu': idMenu,
        'jumlah': jumlah,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory PaketKomboRincian.dariMap(Map<String, Object?> map) {
    return PaketKomboRincian(
      id: map['id'] as String,
      idPaket: map['id_paket'] as String,
      idMenu: map['id_menu'] as String,
      jumlah: (map['jumlah'] as int?) ?? 1,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

/// Resep: kaitan menu ↔ bahan + takaran.
///
/// Satu menu bisa memakai beberapa bahan; satu bahan bisa dipakai
/// beberapa menu. [takaran] dalam satuan bahan yang bersangkutan.
class Resep {
  const Resep({
    required this.id,
    required this.idMenu,
    required this.idBahan,
    this.takaran = 1,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
  });

  final String id;
  final String idMenu;
  final String idBahan;
  final double takaran;
  final String statusSinkron;
  final DateTime diperbaruiPada;

  Resep copyWith({
    String? id,
    String? idMenu,
    String? idBahan,
    double? takaran,
    String? statusSinkron,
    DateTime? diperbaruiPada,
  }) {
    return Resep(
      id: id ?? this.id,
      idMenu: idMenu ?? this.idMenu,
      idBahan: idBahan ?? this.idBahan,
      takaran: takaran ?? this.takaran,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
    );
  }

  Map<String, dynamic> keBaris() {
    return {
      'id': id,
      'id_menu': idMenu,
      'id_bahan': idBahan,
      'takaran': takaran,
      'status_sinkron': statusSinkron,
      'diperbarui_pada': diperbaruiPada.toIso8601String(),
    };
  }

  factory Resep.dariBaris(Map<String, dynamic> baris) {
    return Resep(
      id: baris['id'] as String,
      idMenu: baris['id_menu'] as String,
      idBahan: baris['id_bahan'] as String,
      takaran: (baris['takaran'] as num).toDouble(),
      statusSinkron: baris['status_sinkron'] as String? ?? 'tertunda',
      diperbaruiPada: DateTime.parse(baris['diperbarui_pada'] as String),
    );
  }
}

/// Resep beserta nama & satuan bahan — hasil JOIN untuk tampilan.
class ResepLengkap {
  const ResepLengkap({
    required this.resep,
    required this.namaBahan,
    required this.satuan,
  });

  final Resep resep;
  final String namaBahan;
  final String satuan;
}


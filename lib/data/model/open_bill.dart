/// Tagihan terbuka (open bill): nota yang ditahan dan dibayar nanti.
///
/// [status] 'buka' berarti tagihan masih aktif, 'tutup' berarti sudah
/// dilunasi / dibatalkan.
class OpenBill {
  const OpenBill({
    required this.id,
    required this.label,
    this.status = 'buka',
    required this.idAkun,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String label;
  final String status; // 'buka' | 'tutup'
  final String idAkun;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  OpenBill copyWith({
    String? id,
    String? label,
    String? status,
    String? idAkun,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return OpenBill(
      id: id ?? this.id,
      label: label ?? this.label,
      status: status ?? this.status,
      idAkun: idAkun ?? this.idAkun,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'label': label,
        'status': status,
        'id_akun': idAkun,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory OpenBill.dariMap(Map<String, Object?> map) {
    return OpenBill(
      id: map['id'] as String,
      label: map['label'] as String,
      status: (map['status'] as String?) ?? 'buka',
      idAkun: map['id_akun'] as String,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

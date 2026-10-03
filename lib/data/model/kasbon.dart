/// Catatan utang pelanggan (kasbon).
///
/// [sudahBayar] mengakumulasi cicilan; kasbon dianggap lunas saat
/// [sudahBayar] ≥ [nominal] (status ikut diubah ke 'lunas').
class Kasbon {
  const Kasbon({
    required this.id,
    required this.namaPelanggan,
    required this.nominal,
    this.sudahBayar = 0,
    this.jatuhTempo,
    this.status = 'belum_lunas',
    required this.idAkun,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String namaPelanggan;
  final int nominal;
  final int sudahBayar;
  final DateTime? jatuhTempo;
  final String status; // 'belum_lunas' | 'lunas'
  final String idAkun;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  Kasbon copyWith({
    String? id,
    String? namaPelanggan,
    int? nominal,
    int? sudahBayar,
    DateTime? jatuhTempo,
    String? status,
    String? idAkun,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return Kasbon(
      id: id ?? this.id,
      namaPelanggan: namaPelanggan ?? this.namaPelanggan,
      nominal: nominal ?? this.nominal,
      sudahBayar: sudahBayar ?? this.sudahBayar,
      jatuhTempo: jatuhTempo ?? this.jatuhTempo,
      status: status ?? this.status,
      idAkun: idAkun ?? this.idAkun,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nama_pelanggan': namaPelanggan,
        'nominal': nominal,
        'sudah_bayar': sudahBayar,
        'jatuh_tempo': jatuhTempo?.toUtc().toIso8601String(),
        'status': status,
        'id_akun': idAkun,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory Kasbon.dariMap(Map<String, Object?> map) {
    final jatuhTempo = map['jatuh_tempo'] as String?;
    return Kasbon(
      id: map['id'] as String,
      namaPelanggan: map['nama_pelanggan'] as String,
      nominal: (map['nominal'] as int?) ?? 0,
      sudahBayar: (map['sudah_bayar'] as int?) ?? 0,
      jatuhTempo: jatuhTempo == null ? null : DateTime.parse(jatuhTempo),
      status: (map['status'] as String?) ?? 'belum_lunas',
      idAkun: map['id_akun'] as String,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

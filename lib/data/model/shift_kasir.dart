/// Satu sesi shift kasir.
///
/// Kasir membuka shift dengan [saldoAwal], lalu menutupnya dengan
/// [kasAkhirFisik]; [selisih] = fisik − sistem.
class ShiftKasir {
  const ShiftKasir({
    required this.id,
    required this.idAkun,
    required this.dibukaPada,
    this.ditutupPada,
    this.saldoAwal = 0,
    this.kasAkhirSistem = 0,
    this.kasAkhirFisik,
    this.selisih,
    this.status = 'buka',
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String idAkun;
  final DateTime dibukaPada;
  final DateTime? ditutupPada;
  final int saldoAwal;
  final int kasAkhirSistem;
  final int? kasAkhirFisik;
  final int? selisih;
  final String status; // 'buka' | 'tutup'
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  ShiftKasir copyWith({
    String? id,
    String? idAkun,
    DateTime? dibukaPada,
    DateTime? ditutupPada,
    int? saldoAwal,
    int? kasAkhirSistem,
    int? kasAkhirFisik,
    int? selisih,
    String? status,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return ShiftKasir(
      id: id ?? this.id,
      idAkun: idAkun ?? this.idAkun,
      dibukaPada: dibukaPada ?? this.dibukaPada,
      ditutupPada: ditutupPada ?? this.ditutupPada,
      saldoAwal: saldoAwal ?? this.saldoAwal,
      kasAkhirSistem: kasAkhirSistem ?? this.kasAkhirSistem,
      kasAkhirFisik: kasAkhirFisik ?? this.kasAkhirFisik,
      selisih: selisih ?? this.selisih,
      status: status ?? this.status,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'id_akun': idAkun,
        'dibuka_pada': dibukaPada.toUtc().toIso8601String(),
        'ditutup_pada': ditutupPada?.toUtc().toIso8601String(),
        'saldo_awal': saldoAwal,
        'kas_akhir_sistem': kasAkhirSistem,
        'kas_akhir_fisik': kasAkhirFisik,
        'selisih': selisih,
        'status': status,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory ShiftKasir.dariMap(Map<String, Object?> map) {
    final ditutup = map['ditutup_pada'] as String?;
    return ShiftKasir(
      id: map['id'] as String,
      idAkun: map['id_akun'] as String,
      dibukaPada: DateTime.parse(map['dibuka_pada'] as String),
      ditutupPada: ditutup == null ? null : DateTime.parse(ditutup),
      saldoAwal: (map['saldo_awal'] as int?) ?? 0,
      kasAkhirSistem: (map['kas_akhir_sistem'] as int?) ?? 0,
      kasAkhirFisik: map['kas_akhir_fisik'] as int?,
      selisih: map['selisih'] as int?,
      status: (map['status'] as String?) ?? 'buka',
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

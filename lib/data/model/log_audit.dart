/// Jejak audit aktivitas penting di aplikasi.
///
/// Append-only: baris log hanya boleh ditambah ([catatAudit]), tidak
/// boleh diubah atau dihapus. Tidak punya kolom sinkron — log cukup
/// tersimpan lokal.
class LogAudit {
  const LogAudit({
    required this.id,
    required this.aksi,
    this.idAkun,
    this.idReferensi,
    this.detail,
    this.alasan,
    required this.dibuatPada,
  });

  final String id;
  final String aksi;
  final String? idAkun;
  final String? idReferensi;
  final String? detail; // JSON string
  final String? alasan;
  final DateTime dibuatPada;

  LogAudit copyWith({
    String? id,
    String? aksi,
    String? idAkun,
    String? idReferensi,
    String? detail,
    String? alasan,
    DateTime? dibuatPada,
  }) {
    return LogAudit(
      id: id ?? this.id,
      aksi: aksi ?? this.aksi,
      idAkun: idAkun ?? this.idAkun,
      idReferensi: idReferensi ?? this.idReferensi,
      detail: detail ?? this.detail,
      alasan: alasan ?? this.alasan,
      dibuatPada: dibuatPada ?? this.dibuatPada,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'aksi': aksi,
        'id_akun': idAkun,
        'id_referensi': idReferensi,
        'detail': detail,
        'alasan': alasan,
        'dibuat_pada': dibuatPada.toUtc().toIso8601String(),
      };

  factory LogAudit.dariMap(Map<String, Object?> map) {
    return LogAudit(
      id: map['id'] as String,
      aksi: map['aksi'] as String,
      idAkun: map['id_akun'] as String?,
      idReferensi: map['id_referensi'] as String?,
      detail: map['detail'] as String?,
      alasan: map['alasan'] as String?,
      dibuatPada: DateTime.parse(map['dibuat_pada'] as String),
    );
  }
}

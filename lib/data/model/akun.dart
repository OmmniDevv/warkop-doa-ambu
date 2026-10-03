/// Akun pengguna aplikasi — owner atau kasir.
///
/// Login kasir memakai PIN lokal, sehingga [pinHash] boleh null untuk
/// akun yang belum mengatur PIN. Kolom sinkron mengikuti tabel
/// `public.akun` di Supabase.
class Akun {
  const Akun({
    required this.id,
    required this.nama,
    this.pinHash,
    required this.peran,
    this.aktif = true,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String nama;
  final String? pinHash;
  final String peran; // 'owner' | 'kasir'
  final bool aktif;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  Akun copyWith({
    String? id,
    String? nama,
    String? pinHash,
    String? peran,
    bool? aktif,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return Akun(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      pinHash: pinHash ?? this.pinHash,
      peran: peran ?? this.peran,
      aktif: aktif ?? this.aktif,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nama': nama,
        'pin_hash': pinHash,
        'peran': peran,
        'aktif': aktif ? 1 : 0,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory Akun.dariMap(Map<String, Object?> map) {
    return Akun(
      id: map['id'] as String,
      nama: map['nama'] as String,
      pinHash: map['pin_hash'] as String?,
      peran: map['peran'] as String,
      aktif: (map['aktif'] as int? ?? 1) == 1,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

/// Entitas profil pemilik (owner) — full Bahasa Indonesia.
///
/// Disimpan di SQLite lokal (`pemilik`) dan dicerminkan ke Supabase
/// (`public.pemilik`). `id` mengikuti `auth.users.id` dari Supabase.
class Pemilik {
  const Pemilik({
    required this.id,
    required this.namaPemilik,
    this.namaWarkop = 'WARKOP DOA AMBU',
    required this.email,
    this.nomorKontak,
    required this.hashPinMaster,
    this.apakahBiometrikAktif = false,
    required this.dibuatPada,
    this.statusSinkron = 'tersinkron',
  });

  final String id;
  final String namaPemilik;
  final String namaWarkop;
  final String email;
  final String? nomorKontak;
  final String hashPinMaster;
  final bool apakahBiometrikAktif;
  final DateTime dibuatPada;
  final String statusSinkron;

  Pemilik copyWith({
    String? hashPinMaster,
    bool? apakahBiometrikAktif,
    String? statusSinkron,
  }) {
    return Pemilik(
      id: id,
      namaPemilik: namaPemilik,
      namaWarkop: namaWarkop,
      email: email,
      nomorKontak: nomorKontak,
      hashPinMaster: hashPinMaster ?? this.hashPinMaster,
      apakahBiometrikAktif:
          apakahBiometrikAktif ?? this.apakahBiometrikAktif,
      dibuatPada: dibuatPada,
      statusSinkron: statusSinkron ?? this.statusSinkron,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nama_pemilik': namaPemilik,
        'nama_warkop': namaWarkop,
        'email': email,
        'nomor_kontak': nomorKontak,
        'hash_pin_master': hashPinMaster,
        'apakah_biometrik_aktif': apakahBiometrikAktif ? 1 : 0,
        'dibuat_pada': dibuatPada.toUtc().toIso8601String(),
        'status_sinkron': statusSinkron,
      };

  factory Pemilik.dariMap(Map<String, Object?> map) {
    return Pemilik(
      id: map['id'] as String,
      namaPemilik: map['nama_pemilik'] as String,
      namaWarkop: (map['nama_warkop'] as String?) ?? 'WARKOP DOA AMBU',
      email: map['email'] as String,
      nomorKontak: map['nomor_kontak'] as String?,
      hashPinMaster: map['hash_pin_master'] as String,
      apakahBiometrikAktif: (map['apakah_biometrik_aktif'] as int? ?? 0) == 1,
      dibuatPada: DateTime.parse(map['dibuat_pada'] as String),
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tersinkron',
    );
  }
}

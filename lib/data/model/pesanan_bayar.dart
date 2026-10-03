/// Satu komponen pembayaran dalam bayar gabungan.
///
/// Satu pesanan bisa dibayar dengan beberapa metode (misal tunai Rp10.000
/// + non-tunai Rp15.000). Total [nominal] semua baris harus sama dengan
/// total pesanan setelah diskon.
class PesananBayar {
  const PesananBayar({
    required this.id,
    required this.idPesanan,
    required this.metode,
    required this.nominal,
    this.statusSinkron = 'tertunda',
    required this.dibuatPada,
  });

  final String id;
  final String idPesanan;
  final String metode; // 'tunai' | 'non_tunai'
  final int nominal;
  final String statusSinkron;
  final DateTime dibuatPada;

  PesananBayar copyWith({
    String? id,
    String? idPesanan,
    String? metode,
    int? nominal,
    String? statusSinkron,
    DateTime? dibuatPada,
  }) {
    return PesananBayar(
      id: id ?? this.id,
      idPesanan: idPesanan ?? this.idPesanan,
      metode: metode ?? this.metode,
      nominal: nominal ?? this.nominal,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      dibuatPada: dibuatPada ?? this.dibuatPada,
    );
  }

  Map<String, dynamic> keBaris() {
    return {
      'id': id,
      'id_pesanan': idPesanan,
      'metode': metode,
      'nominal': nominal,
      'status_sinkron': statusSinkron,
      'dibuat_pada': dibuatPada.toIso8601String(),
    };
  }

  factory PesananBayar.dariBaris(Map<String, dynamic> baris) {
    return PesananBayar(
      id: baris['id'] as String,
      idPesanan: baris['id_pesanan'] as String,
      metode: baris['metode'] as String,
      nominal: (baris['nominal'] as num).toInt(),
      statusSinkron: baris['status_sinkron'] as String? ?? 'tertunda',
      dibuatPada: DateTime.parse(baris['dibuat_pada'] as String),
    );
  }
}


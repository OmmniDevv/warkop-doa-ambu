/// Satu baris item di dalam [Pesanan].
///
/// Nama & harga disalin (snapshot) saat dipesan supaya nota tidak berubah
/// walau master menu/paket berubah kemudian.
class PesananRincian {
  const PesananRincian({
    required this.id,
    required this.idPesanan,
    this.idMenu,
    this.idPaket,
    required this.namaSnapshot,
    required this.hargaSnapshot,
    this.jumlah = 1,
    required this.subtotal,
    this.catatan,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String idPesanan;
  final String? idMenu;
  final String? idPaket;
  final String namaSnapshot;
  final int hargaSnapshot;
  final int jumlah;
  final int subtotal;
  final String? catatan;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  PesananRincian copyWith({
    String? id,
    String? idPesanan,
    String? idMenu,
    String? idPaket,
    String? namaSnapshot,
    int? hargaSnapshot,
    int? jumlah,
    int? subtotal,
    String? catatan,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return PesananRincian(
      id: id ?? this.id,
      idPesanan: idPesanan ?? this.idPesanan,
      idMenu: idMenu ?? this.idMenu,
      idPaket: idPaket ?? this.idPaket,
      namaSnapshot: namaSnapshot ?? this.namaSnapshot,
      hargaSnapshot: hargaSnapshot ?? this.hargaSnapshot,
      jumlah: jumlah ?? this.jumlah,
      subtotal: subtotal ?? this.subtotal,
      catatan: catatan ?? this.catatan,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'id_pesanan': idPesanan,
        'id_menu': idMenu,
        'id_paket': idPaket,
        'nama_snapshot': namaSnapshot,
        'harga_snapshot': hargaSnapshot,
        'jumlah': jumlah,
        'subtotal': subtotal,
        'catatan': catatan,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory PesananRincian.dariMap(Map<String, Object?> map) {
    return PesananRincian(
      id: map['id'] as String,
      idPesanan: map['id_pesanan'] as String,
      idMenu: map['id_menu'] as String?,
      idPaket: map['id_paket'] as String?,
      namaSnapshot: map['nama_snapshot'] as String,
      hargaSnapshot: (map['harga_snapshot'] as int?) ?? 0,
      jumlah: (map['jumlah'] as int?) ?? 1,
      subtotal: (map['subtotal'] as int?) ?? 0,
      catatan: map['catatan'] as String?,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}

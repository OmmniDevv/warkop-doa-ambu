/// Satu transaksi pesanan (nota).
///
/// [nomorNota] unik per hari dengan format "WDA-YYYYMMDD-XXXX".
/// Void butuh [voidAlasan] dan persetujuan owner
/// ([voidDisetujuiOwner]).
class Pesanan {
  const Pesanan({
    required this.id,
    required this.nomorNota,
    required this.idAkun,
    this.idShift,
    this.idOpenBill,
    required this.metodeBayar,
    this.status = 'baru',
    this.total = 0,
    this.bayar = 0,
    this.kembalian = 0,
    this.fotoBuktiLokal,
    this.fotoBuktiRemote,
    this.voidAlasan,
    this.voidDisetujuiOwner = false,
    this.diskonNotaNominal = 0,
    this.diskonNotaPersen = 0,
    this.alasanDiskon,
    this.statusSinkron = 'tertunda',
    required this.diperbaruiPada,
    this.apakahDihapus = false,
  });

  final String id;
  final String nomorNota;
  final String idAkun;
  final String? idShift;
  final String? idOpenBill;
  final String metodeBayar; // 'tunai' | 'non_tunai'
  final String status; // 'baru' | 'lunas' | 'void'
  final int total;
  final int bayar;
  final int kembalian;
  final String? fotoBuktiLokal;
  final String? fotoBuktiRemote;
  final String? voidAlasan;
  final bool voidDisetujuiOwner;
  final int diskonNotaNominal;
  final double diskonNotaPersen;
  final String? alasanDiskon;
  final String statusSinkron; // 'tertunda' | 'tersinkron' | 'gagal'
  final DateTime diperbaruiPada;
  final bool apakahDihapus;

  Pesanan copyWith({
    String? id,
    String? nomorNota,
    String? idAkun,
    String? idShift,
    String? idOpenBill,
    String? metodeBayar,
    String? status,
    int? total,
    int? bayar,
    int? kembalian,
    String? fotoBuktiLokal,
    String? fotoBuktiRemote,
    String? voidAlasan,
    bool? voidDisetujuiOwner,
    int? diskonNotaNominal,
    double? diskonNotaPersen,
    String? alasanDiskon,
    String? statusSinkron,
    DateTime? diperbaruiPada,
    bool? apakahDihapus,
  }) {
    return Pesanan(
      id: id ?? this.id,
      nomorNota: nomorNota ?? this.nomorNota,
      idAkun: idAkun ?? this.idAkun,
      idShift: idShift ?? this.idShift,
      idOpenBill: idOpenBill ?? this.idOpenBill,
      metodeBayar: metodeBayar ?? this.metodeBayar,
      status: status ?? this.status,
      total: total ?? this.total,
      bayar: bayar ?? this.bayar,
      kembalian: kembalian ?? this.kembalian,
      fotoBuktiLokal: fotoBuktiLokal ?? this.fotoBuktiLokal,
      fotoBuktiRemote: fotoBuktiRemote ?? this.fotoBuktiRemote,
      voidAlasan: voidAlasan ?? this.voidAlasan,
      voidDisetujuiOwner: voidDisetujuiOwner ?? this.voidDisetujuiOwner,
      diskonNotaNominal: diskonNotaNominal ?? this.diskonNotaNominal,
      diskonNotaPersen: diskonNotaPersen ?? this.diskonNotaPersen,
      alasanDiskon: alasanDiskon ?? this.alasanDiskon,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
      apakahDihapus: apakahDihapus ?? this.apakahDihapus,
    );
  }

  Map<String, Object?> keMap() => {
        'id': id,
        'nomor_nota': nomorNota,
        'id_akun': idAkun,
        'id_shift': idShift,
        'id_open_bill': idOpenBill,
        'metode_bayar': metodeBayar,
        'status': status,
        'total': total,
        'bayar': bayar,
        'kembalian': kembalian,
        'foto_bukti_lokal': fotoBuktiLokal,
        'foto_bukti_remote': fotoBuktiRemote,
        'void_alasan': voidAlasan,
        'void_disetujui_owner': voidDisetujuiOwner ? 1 : 0,
        'diskon_nota_nominal': diskonNotaNominal,
        'diskon_nota_persen': diskonNotaPersen,
        'alasan_diskon': alasanDiskon,
        'status_sinkron': statusSinkron,
        'diperbarui_pada': diperbaruiPada.toUtc().toIso8601String(),
        'apakah_dihapus': apakahDihapus ? 1 : 0,
      };

  factory Pesanan.dariMap(Map<String, Object?> map) {
    return Pesanan(
      id: map['id'] as String,
      nomorNota: map['nomor_nota'] as String,
      idAkun: map['id_akun'] as String,
      idShift: map['id_shift'] as String?,
      idOpenBill: map['id_open_bill'] as String?,
      metodeBayar: map['metode_bayar'] as String,
      status: (map['status'] as String?) ?? 'baru',
      total: (map['total'] as int?) ?? 0,
      bayar: (map['bayar'] as int?) ?? 0,
      kembalian: (map['kembalian'] as int?) ?? 0,
      fotoBuktiLokal: map['foto_bukti_lokal'] as String?,
      fotoBuktiRemote: map['foto_bukti_remote'] as String?,
      voidAlasan: map['void_alasan'] as String?,
      voidDisetujuiOwner: (map['void_disetujui_owner'] as int? ?? 0) == 1,
      diskonNotaNominal: (map['diskon_nota_nominal'] as num?)?.toInt() ?? 0,
      diskonNotaPersen:
          (map['diskon_nota_persen'] as num?)?.toDouble() ?? 0,
      alasanDiskon: map['alasan_diskon'] as String?,
      statusSinkron: (map['status_sinkron'] as String?) ?? 'tertunda',
      diperbaruiPada: DateTime.parse(map['diperbarui_pada'] as String),
      apakahDihapus: (map['apakah_dihapus'] as int? ?? 0) == 1,
    );
  }
}


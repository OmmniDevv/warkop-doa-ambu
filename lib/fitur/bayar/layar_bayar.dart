import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/hitung_diskon.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/pesanan.dart';
import '../../data/model/pesanan_bayar.dart';
import '../../data/model/pesanan_rincian.dart';
import 'kamera_bukti.dart';

/// Pilihan metode pembayaran.
enum _Metode { tunai, nonTunai }

extension _MetodeX on _Metode {
  /// Nilai kolom `metode` di database.
  String get nilaiDb => switch (this) {
        _Metode.tunai => 'tunai',
        _Metode.nonTunai => 'non_tunai',
      };
}

/// Satu baris komponen pembayaran pada mode bayar gabungan.
class _BarisBayar {
  _BarisBayar({required this.metode, this.nominal = 0});

  _Metode metode;
  int nominal;
}

/// Hasil dialog diskon nota.
class _HasilDiskonNota {
  const _HasilDiskonNota({
    required this.nominal,
    required this.persen,
    required this.alasan,
  });

  final int nominal;
  final double persen;
  final String alasan;
}

/// Hasil muat awal: pesanan + rincian itemnya.
class _DataBayar {
  const _DataBayar(this.pesanan, this.rincian);

  final Pesanan? pesanan;
  final List<PesananRincian> rincian;
}

/// Layar pembayaran satu nota.
///
/// Dua mode: tunggal (tunai dengan keypad + kembalian, atau non-tunai
/// dengan foto bukti) dan gabungan (beberapa baris tunai/non-tunai yang
/// totalnya harus pas dengan total tagihan setelah diskon).
///
/// Kasir juga bisa memberi diskon nota (nominal/persen + alasan wajib)
/// sebelum membayar.
///
/// Tata letak: 55% atas = ringkasan nota, 45% bawah = zona aksi jempol.
class LayarBayar extends ConsumerStatefulWidget {
  const LayarBayar({super.key, required this.idPesanan});

  final String idPesanan;

  @override
  ConsumerState<LayarBayar> createState() => _LayarBayarState();
}

class _LayarBayarState extends ConsumerState<LayarBayar> {
  /// Nominal cepat: label + nilai; `null` berarti samakan dengan total.
  static const _nominalCepat = <({String label, int? nilai})>[
    (label: 'Uang Pas', nilai: null),
    (label: '10rb', nilai: 10000),
    (label: '20rb', nilai: 20000),
    (label: '50rb', nilai: 50000),
    (label: '100rb', nilai: 100000),
  ];

  late Future<_DataBayar> _muat;

  // Mode tunggal.
  _Metode _metode = _Metode.tunai;
  String _digitTunai = '';
  String? _pathFoto;

  // Mode gabungan.
  bool _gabungan = false;
  final List<_BarisBayar> _barisBayar = [_BarisBayar(metode: _Metode.tunai)];

  bool _memproses = false;

  @override
  void initState() {
    super.initState();
    _muat = _muatUlang();
  }

  Future<_DataBayar> _muatUlang() async {
    final db = ref.read(penyediaDatabaseLokal);
    final pesanan = await db.ambilPesanan(widget.idPesanan);
    final rincian = await db.daftarRincianPesanan(widget.idPesanan);
    return _DataBayar(pesanan, rincian);
  }

  int get _bayarTunai => int.tryParse(_digitTunai) ?? 0;

  /// Total terkumpul dari seluruh baris bayar gabungan.
  int get _terkumpulGabungan =>
      _barisBayar.fold(0, (total, baris) => total + baris.nominal);

  bool get _gabunganAdaNonTunai =>
      _barisBayar.any((baris) => baris.metode == _Metode.nonTunai);

  void _pilihMetode(_Metode metode) {
    if (_metode == metode) return;
    HapticFeedback.selectionClick();
    setState(() => _metode = metode);
  }

  void _isiNominal(int nilai) {
    HapticFeedback.lightImpact();
    setState(() => _digitTunai = nilai.toString());
  }

  Future<void> _ambilFoto() async {
    final path = await ambilFotoBukti(context);
    if (!mounted || path == null) return;
    HapticFeedback.lightImpact();
    setState(() => _pathFoto = path);
  }

  /// Buka dialog diskon nota; bila disimpan, terapkan ke pesanan +
  /// catat audit, lalu muat ulang nota.
  Future<void> _aturDiskonNota(Pesanan pesanan) async {
    final hasil = await showDialog<_HasilDiskonNota>(
      context: context,
      builder: (context) => _DialogDiskonNota(pesanan: pesanan),
    );
    if (hasil == null || !mounted) return;
    final db = ref.read(penyediaDatabaseLokal);
    final potongan = hitungPotongan(
      pesanan.total,
      nominal: hasil.nominal,
      persen: hasil.persen,
    );
    await db.perbaruiPesanan(
      pesanan.copyWith(
        diskonNotaNominal: hasil.nominal,
        diskonNotaPersen: hasil.persen,
        alasanDiskon: hasil.alasan,
        diperbaruiPada: DateTime.now(),
      ),
    );
    if (potongan > 0) {
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'diskon_diberikan',
          idAkun: pesanan.idAkun,
          idReferensi: pesanan.id,
          detail:
              '{"nominal":${hasil.nominal},"persen":${hasil.persen},"potongan":$potongan,"total_sebelum":${pesanan.total}}',
          alasan: hasil.alasan,
          dibuatPada: DateTime.now(),
        ),
      );
      HapticFeedback.lightImpact();
    }
    setState(() => _muat = _muatUlang());
  }

  /// Buka lembar keypad untuk mengisi nominal satu baris bayar gabungan.
  Future<void> _isiNominalBaris(int indeks, int totalTagihan) async {
    final baris = _barisBayar[indeks];
    final lain = _terkumpulGabungan - baris.nominal;
    final sisa = totalTagihan - lain;
    final hasil = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _LembarNominalBayar(
          awal: baris.nominal,
          sisa: sisa,
        ),
      ),
    );
    if (hasil == null || !mounted) return;
    setState(() => baris.nominal = hasil);
    HapticFeedback.lightImpact();
  }

  void _tambahBarisBayar() {
    if (_barisBayar.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _barisBayar.add(_BarisBayar(metode: _Metode.nonTunai));
    });
  }

  void _hapusBarisBayar(int indeks) {
    if (_barisBayar.length <= 1) return;
    HapticFeedback.lightImpact();
    setState(() => _barisBayar.removeAt(indeks));
  }

  /// Menyelesaikan pembayaran: tandai lunas → simpan baris pembayaran →
  /// kurangi stok menu & bahan → catat audit → dialog sukses.
  /// Unggah bukti berjalan di latar.
  Future<void> _selesaikan(Pesanan pesanan, List<PesananRincian> rincian) async {
    if (_memproses) return;
    final total = totalBersihNota(pesanan);
    final tunai = _metode == _Metode.tunai;

    late final String metodeStr;
    late final int bayar;
    late final int kembalian;
    late final List<_BarisBayar> barisFinal;

    if (_gabungan) {
      // Validasi gabungan: total baris harus PAS dengan total tagihan.
      if (_terkumpulGabungan != total) return;
      if (_barisBayar.any((baris) => baris.nominal <= 0)) return;
      if (_gabunganAdaNonTunai && _pathFoto == null) return;
      final metodeUnik =
          _barisBayar.map((baris) => baris.metode.nilaiDb).toSet();
      metodeStr = metodeUnik.length > 1
          ? 'gabungan'
          : metodeUnik.single;
      bayar = total;
      kembalian = 0;
      barisFinal = List.of(_barisBayar);
    } else {
      final bayarTunggal = tunai ? _bayarTunai : total;
      if (tunai && bayarTunggal < total) return;
      if (!tunai && _pathFoto == null) return;
      metodeStr = tunai ? 'tunai' : 'non_tunai';
      bayar = bayarTunggal;
      kembalian = bayarTunggal - total;
      barisFinal = [_BarisBayar(metode: _metode, nominal: bayarTunggal)];
    }

    setState(() => _memproses = true);
    final db = ref.read(penyediaDatabaseLokal);
    try {
      final sekarang = DateTime.now();
      final lunas = pesanan.copyWith(
        status: 'lunas',
        metodeBayar: metodeStr,
        bayar: bayar,
        kembalian: kembalian,
        fotoBuktiLokal: _pathFoto,
        diperbaruiPada: sekarang,
      );
      await db.perbaruiPesanan(lunas);

      // Simpan tiap baris ke tabel pesanan_bayar (ikut antrean sinkron).
      for (final baris in barisFinal) {
        await db.simpanPembayaran(
          PesananBayar(
            id: idBaru(),
            idPesanan: pesanan.id,
            metode: baris.metode.nilaiDb,
            nominal: baris.nominal,
            dibuatPada: sekarang,
          ),
        );
      }

      // Kurangi stok tiap item menu + bahan resepnya. Kegagalan stok
      // TIDAK boleh menggagalkan pembayaran — abaikan diam-diam.
      final bahanMenipis = <String>[];
      for (final baris in rincian) {
        final idMenu = baris.idMenu;
        if (idMenu == null) continue;
        try {
          await db.kurangiStok(idMenu, baris.jumlah);
        } catch (_) {
          // Abaikan: stok bisa dikoreksi manual kemudian.
        }
        try {
          final menipis =
              await db.kurangiStokBahanResep(idMenu, baris.jumlah);
          for (final bahan in menipis) {
            if (!bahanMenipis.contains(bahan.nama)) {
              bahanMenipis.add(bahan.nama);
            }
          }
        } catch (_) {
          // Abaikan: stok bahan bisa dikoreksi manual kemudian.
        }
      }

      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'bayar_pesanan',
          idAkun: pesanan.idAkun,
          idReferensi: pesanan.id,
          detail:
              '{"metode":"$metodeStr","total":$total,"bayar":$bayar,"kembalian":$kembalian}',
          dibuatPada: sekarang,
        ),
      );

      HapticFeedback.mediumImpact();

      // Unggah bukti di latar — jangan blokir UI.
      final pathFoto = _pathFoto;
      if (pathFoto != null) {
        unawaited(_unggahBukti(db, pesanan.id, pathFoto));
      }

      if (!mounted) return;
      final idOpenBill = pesanan.idOpenBill;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogSukses(
          tunai: tunai && !_gabungan,
          kembalian: kembalian,
          bahanMenipis: bahanMenipis,
        ),
      );
      if (!mounted) return;
      if (idOpenBill != null) {
        context.go('/tagihan/$idOpenBill');
      } else {
        context.go('/pos');
      }
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  /// Mengunggah foto bukti ke Storage Supabase di latar.
  ///
  /// Selalu dibungkus try/catch: bila client belum init / offline / gagal
  /// jaringan, lewati diam-diam. [perbaruiPesanan] sudah menandai
  /// `status_sinkron` = 'tertunda', jadi jangan disentuh manual.
  Future<void> _unggahBukti(
    DatabaseLokal db,
    String idPesanan,
    String pathLokal,
  ) async {
    try {
      final klien = Supabase.instance.client;
      final cap = DateTime.now().millisecondsSinceEpoch;
      final namaBerkas = 'bukti/${idPesanan}_$cap.jpg';
      await klien.storage
          .from('bukti-pembayaran')
          .upload(namaBerkas, File(pathLokal));
      final terbaru = await db.ambilPesanan(idPesanan);
      if (terbaru != null) {
        await db.perbaruiPesanan(
          terbaru.copyWith(fotoBuktiRemote: namaBerkas),
        );
      }
    } catch (_) {
      // Lewati diam-diam: bukti lokal tetap tersimpan & tertandai tertunda.
    }
  }

  String _labelStatus(String status) => switch (status) {
        'lunas' => 'lunas',
        'void' => 'dibatalkan',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PEMBAYARAN')),
      body: SafeArea(
        child: FutureBuilder<_DataBayar>(
          future: _muat,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _layarPesan('Gagal memuat pesanan. Coba lagi.');
            }
            final data = snapshot.data!;
            final pesanan = data.pesanan;
            if (pesanan == null) {
              return _layarPesan('Pesanan tidak ditemukan.');
            }
            if (pesanan.status != 'baru') {
              return _layarPesan(
                'Pesanan ini sudah ${_labelStatus(pesanan.status)}.',
              );
            }
            return Column(
              children: [
                // 55% atas: ringkasan nota (bisa scroll).
                Flexible(
                  flex: 55,
                  child: _bangunZonaNota(pesanan, data.rincian),
                ),
                // 45% bawah: zona aksi jempol.
                Flexible(
                  flex: 45,
                  child: _bangunZonaAksi(pesanan, data.rincian),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Layar pesan tengah + tombol kembali (untuk galat / status final).
  Widget _layarPesan(String pesan) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KartuKaca(
              tanpaBlur: true,
              child: Text(
                pesan,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            TombolKaca(
              label: 'Kembali',
              ikon: Icons.arrow_back,
              lebarPenuh: false,
              saatDitekan: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Zona atas: nomor nota + daftar rincian + diskon nota + total besar.
  ///
  /// Header dan total di-pin; hanya daftar item yang scroll
  /// ([ListView.builder] agar tidak dirender sekaligus).
  Widget _bangunZonaNota(Pesanan pesanan, List<PesananRincian> rincian) {
    final tema = Theme.of(context);
    final gelap = tema.brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final potongan = hitungPotongan(
      pesanan.total,
      nominal: pesanan.diskonNotaNominal,
      persen: pesanan.diskonNotaPersen,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KartuKaca(
            tanpaBlur: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NOTA', style: tema.textTheme.labelLarge),
                Text(
                  pesanan.nomorNota,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: KartuKaca(
              tanpaBlur: true,
              child: rincian.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada item.',
                        style: tema.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: rincian.length,
                      itemBuilder: (context, indeks) {
                        final baris = rincian[indeks];
                        final potonganItem = hitungPotongan(
                          baris.hargaSnapshot * baris.jumlah,
                          nominal: baris.diskonNominal,
                          persen: baris.diskonPersen,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${baris.namaSnapshot} × ${baris.jumlah}',
                                      style: tema.textTheme.bodyMedium,
                                    ),
                                    if (potonganItem > 0)
                                      Text(
                                        'Diskon -${formatRupiah(potonganItem)}',
                                        style: tema.textTheme.bodySmall
                                            ?.copyWith(
                                          color: WarnaWarkop.hijauAman,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formatRupiah(baris.subtotal),
                                style: tema.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Baris diskon nota: ketuk untuk atur/ubah.
          _BarisDiskonNota(
            potongan: potongan,
            alasan: pesanan.alasanDiskon,
            saatAtur: () => _aturDiskonNota(pesanan),
          ),
          const SizedBox(height: 8),
          KartuKaca(
            tanpaBlur: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (potongan > 0)
                      Text(
                        formatRupiah(pesanan.total),
                        style: tema.textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      formatRupiah(totalBersihNota(pesanan)),
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: aksen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Zona bawah: pilih mode tunggal/gabungan + input bayar + Selesaikan.
  Widget _bangunZonaAksi(Pesanan pesanan, List<PesananRincian> rincian) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final total = totalBersihNota(pesanan);

    final bool bisaSelesai;
    if (_gabungan) {
      bisaSelesai = !_memproses &&
          _terkumpulGabungan == total &&
          _barisBayar.every((baris) => baris.nominal > 0) &&
          (!_gabunganAdaNonTunai || _pathFoto != null);
    } else {
      final tunai = _metode == _Metode.tunai;
      bisaSelesai = !_memproses &&
          (tunai ? _bayarTunai >= total : _pathFoto != null);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: skema.surface,
        border: Border(
          top: BorderSide(color: skema.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pilihan mode pembayaran.
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Tunggal'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Gabungan'),
                  icon: Icon(Icons.splitscreen_outlined),
                ),
              ],
              selected: {_gabungan},
              onSelectionChanged: (pilihan) {
                HapticFeedback.selectionClick();
                setState(() => _gabungan = pilihan.first);
              },
            ),
            const SizedBox(height: 12),
            if (_gabungan) ...[
              ..._bangunGabungan(total),
            ] else ...[
              _bangunPilihMetode(),
              const SizedBox(height: 12),
              if (_metode == _Metode.tunai) ..._bangunTunai(total) else ..._bangunNonTunai(total),
            ],
            const SizedBox(height: 12),
            TombolKaca(
              label: 'Selesaikan',
              ikon: Icons.check,
              memuat: _memproses,
              aktif: bisaSelesai,
              saatDitekan: () => _selesaikan(pesanan, rincian),
            ),
          ],
        ),
      ),
    );
  }

  /// Daftar baris pembayaran gabungan + progres terkumpul.
  List<Widget> _bangunGabungan(int total) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final terkumpul = _terkumpulGabungan;
    final sisa = total - terkumpul;

    return [
      for (var i = 0; i < _barisBayar.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _UbinBarisBayar(
            baris: _barisBayar[i],
            bisaHapus: _barisBayar.length > 1,
            saatUbahMetode: (metode) =>
                setState(() => _barisBayar[i].metode = metode),
            saatUbahNominal: () => _isiNominalBaris(i, total),
            saatHapus: () => _hapusBarisBayar(i),
          ),
        ),
      OutlinedButton.icon(
        onPressed:
            _barisBayar.length >= 4 ? null : _tambahBarisBayar,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Baris Pembayaran'),
      ),
      const SizedBox(height: 8),
      KartuKaca(
        tanpaBlur: true,
        tingkat: TingkatKaca.ringan,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Terkumpul', style: tema.textTheme.bodyMedium),
                Text(
                  formatRupiah(terkumpul),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sisa == 0
                  ? 'Pas dengan total tagihan'
                  : sisa > 0
                      ? 'Kurang ${formatRupiah(sisa)}'
                      : 'Kelebihan ${formatRupiah(-sisa)}',
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: sisa == 0
                    ? WarnaWarkop.hijauAman
                    : WarnaWarkop.merahMenyala,
              ),
            ),
          ],
        ),
      ),
      if (_gabunganAdaNonTunai) ...[
        const SizedBox(height: 8),
        _bagianFotoBukti(),
      ],
      if (sisa != 0 || terkumpul == 0) ...[
        const SizedBox(height: 4),
        Text(
          'Total semua baris harus pas ${formatRupiah(total)}.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: skema.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ];
  }

  /// Bagian foto bukti untuk pembayaran non-tunai.
  Widget _bagianFotoBukti() {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final pathFoto = _pathFoto;

    if (pathFoto == null) {
      return TombolKaca(
        label: 'Ambil Foto Bukti',
        ikon: Icons.camera_alt_outlined,
        saatDitekan: _ambilFoto,
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(pathFoto),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Bukti tersimpan. Akan diunggah otomatis saat online.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: _ambilFoto,
          child: const Text('Ambil Ulang'),
        ),
      ],
    );
  }

  /// Dua kartu pilih metode: Tunai / Non-Tunai (mode tunggal).
  Widget _bangunPilihMetode() {
    return Row(
      children: [
        Expanded(
          child: _KartuMetode(
            dipilih: _metode == _Metode.tunai,
            ikon: Icons.payments_outlined,
            judul: 'Tunai',
            subjudul: 'Uang cash',
            saatDipilih: () => _pilihMetode(_Metode.tunai),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KartuMetode(
            dipilih: _metode == _Metode.nonTunai,
            ikon: Icons.qr_code_2_outlined,
            judul: 'Non-Tunai',
            subjudul: 'QRIS / Transfer',
            saatDipilih: () => _pilihMetode(_Metode.nonTunai),
          ),
        ),
      ],
    );
  }

  /// Isi zona aksi untuk pembayaran tunai (mode tunggal).
  List<Widget> _bangunTunai(int total) {
    final tema = Theme.of(context);
    final kurang = total - _bayarTunai;

    return [
      Text(
        'Nominal Tunai',
        style: tema.textTheme.labelLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        formatRupiah(_bayarTunai),
        style: tema.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final cepat in _nominalCepat)
            _ChipCepat(
              label: cepat.label,
              saatDitekan: () => _isiNominal(cepat.nilai ?? total),
            ),
        ],
      ),
      const SizedBox(height: 4),
      KeypadAngka(
        saatAngka: (digit) {
          if (_digitTunai.length >= 9) return;
          setState(() => _digitTunai += digit);
        },
        saatHapus: () {
          if (_digitTunai.isEmpty) return;
          setState(
            () => _digitTunai = _digitTunai.substring(0, _digitTunai.length - 1),
          );
        },
      ),
      const SizedBox(height: 8),
      Text(
        kurang > 0
            ? 'Kurang ${formatRupiah(kurang)}'
            : 'Kembalian ${formatRupiah(-kurang)}',
        style: tema.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: kurang > 0 ? WarnaWarkop.merahMenyala : WarnaWarkop.hijauAman,
        ),
        textAlign: TextAlign.center,
      ),
    ];
  }

  /// Isi zona aksi untuk pembayaran non-tunai (mode tunggal).
  List<Widget> _bangunNonTunai(int total) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;

    return [
      _bagianFotoBukti(),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Nominal', style: tema.textTheme.bodyMedium),
          Text(
            formatRupiah(total),
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Nominal non-tunai mengikuti total tagihan.',
        style: tema.textTheme.bodySmall?.copyWith(
          color: skema.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ];
  }
}

/// Baris "Diskon Nota" di zona nota: menampilkan potongan + alasan,
/// atau tombol untuk memberi diskon. Ketuk untuk atur/ubah.
class _BarisDiskonNota extends StatelessWidget {
  const _BarisDiskonNota({
    required this.potongan,
    required this.alasan,
    required this.saatAtur,
  });

  final int potongan;
  final String? alasan;
  final VoidCallback saatAtur;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ada = potongan > 0;

    return KartuKaca(
      tanpaBlur: true,
      tingkat: TingkatKaca.ringan,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: InkWell(
        onTap: saatAtur,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            const Icon(Icons.percent_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diskon Nota',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (ada && alasan != null && alasan!.isNotEmpty)
                    Text(
                      alasan!,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (ada)
              Text(
                '-${formatRupiah(potongan)}',
                style: tema.textTheme.titleSmall?.copyWith(
                  color: WarnaWarkop.hijauAman,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                'Atur',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Dialog atur diskon nota: nominal/persen + ALASAN WAJIB diisi.
class _DialogDiskonNota extends StatefulWidget {
  const _DialogDiskonNota({required this.pesanan});

  final Pesanan pesanan;

  @override
  State<_DialogDiskonNota> createState() => _DialogDiskonNotaState();
}

class _DialogDiskonNotaState extends State<_DialogDiskonNota> {
  bool _modeNominal = true;
  late final TextEditingController _nilaiController;
  late final TextEditingController _alasanController;

  @override
  void initState() {
    super.initState();
    final pesanan = widget.pesanan;
    _modeNominal =
        pesanan.diskonNotaNominal > 0 || pesanan.diskonNotaPersen <= 0;
    _nilaiController = TextEditingController(
      text: _modeNominal
          ? (pesanan.diskonNotaNominal > 0
              ? '${pesanan.diskonNotaNominal}'
              : '')
          : (pesanan.diskonNotaPersen > 0
              ? _formatPersen(pesanan.diskonNotaPersen)
              : ''),
    );
    _alasanController =
        TextEditingController(text: pesanan.alasanDiskon ?? '');
  }

  static String _formatPersen(double persen) {
    return persen.truncateToDouble() == persen
        ? '${persen.toInt()}'
        : '$persen';
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    _alasanController.dispose();
    super.dispose();
  }

  int get _nominal =>
      _modeNominal ? int.tryParse(_nilaiController.text) ?? 0 : 0;
  double get _persen =>
      _modeNominal ? 0 : double.tryParse(_nilaiController.text) ?? 0;

  int get _potongan => hitungPotongan(
        widget.pesanan.total,
        nominal: _nominal,
        persen: _persen,
      );

  bool get _bisaSimpan =>
      _potongan > 0 && _alasanController.text.trim().isNotEmpty;

  void _simpan() {
    if (!_bisaSimpan) return;
    Navigator.of(context).pop(
      _HasilDiskonNota(
        nominal: _nominal,
        persen: _persen,
        alasan: _alasanController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      title: const Text('Diskon Nota'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Nominal'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Persen'),
                  icon: Icon(Icons.percent_outlined),
                ),
              ],
              selected: {_modeNominal},
              onSelectionChanged: (pilihan) {
                setState(() {
                  _modeNominal = pilihan.first;
                  _nilaiController.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nilaiController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: _modeNominal ? 'Nominal diskon' : 'Persen diskon',
                prefixText: _modeNominal ? 'Rp ' : null,
                suffixText: _modeNominal ? null : '%',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _alasanController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan (wajib)',
                hintText: 'mis. buat teman',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Potongan: ${formatRupiah(_potongan)}',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: WarnaWarkop.hijauAman,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _HasilDiskonNota(nominal: 0, persen: 0, alasan: ''),
          ),
          child: const Text('Hapus'),
        ),
        FilledButton(
          onPressed: _bisaSimpan ? _simpan : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Satu baris pembayaran gabungan: pilih metode + ketuk nominal.
class _UbinBarisBayar extends StatelessWidget {
  const _UbinBarisBayar({
    required this.baris,
    required this.bisaHapus,
    required this.saatUbahMetode,
    required this.saatUbahNominal,
    required this.saatHapus,
  });

  final _BarisBayar baris;
  final bool bisaHapus;
  final ValueChanged<_Metode> saatUbahMetode;
  final VoidCallback saatUbahNominal;
  final VoidCallback saatHapus;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return KartuKaca(
      tanpaBlur: true,
      tingkat: TingkatKaca.ringan,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          SegmentedButton<_Metode>(
            segments: const [
              ButtonSegment(
                value: _Metode.tunai,
                label: Text('Tunai'),
              ),
              ButtonSegment(
                value: _Metode.nonTunai,
                label: Text('Non-Tunai'),
              ),
            ],
            selected: {baris.metode},
            onSelectionChanged: (pilihan) =>
                saatUbahMetode(pilihan.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: saatUbahNominal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: tema.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatRupiah(baris.nominal),
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          if (bisaHapus)
            IconButton(
              tooltip: 'Hapus baris',
              icon: const Icon(Icons.delete_outline),
              onPressed: saatHapus,
            ),
        ],
      ),
    );
  }
}

/// Lembar keypad untuk mengisi nominal satu baris bayar gabungan.
class _LembarNominalBayar extends StatefulWidget {
  const _LembarNominalBayar({required this.awal, required this.sisa});

  /// Nominal awal baris ini.
  final int awal;

  /// Sisa yang dibutuhkan agar total pas (untuk tombol "Uang Pas").
  final int sisa;

  @override
  State<_LembarNominalBayar> createState() => _LembarNominalBayarState();
}

class _LembarNominalBayarState extends State<_LembarNominalBayar> {
  late String _digit;

  @override
  void initState() {
    super.initState();
    _digit = widget.awal > 0 ? '${widget.awal}' : '';
  }

  int get _nilai => int.tryParse(_digit) ?? 0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return KartuKaca(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: tema.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Nominal Pembayaran',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(_nilai),
            style: tema.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: widget.sisa > 0
                  ? () => setState(() => _digit = '${widget.sisa}')
                  : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text('Uang Pas (${formatRupiah(widget.sisa)})'),
            ),
          ),
          KeypadAngka(
            saatAngka: (digit) {
              if (_digit.length >= 9) return;
              setState(() => _digit += digit);
            },
            saatHapus: () {
              if (_digit.isEmpty) return;
              setState(
                () => _digit = _digit.substring(0, _digit.length - 1),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TombolKaca(
                  label: 'OK',
                  ikon: Icons.check,
                  saatDitekan: () =>
                      Navigator.of(context).pop(_nilai),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu pilih satu metode pembayaran (terpilih = border aksen + centang).
class _KartuMetode extends StatelessWidget {
  const _KartuMetode({
    required this.dipilih,
    required this.ikon,
    required this.judul,
    required this.subjudul,
    required this.saatDipilih,
  });

  final bool dipilih;
  final IconData ikon;
  final String judul;
  final String subjudul;
  final VoidCallback saatDipilih;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final gelap = tema.brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return GestureDetector(
      onTap: saatDipilih,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: dipilih
              ? aksen.withValues(alpha: 0.10)
              : skema.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dipilih ? aksen : skema.outlineVariant,
            width: dipilih ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ikon,
              color: dipilih ? aksen : skema.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dipilih ? aksen : null,
                    ),
                  ),
                  Text(
                    subjudul,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (dipilih) Icon(Icons.check_circle, color: aksen, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Chip nominal cepat (Uang Pas / 10rb / dst) — atur nominal langsung.
class _ChipCepat extends StatelessWidget {
  const _ChipCepat({required this.label, required this.saatDitekan});

  final String label;
  final VoidCallback saatDitekan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gelap = tema.brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return GestureDetector(
      onTap: saatDitekan,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: aksen.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: tema.textTheme.labelLarge?.copyWith(color: aksen),
        ),
      ),
    );
  }
}

/// Dialog sukses pembayaran: centang membesar + peringatan stok menipis.
class _DialogSukses extends StatelessWidget {
  const _DialogSukses({
    required this.tunai,
    required this.kembalian,
    this.bahanMenipis = const [],
  });

  final bool tunai;
  final int kembalian;

  /// Nama bahan yang stoknya kini menipis — tampilkan sebagai peringatan.
  final List<String> bahanMenipis;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centang muncul dengan skala memantul — hanya transform.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, nilai, _) => Transform.scale(
              scale: nilai,
              child: const Icon(
                Icons.check_circle,
                size: 72,
                color: WarnaWarkop.hijauAman,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pembayaran Berhasil',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (tunai && kembalian > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Kembalian ${formatRupiah(kembalian)}',
              style: tema.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
          if (bahanMenipis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WarnaWarkop.emas.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WarnaWarkop.emas.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: WarnaWarkop.emas,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stok menipis: ${bahanMenipis.join(', ')}',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: WarnaWarkop.emas,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TombolKaca(
            label: 'Selesai',
            saatDitekan: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

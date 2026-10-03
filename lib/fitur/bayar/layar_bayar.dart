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
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/pesanan.dart';
import '../../data/model/pesanan_rincian.dart';
import 'kamera_bukti.dart';

/// Pilihan metode pembayaran di layar bayar.
enum _Metode { tunai, nonTunai }

/// Hasil muat awal: pesanan + rincian itemnya.
class _DataBayar {
  const _DataBayar(this.pesanan, this.rincian);

  final Pesanan? pesanan;
  final List<PesananRincian> rincian;
}

/// Layar pembayaran satu nota: tunai (keypad + uang cepat) atau non-tunai
/// (QRIS/transfer + foto bukti).
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

  late final Future<_DataBayar> _muat;
  _Metode _metode = _Metode.tunai;
  String _digitTunai = '';
  String? _pathFoto;
  bool _memproses = false;

  @override
  void initState() {
    super.initState();
    _muat = () async {
      final db = ref.read(penyediaDatabaseLokal);
      final pesanan = await db.ambilPesanan(widget.idPesanan);
      final rincian = await db.daftarRincianPesanan(widget.idPesanan);
      return _DataBayar(pesanan, rincian);
    }();
  }

  int get _bayarTunai => int.tryParse(_digitTunai) ?? 0;

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

  /// Menyelesaikan pembayaran: tandai lunas → kurangi stok → catat audit →
  /// dialog sukses → navigasi pulang. Unggah bukti berjalan di latar.
  Future<void> _selesaikan(Pesanan pesanan, List<PesananRincian> rincian) async {
    if (_memproses) return;
    final tunai = _metode == _Metode.tunai;
    final total = pesanan.total;
    final bayar = tunai ? _bayarTunai : total;
    if (tunai && bayar < total) return;
    if (!tunai && _pathFoto == null) return;

    setState(() => _memproses = true);
    final db = ref.read(penyediaDatabaseLokal);
    try {
      final kembalian = bayar - total;
      final metodeStr = tunai ? 'tunai' : 'non_tunai';
      final lunas = pesanan.copyWith(
        status: 'lunas',
        metodeBayar: metodeStr,
        bayar: bayar,
        kembalian: kembalian,
        fotoBuktiLokal: _pathFoto,
        diperbaruiPada: DateTime.now(),
      );
      await db.perbaruiPesanan(lunas);

      // Kurangi stok tiap item menu. Kegagalan stok TIDAK boleh
      // menggagalkan pembayaran — abaikan diam-diam.
      for (final baris in rincian) {
        final idMenu = baris.idMenu;
        if (idMenu == null) continue;
        try {
          await db.kurangiStok(idMenu, baris.jumlah);
        } catch (_) {
          // Abaikan: stok bisa dikoreksi manual kemudian.
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
          dibuatPada: DateTime.now(),
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
          tunai: tunai,
          kembalian: kembalian,
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
              pakaiBlur: false,
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

  /// Zona atas: nomor nota + daftar rincian + total besar.
  ///
  /// Header dan total di-pin; hanya daftar item yang scroll
  /// ([ListView.builder] agar tidak dirender sekaligus).
  Widget _bangunZonaNota(Pesanan pesanan, List<PesananRincian> rincian) {
    final tema = Theme.of(context);
    final gelap = tema.brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KartuKaca(
            pakaiBlur: false,
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
              pakaiBlur: false,
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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${baris.namaSnapshot} × ${baris.jumlah}',
                                  style: tema.textTheme.bodyMedium,
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
          KartuKaca(
            pakaiBlur: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatRupiah(pesanan.total),
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: aksen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Zona bawah: pilih metode + input bayar + tombol Selesaikan.
  Widget _bangunZonaAksi(Pesanan pesanan, List<PesananRincian> rincian) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final tunai = _metode == _Metode.tunai;
    final total = pesanan.total;
    final bayar = tunai ? _bayarTunai : total;
    final bisaSelesai =
        !_memproses && (tunai ? bayar >= total : _pathFoto != null);

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
            _bangunPilihMetode(),
            const SizedBox(height: 12),
            if (tunai) ..._bangunTunai(total) else ..._bangunNonTunai(total),
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

  /// Dua kartu pilih metode: Tunai / Non-Tunai.
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

  /// Isi zona aksi untuk pembayaran tunai.
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

  /// Isi zona aksi untuk pembayaran non-tunai (foto bukti wajib).
  List<Widget> _bangunNonTunai(int total) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final pathFoto = _pathFoto;

    return [
      Text(
        'Bukti Pembayaran',
        style: tema.textTheme.labelLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      if (pathFoto == null)
        TombolKaca(
          label: 'Ambil Foto Bukti',
          ikon: Icons.camera_alt_outlined,
          saatDitekan: _ambilFoto,
        )
      else
        Row(
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
        ),
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

/// Dialog sukses pembayaran: centang visual membesar, TANPA suara.
class _DialogSukses extends StatelessWidget {
  const _DialogSukses({required this.tunai, required this.kembalian});

  final bool tunai;
  final int kembalian;

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

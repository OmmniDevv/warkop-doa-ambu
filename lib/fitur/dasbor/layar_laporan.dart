import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warkop_doa_ambu/fitur/void_kasbon/dialog_void.dart';

import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/pesanan.dart';
import 'util_tanggal.dart';

/// Seluruh pesanan untuk agregasi laporan (7 hari terakhir + harian).
final penyediaSemuaPesanan = FutureProvider<List<Pesanan>>((ref) async {
  return DatabaseLokal.instance.daftarPesanan();
});

class _RekapHarian {
  const _RekapHarian({
    required this.tanggal,
    required this.omzet,
    required this.jumlahPesanan,
    required this.jumlahVoid,
  });

  final DateTime tanggal;
  final int omzet;
  final int jumlahPesanan;
  final int jumlahVoid;
}

/// Layar laporan owner: rekap 7 hari terakhir + daftar pesanan harian.
///
/// - Kartu harian bisa diketuk untuk memilih tanggal yang ditampilkan.
/// - Filter metode: Semua / Tunai / Non-Tunai.
/// - Pesanan berstatus 'baru' bisa di-void lewat dialog fase 6.
class LayarLaporan extends ConsumerStatefulWidget {
  const LayarLaporan({super.key});

  @override
  ConsumerState<LayarLaporan> createState() => _LayarLaporanState();
}

class _LayarLaporanState extends ConsumerState<LayarLaporan> {
  late DateTime _tanggalTerpilih;
  String _filterMetode = 'semua'; // 'semua' | 'tunai' | 'non_tunai'

  @override
  void initState() {
    super.initState();
    final sekarang = DateTime.now();
    _tanggalTerpilih = DateTime(sekarang.year, sekarang.month, sekarang.day);
  }

  List<_RekapHarian> _rekapTujuhHari(List<Pesanan> semua) {
    final sekarang = DateTime.now();
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    return List.generate(7, (i) {
      final tanggal = hariIni.subtract(Duration(days: i));
      final milikHari = semua
          .where((p) => apakahHariYangSama(p.diperbaruiPada, tanggal))
          .toList();
      final omzet = milikHari
          .where((p) => p.status == 'lunas')
          .fold<int>(0, (jumlah, p) => jumlah + p.total);
      return _RekapHarian(
        tanggal: tanggal,
        omzet: omzet,
        jumlahPesanan: milikHari.length,
        jumlahVoid: milikHari.where((p) => p.status == 'void').length,
      );
    });
  }

  String _labelHari(DateTime tanggal) {
    final sekarang = DateTime.now();
    if (apakahHariYangSama(tanggal, sekarang)) return 'Hari ini';
    if (apakahHariYangSama(
      tanggal,
      sekarang.subtract(const Duration(days: 1)),
    )) {
      return 'Kemarin';
    }
    return formatTanggalPendek(tanggal);
  }

  Future<void> _voidPesanan(Pesanan pesanan) async {
    final berubah = await tampilkanDialogVoid(
      context,
      ref,
      idPesanan: pesanan.id,
      nomorNota: pesanan.nomorNota,
    );
    if (berubah && mounted) {
      ref.invalidate(penyediaSemuaPesanan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pesananAsync = ref.watch(penyediaSemuaPesanan);

    return Scaffold(
      appBar: AppBar(title: const Text('LAPORAN')),
      body: SafeArea(
        child: pesananAsync.when(
          data: (semua) {
            final rekap = _rekapTujuhHari(semua);
            final pesananTanggal = semua
                .where(
                  (p) =>
                      apakahHariYangSama(p.diperbaruiPada, _tanggalTerpilih) &&
                      (_filterMetode == 'semua' ||
                          p.metodeBayar == _filterMetode),
                )
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KartuMingguan(rekap: rekap),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      _ChipMetode(
                        label: 'Semua',
                        terpilih: _filterMetode == 'semua',
                        saatPilih: () =>
                            setState(() => _filterMetode = 'semua'),
                      ),
                      _ChipMetode(
                        label: 'Tunai',
                        terpilih: _filterMetode == 'tunai',
                        saatPilih: () =>
                            setState(() => _filterMetode = 'tunai'),
                      ),
                      _ChipMetode(
                        label: 'Non-Tunai',
                        terpilih: _filterMetode == 'non_tunai',
                        saatPilih: () =>
                            setState(() => _filterMetode = 'non_tunai'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Harian — 7 Hari Terakhir',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final r in rekap)
                    _KartuHarian(
                      rekap: r,
                      label: _labelHari(r.tanggal),
                      terpilih:
                          apakahHariYangSama(r.tanggal, _tanggalTerpilih),
                      saatTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _tanggalTerpilih = r.tanggal);
                      },
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Pesanan — ${formatTanggalPendek(_tanggalTerpilih)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (pesananTanggal.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Tidak ada pesanan pada tanggal ini.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final p in pesananTanggal)
                      _BarisPesanan(
                        pesanan: p,
                        saatVoid: () => _voidPesanan(p),
                      ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat laporan: $e')),
        ),
      ),
    );
  }
}

class _ChipMetode extends StatelessWidget {
  const _ChipMetode({
    required this.label,
    required this.terpilih,
    required this.saatPilih,
  });

  final String label;
  final bool terpilih;
  final VoidCallback saatPilih;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: terpilih,
      onSelected: (_) => saatPilih(),
    );
  }
}

/// Kartu total mingguan di header laporan.
class _KartuMingguan extends StatelessWidget {
  const _KartuMingguan({required this.rekap});

  final List<_RekapHarian> rekap;

  @override
  Widget build(BuildContext context) {
    final omzet = rekap.fold<int>(0, (jumlah, r) => jumlah + r.omzet);
    final pesanan =
        rekap.fold<int>(0, (jumlah, r) => jumlah + r.jumlahPesanan);
    final voidCount =
        rekap.fold<int>(0, (jumlah, r) => jumlah + r.jumlahVoid);

    return KartuKaca(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total 7 Hari Terakhir',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Text(
            formatRupiah(omzet),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.merge(TipografiWarkop.nominal)
                .copyWith(color: WarnaWarkop.emas),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Pesanan',
                  nilai: '$pesanan',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Void',
                  nilai: '$voidCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nilai,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.merge(TipografiWarkop.nominal),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Kartu rekap satu hari — ketuk untuk memilih tanggal.
class _KartuHarian extends StatelessWidget {
  const _KartuHarian({
    required this.rekap,
    required this.label,
    required this.terpilih,
    required this.saatTap,
  });

  final _RekapHarian rekap;
  final String label;
  final bool terpilih;
  final VoidCallback saatTap;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: saatTap,
          child: KartuKaca(
            pakaiBlur: false,
            radius: 16,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: terpilih ? aksen.withValues(alpha: 0.6) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: terpilih ? aksen : null,
                              fontWeight:
                                  terpilih ? FontWeight.w700 : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rekap.jumlahPesanan} pesanan • '
                        '${rekap.jumlahVoid} void',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRupiah(rekap.omzet),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.merge(TipografiWarkop.nominal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris pesanan: nota, total, metode, status + tombol void.
class _BarisPesanan extends StatelessWidget {
  const _BarisPesanan({
    required this.pesanan,
    required this.saatVoid,
  });

  final Pesanan pesanan;
  final VoidCallback saatVoid;

  @override
  Widget build(BuildContext context) {
    final labelMetode =
        pesanan.metodeBayar == 'non_tunai' ? 'Non-Tunai' : 'Tunai';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KartuKaca(
        pakaiBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            pesanan.nomorNota,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            '${formatRupiah(pesanan.total)} • $labelMetode',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChipStatus(pesanan.status),
              if (pesanan.status == 'baru') ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Void pesanan',
                  icon: Icon(
                    Icons.delete_forever_outlined,
                    color: WarnaWarkop.merahMenyala,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    saatVoid();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color warna;
    final String label;
    switch (status) {
      case 'lunas':
        warna = WarnaWarkop.hijauAman;
        label = 'Lunas';
      case 'void':
        warna = WarnaWarkop.merahMenyala;
        label = 'Void';
      default:
        warna = WarnaWarkop.kuningAntre;
        label = 'Baru';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

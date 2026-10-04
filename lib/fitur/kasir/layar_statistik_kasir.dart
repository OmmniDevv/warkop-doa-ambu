import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import 'penyedia_kasir.dart';

/// Ringkasan statistik kasir hari ini (WIB).
class RingkasanKasir {
  const RingkasanKasir({
    required this.omzet,
    required this.jumlahTransaksi,
    required this.perJam,
    required this.terlaris,
  });

  final int omzet;
  final int jumlahTransaksi;

  /// Omzet per jam 0–23 WIB.
  final List<int> perJam;

  /// Top 5 menu terlaris (nama, qty).
  final List<({String nama, int qty})> terlaris;
}

/// Hitung statistik kasir yang sedang login, hari ini (WIB).
///
/// Hanya data milik kasir ini (filter id_akun). TIDAK menampilkan data
/// sensitif owner (modal, laba, dsb).
final penyediaRingkasanKasir = FutureProvider<RingkasanKasir>((ref) async {
  final kasir = ref.watch(sesiKasirProvider);
  if (kasir == null) {
    return const RingkasanKasir(
      omzet: 0,
      jumlahTransaksi: 0,
      perJam: [],
      terlaris: [],
    );
  }

  final awalHari = awalHariWib(sekarangWib());
  final awalBesok = awalHari.add(const Duration(days: 1));
  final db = await DatabaseLokal.instance.db;

  // Pesanan lunas milik kasir ini hari ini.
  final pesanan = await db.rawQuery(
    '''
    SELECT id, total, diperbarui_pada FROM pesanan
    WHERE status = 'lunas' AND apakah_dihapus = 0
      AND id_akun = ?
      AND diperbarui_pada >= ? AND diperbarui_pada < ?
    ''',
    [kasir.id, awalHari.toUtc().toIso8601String(), awalBesok.toUtc().toIso8601String()],
  );

  var omzet = 0;
  final perJam = List<int>.filled(24, 0);
  final idPesanan = <String>[];
  for (final p in pesanan) {
    final total = (p['total'] as int?) ?? 0;
    omzet += total;
    idPesanan.add(p['id'] as String);
    final waktu = DateTime.parse(p['diperbarui_pada'] as String);
    perJam[jamWib(waktu)] += total;
  }

  // Menu terlaris milik kasir ini hari ini.
  var terlaris = <({String nama, int qty})>[];
  if (idPesanan.isNotEmpty) {
    final tanda = List.filled(idPesanan.length, '?').join(',');
    final baris = await db.rawQuery(
      '''
      SELECT nama_snapshot AS nama, SUM(jumlah) AS qty
      FROM pesanan_rincian
      WHERE apakah_dihapus = 0 AND id_pesanan IN ($tanda)
      GROUP BY nama_snapshot
      ORDER BY qty DESC
      LIMIT 5
      ''',
      idPesanan,
    );
    terlaris = baris
        .map((b) => (
              nama: (b['nama'] as String?) ?? '-',
              qty: ((b['qty'] as num?) ?? 0).toInt(),
            ))
        .toList();
  }

  return RingkasanKasir(
    omzet: omzet,
    jumlahTransaksi: pesanan.length,
    perJam: perJam,
    terlaris: terlaris,
  );
});

/// Layar statistik kasir: omzet & transaksi hari ini, grafik jam sibuk,
/// menu terlaris — khusus data kasir yang login.
class LayarStatistikKasir extends ConsumerWidget {
  const LayarStatistikKasir({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kasir = ref.watch(sesiKasirProvider);
    final ringkasanAsync = ref.watch(penyediaRingkasanKasir);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('STATISTIK')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_outlined, size: 64, color: aksen),
                  const SizedBox(height: 16),
                  Text(
                    'Masuk dulu sebagai kasir untuk melihat statistikmu.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  TombolKaca(
                    label: 'Masuk sebagai Kasir',
                    lebarPenuh: false,
                    saatDitekan: () => context.go(Rute.selamatDatang),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('STATISTIK')),
      body: OrbLatar(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(penyediaRingkasanKasir);
              await ref.read(penyediaRingkasanKasir.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Halo, ${kasir.nama}!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statistik penjualanmu hari ini (WIB).',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: teksRedup),
                  ),
                  const SizedBox(height: 16),
                  ringkasanAsync.when(
                    data: (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _KartuAngka(
                                label: 'Omzet Hari Ini',
                                nilai: formatRupiah(r.omzet),
                                ikon: Icons.payments_outlined,
                                aksen: aksen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _KartuAngka(
                                label: 'Transaksi Hari Ini',
                                nilai: '${r.jumlahTransaksi}',
                                ikon: Icons.receipt_outlined,
                                aksen: aksen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _GrafikJamKasir(
                          perJam: r.perJam,
                          aksen: aksen,
                          teksRedup: teksRedup,
                        ),
                        const SizedBox(height: 12),
                        _TerlarisKasir(
                          terlaris: r.terlaris,
                          aksen: aksen,
                          teksRedup: teksRedup,
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Gagal memuat statistik: $e'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuAngka extends StatelessWidget {
  const _KartuAngka({
    required this.label,
    required this.nilai,
    required this.ikon,
    required this.aksen,
  });

  final String label;
  final String nilai;
  final IconData ikon;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: aksen, size: 22),
          const SizedBox(height: 8),
          Text(
            nilai,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GrafikJamKasir extends StatelessWidget {
  const _GrafikJamKasir({
    required this.perJam,
    required this.aksen,
    required this.teksRedup,
  });

  final List<int> perJam;
  final Color aksen;
  final Color teksRedup;

  @override
  Widget build(BuildContext context) {
    final maks = perJam.fold<int>(0, (a, b) => a > b ? a : b);
    final jamTersibuk = maks > 0 ? perJam.indexOf(maks) : -1;

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                'JAM SIBUKMU (WIB)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          if (jamTersibuk >= 0) ...[
            const SizedBox(height: 8),
            Text(
              'Tersibuk jam ${jamTersibuk.toString().padLeft(2, '0')}.00 WIB',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: maks == 0
                ? Center(
                    child: Text(
                      'Belum ada penjualan hari ini.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: teksRedup),
                    ),
                  )
                : RepaintBoundary(
                    child: BarChart(
                      BarChartData(
                        maxY: (maks * 1.25).clamp(1, double.infinity).toDouble(),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (grup, _, rod, __) {
                              final jam = grup.x.toInt();
                              return BarTooltipItem(
                                'Jam ${jam.toString().padLeft(2, '0')}.00\n'
                                '${formatRupiah(rod.toY.round())}',
                                const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (nilai, _) {
                                final jam = nilai.toInt();
                                if (jam % 4 != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  jam.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: teksRedup,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var jam = 0; jam < 24; jam++)
                            BarChartGroupData(
                              x: jam,
                              barRods: [
                                BarChartRodData(
                                  toY: perJam[jam].toDouble(),
                                  width: 6,
                                  borderRadius: BorderRadius.circular(3),
                                  color: jam == jamTersibuk
                                      ? aksen
                                      : aksen.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TerlarisKasir extends StatelessWidget {
  const _TerlarisKasir({
    required this.terlaris,
    required this.aksen,
    required this.teksRedup,
  });

  final List<({String nama, int qty})> terlaris;
  final Color aksen;
  final Color teksRedup;

  @override
  Widget build(BuildContext context) {
    final maks = terlaris.fold<int>(0, (a, b) => a > b.qty ? a : b.qty);

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_outlined,
                  color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                'MENU TERLARISMU',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (terlaris.isEmpty)
            Text(
              'Belum ada penjualan hari ini.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: teksRedup),
            )
          else
            for (var i = 0; i < terlaris.length; i++) ...[
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: aksen,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                terlaris[i].nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '${terlaris[i].qty}x',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: teksRedup),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maks > 0 ? terlaris[i].qty / maks : 0,
                            minHeight: 6,
                            backgroundColor:
                                aksen.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(aksen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < terlaris.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

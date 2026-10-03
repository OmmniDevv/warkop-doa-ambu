import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import 'util_tanggal.dart';

/// Satu titik omzet harian untuk grafik.
class TitikOmzetHarian {
  const TitikOmzetHarian({required this.tanggal, required this.omzet});

  final DateTime tanggal; // awal hari WIB
  final int omzet;
}

/// Omzet 7 hari terakhir (termasuk hari ini), dalam WIB.
/// Urut dari 6 hari lalu → hari ini.
final penyediaOmzet7Hari =
    FutureProvider<List<TitikOmzetHarian>>((ref) async {
  final hariIni = awalHariWib(sekarangWib());
  final semua = await DatabaseLokal.instance.daftarPesanan();
  return List.generate(7, (i) {
    final tanggal = hariIni.subtract(Duration(days: 6 - i));
    final besok = tanggal.add(const Duration(days: 1));
    final omzet = semua
        .where((p) =>
            p.status == 'lunas' &&
            !p.diperbaruiPada.isBefore(tanggal) &&
            p.diperbaruiPada.isBefore(besok))
        .fold<int>(0, (jumlah, p) => jumlah + p.total);
    return TitikOmzetHarian(tanggal: tanggal, omzet: omzet);
  });
});

/// Omzet per jam hari ini (24 slot jam 0–23 WIB).
final penyediaOmzetPerJam = FutureProvider<List<int>>((ref) async {
  final awalHari = awalHariWib(sekarangWib());
  final awalBesok = awalHari.add(const Duration(days: 1));
  final semua = await DatabaseLokal.instance.daftarPesanan();
  final perJam = List<int>.filled(24, 0);
  for (final p in semua) {
    if (p.status != 'lunas') continue;
    if (p.diperbaruiPada.isBefore(awalHari) ||
        !p.diperbaruiPada.isBefore(awalBesok)) {
      continue;
    }
    perJam[jamWib(p.diperbaruiPada)] += p.total;
  }
  return perJam;
});

/// Grafik batang omzet 7 hari terakhir.
///
/// Label sumbu-X: nama hari pendek Indonesia (Sen, Sel, ...).
/// Sentuh batang untuk melihat angka pastinya (tooltip).
class GrafikOmzet7Hari extends ConsumerWidget {
  const GrafikOmzet7Hari({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(penyediaOmzet7Hari);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final garisGrid = gelap
        ? WarnaWarkop.teksSekunderGelap.withValues(alpha: 0.15)
        : WarnaWarkop.teksSekunderTerang.withValues(alpha: 0.15);

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                'OMZET 7 HARI TERAKHIR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (titik) {
              final maks = titik
                  .map((t) => t.omzet)
                  .fold<int>(0, (a, b) => a > b ? a : b);
              return SizedBox(
                height: 200,
                child: RepaintBoundary(
                  child: BarChart(
                    BarChartData(
                      maxY: (maks * 1.2).clamp(1, double.infinity).toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (grup, _, rod, __) {
                            final t = titik[grup.x.toInt()];
                            return BarTooltipItem(
                              '${namaHariPendek(t.tanggal)}, '
                              '${formatTanggalPendek(t.tanggal)}\n'
                              '${formatRupiah(rod.toY.round())}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: garisGrid, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (nilai, _) {
                              final i = nilai.toInt();
                              if (i < 0 || i >= titik.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  namaHariPendek(titik[i].tanggal),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: teksRedup),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < titik.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: titik[i].omzet.toDouble(),
                                width: 22,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: LinearGradient(
                                  colors: [aksen, aksen.withValues(alpha: 0.55)],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 200,
              child: Center(child: Text('Gagal memuat grafik: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafik batang omzet per jam hari ini (00–23 WIB).
///
/// Menjawab "jam berapa paling rame?" — dipakai juga untuk laporan jam sibuk.
class GrafikJamSibuk extends ConsumerWidget {
  const GrafikJamSibuk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(penyediaOmzetPerJam);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final garisGrid = gelap
        ? WarnaWarkop.teksSekunderGelap.withValues(alpha: 0.15)
        : WarnaWarkop.teksSekunderTerang.withValues(alpha: 0.15);

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
                'JAM SIBUK HARI INI (WIB)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Omzet per jam — bantu atur jadwal jaga.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: teksRedup),
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (perJam) {
              final maks =
                  perJam.fold<int>(0, (a, b) => a > b ? a : b);
              final jamTersibuk = perJam.indexOf(maks);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (maks > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Tersibuk jam ${jamTersibuk.toString().padLeft(2, '0')}.00 WIB',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  SizedBox(
                    height: 180,
                    child: RepaintBoundary(
                      child: BarChart(
                        BarChartData(
                          maxY:
                              (maks * 1.25).clamp(1, double.infinity).toDouble(),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (grup, _, rod, __) {
                                final jam = grup.x.toInt();
                                return BarTooltipItem(
                                  'Jam ${jam.toString().padLeft(2, '0')}.00 WIB\n'
                                  '${formatRupiah(rod.toY.round())}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) =>
                                FlLine(color: garisGrid, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (nilai, _) {
                                  final jam = nilai.toInt();
                                  // Label tiap 3 jam agar tidak berdesakan.
                                  if (jam % 3 != 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '$jam',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: teksRedup),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var jam = 0; jam < 24; jam++)
                              BarChartGroupData(
                                x: jam,
                                barRods: [
                                  BarChartRodData(
                                    toY: perJam[jam].toDouble(),
                                    width: 8,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                    color: jam == jamTersibuk && maks > 0
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
              );
            },
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 180,
              child: Center(child: Text('Gagal memuat grafik: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

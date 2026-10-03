import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../data/lokal/database_lokal.dart';

/// Periode untuk laporan tambahan: hari / minggu / bulan ini (WIB).
enum PeriodeLaporanTambahan { hari, minggu, bulan }

extension PeriodeLaporanTambahanX on PeriodeLaporanTambahan {
  String get label => switch (this) {
        PeriodeLaporanTambahan.hari => 'Hari ini',
        PeriodeLaporanTambahan.minggu => 'Minggu ini',
        PeriodeLaporanTambahan.bulan => 'Bulan ini',
      };

  /// Batas awal periode dalam UTC ISO8601 (untuk perbandingan string SQL).
  String awalUtcIso() {
    final sekarang = sekarangWib();
    final awal = switch (this) {
      PeriodeLaporanTambahan.hari => awalHariWib(sekarang),
      PeriodeLaporanTambahan.minggu => awalMingguWib(sekarang),
      PeriodeLaporanTambahan.bulan => awalBulanWib(sekarang),
    };
    return awal.toUtc().toIso8601String();
  }
}

/// Satu baris menu terlaris.
class MenuTerlaris {
  const MenuTerlaris({
    required this.nama,
    required this.qty,
    required this.omzet,
  });

  final String nama;
  final int qty;
  final int omzet;
}

/// Ambil top 10 menu terlaris per periode (berdasar qty terjual).
Future<List<MenuTerlaris>> ambilMenuTerlaris(
    PeriodeLaporanTambahan periode) async {
  final db = await DatabaseLokal.instance.db;
  final awal = periode.awalUtcIso();
  final baris = await db.rawQuery(
    '''
    SELECT pr.nama_snapshot AS nama,
           SUM(pr.jumlah) AS qty,
           SUM(pr.subtotal) AS omzet
    FROM pesanan_rincian pr
    JOIN pesanan p ON p.id = pr.id_pesanan
    WHERE p.status = 'lunas'
      AND p.apakah_dihapus = 0
      AND pr.apakah_dihapus = 0
      AND p.diperbarui_pada >= ?
    GROUP BY pr.nama_snapshot
    ORDER BY qty DESC
    LIMIT 10
    ''',
    [awal],
  );
  return baris
      .map((b) => MenuTerlaris(
            nama: (b['nama'] as String?) ?? '-',
            qty: (b['qty'] as int?) ?? 0,
            omzet: (b['omzet'] as int?) ?? 0,
          ))
      .toList();
}

/// Rekap nominal per metode bayar dalam satu periode.
///
/// Untuk pesanan 'gabungan', nominal diambil dari tabel pesanan_bayar
/// (rinci tunai vs non-tunai). Pesanan tunai/non-tunai biasa memakai total.
class RekapMetodeBayar {
  const RekapMetodeBayar({
    required this.tunai,
    required this.nonTunai,
    required this.jumlahTransaksi,
  });

  final int tunai;
  final int nonTunai;
  final int jumlahTransaksi;

  int get total => tunai + nonTunai;
}

Future<RekapMetodeBayar> ambilRekapMetodeBayar(
    PeriodeLaporanTambahan periode) async {
  final db = await DatabaseLokal.instance.db;
  final awal = periode.awalUtcIso();

  final pesanan = await db.rawQuery(
    '''
    SELECT id, metode_bayar, total
    FROM pesanan
    WHERE status = 'lunas'
      AND apakah_dihapus = 0
      AND diperbarui_pada >= ?
    ''',
    [awal],
  );

  var tunai = 0;
  var nonTunai = 0;
  for (final p in pesanan) {
    final metode = p['metode_bayar'] as String?;
    final total = (p['total'] as int?) ?? 0;
    if (metode == 'gabungan') {
      // Rinci dari pesanan_bayar.
      final id = p['id'] as String;
      final komponen = await db.query(
        'pesanan_bayar',
        where: 'id_pesanan = ?',
        whereArgs: [id],
      );
      for (final k in komponen) {
        final nominal = (k['nominal'] as int?) ?? 0;
        if (k['metode'] == 'tunai') {
          tunai += nominal;
        } else {
          nonTunai += nominal;
        }
      }
    } else if (metode == 'tunai') {
      tunai += total;
    } else {
      nonTunai += total;
    }
  }

  return RekapMetodeBayar(
    tunai: tunai,
    nonTunai: nonTunai,
    jumlahTransaksi: pesanan.length,
  );
}

/// Bagian "Menu Terlaris": pilih periode + top 10 bar horizontal.
class BagianMenuTerlaris extends StatefulWidget {
  const BagianMenuTerlaris({super.key});

  @override
  State<BagianMenuTerlaris> createState() => _BagianMenuTerlarisState();
}

class _BagianMenuTerlarisState extends State<BagianMenuTerlaris> {
  PeriodeLaporanTambahan _periode = PeriodeLaporanTambahan.minggu;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                'MENU TERLARIS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PilihPeriode(
            periode: _periode,
            saatUbah: (p) => setState(() => _periode = p),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<MenuTerlaris>>(
            future: ambilMenuTerlaris(_periode),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final daftar = snapshot.data ?? [];
              if (daftar.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Belum ada penjualan pada periode ini.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: teksRedup),
                  ),
                );
              }
              final maksQty =
                  daftar.map((m) => m.qty).fold<int>(1, (a, b) => a > b ? a : b);
              return Column(
                children: [
                  for (var i = 0; i < daftar.length; i++)
                    _BarisTerlaris(
                      peringkat: i + 1,
                      menu: daftar[i],
                      maksQty: maksQty,
                      aksen: aksen,
                      teksRedup: teksRedup,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Satu baris peringkat menu terlaris dengan bar horizontal.
class _BarisTerlaris extends StatelessWidget {
  const _BarisTerlaris({
    required this.peringkat,
    required this.menu,
    required this.maksQty,
    required this.aksen,
    required this.teksRedup,
  });

  final int peringkat;
  final MenuTerlaris menu;
  final int maksQty;
  final Color aksen;
  final Color teksRedup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$peringkat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: peringkat <= 3 ? aksen : teksRedup,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        menu.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${menu.qty}x • ${formatRupiahRingkas(menu.omzet)}',
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
                    value: menu.qty / maksQty,
                    minHeight: 8,
                    backgroundColor: aksen.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(aksen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bagian "Rekap Metode Bayar": kartu angka + pie chart.
class BagianRekapMetodeBayar extends StatefulWidget {
  const BagianRekapMetodeBayar({super.key});

  @override
  State<BagianRekapMetodeBayar> createState() => _BagianRekapMetodeBayarState();
}

class _BagianRekapMetodeBayarState extends State<BagianRekapMetodeBayar> {
  PeriodeLaporanTambahan _periode = PeriodeLaporanTambahan.minggu;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final hijau = WarnaWarkop.hijauAman;

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                'REKAP METODE BAYAR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PilihPeriode(
            periode: _periode,
            saatUbah: (p) => setState(() => _periode = p),
          ),
          const SizedBox(height: 12),
          FutureBuilder<RekapMetodeBayar>(
            future: ambilRekapMetodeBayar(_periode),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final rekap = snapshot.data ??
                  const RekapMetodeBayar(
                      tunai: 0, nonTunai: 0, jumlahTransaksi: 0);
              final total = rekap.total;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KartuMetode(
                          label: 'Tunai',
                          nominal: rekap.tunai,
                          warna: hijau,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _KartuMetode(
                          label: 'Non-Tunai',
                          nominal: rekap.nonTunai,
                          warna: aksen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (total > 0)
                    SizedBox(
                      height: 180,
                      child: RepaintBoundary(
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                            sections: [
                              PieChartSectionData(
                                value: rekap.tunai.toDouble(),
                                color: hijau,
                                radius: 60,
                                title:
                                    '${(rekap.tunai / total * 100).round()}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                value: rekap.nonTunai.toDouble(),
                                color: aksen,
                                radius: 60,
                                title:
                                    '${(rekap.nonTunai / total * 100).round()}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Belum ada pembayaran pada periode ini.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: teksRedup),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${rekap.jumlahTransaksi} transaksi • '
                    'Total ${formatRupiah(total)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: teksRedup),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Kartu angka satu metode bayar.
class _KartuMetode extends StatelessWidget {
  const _KartuMetode({
    required this.label,
    required this.nominal,
    required this.warna,
  });

  final String label;
  final int nominal;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: warna,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(nominal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

/// Pemilih periode: Hari ini / Minggu ini / Bulan ini.
class _PilihPeriode extends StatelessWidget {
  const _PilihPeriode({required this.periode, required this.saatUbah});

  final PeriodeLaporanTambahan periode;
  final ValueChanged<PeriodeLaporanTambahan> saatUbah;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PeriodeLaporanTambahan>(
      segments: const [
        ButtonSegment(
          value: PeriodeLaporanTambahan.hari,
          label: Text('Hari ini'),
        ),
        ButtonSegment(
          value: PeriodeLaporanTambahan.minggu,
          label: Text('Minggu ini'),
        ),
        ButtonSegment(
          value: PeriodeLaporanTambahan.bulan,
          label: Text('Bulan ini'),
        ),
      ],
      selected: {periode},
      onSelectionChanged: (pilihan) => saatUbah(pilihan.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

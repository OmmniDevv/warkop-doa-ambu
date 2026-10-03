import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/pesanan.dart';
import 'direktori_ekspor.dart';
import 'pengekspor_laporan.dart';
import 'util_tanggal.dart';

/// Pengekspor laporan ke berkas PDF.
///
/// Tata letak: kop warkop → judul laporan → info (dibuat oleh, tanggal,
/// periode) → tabel data → baris total → footer nomor halaman.
/// Berkas disimpan ke `Documents/WarkopDoaAmbu/` (lihat [DirektoriEkspor]).
class PengeksporPdf {
  PengeksporPdf._();

  static final _ungu = PdfColor.fromHex('#6B4EFF');
  static final _unguMuda = PdfColor.fromHex('#EDEBFF');
  static final _abu = PdfColor.fromHex('#6B7280');
  static final _hitam = PdfColor.fromHex('#1F2937');

  /// Pesanan lunas di dalam periode (urut waktu naik).
  /// Batas periode memakai WIB (Asia/Jakarta).
  static Future<List<Pesanan>> _pesananLunas(PeriodeLaporan periode) async {
    final hariIni = awalHariWib(sekarangWib());
    final awal = hariIni.subtract(Duration(days: periode.jumlahHari - 1));
    final semua = await DatabaseLokal.instance.daftarPesanan();
    final milik = semua
        .where((p) => p.status == 'lunas' && !p.diperbaruiPada.isBefore(awal))
        .toList()
      ..sort((a, b) => a.diperbaruiPada.compareTo(b.diperbaruiPada));
    return milik;
  }

  static String _labelRentang(DateTime awal, DateTime akhir) {
    if (apakahHariYangSama(awal, akhir)) {
      return formatTanggalPendek(akhir);
    }
    return '${formatTanggalPendek(awal)} – ${formatTanggalPendek(akhir)}';
  }

  /// Kop halaman: nama warkop + judul + info pembuat.
  static pw.Widget _kop({
    required String judul,
    required String dibuatOleh,
    required String labelPeriode,
  }) {
    final sekarang = sekarangWib();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'WARKOP DOA AMBU',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _ungu,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          judul,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _hitam,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Dibuat oleh: $dibuatOleh',
            style: pw.TextStyle(fontSize: 10, color: _abu)),
        pw.Text('Tanggal: ${formatTanggalWaktu(sekarang)}',
            style: pw.TextStyle(fontSize: 10, color: _abu)),
        pw.Text('Periode: $labelPeriode',
            style: pw.TextStyle(fontSize: 10, color: _abu)),
        pw.SizedBox(height: 12),
        pw.Divider(color: _ungu, thickness: 2),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// Tabel PDF generik dengan header ungu dan baris total.
  static pw.Widget _tabel({
    required List<String> kepala,
    required List<List<String>> baris,
    required List<String> total,
    required List<int> rataKanan,
  }) {
    pw.Widget sel(String teks,
        {bool kepala = false, bool total = false, bool kanan = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: pw.Text(
          teks,
          textAlign: kanan ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: (kepala || total)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: kepala ? PdfColors.white : _hitam,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        for (var i = 0; i < kepala.length; i++)
          i: i == 0
              ? const pw.FixedColumnWidth(32)
              : const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _ungu),
          children: [
            for (var i = 0; i < kepala.length; i++)
              sel(kepala[i],
                  kepala: true, kanan: rataKanan.contains(i)),
          ],
        ),
        for (final b in baris)
          pw.TableRow(
            children: [
              for (var i = 0; i < b.length; i++)
                sel(b[i], kanan: rataKanan.contains(i)),
            ],
          ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _unguMuda),
          children: [
            for (var i = 0; i < total.length; i++)
              sel(total[i], total: true, kanan: rataKanan.contains(i)),
          ],
        ),
      ],
    );
  }

  static pw.PageTheme _temaHalaman() => const pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
      );

  /// Footer: nomor halaman + nama warkop.
  static pw.Widget Function(pw.Context) _kaki(String judul) {
    return (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            '$judul — Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _abu),
          ),
        );
  }

  static Future<String> _simpan(
      pw.Document dokumen, String namaBerkas) async {
    final bytes = await dokumen.save();
    final dir = await DirektoriEkspor.direktori();
    final berkas = File('${dir.path}/$namaBerkas');
    await berkas.writeAsBytes(bytes, flush: true);
    return berkas.path;
  }

  // ── Rekap penjualan ──────────────────────────────────────────────

  /// Export rekap penjualan ke PDF. Mengembalikan path berkas.
  static Future<String> eksporRekapPenjualan({
    required PeriodeLaporan periode,
    required String dibuatOleh,
  }) async {
    final pesanan = await _pesananLunas(periode);
    final sekarang = sekarangWib();
    final akhir = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final awal =
        akhir.subtract(Duration(days: periode.jumlahHari - 1));

    // Kelompokkan: per jam (harian) atau per hari.
    final Map<String, _KelompokPdf> kelompok = {};
    final List<String> urutan = [];
    if (periode == PeriodeLaporan.harian) {
      for (var jam = 0; jam < 24; jam++) {
        final kunci = 'pukul ${jam.toString().padLeft(2, '0')}.00';
        kelompok[kunci] = _KelompokPdf();
        urutan.add(kunci);
      }
      for (final p in pesanan) {
        final kunci =
            'pukul ${p.diperbaruiPada.hour.toString().padLeft(2, '0')}.00';
        kelompok[kunci]!.tambah(p.total);
      }
    } else {
      var tanggal = awal;
      while (!tanggal.isAfter(akhir)) {
        final kunci = formatTanggalPendek(tanggal);
        kelompok[kunci] = _KelompokPdf();
        urutan.add(kunci);
        tanggal = tanggal.add(const Duration(days: 1));
      }
      for (final p in pesanan) {
        final kunci = formatTanggalPendek(p.diperbaruiPada);
        kelompok[kunci]?.tambah(p.total);
      }
    }

    final judul = 'REKAP PENJUALAN — ${periode.label.toUpperCase()}';
    final dokumen = pw.Document();

    final barisData = <List<String>>[];
    var totalPesanan = 0;
    var totalOmzet = 0;
    for (var i = 0; i < urutan.length; i++) {
      final k = kelompok[urutan[i]]!;
      totalPesanan += k.jumlah;
      totalOmzet += k.omzet;
      final rata = k.jumlah == 0 ? 0 : (k.omzet / k.jumlah).round();
      barisData.add([
        '${i + 1}',
        urutan[i],
        '${k.jumlah}',
        formatRupiah(k.omzet),
        formatRupiah(rata),
      ]);
    }

    dokumen.addPage(
      pw.MultiPage(
        pageTheme: _temaHalaman(),
        header: (ctx) => _kop(
          judul: judul,
          dibuatOleh: dibuatOleh,
          labelPeriode: _labelRentang(awal, akhir),
        ),
        footer: _kaki('Rekap Penjualan'),
        build: (ctx) => [
          _tabel(
            kepala: const [
              'No',
              'Waktu',
              'Jumlah Pesanan',
              'Omzet (Rp)',
              'Rata-rata (Rp)'
            ],
            baris: barisData,
            total: [
              '',
              'TOTAL',
              '$totalPesanan',
              formatRupiah(totalOmzet),
              totalPesanan == 0
                  ? formatRupiah(0)
                  : formatRupiah((totalOmzet / totalPesanan).round()),
            ],
            rataKanan: const [2, 3, 4],
          ),
        ],
      ),
    );

    return _simpan(
        dokumen, DirektoriEkspor.namaBerkas('rekap-${periode.name}', 'pdf'));
  }

  // ── Menu terlaris ────────────────────────────────────────────────

  /// Export menu terlaris ke PDF. Mengembalikan path berkas.
  static Future<String> eksporMenuTerlaris({
    required PeriodeLaporan periode,
    required String dibuatOleh,
  }) async {
    final pesanan = await _pesananLunas(periode);
    final sekarang = sekarangWib();
    final akhir = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final awal =
        akhir.subtract(Duration(days: periode.jumlahHari - 1));

    final Map<String, _KelompokPdf> agregat = {};
    for (final p in pesanan) {
      final rincian =
          await DatabaseLokal.instance.daftarRincianPesanan(p.id);
      for (final r in rincian) {
        agregat
            .putIfAbsent(r.namaSnapshot, () => _KelompokPdf())
            .tambah(r.subtotal, r.jumlah);
      }
    }
    final urutan = agregat.keys.toList()
      ..sort((a, b) => agregat[b]!.jumlah.compareTo(agregat[a]!.jumlah));

    final judul = 'MENU TERLARIS — ${periode.label.toUpperCase()}';
    final dokumen = pw.Document();

    final barisData = <List<String>>[];
    var totalTerjual = 0;
    var totalOmzet = 0;
    for (var i = 0; i < urutan.length; i++) {
      final nama = urutan[i];
      final k = agregat[nama]!;
      totalTerjual += k.jumlah;
      totalOmzet += k.omzet;
      barisData.add([
        '${i + 1}',
        nama,
        '${k.jumlah}',
        formatRupiah(k.omzet),
        formatRupiah(k.jumlah == 0 ? 0 : (k.omzet / k.jumlah).round()),
      ]);
    }

    dokumen.addPage(
      pw.MultiPage(
        pageTheme: _temaHalaman(),
        header: (ctx) => _kop(
          judul: judul,
          dibuatOleh: dibuatOleh,
          labelPeriode: _labelRentang(awal, akhir),
        ),
        footer: _kaki('Menu Terlaris'),
        build: (ctx) => [
          if (barisData.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Text(
                'Belum ada penjualan lunas pada periode ini.',
                style: pw.TextStyle(fontSize: 11, color: _abu),
              ),
            )
          else
            _tabel(
              kepala: const [
                'No',
                'Menu',
                'Terjual',
                'Omzet (Rp)',
                'Harga Rata-rata (Rp)'
              ],
              baris: barisData,
              total: [
                '',
                'TOTAL',
                '$totalTerjual',
                formatRupiah(totalOmzet),
                '',
              ],
              rataKanan: const [2, 3, 4],
            ),
        ],
      ),
    );

    return _simpan(dokumen,
        DirektoriEkspor.namaBerkas('menu-terlaris-${periode.name}', 'pdf'));
  }
}

/// Akumulator sederhana: jumlah item + total omzet.
class _KelompokPdf {
  int jumlah = 0;
  int omzet = 0;

  void tambah(int nilai, [int qty = 1]) {
    jumlah += qty;
    omzet += nilai;
  }
}

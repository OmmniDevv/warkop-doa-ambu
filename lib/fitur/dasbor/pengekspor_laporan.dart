import 'dart:io';

import 'package:excel/excel.dart';

import '../../data/lokal/database_lokal.dart';
import '../../data/model/pesanan.dart';
import 'direktori_ekspor.dart';
import 'util_tanggal.dart';

/// Periode yang didukung laporan Excel.
enum PeriodeLaporan { harian, mingguan, bulanan }

extension PeriodeLaporanX on PeriodeLaporan {
  String get label {
    switch (this) {
      case PeriodeLaporan.harian:
        return 'Harian';
      case PeriodeLaporan.mingguan:
        return 'Mingguan';
      case PeriodeLaporan.bulanan:
        return 'Bulanan';
    }
  }

  /// Jumlah hari kalender yang dicakup (harian = hari ini saja).
  int get jumlahHari {
    switch (this) {
      case PeriodeLaporan.harian:
        return 1;
      case PeriodeLaporan.mingguan:
        return 7;
      case PeriodeLaporan.bulanan:
        return 30;
    }
  }
}

/// Pengekspor laporan ke berkas Excel (.xlsx).
///
/// - Setiap sheet mencantumkan "Dibuat oleh" + "Tanggal" pembuatan.
/// - Total & rata-rata memakai RUMUS Excel asli (=SUM, =AVERAGE, =IF),
///   bukan nilai mati — bisa diedit/diolah ulang di spreadsheet.
/// - Berkas disimpan ke direktori dokumen aplikasi; nama berkas
///   mengandung tanggal pembuatan.
class PengeksporLaporan {
  PengeksporLaporan._();

  static final _violet = ExcelColor.fromHexString('FF6B4EFF');
  static final _violetMuda = ExcelColor.fromHexString('FFEDEBFF');

  /// Batas awal periode (tengah malam hari pertama).
  static DateTime _awalPeriode(PeriodeLaporan periode) {
    final sekarang = DateTime.now();
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    return hariIni.subtract(Duration(days: periode.jumlahHari - 1));
  }

  /// Pesanan lunas di dalam periode (urut waktu naik).
  static Future<List<Pesanan>> _pesananLunas(PeriodeLaporan periode) async {
    final awal = _awalPeriode(periode);
    final semua = await DatabaseLokal.instance.daftarPesanan();
    final milik = semua
        .where((p) => p.status == 'lunas' && !p.diperbaruiPada.isBefore(awal))
        .toList()
      ..sort((a, b) => a.diperbaruiPada.compareTo(b.diperbaruiPada));
    return milik;
  }

  // ── Util sel ─────────────────────────────────────────────────────

  static CellStyle get _gayaJudul => CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: _violet,
      );

  static CellStyle get _gayaKepala => CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: _violet,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  static CellStyle get _gayaSel => CellStyle(
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  static CellStyle get _gayaTotal => CellStyle(
        bold: true,
        backgroundColorHex: _violetMuda,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  static CellStyle get _gayaAngka => CellStyle(
        numberFormat: NumFormat.custom(formatCode: '#,##0'),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  static CellStyle get _gayaAngkaTotal => CellStyle(
        bold: true,
        backgroundColorHex: _violetMuda,
        numberFormat: NumFormat.custom(formatCode: '#,##0'),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

  static void _isi(
    Sheet sheet,
    String sel,
    Object? nilai, {
    CellStyle? gaya,
  }) {
    final cell = sheet.cell(CellIndex.indexByString(sel));
    cell.value = switch (nilai) {
      int v => IntCellValue(v),
      double v => DoubleCellValue(v),
      String v => TextCellValue(v),
      null => null,
      _ => TextCellValue('$nilai'),
    };
    if (gaya != null) cell.cellStyle = gaya;
  }

  static void _rumus(Sheet sheet, String sel, String rumus,
      {CellStyle? gaya}) {
    final cell = sheet.cell(CellIndex.indexByString(sel));
    cell.setFormula(rumus);
    if (gaya != null) cell.cellStyle = gaya;
  }

  /// Kepala standar: judul, pembuat, tanggal, periode. Kembali ke baris
  /// pertama tabel (header kolom).
  static int _tulisKepala(
    Sheet sheet, {
    required String judul,
    required String dibuatOleh,
    required String labelPeriode,
  }) {
    final sekarang = DateTime.now();
    _isi(sheet, 'A1', judul, gaya: _gayaJudul);
    _isi(sheet, 'A2', 'Dibuat oleh: $dibuatOleh');
    _isi(sheet, 'A3', 'Tanggal: ${formatTanggalWaktu(sekarang)}');
    _isi(sheet, 'A4', 'Periode: $labelPeriode');
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 22);
    return 6; // baris header kolom
  }

  static String _namaBerkas(String jenis) =>
      DirektoriEkspor.namaBerkas(jenis, 'xlsx');

  static Future<String> _simpan(Excel excel, String namaBerkas) async {
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Gagal mengenkode berkas Excel.');
    }
    final dir = await DirektoriEkspor.direktori();
    final berkas = File('${dir.path}/$namaBerkas');
    await berkas.writeAsBytes(bytes, flush: true);
    return berkas.path;
  }

  static String _labelRentang(DateTime awal, DateTime akhir) {
    if (apakahHariYangSama(awal, akhir)) {
      return formatTanggalPendek(akhir);
    }
    return '${formatTanggalPendek(awal)} – ${formatTanggalPendek(akhir)}';
  }

  // ── Rekap penjualan ──────────────────────────────────────────────

  /// Export rekap penjualan per periode ke .xlsx. Mengembalikan path berkas.
  ///
  /// - Harian: rincian per jam pada hari ini.
  /// - Mingguan/Bulanan: rincian per hari.
  static Future<String> eksporRekapPenjualan({
    required PeriodeLaporan periode,
    required String dibuatOleh,
  }) async {
    final pesanan = await _pesananLunas(periode);
    final sekarang = DateTime.now();
    final akhir = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final awal = _awalPeriode(periode);

    // Kelompokkan: per jam (harian) atau per hari.
    final Map<String, _Kelompok> kelompok = {};
    final List<String> urutan = [];
    if (periode == PeriodeLaporan.harian) {
      for (var jam = 0; jam < 24; jam++) {
        final kunci = 'pukul ${jam.toString().padLeft(2, '0')}.00';
        kelompok[kunci] = _Kelompok();
        urutan.add(kunci);
      }
      for (final p in pesanan) {
        final kunci = 'pukul ${p.diperbaruiPada.hour.toString().padLeft(2, '0')}.00';
        kelompok[kunci]!.tambah(p.total);
      }
    } else {
      var tanggal = awal;
      while (!tanggal.isAfter(akhir)) {
        final kunci = formatTanggalPendek(tanggal);
        kelompok[kunci] = _Kelompok();
        urutan.add(kunci);
        tanggal = tanggal.add(const Duration(days: 1));
      }
      for (final p in pesanan) {
        final kunci = formatTanggalPendek(p.diperbaruiPada);
        kelompok[kunci]?.tambah(p.total);
      }
    }

    final excel = Excel.createExcel();
    final sheet = excel['Rekap Penjualan'];
    excel.delete('Sheet1');

    final barisKepala = _tulisKepala(
      sheet,
      judul: 'REKAP PENJUALAN — ${periode.label.toUpperCase()}',
      dibuatOleh: dibuatOleh,
      labelPeriode: _labelRentang(awal, akhir),
    );

    // Header kolom.
    const kolom = ['No', 'Waktu', 'Jumlah Pesanan', 'Omzet (Rp)', 'Rata-rata (Rp)'];
    for (var c = 0; c < kolom.length; c++) {
      _isi(
        sheet,
        '${String.fromCharCode(65 + c)}$barisKepala',
        kolom[c],
        gaya: _gayaKepala,
      );
    }

    // Baris data: No | Waktu | jumlah | omzet | rata-rata (=IF(...)).
    var baris = barisKepala + 1;
    final barisPertamaData = baris;
    for (var i = 0; i < urutan.length; i++) {
      final kunci = urutan[i];
      final k = kelompok[kunci]!;
      _isi(sheet, 'A$baris', i + 1, gaya: _gayaSel);
      _isi(sheet, 'B$baris', kunci, gaya: _gayaSel);
      _isi(sheet, 'C$baris', k.jumlah, gaya: _gayaAngka);
      _isi(sheet, 'D$baris', k.omzet, gaya: _gayaAngka);
      _rumus(
        sheet,
        'E$baris',
        '=IF(C$baris=0,0,D$baris/C$baris)',
        gaya: _gayaAngka,
      );
      baris++;
    }

    // Baris total — RUMUS asli, bukan nilai mati.
    final barisTotal = baris;
    _isi(sheet, 'A$barisTotal', '', gaya: _gayaTotal);
    _isi(sheet, 'B$barisTotal', 'TOTAL', gaya: _gayaTotal);
    _rumus(
      sheet,
      'C$barisTotal',
      '=SUM(C$barisPertamaData:C${barisTotal - 1})',
      gaya: _gayaAngkaTotal,
    );
    _rumus(
      sheet,
      'D$barisTotal',
      '=SUM(D$barisPertamaData:D${barisTotal - 1})',
      gaya: _gayaAngkaTotal,
    );
    _rumus(
      sheet,
      'E$barisTotal',
      '=AVERAGE(E$barisPertamaData:E${barisTotal - 1})',
      gaya: _gayaAngkaTotal,
    );

    return _simpan(excel, _namaBerkas('rekap-${periode.name}'));
  }

  // ── Menu terlaris ────────────────────────────────────────────────

  /// Export daftar menu terlaris per periode ke .xlsx. Mengembalikan path.
  static Future<String> eksporMenuTerlaris({
    required PeriodeLaporan periode,
    required String dibuatOleh,
  }) async {
    final pesanan = await _pesananLunas(periode);
    final sekarang = DateTime.now();
    final akhir = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final awal = _awalPeriode(periode);

    // Agregasi rincian: nama menu -> {terjual, omzet}.
    final Map<String, _Kelompok> agregat = {};
    for (final p in pesanan) {
      final rincian =
          await DatabaseLokal.instance.daftarRincianPesanan(p.id);
      for (final r in rincian) {
        agregat
            .putIfAbsent(r.namaSnapshot, () => _Kelompok())
            .tambah(r.subtotal, r.jumlah);
      }
    }
    final urutan = agregat.keys.toList()
      ..sort((a, b) => agregat[b]!.jumlah.compareTo(agregat[a]!.jumlah));

    final excel = Excel.createExcel();
    final sheet = excel['Menu Terlaris'];
    excel.delete('Sheet1');

    final barisKepala = _tulisKepala(
      sheet,
      judul: 'MENU TERLARIS — ${periode.label.toUpperCase()}',
      dibuatOleh: dibuatOleh,
      labelPeriode: _labelRentang(awal, akhir),
    );

    const kolom = ['No', 'Menu', 'Terjual', 'Omzet (Rp)', 'Harga Rata-rata (Rp)'];
    for (var c = 0; c < kolom.length; c++) {
      _isi(
        sheet,
        '${String.fromCharCode(65 + c)}$barisKepala',
        kolom[c],
        gaya: _gayaKepala,
      );
    }

    var baris = barisKepala + 1;
    final barisPertamaData = baris;
    for (var i = 0; i < urutan.length; i++) {
      final nama = urutan[i];
      final k = agregat[nama]!;
      _isi(sheet, 'A$baris', i + 1, gaya: _gayaSel);
      _isi(sheet, 'B$baris', nama, gaya: _gayaSel);
      _isi(sheet, 'C$baris', k.jumlah, gaya: _gayaAngka);
      _isi(sheet, 'D$baris', k.omzet, gaya: _gayaAngka);
      _rumus(
        sheet,
        'E$baris',
        '=IF(C$baris=0,0,D$baris/C$baris)',
        gaya: _gayaAngka,
      );
      baris++;
    }

    if (urutan.isEmpty) {
      _isi(sheet, 'A$baris', 'Belum ada penjualan lunas pada periode ini.',
          gaya: _gayaSel);
      baris++;
    }

    // Baris total — RUMUS asli.
    final barisTotal = baris;
    final barisTerakhirData = barisTotal - 1;
    _isi(sheet, 'A$barisTotal', '', gaya: _gayaTotal);
    _isi(sheet, 'B$barisTotal', 'TOTAL', gaya: _gayaTotal);
    if (barisTerakhirData >= barisPertamaData) {
      _rumus(
        sheet,
        'C$barisTotal',
        '=SUM(C$barisPertamaData:C$barisTerakhirData)',
        gaya: _gayaAngkaTotal,
      );
      _rumus(
        sheet,
        'D$barisTotal',
        '=SUM(D$barisPertamaData:D$barisTerakhirData)',
        gaya: _gayaAngkaTotal,
      );
    } else {
      _isi(sheet, 'C$barisTotal', 0, gaya: _gayaAngkaTotal);
      _isi(sheet, 'D$barisTotal', 0, gaya: _gayaAngkaTotal);
    }
    _isi(sheet, 'E$barisTotal', '', gaya: _gayaTotal);

    return _simpan(excel, _namaBerkas('menu-terlaris-${periode.name}'));
  }
}

/// Akumulator sederhana: jumlah item + total omzet.
class _Kelompok {
  int jumlah = 0;
  int omzet = 0;

  void tambah(int nilai, [int qty = 1]) {
    jumlah += qty;
    omzet += nilai;
  }
}

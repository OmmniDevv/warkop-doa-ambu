import '../../bersama/format/format_uang.dart';
import '../../data/model/pesanan_rincian.dart';
import '../dasbor/util_tanggal.dart';

/// Lebar kertas printer thermal mini: 32 kolom.
const _lebarNota = 32;

/// Bangun teks nota 32 kolom siap cetak ke printer thermal.
///
/// Struktur: header nama warkop rata tengah, garis '-', baris item
/// "nama xJumlah .... RpX", total/bayar/kembalian, "Terima kasih!",
/// lalu umpan baris untuk potong kertas.
String bangunTeksNota({
  required String namaWarkop,
  required String nomorNota,
  required String namaKasir,
  required List<PesananRincian> rincian,
  required int total,
  required int bayar,
  required int kembalian,
  required String metodeBayar,
  required DateTime waktu,
}) {
  final buf = StringBuffer();

  buf.writeln(_rataTengah(namaWarkop.toUpperCase()));
  buf.writeln(_rataTengah(nomorNota));
  buf.writeln(_rataTengah(formatTanggalWaktu(waktu)));
  buf.writeln('-' * _lebarNota);
  buf.writeln(_potong('Kasir: $namaKasir'));
  buf.writeln('-' * _lebarNota);

  for (final baris in rincian) {
    buf.writeln(_barisItem(baris.namaSnapshot, baris.jumlah, baris.subtotal));
  }

  buf.writeln('-' * _lebarNota);
  buf.writeln(_barisDuaKolom('TOTAL', formatRupiah(total)));
  buf.writeln(_barisDuaKolom(_labelMetode(metodeBayar), formatRupiah(bayar)));
  buf.writeln(_barisDuaKolom('KEMBALI', formatRupiah(kembalian)));
  buf.writeln('-' * _lebarNota);
  buf.writeln(_rataTengah('Terima kasih!'));
  buf.writeln(_rataTengah('Sampai jumpa kembali'));

  // Umpan baris untuk potong kertas.
  buf.write('\n\n\n');
  return buf.toString();
}

String _rataTengah(String teks) {
  final bersih = teks.trim();
  if (bersih.length >= _lebarNota) return bersih.substring(0, _lebarNota);
  final kiri = (_lebarNota - bersih.length) ~/ 2;
  return '${' ' * kiri}$bersih';
}

String _potong(String teks) =>
    teks.length <= _lebarNota ? teks : teks.substring(0, _lebarNota);

String _barisDuaKolom(String kiri, String kanan) {
  final celah = _lebarNota - kiri.length - kanan.length;
  if (celah < 1) return _potong('$kiri $kanan');
  return '$kiri${' ' * celah}$kanan';
}

String _barisItem(String nama, int jumlah, int subtotal) {
  final kiri = '$nama x$jumlah';
  final kanan = formatRupiah(subtotal);
  final titik = _lebarNota - kiri.length - kanan.length;
  if (titik >= 1) return '$kiri${'.' * titik}$kanan';

  // Nama terlalu panjang → pecah dua baris.
  final buf = StringBuffer(_potong(nama));
  final kiri2 = 'x$jumlah';
  final titik2 = _lebarNota - kiri2.length - kanan.length;
  buf.write('\n$kiri2${'.' * (titik2 < 1 ? 1 : titik2)}$kanan');
  return buf.toString();
}

String _labelMetode(String metode) =>
    metode == 'non_tunai' ? 'NON-TUNAI' : 'TUNAI';

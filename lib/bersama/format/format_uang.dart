/// Format angka rupiah Bahasa Indonesia: 15000 -> "Rp15.000".
String formatRupiah(int nominal) {
  final negatif = nominal < 0;
  var sisa = nominal.abs().toString();
  final buf = StringBuffer();
  var hitung = 0;
  for (var i = sisa.length - 1; i >= 0; i--) {
    buf.write(sisa[i]);
    hitung++;
    if (hitung == 3 && i != 0) {
      buf.write('.');
      hitung = 0;
    }
  }
  final terbalik = buf.toString().split('').reversed.join();
  return '${negatif ? '-' : ''}Rp$terbalik';
}

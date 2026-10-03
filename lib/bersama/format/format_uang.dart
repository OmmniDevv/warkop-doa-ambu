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

/// Format rupiah ringkas untuk ruang sempit (cincin, kartu statistik):
/// 1500000 -> "Rp1,5 jt", 2500 -> "Rp2,5 rb".
String formatRupiahRingkas(int nominal) {
  String ringkas(double nilai) {
    final teks = nilai.toStringAsFixed(1).replaceAll('.', ',');
    return teks.endsWith(',0') ? teks.substring(0, teks.length - 2) : teks;
  }

  final negatif = nominal < 0;
  final n = nominal.abs();
  final hasil = n >= 1000000000
      ? 'Rp${ringkas(n / 1000000000)} M'
      : n >= 1000000
          ? 'Rp${ringkas(n / 1000000)} jt'
          : n >= 1000
              ? 'Rp${ringkas(n / 1000)} rb'
              : formatRupiah(n);
  return negatif ? '-$hasil' : hasil;
}

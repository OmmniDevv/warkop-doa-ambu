import '../../data/model/pesanan.dart';

/// Hitung potongan diskon dari [bruto].
///
/// Bila [nominal] > 0, potongan = [nominal] (dibatasi maksimal [bruto]).
/// Bila tidak, potongan = [persen]% dari [bruto] ([persen] dijepit 0–100).
int hitungPotongan(int bruto, {int nominal = 0, double persen = 0}) {
  if (bruto <= 0) return 0;
  if (nominal > 0) return nominal.clamp(0, bruto);
  final persenAman = persen.clamp(0, 100);
  if (persenAman <= 0) return 0;
  return (bruto * persenAman / 100).round();
}

/// Total tagihan [pesanan] setelah diskon nota diterapkan.
int totalBersihNota(Pesanan pesanan) {
  return pesanan.total -
      hitungPotongan(
        pesanan.total,
        nominal: pesanan.diskonNotaNominal,
        persen: pesanan.diskonNotaPersen,
      );
}

/// True bila ada diskon nota yang aktif pada [pesanan].
bool adaDiskonNota(Pesanan pesanan) {
  return pesanan.diskonNotaNominal > 0 || pesanan.diskonNotaPersen > 0;
}

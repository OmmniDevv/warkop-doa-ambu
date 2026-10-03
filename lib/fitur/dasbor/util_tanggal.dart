import '../../bersama/util/waktu_wib.dart';

/// Format tanggal Bahasa Indonesia manual — tanpa package intl.
///
/// Contoh: "4 Okt 2026".
///
/// PENTING: semua format memakai Asia/Jakarta (WIB) eksplisit,
/// bukan zona waktu perangkat. Data disimpan UTC di DB.
const _namaBulanPendek = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const _namaHari = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// "4 Okt 2026" — dalam WIB.
String formatTanggalPendek(DateTime waktu) {
  final wib = keWib(waktu);
  return '${wib.day} ${_namaBulanPendek[wib.month - 1]} ${wib.year}';
}

/// "4 Okt 2026 14:05 WIB" — dalam WIB dengan label zona yang jelas.
String formatTanggalWaktu(DateTime waktu) {
  final wib = keWib(waktu);
  final jam = wib.hour.toString().padLeft(2, '0');
  final menit = wib.minute.toString().padLeft(2, '0');
  return '${formatTanggalPendek(waktu)} $jam:$menit WIB';
}

/// "Senin, 4 Okt 2026" — dalam WIB.
String formatHariTanggal(DateTime waktu) {
  final wib = keWib(waktu);
  return '${_namaHari[wib.weekday - 1]}, ${formatTanggalPendek(waktu)}';
}

/// "Sen" — nama hari pendek dalam WIB, untuk label grafik.
String namaHariPendek(DateTime waktu) {
  return _namaHari[keWib(waktu).weekday - 1].substring(0, 3);
}

/// true jika [waktu] jatuh pada hari kalender WIB yang sama dengan [acuan].
bool apakahHariYangSama(DateTime waktu, DateTime acuan) {
  return apakahHariYangSamaWib(waktu, acuan);
}

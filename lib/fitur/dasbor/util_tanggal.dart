/// Format tanggal Bahasa Indonesia manual — tanpa package intl.
///
/// Contoh: "4 Okt 2026".
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

/// "4 Okt 2026" — memakai waktu lokal perangkat.
String formatTanggalPendek(DateTime waktu) {
  final lokal = waktu.toLocal();
  return '${lokal.day} ${_namaBulanPendek[lokal.month - 1]} ${lokal.year}';
}

/// "4 Okt 2026 14:05" — memakai waktu lokal perangkat.
String formatTanggalWaktu(DateTime waktu) {
  final lokal = waktu.toLocal();
  final jam = lokal.hour.toString().padLeft(2, '0');
  final menit = lokal.minute.toString().padLeft(2, '0');
  return '${formatTanggalPendek(waktu)} $jam:$menit';
}

/// true jika [waktu] jatuh pada hari kalender yang sama dengan [acuan].
bool apakahHariYangSama(DateTime waktu, DateTime acuan) {
  final a = waktu.toLocal();
  final b = acuan.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

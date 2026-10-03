import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Helper zona waktu Asia/Jakarta (WIB, UTC+7, tanpa DST).
///
/// Semua tanggal/jam yang DITAMPILKAN ke user HARUS lewat helper ini.
/// Data di SQLite/Supabase disimpan sebagai UTC; konversi ke WIB hanya
/// saat tampil/hitung batas hari — jangan ubah cara penyimpanan.
///
/// Aturan: "hari ini" = 00:00–24:00 WIB, bukan UTC. Kalau pakai UTC,
/// hari kepotong jam 07:00 pagi dan laporan jadi salah.

/// Wajib dipanggil sekali di main() sebelum runApp.
/// Juga dipanggil otomatis (lazy) pada akses pertama bila lupa.
void inisialisasiZonaWaktu() {
  tzdata.initializeTimeZones();
  _sudahInit = true;
}

var _sudahInit = false;

void _pastikanInit() {
  if (!_sudahInit) {
    inisialisasiZonaWaktu();
  }
}

tz.Location get _jakarta {
  _pastikanInit();
  return tz.getLocation('Asia/Jakarta');
}

/// Konversi DateTime apapun (UTC/lokal) ke waktu WIB.
DateTime keWib(DateTime waktu) => tz.TZDateTime.from(waktu, _jakarta);

/// Waktu "sekarang" dalam WIB.
DateTime sekarangWib() => tz.TZDateTime.now(_jakarta);

/// Awal hari (00:00 WIB) dari [waktu].
DateTime awalHariWib(DateTime waktu) {
  final wib = keWib(waktu);
  return tz.TZDateTime(_jakarta, wib.year, wib.month, wib.day);
}

/// Awal minggu (Senin 00:00 WIB) dari [waktu].
DateTime awalMingguWib(DateTime waktu) {
  final awalHari = awalHariWib(waktu);
  return awalHari.subtract(Duration(days: awalHari.weekday - 1));
}

/// Awal bulan (tanggal 1, 00:00 WIB) dari [waktu].
DateTime awalBulanWib(DateTime waktu) {
  final wib = keWib(waktu);
  return tz.TZDateTime(_jakarta, wib.year, wib.month);
}

/// true jika [waktu] jatuh pada hari kalender WIB yang sama dengan [acuan].
bool apakahHariYangSamaWib(DateTime waktu, DateTime acuan) {
  final a = keWib(waktu);
  final b = keWib(acuan);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Jam (0–23) dalam WIB — untuk grafik jam sibuk.
int jamWib(DateTime waktu) => keWib(waktu).hour;

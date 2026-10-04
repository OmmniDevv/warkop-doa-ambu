import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status satu izin untuk ditampilkan di layar penjelasan.
class StatusIzin {
  const StatusIzin({
    required this.nama,
    required this.penjelasan,
    required this.ikon,
    required this.izin,
    this.diberikan = false,
  });

  final String nama;
  final String penjelasan;

  /// Nama ikon material (dipetakan di UI).
  final String ikon;
  final Permission izin;
  final bool diberikan;

  StatusIzin salin({bool? diberikan}) => StatusIzin(
        nama: nama,
        penjelasan: penjelasan,
        ikon: ikon,
        izin: izin,
        diberikan: diberikan ?? this.diberikan,
      );
}

/// Layanan izin aplikasi: kamera, notifikasi, penyimpanan, bluetooth printer.
///
/// Kamera/notifikasi/penyimpanan diminta SEKALI di awal setelah login
/// (layar penjelasan izin). Bluetooth printer diminta TERPISAH via
/// [mintaIzinBluetooth] tepat sebelum pindai printer, agar user yang
/// tidak pakai printer tidak diganggu dialog izin.
/// Status "sudah pernah diminta" disimpan agar tidak mengganggu
/// berulang-ulang. Bila ditolak permanen, user diarahkan ke Pengaturan.
class LayananIzin {
  LayananIzin._();

  static const _kunciSudahDiminta = 'wda_izin_sudah_diminta';

  /// Daftar izin yang diminta di awal, beserta penjelasannya.
  static List<StatusIzin> daftarIzin() {
    final daftar = <StatusIzin>[
      StatusIzin(
        nama: 'Notifikasi',
        penjelasan:
            'Memberi tahu saat stok bahan menipis, jadi tidak kehabisan mendadak.',
        ikon: 'notifikasi',
        izin: Permission.notification,
      ),
      StatusIzin(
        nama: 'Kamera',
        penjelasan:
            'Untuk foto bukti pembayaran dan foto menu langsung dari aplikasi.',
        ikon: 'kamera',
        izin: Permission.camera,
      ),
    ];
    // Izin penyimpanan hanya relevan di Android (iOS pakai sandbox).
    if (Platform.isAndroid) {
      daftar.add(
        StatusIzin(
          nama: 'Penyimpanan',
          penjelasan:
              'Menyimpan laporan PDF/Excel ke folder Documents agar mudah ditemukan.',
          ikon: 'penyimpanan',
          izin: Permission.storage,
        ),
      );
    }
    return daftar;
  }

  /// True bila layar izin awal sudah pernah ditampilkan.
  static Future<bool> sudahDiminta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kunciSudahDiminta) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Tandai layar izin awal sudah ditampilkan.
  static Future<void> tandaiSudahDiminta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kunciSudahDiminta, true);
    } catch (_) {}
  }

  /// Minta satu [izin]. Mengembalikan true bila diberikan.
  ///
  /// Tidak mengulang bila sudah ditolak permanen — panggil
  /// [bukaPengaturan] untuk mengarahkan user.
  static Future<bool> minta(Permission izin) async {
    final status = await izin.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;
    final hasil = await izin.request();
    return hasil.isGranted || hasil.isLimited;
  }

  /// Minta izin Bluetooth untuk printer thermal.
  ///
  /// Dipanggil TEPAT SEBELUM pindai printer (di layar printer), BUKAN di
  /// layar izin awal — user yang tidak pakai printer tidak diganggu.
  ///
  /// Android ≤11: BLUETOOTH + BLUETOOTH_ADMIN (install-time).
  /// Android 12+: BLUETOOTH_SCAN (pindai perangkat) dan BLUETOOTH_CONNECT
  /// (sambung & kirim data cetak) adalah runtime permission, wajib diminta.
  /// Mengembalikan true bila semua izin yang relevan diberikan.
  static Future<bool> mintaIzinBluetooth() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    var ok = true;
    for (final izin in const [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]) {
      ok = await minta(izin) && ok;
    }
    return ok;
  }

  /// True bila [izin] ditolak permanen (harus via Pengaturan).
  static Future<bool> ditolakPermanen(Permission izin) async {
    return (await izin.status).isPermanentlyDenied;
  }

  /// Buka halaman pengaturan aplikasi di HP.
  static Future<void> bukaPengaturan() async {
    await openAppSettings();
  }

  /// Path tujuan setelah login: ke layar izin dulu bila belum pernah
  /// ditampilkan, langsung ke [tujuan] bila sudah.
  static Future<String> tujuanSetelahMasuk(String tujuan) async {
    if (await sudahDiminta()) return tujuan;
    return '/izin-awal?lanjut=${Uri.encodeComponent(tujuan)}';
  }
}

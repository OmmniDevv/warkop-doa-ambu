import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper direktori export: semua berkas PDF & Excel disimpan ke folder
/// pilihan user (default: `/storage/emulated/0/Documents/WarkopDoaAmbu/`)
/// agar mudah ditemukan. Bila gagal (izin ditolak / Android 11+ scoped
/// storage), fallback ke direktori dokumen aplikasi.
class DirektoriEkspor {
  DirektoriEkspor._();

  static const _namaFolder = 'WarkopDoaAmbu';

  /// Kunci folder kustom di SharedPreferences (dipilih via Pengaturan).
  static const kunciFolderKustom = 'wda_folder_ekspor_kustom';

  /// Minta izin penyimpanan bila diperlukan (Android saja).
  /// Mengembalikan true bila boleh menulis ke penyimpanan publik.
  static Future<bool> mintaIzin() async {
    if (!Platform.isAndroid) return true;
    // Android 10 ke bawah: WRITE_EXTERNAL_STORAGE cukup.
    // Android 11+: coba storage biasa dulu; bila gagal tulis,
    // _direktoriPublik akan fallback otomatis.
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return true;
    final hasil = await Permission.storage.request();
    return hasil.isGranted || hasil.isLimited;
  }

  /// Direktori export: folder kustom (bila dipilih) → `Documents/WarkopDoaAmbu`
  /// (publik) → fallback direktori dokumen aplikasi.
  static Future<Directory> direktori() async {
    final kustom = await folderKustom();
    if (kustom != null) {
      final folder = Directory(kustom);
      try {
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        return folder;
      } catch (_) {
        // Folder kustom tidak bisa dipakai — lanjut ke default.
      }
    }
    final publik = await _direktoriPublik();
    if (publik != null) return publik;
    final app = await getApplicationDocumentsDirectory();
    final folder = Directory('${app.path}/$_namaFolder');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Path folder kustom pilihan user, atau null bila belum memilih.
  static Future<String?> folderKustom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(kunciFolderKustom);
    } catch (_) {
      return null;
    }
  }

  /// Simpan pilihan folder kustom. Null = kembali ke default.
  static Future<void> simpanFolderKustom(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(kunciFolderKustom);
    } else {
      await prefs.setString(kunciFolderKustom, path);
    }
  }

  /// Label folder yang sedang dipakai (untuk ditampilkan di Pengaturan).
  static Future<String> labelFolderAktif() async {
    final folder = await direktori();
    return folder.path;
  }

  /// Coba buka/buat folder publik. Null bila tidak bisa (fallback).
  static Future<Directory?> _direktoriPublik() async {
    try {
      if (!Platform.isAndroid) return null;
      const akar = '/storage/emulated/0/Documents';
      final folder = Directory('$akar/$_namaFolder');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      // Uji tulis: pastikan benar-benar bisa ditulis.
      final uji = File(
          '${folder.path}/.uji_tulis_${DateTime.now().millisecondsSinceEpoch}');
      await uji.writeAsString('ok', flush: true);
      await uji.delete();
      return folder;
    } catch (_) {
      return null;
    }
  }

  /// Nama berkas export: `laporan_<jenis>_yyyy-mm-dd_hhmm.<ekstensi>`.
  /// Contoh: `laporan_rekap-harian_2026-10-04_0355.pdf`.
  static String namaBerkas(String jenis, String ekstensi) {
    final s = DateTime.now();
    final tgl = '${s.year}'
        '-${s.month.toString().padLeft(2, '0')}'
        '-${s.day.toString().padLeft(2, '0')}'
        '_${s.hour.toString().padLeft(2, '0')}'
        '${s.minute.toString().padLeft(2, '0')}';
    final jenisAman = jenis.replaceAll(' ', '-');
    return 'laporan_${jenisAman}_$tgl.$ekstensi';
  }

  /// Label lokasi yang ramah dibaca user untuk snackbar.
  static String labelLokasi(String path) {
    if (path.contains('/Documents/WarkopDoaAmbu/')) {
      return 'Documents/WarkopDoaAmbu/${path.split('/').last}';
    }
    return path;
  }
}

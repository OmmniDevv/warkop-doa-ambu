import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bersama/util/waktu_wib.dart';
import '../../data/lokal/database_lokal.dart';

/// Layanan notifikasi lokal untuk peringatan stok bahan menipis.
///
/// Aturan:
/// - Dicek tiap sinkronisasi + saat aplikasi dibuka.
/// - Satu bahan = satu notifikasi per hari (tidak spam).
/// - Pesan: "Stok [nama] menipis! Sisa [jumlah] [satuan]".
class LayananNotifikasi {
  LayananNotifikasi._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _siap = false;

  /// Kunci timestamp notifikasi terakhir per bahan: `wda_notif_bahan_<id>`.
  static String _kunciNotifikasi(String idBahan) => 'wda_notif_bahan_$idBahan';

  /// Inisialisasi plugin + minta izin notifikasi (Android 13+).
  /// Aman dipanggil berulang; tidak pernah throw.
  static Future<void> inisialisasi() async {
    if (_siap) return;
    try {
      const pengaturanAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const pengaturan = InitializationSettings(
        android: pengaturanAndroid,
      );
      await _plugin.initialize(pengaturan);
      // Android 13+: minta izin runtime.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _siap = true;
    } catch (e) {
      debugPrint('[Notifikasi] inisialisasi gagal: $e');
    }
  }

  /// Cek bahan menipis dan kirim notifikasi (maks 1x per bahan per hari).
  ///
  /// Dipanggil setelah sinkronisasi dan saat aplikasi dibuka.
  /// Tidak pernah throw.
  static Future<void> cekBahanMenipis() async {
    try {
      await inisialisasi();
      if (!_siap) return;

      final daftar = await DatabaseLokal.instance.daftarBahanMenipis();
      if (daftar.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final hariIni = awalHariWib(sekarangWib());

      for (final bahan in daftar) {
        // Sudah dinotifikasi hari ini? Lewati.
        final terakhirIso = prefs.getString(_kunciNotifikasi(bahan.id));
        if (terakhirIso != null) {
          try {
            final terakhir = DateTime.parse(terakhirIso);
            if (!terakhir.isBefore(hariIni)) continue;
          } catch (_) {
            // Format rusak — anggap belum dinotifikasi.
          }
        }

        // Format stok: hilangkan .0 bila bulat.
        final stokTampil = bahan.stok == bahan.stok.roundToDouble()
            ? '${bahan.stok.toInt()}'
            : '${bahan.stok}';
        await _tampilkan(
          id: bahan.id.hashCode,
          judul: 'Stok bahan menipis!',
          isi: 'Stok ${bahan.nama} menipis! '
              'Sisa $stokTampil ${bahan.satuan}. '
              'Jangan lupa belanja ya.',
        );
        await prefs.setString(
          _kunciNotifikasi(bahan.id),
          DateTime.now().toUtc().toIso8601String(),
        );
        debugPrint('[Notifikasi] bahan menipis: ${bahan.nama}');
      }
    } catch (e) {
      debugPrint('[Notifikasi] cek gagal: $e');
    }
  }

  static Future<void> _tampilkan({
    required int id,
    required String judul,
    required String isi,
  }) async {
    const detailAndroid = AndroidNotificationDetails(
      'wda_bahan_menipis',
      'Peringatan Stok Bahan',
      channelDescription: 'Notifikasi saat stok bahan mencapai batas minimum',
      importance: Importance.high,
      priority: Priority.high,
    );
    const detail = NotificationDetails(android: detailAndroid);
    await _plugin.show(id, judul, isi, detail);
  }
}

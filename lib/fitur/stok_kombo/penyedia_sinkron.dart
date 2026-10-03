import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesin_sinkron.dart';

/// Mesin sinkron upload-only, dipakai koordinator pemicu berkala.
final penyediaMesinSinkron = Provider<MesinSinkron>((ref) => MesinSinkron());

/// Status sinkron terakhir yang tampil di UI:
/// 'Siap' | 'Menyinkron...' | 'Tersinkron' | 'Sebagian gagal' | 'Offline'.
/// Koordinator mengubahnya lewat `ref.read(penyediaStatusSinkron.notifier)`.
final penyediaStatusSinkron =
    NotifierProvider<NotifikasiStatusSinkron, String>(
  NotifikasiStatusSinkron.new,
);

class NotifikasiStatusSinkron extends Notifier<String> {
  @override
  String build() => 'Siap';

  void ubah(String status) => state = status;
}

/// Pemicu sinkronisasi otomatis: jalan 15 detik setelah aplikasi dibuka,
/// lalu berulang tiap 2 menit. Tonton (watch) provider ini sekali dari
/// root aplikasi agar timer hidup selama aplikasi berjalan.
final pemicuSinkronOtomatis = Provider<void>((ref) {
  // Jangan hidupkan timer saat widget test (menghindari pumpAndSettle
  // menunggu timer periodik selamanya).
  if (const bool.fromEnvironment('FLUTTER_TEST')) return;

  Future<void> jalankan() async {
    final notifikasi = ref.read(penyediaStatusSinkron.notifier);
    notifikasi.ubah('Menyinkronkan...');
    final hasil = await ref.read(penyediaMesinSinkron).sinkronkan();
    if (hasil.berhasil == 0 && hasil.gagal == 0) {
      notifikasi.ubah('Tersinkron');
    } else if (hasil.gagal == 0) {
      notifikasi.ubah('Tersinkron');
    } else if (hasil.berhasil == 0) {
      notifikasi.ubah('Offline');
    } else {
      notifikasi.ubah('Sebagian gagal');
    }
  }

  // Jalankan sekali tak lama setelah start (beri waktu UI tampil dulu).
  final tunda = Timer(const Duration(seconds: 15), jalankan);
  final berkala = Timer.periodic(const Duration(minutes: 2), (_) => jalankan());
  ref.onDispose(() {
    tunda.cancel();
    berkala.cancel();
  });
});

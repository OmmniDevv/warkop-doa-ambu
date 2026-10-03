import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/lokal/database_lokal.dart';
import '../data/model/pemilik.dart';
import '../fitur/auth_owner/service_auth_owner.dart';
import 'router.dart';

/// Service auth owner — satu instance per aplikasi.
final penyediaServiceAuthOwner = Provider<ServiceAuthOwner>(
  (ref) => ServiceAuthOwner(),
);

/// Database lokal — satu instance per aplikasi.
final penyediaDatabaseLokal = Provider<DatabaseLokal>(
  (ref) => DatabaseLokal.instance,
);

/// Profil pemilik yang tersimpan di perangkat (null = belum daftar/masuk).
final penyediaProfilPemilik = FutureProvider<Pemilik?>((ref) async {
  return ref.watch(penyediaDatabaseLokal).ambilPemilik();
});

/// Mode tema: false = terang (Vintage Parchment), true = gelap (Espresso).
///
/// Disimpan persisten via SharedPreferences.
final penyediaModeGelap =
    NotifierProvider<NotifikasiModeGelap, bool>(NotifikasiModeGelap.new);

class NotifikasiModeGelap extends Notifier<bool> {
  static const _kunci = 'wda_mode_gelap';

  @override
  bool build() {
    _muat();
    return false;
  }

  Future<void> _muat() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kunci) ?? false;
  }

  Future<void> alihkan() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kunci, state);
  }
}

/// Router aplikasi — SATU instance untuk seluruh umur aplikasi.
///
/// PENTING: Jangan panggil [bangunRouter] di dalam build()! Membuat GoRouter
/// baru setiap rebuild (mis. saat ganti tema) akan me-reset seluruh state
/// navigasi dan melempar user ke layar awal — terlihat seperti "logout".
final penyediaRouter = Provider<GoRouter>((ref) => bangunRouter());

/// Memaksa [penyediaProfilPemilik] dibaca ulang (mis. setelah PIN disimpan).
void segarkanProfil(WidgetRef ref) {
  ref.invalidate(penyediaProfilPemilik);
}

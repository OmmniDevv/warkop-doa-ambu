import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/akun.dart';
import '../../data/model/shift_kasir.dart';

/// Akun kasir yang sedang masuk (null = belum masuk).
///
/// Nama FINAL — dipakai lintas fase. Diimplementasikan dengan
/// [NotifierProvider] karena `StateProvider` tidak tersedia di
/// Riverpod 3; API-nya tetap sama: baca lewat `ref.watch(...)`,
/// tulis lewat `ref.read(sesiKasirProvider.notifier).state = ...`.
final sesiKasirProvider =
    NotifierProvider<PenampungSesiKasir, Akun?>(PenampungSesiKasir.new);

/// Shift kasir yang sedang dibuka (null = belum buka shift).
///
/// Nama FINAL — dipakai lintas fase (lihat [sesiKasirProvider]).
final shiftAktifProvider =
    NotifierProvider<PenampungShiftAktif, ShiftKasir?>(
        PenampungShiftAktif.new);

/// Penampung nilai sesi kasir — setara StateProvider di Riverpod 3.
class PenampungSesiKasir extends Notifier<Akun?> {
  @override
  Akun? build() => null;

  /// Mengganti sesi kasir (null = keluar).
  void ganti(Akun? akun) => state = akun;
}

/// Penampung nilai shift aktif — setara StateProvider di Riverpod 3.
class PenampungShiftAktif extends Notifier<ShiftKasir?> {
  @override
  ShiftKasir? build() => null;

  /// Mengganti shift aktif (null = tidak ada shift dibuka).
  void ganti(ShiftKasir? shift) => state = shift;
}

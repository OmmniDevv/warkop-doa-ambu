import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Membuat hash SHA-256 dari PIN kasir dengan salt berbasis ID akun.
///
/// Dipakai saat owner membuat/mereset PIN kasir. Nama fungsi FINAL —
/// dipakai lintas fase (lihat Fase 8).
String buatHashPinKasir({
  required String idAkun,
  required String pin,
}) {
  final bahan = utf8.encode('wda::doa-ambu::pin-kasir::$idAkun::$pin');
  return sha256.convert(bahan).toString();
}

/// Mengecek PIN kasir terhadap [hashTersimpan] dengan perbandingan
/// waktu-konstan agar tahan timing attack.
bool cocokHashPinKasir({
  required String pin,
  required String idAkun,
  required String hashTersimpan,
}) {
  if (hashTersimpan.isEmpty) return false;
  final hitung = buatHashPinKasir(idAkun: idAkun, pin: pin);
  if (hitung.length != hashTersimpan.length) return false;
  var beda = 0;
  for (var i = 0; i < hitung.length; i++) {
    beda |= hitung.codeUnitAt(i) ^ hashTersimpan.codeUnitAt(i);
  }
  return beda == 0;
}

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Kompresi JPG foto menu: sisi terpanjang <= 1280 px, quality menurun
/// 85 → 60 → 40 sampai ukuran 100–180 KB.
///
/// [awalanNama] dipakai untuk nama berkas, mis. "menu". Mengembalikan path
/// lokal berkas hasil kompresi di folder dokumen aplikasi.
Future<String> kompresFotoMenu(String pathMentah, String awalanNama) async {
  final mentah = await File(pathMentah).readAsBytes();
  final gambar = img.decodeImage(mentah);
  if (gambar == null) {
    throw const FormatException('Berkas foto tidak terbaca.');
  }

  img.Image olahan = gambar;
  final sisiTerpanjang =
      gambar.width > gambar.height ? gambar.width : gambar.height;
  if (sisiTerpanjang > 1280) {
    final skala = 1280 / sisiTerpanjang;
    olahan = img.copyResize(
      gambar,
      width: (gambar.width * skala).round(),
      height: (gambar.height * skala).round(),
    );
  }

  var terkompresi = img.encodeJpg(olahan, quality: 85);
  for (final quality in const [60, 40]) {
    if (terkompresi.length <= 180 * 1024) break;
    terkompresi = img.encodeJpg(olahan, quality: quality);
  }

  final dokumen = await getApplicationDocumentsDirectory();
  final folder = Directory('${dokumen.path}/foto-menu');
  await folder.create(recursive: true);
  final tujuan = File(
    '${folder.path}/${awalanNama}_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await tujuan.writeAsBytes(terkompresi);
  return tujuan.path;
}

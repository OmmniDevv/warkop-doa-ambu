import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/menu.dart';

/// Daftar kategori aktif, urut tampilan.
///
/// Dipakai bersama oleh [LayarKategori] dan [LayarMenu] agar satu sumber.
final penyediaDaftarKategori = FutureProvider<List<KategoriMenu>>((ref) async {
  return DatabaseLokal.instance.daftarKategori();
});

/// Seluruh menu; filter kategori & pencarian dilakukan di UI
/// agar invalidasi sederhana.
final penyediaSemuaMenu = FutureProvider<List<Menu>>((ref) async {
  return DatabaseLokal.instance.daftarMenu();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/menu.dart';

/// Provider stok bersama — dipakai LayarStok & LayarStokOpname agar
/// invalidasi stok konsisten setelah opname.
///
/// (Provider bahan: `penyediaDaftarBahan` di `layar_bahan.dart`.)

/// Daftar kategori menu untuk pengelompokan stok.
final penyediaKategoriStokBersama = FutureProvider<List<KategoriMenu>>(
  (ref) => DatabaseLokal.instance.daftarKategori(),
);

/// Daftar seluruh menu untuk layar stok/opname.
final penyediaMenuStokBersama = FutureProvider<List<Menu>>(
  (ref) => DatabaseLokal.instance.daftarMenu(),
);

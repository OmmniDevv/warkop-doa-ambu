import '../../bersama/util/id_unik.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/pesanan.dart';

/// Validasi apakah [pesanan] boleh di-void.
///
/// Mengembalikan `null` bila boleh, atau pesan kesalahan bila tidak.
/// - `null` pesanan → "tidak ditemukan".
/// - status sudah 'void' → ditolak (BUG-05: cegah void ganda + audit ganda).
String? validasiBolehVoid(Pesanan? pesanan) {
  if (pesanan == null) {
    return 'Pesanan tidak ditemukan. Mungkin sudah dihapus.';
  }
  if (pesanan.status == 'void') {
    return 'Pesanan sudah di-void.';
  }
  return null;
}

/// Jalankan void pesanan: validasi → ubah status → kembalikan stok → audit.
///
/// Mengembalikan `null` bila sukses, atau pesan kesalahan bila gagal.
/// Stok menu + bahan resep dikembalikan (BUG-02) karena pembayaran sudah
/// menguranginya saat lunas.
Future<String?> jalankanVoid(
  DatabaseLokal db, {
  required String idPesanan,
  required String alasan,
  String? idAkun,
}) async {
  final pesanan = await db.ambilPesanan(idPesanan);
  final galat = validasiBolehVoid(pesanan);
  if (galat != null) return galat;

  await db.perbaruiPesanan(
    pesanan!.copyWith(
      status: 'void',
      voidAlasan: alasan,
      voidDisetujuiOwner: true,
    ),
  );

  // Kembalikan stok tiap rincian (BUG-02).
  final rincian = await db.daftarRincianPesanan(idPesanan);
  for (final baris in rincian) {
    final idMenu = baris.idMenu;
    if (idMenu == null) continue;
    await db.tambahStok(idMenu, baris.jumlah);
    await db.tambahStokBahanResep(idMenu, baris.jumlah);
  }

  await db.catatAudit(
    LogAudit(
      id: idBaru(),
      aksi: 'void_pesanan',
      idAkun: idAkun,
      idReferensi: idPesanan,
      alasan: alasan,
      dibuatPada: DateTime.now(),
    ),
  );

  return null;
}

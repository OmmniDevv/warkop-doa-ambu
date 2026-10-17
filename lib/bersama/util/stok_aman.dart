/// Pembungkus aman untuk operasi pengurangan stok (BUG-03).
///
/// Mengembalikan `null` bila [operasi] berhasil, atau [namaItem] bila
/// [operasi] melempar. Tidak pernah melempar sendiri — pembayaran harus
/// tetap jalan walau stok gagal dikurangi; kegagalan dicatat ke log audit
/// dan ditampilkan sebagai peringatan di dialog sukses.
Future<String?> kurangiStokAman(
  String namaItem,
  Future<void> Function() operasi,
) async {
  try {
    await operasi();
    return null;
  } catch (_) {
    return namaItem;
  }
}

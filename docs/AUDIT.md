# AUDIT — Warkop Doa Ambu

**Tanggal:** 17 Oktober 2026 · **Cabang:** `redesign-ryux` · **Oleh:** Kana (dengan skill RYUX, entry point Analyze)
**Aturan:** audit ini read-only terhadap perilaku — tidak ada kode yang diubah.
**Status akhir redesign (17 Okt, malam):** SEMUA 7 BUG SUDAH DIPERBAIKI (lihat §9).
`flutter analyze`: bersih, 0 masalah. `flutter test`: **62/62 lolos**.

---

## 1. Ringkasan eksekutif

- `flutter analyze`: **bersih, 0 masalah.**
- `flutter test`: **28/28 lolos.**
- `flutter_ui_audit.py`: **28 kritis**, 88 peringatan, 29 info.
- Ditemukan **4 bug logika** yang bisa bikin uang/stok salah (prioritas 1), 3 bug
  integritas data (prioritas 2), dan **5 ketidakcocokan dokumen vs kode**.
- Uang (total, bayar, kembalian, harga) sudah integer di semua model — aman.
  Yang bertipe `double` hanya persen diskon (dibulatkan saat hitung),
  stok bahan (bisa pecahan, wajar), dan takaran resep (wajar).

---

## 2. Bug prioritas 1 — uang / stok bisa salah

### BUG-01: Diskon hilang diam-diam saat ubah jumlah / catatan
**File:** `lib/fitur/pos/model_keranjang.dart` — `BarisKeranjang.salin()`
**Bukti:** `salin()` menyalin `idBaris, idMenu, idPaket, nama, hargaSatuan,
jumlah, catatan` — TETAPI tidak menyalin `diskonNominal` dan `diskonPersen`.
**Dampak:** `ubahJumlah()` dan `ubahCatatan()` memakai `salin()`, sehingga
setiap kali kasir mengubah jumlah atau catatan SETELAH memberi diskon,
diskonnya hilang tanpa peringatan → pelanggan bayar lebih mahal.
Hanya `ubahDiskonItem()` yang aman (karena mengisi ulang setelah `salin()`).
**Tingkat:** KRITIS (uang).

### BUG-02: Void tidak mengembalikan stok
**File:** `lib/fitur/void_kasbon/dialog_void.dart` — `_prosesVoid()`
**Bukti:** void hanya `copyWith(status: 'void', ...)` + catat audit.
Tidak ada pemanggilan `tambahStok` / pengembalian stok menu maupun bahan resep,
padahal `_selesaikan()` di `layar_bayar.dart` sudah mengurangi stok saat lunas.
**Dampak:** setiap void membuat stok berkurang permanen tanpa ada penjualan.
**Tingkat:** KRITIS (stok).

### BUG-03: Kegagalan kurangi stok diabaikan diam-diam
**File:** `lib/fitur/bayar/layar_bayar.dart` — `_selesaikan()` (~baris 290-310)
**Bukti:** `db.kurangiStok()` dan `db.kurangiStokBahanResep()` dibungkus
`try { } catch (_) { // Abaikan }` dengan komentar "stok bisa dikoreksi manual".
**Dampak:** pembayaran sukses tercatat, tapi stok tidak berkurang (atau hanya
sebagian) — selisih stok vs penjualan tidak terlacak.
**Tingkat:** TINGGI (stok).

### BUG-04: `hapusRincian()` hard-delete baris yang sudah tersinkron
**File:** `lib/data/lokal/database_lokal.dart:966`
**Bukti:** `DELETE FROM pesanan_rincian WHERE id = ?` — hapus permanen lokal,
tanpa menandai `apakah_dihapus`. Dipakai di `layar_detail_tagihan.dart`
(baris 197, 809) saat split bill.
**Dampak:** bila baris sudah `tersinkron`, server tetap menyimpan barisnya
(tidak ada tombstone yang di-upload) → divergensi lokal vs server; unduhan
berikutnya bisa memunculkan kembali baris yang sudah dihapus.
**Tingkat:** TINGGI (integritas sinkron). Catatan: ini risiko yang sama dengan
yang tercatat di memori sebagai "belum terbukti aman".

---

## 3. Bug prioritas 2 — integritas & ketahanan

### BUG-05: Void ganda tidak dicegah
**File:** `lib/fitur/void_kasbon/dialog_void.dart`
**Bukti:** `_prosesVoid()` tidak mengecek `pesanan.status == 'void'` sebelum
memproses. Pesanan yang sudah void bisa di-void lagi → duplikat log audit.
**Tingkat:** SEDANG.

### BUG-06: Guard double-tap pembayaran rapuh secara struktur
**File:** `lib/fitur/bayar/layar_bayar.dart` — `_selesaikan()`
**Bukti:** flag `_memproses` dicek di awal dan di-set sebelum `await` pertama,
sehingga dalam event loop Dart saat ini aman. Namun validasi (total, foto,
nominal) terjadi SEBELUM flag di-set; bila validasi gagal, flag tidak pernah
di-set — tidak masalah. Risiko sisa: bila di masa depan ada `await` yang
disisipkan antara cek dan set, guard jebol. Direkomendasikan memindahkan
`setState(() => _memproses = true)` ke baris pertama setelah cek.
**Tingkat:** RENDAH (saat ini aman, tapi rapuh).

### BUG-07: Upload bukti foto gagal diam-diam
**File:** `lib/fitur/bayar/layar_bayar.dart` — `unawaited(_unggahBukti(...))`
**Bukti:** upload berjalan di latar tanpa penanda status di UI. Perlu verifikasi
apakah kegagalan tercatat sebagai `status_sinkron='gagal'` atau hilang begitu saja.
**Tingkat:** SEDANG (belum dikonfirmasi — ditandai "unconfirmed").

---

## 4. Temuan audit UI otomatis (`flutter_ui_audit.py`)

- **28 KRITIS:**
  - `RIVERPOD_NO_ERROR_HANDLER` (24 lokasi): `AsyncValue.when()` tanpa handler
    `error:` — layar akan crash/blank saat provider gagal. Tersebar di:
    kasir (statistik), stok_kombo (resep, riwayat opname), tagihan (daftar,
    detail), dasbor (laporan, akun kasir, audit, kategori, menu).
  - `PERF_LIST_VIEW_CHILDREN` (4 lokasi): `ListView(children:)` me-render semua
    item sekaligus — kas_keluar, kasbon, daftar tagihan (2x), menu dasbor.
    Ganti ke `ListView.builder`.
- **88 peringatan** — mayoritas `PERF_HARDCODED_FONT_SIZE` dan nilai literal
  (warna/spasi) di luar token tema; detail lengkap via `--all`.
- **29 info** — tidak menghalangi.

---

## 5. Ketidakcocokan dokumen vs kode (dicatat, tidak diubah)

| # | Dokumen bilang | Kode sebenarnya | Yang benar |
|---|---|---|---|
| D-01 | PRD §5: deteksi jaringan via `connectivity_plus`, network listener | Tidak ada `connectivity_plus` di `pubspec.yaml`; sinkron jalan via `Timer.periodic(2 menit)` di `penyedia_sinkron.dart:54` | **Kode** (timer 2 menit, tanpa listener jaringan) |
| D-02 | PRD §8 & README: cetak via paket `print_bluetooth_thermal` | `pubspec.yaml` memakai `flutter_blue_plus` | **Kode** (`flutter_blue_plus`) |
| D-03 | PRD §8: kompresi via `flutter_image_compress` | `pubspec.yaml` memakai paket `image` | **Kode** (paket `image`) |
| D-04 | README: "sync engine upload-only tiap 2 menit" | `mesin_sinkron.dart` punya `_unduhTabel()` + `unduhAkun()` — ada logika unduh | **Kode** (dua arah, tapi dipicu timer — bukan "upload-only", bukan "network listener") |
| D-05 | Spesifikasi redesign: kolom `menu.foto` | `SKEMA_DATABASE.md` dan `menu.dart` memakai `foto_url` | **Kode** (`foto_url`) |

---

## 6. Inventaris layar (31 layar)

| Fitur | Layar |
|---|---|
| `selamat_datang` | layar_selamat_datang |
| `auth_owner` | layar_masuk_owner, layar_setup_pin_owner, layar_beranda |
| `kasir` | layar_pilih_kasir, layar_pin_kasir, layar_buka_shift, layar_tutup_shift, layar_profil_kasir, layar_statistik_kasir |
| `pos` | layar_pos (KASIR UTAMA — pilot redesign) |
| `bayar` | layar_bayar, kamera_bukti |
| `tagihan` | layar_daftar_tagihan, layar_tagihan_baru, layar_detail_tagihan |
| `void_kasbon` | dialog_void, layar_kasbon, layar_kas_keluar |
| `stok_kombo` | layar_stok, layar_bahan, layar_stok_opname, layar_riwayat_opname, layar_belanja, layar_kombo, kamera_menu |
| `dasbor` | layar_dasbor, layar_laporan, layar_menu, layar_kategori, layar_akun_kasir, layar_audit, layar_riwayat_shift |
| `lainnya` | layar_lainnya, layar_pengaturan |
| `printer` | (interface + driver, tanpa layar) |

**Struktur kode:** `lib/app/` (tema, router, penyedia), `lib/fitur/` (11 fitur,
feature-first), `lib/data/` (lokal/sinkron/model), `lib/bersama/` (widget,
printer, kamera, util). Penamaan Bahasa Indonesia konsisten.
**Token desain lama:** `lib/app/tema/` sudah ada (`token_warna.dart`,
`token_tipografi.dart`, `tema_app.dart`) — tidak ada `Color(0x...)` hardcoded
di `lib/fitur/`; `layar_pos.dart` dan `layar_bayar.dart` sudah 0 `fontSize:`
literal.

---

## 7. Alur yang ditelusuri

- ✅ Keranjang: tambah/ubah/hapus baris, catatan, diskon per baris
      → temuan BUG-01.
- ✅ Uang: total/bayar/kembalian integer di model & DB; persen diskon
      double tapi dibulatkan → aman.
- ✅ Bayar tunai/non-tunai/gabungan: guard `_memproses` ada (rapuh, BUG-06);
      stok dikurangi pasca-lunas (gagal diabaikan, BUG-03); foto bukti
      di-upload di latar (BUG-07 unconfirmed).
- ✅ Open bill + split bill: tambah item susulan, pindah item ke nota baru
      → temuan BUG-04.
- ✅ Shift: selisih = fisik − sistem, tercatat + terlihat owner → benar.
- ✅ Void: wajib PIN owner 6 digit + alasan min 3 karakter, PIN salah
      di-reset + goyang; audit tercatat → benar, kecuali BUG-02 & BUG-05.
- ✅ Sinkron offline→online: tulis lokal `tertunda` → timer 2 menit
      upload batch + unduh → tandai `tersinkron`/`gagal` → benar,
      kecuali BUG-04.

---

## 8. Yang belum diverifikasi (unconfirmed)

- U-01: ✅ TERKONFIRMASI & DIPERBAIKI — kegagalan upload foto bukti ternyata
      hilang diam-diam (sync engine TIDAK PERNAH retry upload foto; `daftarTertunda`
      hanya ambil status 'tertunda', bukan 'gagal'). Diperbaiki BUG-07 (lihat §9).
- U-02: Perilaku keyboard menutupi input di layar kasbon/kas_keluar
      (perlu uji di perangkat).
- U-03: Kontras tema gelap per elemen — 12 pasangan warna terverifikasi
      kontras ≥ 4.5:1 saat penulisan DESIGN.md (dihitung manual).

---

## 9. Status perbaikan bug (langkah 6 redesign, 17 Okt malam)

| Bug | Status | Commit | Keterangan |
|---|---|---|---|
| BUG-01 | ✅ TIDAK TERBUKTI (false alarm) | `cdbf7bb` (test) | `salin()` ternyata SUDAH menyalin diskon sejak commit `37f558e`; klaim audit salah. 4 test regresi ditambahkan. |
| BUG-02 | ✅ FIXED | `1a94cc8` | Void sekarang kembalikan stok menu + bahan resep (`tambahStok`/`tambahStokBahanResep` baru), catat audit. 2 integration test lolos. |
| BUG-03 | ✅ FIXED | `e89c66f` | Gagal kurangi stok dicatat ke audit (`aksi: 'stok_gagal_dikurangi'`) + peringatan merah di dialog sukses; pembayaran tetap jalan. 3 test lolos. |
| BUG-04 | ✅ FIXED | `846a103` (test) + fix | `hapusRincian()` jadi soft-delete (`apakah_dihapus=1`, `status_sinkron='tertunda'`) via `_hapusLunak()`. 3 test lolos. |
| BUG-05 | ✅ FIXED | `862a736` | `validasiBolehVoid()` menolak void ganda ("Pesanan sudah di-void."). 4 test lolos. |
| BUG-06 | ✅ FIXED | `2c985cb` | `setState(_memproses = true)` dipindah segera setelah cek guard; `_selesaikanInti()` diekstrak. |
| BUG-07 | ✅ FIXED | `0626c4d` | `_unggahUlangBuktiTertunda()` di `MesinSinkron.sinkronkan()` retry upload foto yang gagal tiap putaran sinkron. 4 test lolos. |

**Migrasi visual:** 31 layar + 5 widget pendukung + 2 layar sistem (akses ditolak,
izin awal) dimigrasi ke tema solid hangat + 8 komponen bersama. Komponen lama
(`kartu_kaca.dart`, `tombol_kaca.dart`, `orb_latar.dart`) dihapus. Bonus fix:
bug mode gelap di `layar_lainnya.dart` (warna statis terang dipakai di dark mode).

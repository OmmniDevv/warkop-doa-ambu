# PRD — Sistem POS Kasir "WARKOP DOA AMBU"

**Versi:** 1.0 · **Tanggal:** 3 Oktober 2026
**Platform:** Flutter (Android & iOS, portrait only)
**Arsitektur data:** Offline-First — SQLite lokal + Supabase Cloud & Storage

---

## 1. Ringkasan Produk

Aplikasi kasir (Point of Sale) untuk warung kopi "WARKOP DOA AMBU" (kopi · teh · mie).
Dirancang untuk ritme pemesanan cepat dengan frekuensi transaksi tinggi, budaya
nongkrong lama (open bill per meja/nama), dan operasional yang tetap berjalan
lancar saat internet mati.

**Prinsip arsitektur:**

- **Offline-First** — semua transaksi ditulis ke SQLite lokal dulu (instan, tanpa
  menunggu jaringan), lalu disinkronkan dua arah ke Supabase saat online.
- **Bahasa Indonesia penuh** — seluruh tabel, kolom, status, dan fungsi memakai
  Bahasa Indonesia yang baku dan konsisten.
- **Audit ketat** — setiap pembatalan (void) wajib otorisasi PIN owner + alasan,
  tercatat di log audit.

---

## 2. Persona & Hak Akses (STRICT: hanya dua role)

| Kemampuan | OWNER | KASIR |
|---|---|---|
| Login | Email + kata sandi (Supabase Auth) | Pilih profil nama + PIN 4–6 digit (validasi ke SQLite lokal) |
| Kelola katalog menu & stok bahan | ✅ | ❌ |
| Buat paket kombo promo | ✅ | ❌ |
| Kelola akun & PIN kasir | ✅ | ❌ |
| Pantau omzet & analisis bisnis | ✅ | ❌ (hanya shift sendiri) |
| Lihat log audit pembatalan (void) | ✅ | ❌ |
| Buka/tutup shift (modal awal, kas akhir) | ✅ | ✅ |
| Transaksi kasir, open bill, split bill | ❌ | ✅ |
| Kasbon pelanggan | ❌ | ✅ |
| Kas keluar operasional (petty cash) | ❌ | ✅ |
| Cetak struk (Bluetooth thermal) | ❌ | ✅ |
| Batalkan transaksi (void) | ✅ langsung | ⚠️ wajib PIN owner + alasan |

---

## 3. Alur Operasional Inti

### 3.1 Transaksi cepat (kasir)

1. Kasir login → pilih profil + PIN (keypad in-app, tanpa keyboard OS).
2. Buka shift → input modal awal laci.
3. Pilih menu dari grid 2 kolom (tab kategori: Semua, Paket Kombo, Kopi, Teh, Mie, Cemilan).
4. Keranjang melayang → bottom sheet rincian (85% layar): ubah jumlah, hapus
   (swipe-to-dismiss), pilih metode bayar.
5. Tunai → keypad nominal → kembalian. Non-tunai/QRIS → kamera in-app
   (foto bukti, kompres 100–180 KB, simpan lokal + antre upload).
6. Animasi sukses (centang emas + haptik) → struk meluncur → cetak Bluetooth.

### 3.2 Open bill (pesanan gantung)

- Dibuka per **nomor meja** atau **nama pelanggan**.
- Item susulan bisa ditambah kapan saja sebelum bill ditutup.
- Split bill: pecah per item / per nominal saat pembayaran.

### 3.3 Kasbon & kas keluar

- **Kasbon**: catat hutang pelanggan setia (nominal, jatuh tempo, status lunas).
- **Kas keluar**: pengeluaran darurat operasional (es batu, tabung gas, dll)
  dengan kategori + catatan. Memengaruhi rekap shift.

### 3.4 Tutup shift

Kasir input kas akhir fisik → sistem hitung selisih vs kas akhir sistem
(saldo awal + tunai masuk − kas keluar). Selisih tercatat dan terlihat owner.

### 3.5 Void (pembatalan) — anti-fraud

Kasir **dilarang** membatalkan nota yang sudah terbit tanpa owner.
Alur: kasir pilih void → modal "Masukkan PIN Owner" → input alasan wajib →
transaksi ditandai void (soft-delete, tidak dihapus fisik) → tercatat di log audit.

---

## 4. Model Data (Bahasa Indonesia)

Seluruh tabel memakai **UUID v4** sebagai primary key dan kolom kontrol
sinkronisasi: `status_sinkron` (`tertunda`/`tersinkron`/`gagal`),
`diperbarui_pada` (UTC), `apakah_dihapus` (soft-delete).

| Tabel | Fungsi |
|---|---|
| `akun` | Akun kasir (terikat `id_pemilik`, nama, PIN hash, peran, aktif) |
| `kategori_menu` | Kategori (nama, urutan_tampil, aktif) |
| `menu` | Menu & stok (nama, harga_satuan, stok, stok_minimum, tersedia, foto) |
| `paket_kombo` | Paket promo (nama, harga_paket, aktif) |
| `paket_kombo_rincian` | Relasi menu penyusun kombo (jumlah per menu) |
| `pesanan` | Nota transaksi (nomor_nota, id_akun, id_shift, metode_bayar, status, total, foto bukti lokal/remote, void + alasan + otorisasi) |
| `pesanan_rincian` | Item nota (snapshot nama & harga saat transaksi, jumlah, subtotal, catatan) |
| `open_bill` | Bill gantung (label meja/nama, status buka/tutup) |
| `shift_kasir` | Rekap shift (saldo_awal, kas_akhir_sistem, kas_akhir_fisik, selisih, status) |
| `kasbon` | Hutang pelanggan (id_pelanggan/nama, nominal, sudah_bayar, jatuh_tempo, status) |
| `kas_keluar` | Pengeluaran operasional (kategori, nominal, catatan, id_akun, id_shift) |
| `log_audit` | Jejak audit (aksi, id_akun, id_referensi, detail, alasan) |

Detail skema: `docs/SKEMA_DATABASE.md`.

---

## 5. Mesin Sinkronisasi (Sync Engine)

```
[SQLite lokal] ⇄ [Sync Engine] ⇄ [Supabase Postgres + Storage]
      ↑                ↑
transaksi instan   antrean upload/download
```

- **Deteksi jaringan**: background listener (connectivity_plus).
- **Upload**: data `status_sinkron='tertunda'` → batch upsert → foto bukti ke
  Storage bucket → tandai `tersinkron`. Gagal → `gagal`, coba lagi nanti.
- **Download (pull)**: menu, harga, akun, kombo terbaru berdasarkan
  `diperbarui_pada` > terakhir sinkron.
- **Konflik**: server-menang untuk data master (menu/harga/akun);
  transaksi kasir tidak pernah ditimpa (append-only + UUID).
- **Indikator UI**: awan hijau (aman), awan kuning berdenyut + angka (antrean
  offline), tap untuk sinkron manual.

---

## 6. Sistem Desain: Vintage Glassmorphism

### 6.1 Token

**Terang — Vintage Parchment**

| Token | Nilai |
|---|---|
| Latar | `#F5EEDB` |
| Kaca | `rgba(255,255,255,0.50)`, blur 12–16px |
| Border kaca | `#961C18` 18% opacity, 1px |
| Aksen | `#961C18` (marun pekat) |
| Teks | `#231815` (espresso) |

**Gelap — Roasted Espresso**

| Token | Nilai |
|---|---|
| Latar | `#120D0B` |
| Kaca | `rgba(35,24,21,0.60)`, blur 16px |
| Border kaca | `#DAA520` 30% → transparan, 1px |
| Aksen | `#C4302B` (marun menyala) |
| Teks | `#F4EFEA` (krem susu) |

**Tipografi**: judul/brand serif klasik (`Cinzel`/`Playfair Display`),
fungsional `Plus Jakarta Sans`, angka/struk `JetBrains Mono` (tabular figures).

### 6.2 Aturan ergonomi & performa

- Operasi satu jempol: 45% area bawah layar (floating cart bar, bottom sheet,
  keypad in-app, tombol jepret kamera).
- Portrait terkunci (`DeviceOrientation.portraitUp`).
- **60 FPS**: tanpa `BackdropFilter` di kartu grid yang di-scroll; blur hanya
  untuk elemen mengambang & bottom sheet. Kartu memakai lapisan
  semi-transparan + border tipis.
- **Tanpa audio**: seluruh feedback memakai visual + `HapticFeedback`
  (light/heavy impact). Dilarang efek suara.

---

## 7. Keputusan Arsitektur (dicatat eksplisit)

| Keputusan | Pilihan | Alasan |
|---|---|---|
| State management | **Riverpod** | Rekomendasi skill flutter-ui untuk proyek baru; ringan untuk UI-heavy POS |
| Navigasi | **GoRouter** | Aturan enforced flutter-ui |
| Struktur | Clean Architecture, feature-first | Skill flutter-scalable-app |
| ID | UUID v4 | Anti-tabrakan saat offline |
| Bahasa skema | Indonesia penuh | Permintaan PRD |

---

## 8. Risiko & Batasan v1

- Cetak Bluetooth: interface + implementasi dasar (paket `print_bluetooth_thermal`);
  pairing printer diuji di perangkat nyata.
- Kamera: paket `camera`; kompresi via `flutter_image_compress` (target 100–180 KB).
- PIN kasir: hash (SHA-256 + salt) — bukan enkripsi reversibel.
- Foto bukti: antre upload; tampil placeholder lokal sampai tersinkron.

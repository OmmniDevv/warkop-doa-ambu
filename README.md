# Warkop Doa Ambu — Sistem POS Kasir

Aplikasi kasir (Point of Sale) untuk warung kopi **"WARKOP DOA AMBU"** (kopi ·
teh · mie). Dibangun dengan Flutter, menerapkan arsitektur **Offline-First**:
transaksi berjalan instan dari SQLite lokal lalu tersinkron dua arah ke
Supabase saat online.

> Dokumen spesifikasi lengkap: [`docs/PRD.md`](docs/PRD.md)
> Skema database: [`docs/SKEMA_DATABASE.md`](docs/SKEMA_DATABASE.md)

## Fitur Utama

- **Kasir cepat** — grid menu 2 kolom, tab kategori, floating cart bar, bottom
  sheet nota 85% layar, keypad angka in-app (tanpa keyboard OS).
- **Open bill** — pesanan gantung per nomor meja / nama pelanggan + split bill.
- **Kasbon & kas keluar** — catat hutang pelanggan setia dan pengeluaran
  operasional (petty cash).
- **Shift kasir** — buka/tutup shift dengan modal awal, kas akhir fisik, dan
  hitung selisih otomatis.
- **Void anti-fraud** — pembatalan nota wajib PIN owner + alasan, tercatat di
  log audit.
- **Bukti transfer in-app** — kamera di dalam aplikasi untuk pembayaran
  non-tunai/QRIS; foto dikompresi (±100–180 KB), disimpan lokal, diunggah ke
  Supabase Storage saat online.
- **Paket kombo** — bundling promo yang otomatis memotong stok tiap penyusunnya.
- **Cetak struk** — via Bluetooth thermal printer.
- **Vintage Glassmorphism** — tema terang *Vintage Parchment* & gelap *Roasted
  Espresso*, portrait terkunci, 60 FPS, feedback murni visual + haptik
  (tanpa audio).

## Status Pengembangan

- [x] **Auth owner** — daftar/masuk (Supabase Auth), Master PIN 6 digit +
      biometrik, profil tersimpan di SQLite.
- [x] **Data layer** — 12 model Bahasa Indonesia + SQLite operasional
      (`status_sinkron`, `diperbarui_pada`, `apakah_dihapus`) + seed kategori/menu.
- [x] **Kasir & shift** — pilih profil kasir, PIN kasir (SHA-256+salt),
      buka/tutup shift + hitung selisih otomatis + log audit.
- [x] **POS** — tab kategori, grid menu 2 kolom, badge stok menipis/habis,
      paket kombo, keranjang + bottom sheet (ubah jumlah, hapus, catatan).
- [x] **Open bill** — tagihan per meja/nama pelanggan, pesanan susulan,
      split bill (pindah item ke nota baru), tutup tagihan.
- [x] **Pembayaran** — tunai (keypad + kembalian) / non-tunai + foto bukti
      in-app (kompresi 100–180 KB, upload ke Storage `bukti-pembayaran`
      saat online); stok berkurang otomatis saat lunas.
- [x] **Void / kasbon / kas keluar** — void wajib PIN owner + alasan
      (audit), kasbon + cicilan, kas keluar per shift.
- [x] **Stok, kombo & sinkron** — kelola stok, CRUD paket kombo,
      sync engine upload-only tiap 2 menit (termasuk soft-delete).
- [x] **Printer & dashboard owner** — cetak nota via Bluetooth thermal
      printer, dashboard (omzet, pesanan, kasbon, stok), katalog, laporan
      7 hari, viewer log audit, kelola akun kasir + PIN.
- [ ] Uji cetak di printer fisik (belum ada perangkat saat pengembangan).

## Arsitektur

```
lib/
├── main.dart                 # bootstrap: portrait lock, Riverpod, GoRouter
├── app/                      # tema, router, konstanta
│   ├── tema/                 # token desain (terang/gelap), tipografi
│   └── router.dart           # GoRouter + route guard
├── fitur/                    # feature-first
│   ├── kasir/                # layar POS, keranjang, bottom sheet nota
│   ├── auth/                 # login owner & PIN kasir
│   ├── shift/                # buka/tutup shift
│   ├── open_bill/
│   ├── kasbon/
│   ├── kas_keluar/
│   ├── menu/                 # katalog (owner)
│   ├── kombo/
│   ├── laporan/              # omzet & analisis (owner)
│   └── audit/                # log audit (owner)
├── data/
│   ├── lokal/                # SQLite helper + DAO per tabel
│   ├── sinkron/              # sync engine dua arah
│   └── model/                # entity Bahasa Indonesia
└── bersama/
    ├── widget/               # KartuKaca, keypad, dialog PIN, dll
    ├── printer/              # interface + driver Bluetooth thermal
    └── kamera/               # capture & kompresi bukti transfer
```

**Keputusan stack:** Riverpod (state) + GoRouter (navigasi) + SQLite
(`sqflite`) + Supabase (`supabase_flutter`). Seluruh nama tabel/kolom/status
berbahasa Indonesia; primary key UUID v4.

## Alur Offline-First

```
[SQLite lokal] ⇄ [Sync Engine] ⇄ [Supabase Postgres + Storage]
```

- Tulis transaksi → SQLite (`status_sinkron='tertunda'`) → instan.
- Listener jaringan → upload batch upsert + foto ke Storage → tandai
  `tersinkron`. Gagal → `gagal`, diulang otomatis.
- Pull: menu/harga/akun/kombo terbaru via `diperbarui_pada`.
- Konflik: data master dimenangkan server; transaksi bersifat append-only.

## Panduan Instalasi

### 1. Prasyarat

- Flutter SDK ≥ 3.35 (stable)
- Akun Supabase + project (skema sudah tersedia via migrasi)

### 2. Clone & dependensi

```bash
git clone https://github.com/OmmniDevv/warkop-doa-ambu.git
cd warkop-doa-ambu
flutter pub get
```

### 3. Konfigurasi `.env`

```bash
cp .env.example .env
```

Isi `.env`:

```
SUPABASE_URL=https://xdjzykuzycncqprfnyfm.supabase.co
SUPABASE_ANON_KEY=isi_dengan_anon_key_project
```

> Jangan commit `.env` — file ini sudah masuk `.gitignore`.

### 4. App icon

```bash
dart run flutter_launcher_icons
```

Sumber: `assets/icon/icon.png` (adaptive icon Android + iOS).

### 5. Jalankan

```bash
flutter run
```

## Panduan Build

```bash
# Android APK rilis
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (butuh macOS + Xcode)
flutter build ipa --release
```

## Perintah Berguna

```bash
flutter analyze                        # analisis statik
flutter test                           # unit & widget test
python3 ~/workspace/skills/flutter-ui/scripts/flutter_ui_audit.py .
```

## Struktur Database

Lihat [`docs/SKEMA_DATABASE.md`](docs/SKEMA_DATABASE.md) — 12 tabel Bahasa
Indonesia + bucket Storage `bukti-pembayaran`.

## Lisensi

Proyek privat milik Warkop Doa Ambu.

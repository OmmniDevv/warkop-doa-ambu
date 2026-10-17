# DESIGN.md — Warkop Doa Ambu

<!-- ryux-context:start -->
- **UI direction**: Hangat seperti warkop, rapi, cepat dibaca. Tenang dan fungsional — bukan dekoratif.
- **Motion direction**: Cepat dan tegas. Animasi ≤ 200 ms, hanya untuk feedback status (sukses, loading, perubahan status stok/sinkron). Tanpa audio, hanya visual + haptik.
<!-- ryux-context:end -->

> Dokumen arah desain. Dibuat dengan skill RYUX (entry point Design).
> Menggantikan PRD §6 (Vintage Glassmorphism) setelah disetujui user.
> Bagian lain PRD tetap berlaku. Dibaca oleh `capabilities/build.md` saat implementasi.

---

## 1. Konteks

**Produk:** Aplikasi kasir (POS) offline-first untuk warung kopi "Warkop Doa Ambu"
(kopi · teh · mie · cemilan). Bahasa Indonesia penuh.

**Pengguna (hanya dua role, sesuai PRD §2 — tidak berubah):**

| | Kasir | Owner |
|---|---|---|
| Tugas utama | Transaksi cepat, antrean sibuk, satu tangan | Dasbor, laporan, kelola katalog |
| Kebutuhan | Tombol besar, aksi di jangkauan jempol, feedback instan | Angka jelas, perbandingan periode, jejak audit |
| Login | Pilih profil + PIN 4–6 digit (keypad in-app) | Email + kata sandi (Supabase Auth) |

**Batasan keras (dari PRD §6.2 + spesifikasi user):**
- Portrait terkunci, 60 FPS, offline-first.
- Feedback hanya visual + haptik — tanpa audio.
- Keypad angka in-app (tanpa keyboard OS).
- Aksi primer di 45% area bawah layar.
- Cetak struk via Bluetooth thermal.
- Font tetap bundled: PlusJakartaSans (UI), Cinzel (wordmark saja),
  JetBrainsMono (angka uang — tabular figures).

**Design intent:** kasir harus bisa menyelesaikan satu transaksi dalam
< 30 detik tanpa melihat dua kali; owner harus paham kondisi bisnis
dalam 5 detik pertama membuka dasbor. Keberhasilan = tidak ada salah
pencet saat sibuk, tidak ada angka yang salah baca.

---

## 2. Arah desain (Design Direction)

### UX direction
- **Satu tugas utama per layar.** Layar kasir = jual. Tidak ada navigasi
  samping yang mengganggu saat transaksi.
- **Hierarki informasi:** (1) Total bayar — paling besar & menonjol;
  (2) tombol Bayar; (3) kembalian; (4) sisanya (kategori, menu, status).
- **Model interaksi:** grid menu 2 kolom → floating cart → bottom sheet
  nota (85% layar) → keypad bayar → animasi sukses → struk.
- **States wajib per layar:** loading, kosong (empty), error (+ coba lagi),
  sinkron tertunda/gagal, stok menipis/habis.
- **Edge cases:** bayar tunai kurang dari total (tombol nonaktif),
  non-tunai tanpa foto bukti (tombol nonaktif), stok habis (kartu nonaktif,
  bukan hilang), void butuh PIN owner + alasan.

### UI direction
- **Layout:** grid 2 kolom untuk menu; kartu solid (bukan kaca) di layar sibuk;
  blur hanya untuk bottom sheet & elemen mengambang.
- **Skala teks (maks 5 ukuran):** display 32 (total), judul 20, badan 16,
  label 14, kecil 12. Semua dari `TextTheme`, tidak ada `fontSize:` literal.
- **Spasi:** skala 4/8dp (4, 8, 12, 16, 24, 32). Radius konsisten 12/16/24.
  Elevasi konsisten: kartu 1, mengambang 4, sheet 8.
- **Warna (peran):**

  | Peran | Terang | Gelap |
  |---|---|---|
  | Latar | `#FAF6EF` | `#17110E` |
  | Kartu | `#FFFFFF` | `#221A16` |
  | Teks | `#2A1B14` | `#F5EDE4` |
  | Teks sekunder | `#6B5B4F` | `#B9A99B` |
  | Aksen (bukan merah) | `#9A4A12` (teks putih) | `#E39A4B` (teks `#17110E`) |
  | Sukses | `#1E7A46` | `#5FD39A` |
  | Bahaya & void | `#B3261E` | `#FF8F85` |
  | Stok menipis | teks `#8A5A00` di `#FBEFD0` | `#F2B84B` di kartu |

  Semua pasangan teks/latar ≥ 4.5:1 (terverifikasi 2026-10-17).
  Merah dicadangkan untuk void/bahaya — aksen memakai cokelat/oranye.
- **Kartu menu:** tampilkan foto bila `foto_url` ada; tanpa foto memakai
  placeholder tipografis (inisial menu) + warna kategori.
- **Status stok & sinkron:** selalu tiga sinyal — warna + ikon + teks
  (tidak mengandalkan warna saja).
- **Titik sentuh:** ≥ 48dp untuk semua aksi primer.

### Design language
- **Hangat & jujur:** warna kopi/susu/gula aren, bukan neon. Alasan: warkop
  adalah tempat nongkrong — aplikasi harus terasa seperti bagian dari tempatnya.
- **Rapi & cepat dibaca:** permukaan solid, hierarki tegas, tanpa dekorasi
  yang tidak membantu. Alasan: kasir baca dalam sepersekian detik saat antre.
- **Tegas tapi tidak galak:** sudut membulat, bahasa santai ("Coba lagi ya"),
  tapi status bahaya/void memakai merah tegas. Alasan: kesalahan kasir
  harus terasa serius tanpa menakuti.

### Motion direction
- Liveliness: energi 1 (tenang), ritme 2 (stabil dengan variasi).
- Setiap animasi punya tujuan: sukses (centang + haptik), loading
  (indikator), perubahan status (stok/sinkron). Durasi ≤ 200 ms.
- Pertahankan animasi sukses + haptik yang sudah ada (disukai kasir).

### Responsive
- Lebar uji: 320 / 360 / 412 / 768 dp. Grid menu 2 kolom tetap;
  pada 768 dp kartu lebih lebar, bukan 3 kolom (jaga ukuran sentuh).
- Text scale 1.0 dan 1.5 tidak boleh overflow (diuji via widget test).

---

## 3. Komponen bersama (`lib/bersama/widget/`)

| Komponen | Nama | Catatan |
|---|---|---|
| Tombol | `TombolWarkop` | varian: primer (aksen), bahaya (merah), teks; tinggi ≥ 48dp |
| Kartu | `KartuWarkop` | permukaan solid, radius 16, elevasi 1 |
| Chip | `ChipWarkop` | kategori, status stok, metode bayar |
| Bottom sheet | `LembarWarkop` | blur latar, radius atas 24, max 85% layar |
| Input | `InputWarkop` | label + error text, keyboard menutup tidak menutupi |
| Keypad | `KeypadAngka` | sudah ada — dipakai ulang |
| Dialog PIN | `DialogPin` | sudah ada (`dialog_void.dart`, `titik_pin.dart`) — dipakai ulang |
| Indikator sinkron | `IndikatorSinkron` | awan + teks: aman / antre N / gagal |
| Status kosong | `StatusKosong` | ilustrasi tipografis + teks + aksi |
| Status error | `StatusError` | pesan + tombol "Coba lagi" |

## 4. Token (`lib/app/tema/`)

Token hidup di `ThemeData`/`ThemeExtension`: warna, tipografi, spasi, radius.
Tidak ada warna/ukuran hardcoded di widget layar. Struktur sudah ada
(`token_warna.dart`, `token_tipografi.dart`, `tema_app.dart`) — akan
diperbarui mengikuti tabel warna di atas.

---

## 5. Asumsi & yang belum dikonfirmasi

- **Asumsi:** kasir memakai HP Android 5.5–6.7 inci, satu tangan, layar
  360–412 dp (paling umum).
- **Unconfirmed:** perilaku keyboard di layar kasbon/kas_keluar (U-02 di AUDIT.md)
  — akan diverifikasi saat build pilot.
- PRD §6 resmi diganti setelah user menyetujui dokumen ini.

---

## 6. Decision Receipts

**Keputusan: permukaan solid, bukan glassmorphism**
Opsi: A) pertahankan kaca-blur / B) solid seperti spesifikasi user.
Bukti: spesifikasi user eksplisit + aturan 60 FPS PRD §6.2 (blur di kartu
grid yang di-scroll merusak performa).
Confidence: High. Trade-off: kehilangan kesan "mewah kaca"; diganti
kehangatan warna solid.

**Keputusan: aksen cokelat/oranye, bukan merah**
Opsi: A) merah marun (lama) / B) `#9A4A12`/`#E39A4B`.
Bukti: spesifikasi user — merah dicadangkan untuk void/bahaya agar sinyal
bahaya tidak "tenggelam" di antara tombol biasa.
Confidence: High. Trade-off: tidak ada.

**Keputusan: grid 2 kolom tetap di semua lebar**
Opsi: A) 2 kolom tetap / B) 3 kolom di tablet.
Bukti: batasan sentuh ≥ 48dp + satu tangan; 3 kolom di 768dp membuat
kartu terlalu kecil untuk jempol.
Confidence: Medium. Asumsi: tidak ada tablet kasir di warkop.

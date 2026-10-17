import 'package:flutter/material.dart';

/// Token warna Warkop Doa Ambu — sistem desain solid yang hangat.
///
/// Filosofi: hangat seperti warkop, rapi, cepat dibaca. Permukaan solid
/// (bukan kaca) agar 60 FPS terjaga di layar sibuk; blur hanya untuk
/// bottom sheet & elemen mengambang.
///
/// Merah dicadangkan untuk bahaya/void — aksen memakai cokelat/oranye
/// agar sinyal bahaya tidak tenggelam di antara tombol biasa.
///
/// Semua pasangan teks/latar ≥ 4.5:1 (terverifikasi 2026-10-17).
/// Lihat DESIGN.md §2 untuk arah desain lengkap.
///
/// Jangan pakai warna hardcoded di widget; selalu ambil dari sini lewat
/// [Theme.of(context)] atau [WarnaWarkop].
abstract final class WarnaWarkop {
  // ── Latar & permukaan (solid) ───────────────────────────────────
  /// Latar dasar mode terang: krem susu hangat.
  static const Color latarTerang = Color(0xFFFAF6EF);

  /// Latar dasar mode gelap: espresso pekat.
  static const Color latarGelap = Color(0xFF17110E);

  /// Permukaan kartu mode terang: putih solid.
  static const Color kartuTerang = Color(0xFFFFFFFF);

  /// Permukaan kartu mode gelap: cokelat tua solid.
  static const Color kartuGelap = Color(0xFF221A16);

  /// Garis hairline mode terang (teks 12% — turunan, bukan token baru).
  static const Color garisTerang = Color(0x1F2A1B14);

  /// Garis hairline mode gelap (teks 12% — turunan, bukan token baru).
  static const Color garisGelap = Color(0x1FF5EDE4);

  // ── Teks ────────────────────────────────────────────────────────
  /// Teks utama terang: espresso.
  static const Color teksTerang = Color(0xFF2A1B14);

  /// Teks utama gelap: krem susu.
  static const Color teksGelap = Color(0xFFF5EDE4);

  /// Teks sekunder terang.
  static const Color teksSekunderTerang = Color(0xFF6B5B4F);

  /// Teks sekunder gelap.
  static const Color teksSekunderGelap = Color(0xFFB9A99B);

  // ── Aksen (bukan merah) ─────────────────────────────────────────
  /// Aksen utama terang: cokelat gula aren. Teks di atasnya: putih.
  static const Color aksenTerang = Color(0xFF9A4A12);

  /// Aksen utama gelap: oranye hangat. Teks di atasnya: #17110E.
  static const Color aksenGelap = Color(0xFFE39A4B);

  /// Warna teks di atas aksen terang.
  static const Color diAtasAksenTerang = Color(0xFFFFFFFF);

  /// Warna teks di atas aksen gelap.
  static const Color diAtasAksenGelap = Color(0xFF17110E);

  // ── Warna semantik ──────────────────────────────────────────────
  /// Sukses mode terang.
  static const Color suksesTerang = Color(0xFF1E7A46);

  /// Sukses mode gelap.
  static const Color suksesGelap = Color(0xFF5FD39A);

  /// Bahaya & void mode terang (merah dicadangkan untuk ini).
  static const Color bahayaTerang = Color(0xFFB3261E);

  /// Bahaya & void mode gelap.
  static const Color bahayaGelap = Color(0xFFFF8F85);

  /// Teks peringatan stok menipis (terang) — di atas [peringatanStokLatarTerang].
  static const Color peringatanStokTeksTerang = Color(0xFF8A5A00);

  /// Latar peringatan stok menipis (terang).
  static const Color peringatanStokLatarTerang = Color(0xFFFBEFD0);

  /// Teks peringatan stok menipis (gelap) — di atas kartu gelap.
  static const Color peringatanStokTeksGelap = Color(0xFFF2B84B);

  // ── Alias usang (redesign glassmorphism → solid) ─────────────────
  // Token-token di bawah ini dipertahankan sementara agar 40+ file yang
  // masih memakai nama lama tetap terkompilasi. Semuanya dipetakan ke
  // token solid baru. JANGAN dipakai di kode baru — migrasi ke token
  // kanonis di atas. Daftar migrasi: lihat laporan step 4a.

  /// Usang: gunakan [latarTerang].
  @Deprecated('Gunakan latarTerang — token glassmorphism dihapus saat redesign.')
  static const Color kertasTerang = latarTerang;

  /// Usang: gunakan [latarGelap].
  @Deprecated('Gunakan latarGelap — token glassmorphism dihapus saat redesign.')
  static const Color kertasGelap = latarGelap;

  /// Usang: gunakan [kartuTerang] (solid, bukan kaca).
  @Deprecated('Gunakan kartuTerang — permukaan kini solid, bukan kaca.')
  static const Color kacaTerang = kartuTerang;

  /// Usang: gunakan [kartuTerang].
  @Deprecated('Gunakan kartuTerang — permukaan kini solid, bukan kaca.')
  static const Color kacaTerangSedang = kartuTerang;

  /// Usang: gunakan [kartuTerang].
  @Deprecated('Gunakan kartuTerang — permukaan kini solid, bukan kaca.')
  static const Color kacaTerangRingan = kartuTerang;

  /// Usang: gunakan [garisTerang].
  @Deprecated('Gunakan garisTerang — token glassmorphism dihapus saat redesign.')
  static const Color borderKacaTerang = garisTerang;

  /// Usang: gunakan [kartuGelap] (solid, bukan kaca).
  @Deprecated('Gunakan kartuGelap — permukaan kini solid, bukan kaca.')
  static const Color kacaGelap = kartuGelap;

  /// Usang: gunakan [kartuGelap].
  @Deprecated('Gunakan kartuGelap — permukaan kini solid, bukan kaca.')
  static const Color kacaGelapSedang = kartuGelap;

  /// Usang: gunakan [kartuGelap].
  @Deprecated('Gunakan kartuGelap — permukaan kini solid, bukan kaca.')
  static const Color kacaGelapRingan = kartuGelap;

  /// Usang: gunakan [garisGelap].
  @Deprecated('Gunakan garisGelap — token glassmorphism dihapus saat redesign.')
  static const Color borderKacaGelap = garisGelap;

  /// Usang: gunakan [aksenTerang].
  @Deprecated('Gunakan aksenTerang — token glassmorphism dihapus saat redesign.')
  static const Color aksenGelapHover = aksenTerang;

  /// Usang: orb latar tidak dipakai lagi di desain baru.
  @Deprecated('Tidak dipakai — orb latar dihapus dari desain baru.')
  static const Color orbViolet = aksenTerang;

  /// Usang: orb latar tidak dipakai lagi di desain baru.
  @Deprecated('Tidak dipakai — orb latar dihapus dari desain baru.')
  static const Color orbPink = aksenTerang;

  /// Usang: orb latar tidak dipakai lagi di desain baru.
  @Deprecated('Tidak dipakai — orb latar dihapus dari desain baru.')
  static const Color orbOranye = aksenGelap;

  /// Usang: gunakan [peringatanStokTeksTerang].
  @Deprecated('Gunakan peringatanStokTeksTerang — token glassmorphism dihapus saat redesign.')
  static const Color emas = peringatanStokTeksTerang;

  /// Usang: gunakan [bahayaTerang].
  @Deprecated('Gunakan bahayaTerang — merah dicadangkan untuk bahaya/void.')
  static const Color merahMenyala = bahayaTerang;

  /// Usang: gunakan [suksesTerang].
  @Deprecated('Gunakan suksesTerang — token glassmorphism dihapus saat redesign.')
  static const Color hijauAman = suksesTerang;

  /// Usang: gunakan [peringatanStokTeksTerang].
  @Deprecated('Gunakan peringatanStokTeksTerang — token glassmorphism dihapus saat redesign.')
  static const Color kuningAntre = peringatanStokTeksTerang;
}

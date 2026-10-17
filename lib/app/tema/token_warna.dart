import 'package:flutter/material.dart';

/// Token warna Warkop Doa Ambu — Gojek/GoPay-inspired.
///
/// Filosofi: kejelasan dan kepercayaan ala fintech Indonesia — hijau tua
/// yang confident untuk aksi utama, permukaan putih/off-white yang bersih,
/// border halus sebelum shadow. Bukan copy logo/aset Gojek/GoPay.
///
/// Permukaan solid (bukan kaca) agar 60 FPS terjaga di layar sibuk; blur
/// hanya untuk bottom sheet & elemen mengambang.
///
/// Merah dicadangkan untuk bahaya/void.
///
/// Semua pasangan teks/latar ≥ 4.5:1 (WCAG AA).
/// Lihat DESIGN.md untuk kontrak desain lengkap.
///
/// Jangan pakai warna hardcoded di widget; selalu ambil dari sini lewat
/// [Theme.of(context)] atau [WarnaWarkop].
abstract final class WarnaWarkop {
  // ── Latar & permukaan (solid) ───────────────────────────────────
  /// Latar dasar mode terang: off-white kehijauan.
  static const Color latarTerang = Color(0xFFF6F8F6);

  /// Latar dasar mode gelap: hijau-hitam pekat.
  static const Color latarGelap = Color(0xFF101714);

  /// Permukaan kartu mode terang: putih solid.
  static const Color kartuTerang = Color(0xFFFFFFFF);

  /// Permukaan kartu mode gelap: hijau tua solid.
  static const Color kartuGelap = Color(0xFF18211C);

  /// Panel tenang / filter terpilih (terang).
  static const Color permukaanLembutTerang = Color(0xFFEAF2EC);

  /// Panel tenang / filter terpilih (gelap).
  static const Color permukaanLembutGelap = Color(0xFF202D25);

  /// Garis hairline / border mode terang.
  static const Color garisTerang = Color(0xFFDCE5DE);

  /// Garis hairline / border mode gelap.
  static const Color garisGelap = Color(0xFF2D3B32);

  // ── Teks ────────────────────────────────────────────────────────
  /// Teks utama terang.
  static const Color teksTerang = Color(0xFF17231D);

  /// Teks utama gelap.
  static const Color teksGelap = Color(0xFFF2F7F3);

  /// Teks sekunder terang.
  static const Color teksSekunderTerang = Color(0xFF59675F);

  /// Teks sekunder gelap.
  static const Color teksSekunderGelap = Color(0xFFB3C0B7);

  // ── Aksen: hijau confident ──────────────────────────────────────
  /// Aksen utama terang: hijau tua. Teks di atasnya: putih.
  static const Color aksenTerang = Color(0xFF087F5B);

  /// Aksen utama gelap: hijau terang. Teks di atasnya: #08251A.
  static const Color aksenGelap = Color(0xFF38B889);

  /// Aksen saat ditekan (terang).
  static const Color aksenTekanTerang = Color(0xFF066849);

  /// Aksen saat ditekan (gelap).
  static const Color aksenTekanGelap = Color(0xFF2A9A70);

  /// Warna teks di atas aksen terang.
  static const Color diAtasAksenTerang = Color(0xFFFFFFFF);

  /// Warna teks di atas aksen gelap.
  static const Color diAtasAksenGelap = Color(0xFF08251A);

  // ── Warna semantik ──────────────────────────────────────────────
  /// Sukses mode terang.
  static const Color suksesTerang = Color(0xFF18794E);

  /// Sukses mode gelap.
  static const Color suksesGelap = Color(0xFF62D6A0);

  /// Bahaya & void mode terang (merah dicadangkan untuk ini).
  static const Color bahayaTerang = Color(0xFFB42318);

  /// Bahaya & void mode gelap.
  static const Color bahayaGelap = Color(0xFFFF8F85);

  /// Info mode terang.
  static const Color infoTerang = Color(0xFF175CD3);

  /// Info mode gelap.
  static const Color infoGelap = Color(0xFF84ADFF);

  /// Teks peringatan stok menipis (terang) — di atas [peringatanStokLatarTerang].
  static const Color peringatanStokTeksTerang = Color(0xFF8A5A00);

  /// Latar peringatan stok menipis (terang).
  static const Color peringatanStokLatarTerang = Color(0xFFFFF2D2);

  /// Teks peringatan stok menipis (gelap) — di atas kartu gelap.
  static const Color peringatanStokTeksGelap = Color(0xFFF4C15D);

  /// Latar peringatan stok menipis (gelap).
  static const Color peringatanStokLatarGelap = Color(0xFF3A2E18);

  // ── Alias usang (redesign glassmorphism → solid) ─────────────────
  // Token-token di bawah ini dipertahankan sementara agar file yang
  // masih memakai nama lama tetap terkompilasi. JANGAN dipakai di kode baru.

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

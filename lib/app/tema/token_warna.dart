import 'package:flutter/material.dart';

/// Token warna Violet Glassmorphism — sistem desain baru Warkop Doa Ambu.
///
/// Filosofi: quiet luxury. Kaca buram premium dengan aksen violet tunggal.
/// Tiga lapis kedalaman: atmosfer (gradien latar) → difusi (orb warna) →
/// permukaan (kartu kaca).
///
/// Jangan pakai warna hardcoded di widget; selalu ambil dari sini lewat
/// [Theme.of(context)] atau [WarnaWarkop].
abstract final class WarnaWarkop {
  // ── Aksen utama · Violet ──────────────────────────────────────────
  /// Aksen utama: violet untuk semua elemen interaktif.
  static const Color aksenTerang = Color(0xFF6B4EFF);

  /// Aksen mode gelap: violet lebih terang agar kontras di latar gelap.
  static const Color aksenGelap = Color(0xFF9D8FFF);

  /// Violet gelap untuk hover/pressed.
  static const Color aksenGelapHover = Color(0xFF5038E0);

  /// Tint violet untuk latar ghost button & tag.
  static const Color tintAksen = Color(0x1A6B4EFF);

  // ── Mode terang · Lavender Blush ──────────────────────────────────
  /// Latar dasar lavender-blush (dipakai sebagai warna solid; gradien
  /// lengkap digambar oleh OrbLatar).
  static const Color kertasTerang = Color(0xFFF1EAFF);

  /// Permukaan kaca kuat: putih 52%.
  static const Color kacaTerang = Color(0x85FFFFFF);

  /// Kaca sedang: putih 38%.
  static const Color kacaTerangSedang = Color(0x61FFFFFF);

  /// Kaca ringan: putih 26%.
  static const Color kacaTerangRingan = Color(0x42FFFFFF);

  /// Border kaca: putih 68%.
  static const Color borderKacaTerang = Color(0xADFFFFFF);

  /// Teks utama: near-black sejuk.
  static const Color teksTerang = Color(0xFF1E1B4B);

  /// Teks sekunder: near-black 65%.
  static const Color teksSekunderTerang = Color(0xA61E1B4B);

  // ── Mode gelap · Deep Violet Night ────────────────────────────────
  /// Latar malam ungu pekat.
  static const Color kertasGelap = Color(0xFF12101D);

  /// Permukaan kaca gelap: putih 14%.
  static const Color kacaGelap = Color(0x24FFFFFF);

  /// Kaca sedang gelap: putih 10%.
  static const Color kacaGelapSedang = Color(0x1AFFFFFF);

  /// Kaca ringan gelap: putih 6%.
  static const Color kacaGelapRingan = Color(0x0FFFFFFF);

  /// Border kaca gelap: putih 18%.
  static const Color borderKacaGelap = Color(0x2EFFFFFF);

  /// Teks utama gelap: lavender-putih.
  static const Color teksGelap = Color(0xFFF4F1FF);

  /// Teks sekunder gelap: lavender-putih 65%.
  static const Color teksSekunderGelap = Color(0xA6F4F1FF);

  // ── Warna orb (latar animasi) ─────────────────────────────────────
  /// Orb violet utama.
  static const Color orbViolet = Color(0xFFA78BFA);

  /// Orb pink/blush.
  static const Color orbPink = Color(0xFFF9A8D4);

  /// Orb oranye (aksen hangat, dipakai hemat).
  static const Color orbOranye = Color(0xFFFB923C);

  // ── Warna semantik (kedua mode) ───────────────────────────────────
  /// Emas untuk badge & peringatan.
  static const Color emas = Color(0xFFF59E0B);

  /// Merah untuk error.
  static const Color merahMenyala = Color(0xFFE03131);

  /// Hijau untuk sukses.
  static const Color hijauAman = Color(0xFF3AB07A);

  /// Kuning untuk antrean offline.
  static const Color kuningAntre = Color(0xFFF08C00);
}

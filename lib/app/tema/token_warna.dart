import 'package:flutter/material.dart';

/// Token warna Vintage Glassmorphism — DNA visual dari `icon.png`.
///
/// Terang = Vintage Parchment, Gelap = Roasted Espresso.
/// Jangan pakai warna hardcoded di widget; selalu ambil dari sini lewat
/// [Theme.of(context)] atau [WarnaWarkop].
abstract final class WarnaWarkop {
  // ── Mode terang · Vintage Parchment ──────────────────────────────
  /// Latar krem kertas kuno.
  static const Color kertasTerang = Color(0xFFF5EEDB);

  /// Permukaan kaca: putih 55%.
  static const Color kacaTerang = Color(0x8CFFFFFF);

  /// Border kaca: marun #961C18 @18%.
  static const Color borderKacaTerang = Color(0x2E961C18);

  /// Aksen utama: merah marun pekat khas logo.
  static const Color aksenTerang = Color(0xFF961C18);

  /// Teks utama: espresso pekat.
  static const Color teksTerang = Color(0xFF231815);

  /// Teks sekunder: espresso 65%.
  static const Color teksSekunderTerang = Color(0xA6231815);

  // ── Mode gelap · Roasted Espresso ────────────────────────────────
  /// Latar hitam biji kopi panggang.
  static const Color kertasGelap = Color(0xFF120D0B);

  /// Permukaan kaca: espresso 60%.
  static const Color kacaGelap = Color(0x99231815);

  /// Border kaca: emas kuningan #DAA520 @30%.
  static const Color borderKacaGelap = Color(0x4DDAA520);

  /// Aksen utama: marun menyala hangat.
  static const Color aksenGelap = Color(0xFFC4302B);

  /// Teks utama: krem susu gading.
  static const Color teksGelap = Color(0xFFF4EFEA);

  /// Teks sekunder: krem 65%.
  static const Color teksSekunderGelap = Color(0xA6F4EFEA);

  // ── Warna semantik (kedua mode) ──────────────────────────────────
  /// Emas kuningan untuk badge sukses & aksen dekoratif.
  static const Color emas = Color(0xFFDAA520);

  /// Merah menyala untuk status error / PIN salah.
  static const Color merahMenyala = Color(0xFFE03131);

  /// Hijau untuk status aman / tersinkron.
  static const Color hijauAman = Color(0xFF2F9E44);

  /// Kuning untuk antrean offline.
  static const Color kuningAntre = Color(0xFFF08C00);
}

import 'package:flutter/material.dart';

/// Token tipografi — terdaftar di `pubspec.yaml` (bundel lokal, offline-first).
///
/// - [serif]: judul brand & nota — karakter klasik (Cinzel).
/// - [sans]: seluruh UI fungsional (Plus Jakarta Sans).
/// - [mono]: angka, nominal & struk — tabular figures (JetBrains Mono).
abstract final class TipografiWarkop {
  static const String serif = 'Cinzel';
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';

  /// Gaya judul brand — serif klasik dengan tracking lega.
  static const TextStyle judulBrand = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
  );

  /// Gaya nominal rupiah — monospace agar digit sejajar sempurna.
  static const TextStyle nominal = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

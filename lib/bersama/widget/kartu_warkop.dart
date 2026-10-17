import 'package:flutter/material.dart';

/// Kartu standar Warkop Doa Ambu.
///
/// Permukaan SOLID ([ColorScheme.surface]) — bukan kaca. Sesuai keputusan
/// desain: blur hanya untuk bottom sheet & elemen mengambang, kartu di
/// layar sibuk memakai permukaan solid demi 60 FPS.
///
/// - Radius 16, elevasi 1 (sesuai DESIGN.md).
/// - Padding default 16 (skala 4/8dp).
/// - Opsional [saatDitekan] untuk kartu yang bisa diketuk (efek tinta).
class KartuWarkop extends StatelessWidget {
  const KartuWarkop({
    super.key,
    required this.child,
    this.saatDitekan,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  /// Isi kartu.
  final Widget child;

  /// Bila diisi, kartu menjadi dapat diketuk dengan efek tinta.
  final VoidCallback? saatDitekan;

  /// Padding dalam kartu (default 16).
  final EdgeInsetsGeometry padding;

  /// Margin luar kartu (default nol — induk yang mengatur jarak).
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    final kartu = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: margin,
      decoration: BoxDecoration(
        color: skema.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: skema.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: saatDitekan,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    return kartu;
  }
}

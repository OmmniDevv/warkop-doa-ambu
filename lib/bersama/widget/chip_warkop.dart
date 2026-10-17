import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chip pilihan Warkop Doa Ambu — untuk kategori menu, status stok,
/// dan metode bayar.
///
/// - Tinggi minimal 48dp agar mudah diketuk saat antrean sibuk.
/// - Status terpilih: latar aksen + teks kontras; tidak terpilih:
///   latar netral + teks biasa.
/// - Varian [bahaya] untuk status negatif (mis. stok habis).
///
/// Warna dari [Theme.of(context).colorScheme]; teks dari
/// [Theme.of(context).textTheme].
class ChipWarkop extends StatelessWidget {
  const ChipWarkop({
    super.key,
    required this.label,
    required this.terpilih,
    required this.saatDitekan,
    this.ikon,
    this.bahaya = false,
  });

  /// Teks pada chip.
  final String label;

  /// True = chip dalam keadaan aktif/terpilih.
  final bool terpilih;

  /// Aksi saat chip diketuk.
  final VoidCallback saatDitekan;

  /// Ikon opsional di kiri label.
  final IconData? ikon;

  /// True = memakai warna bahaya saat terpilih (mis. filter "stok habis").
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme.labelLarge;

    final Color latarAktif = bahaya ? skema.error : skema.primary;
    final Color isiAktif = bahaya ? skema.onError : skema.onPrimary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        saatDitekan();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: terpilih ? latarAktif : skema.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: terpilih
              ? null
              : Border.all(color: skema.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (ikon != null) ...[
              Icon(
                ikon,
                size: 18,
                color: terpilih ? isiAktif : skema.onSurface,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: gayaTeks?.copyWith(
                color: terpilih ? isiAktif : skema.onSurface,
                fontWeight: terpilih ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

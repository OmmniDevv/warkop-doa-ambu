import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Varian visual [TombolWarkop].
enum VarianTombol {
  /// Aksi utama — latar aksen ([ColorScheme.primary]).
  primer,

  /// Aksi destruktif — latar merah ([ColorScheme.error]).
  /// Dicadangkan untuk void/batal agar sinyal bahaya tidak tenggelam.
  bahaya,

  /// Aksi sekunder — teks saja tanpa latar.
  teks,
}

/// Tombol standar Warkop Doa Ambu.
///
/// - Tinggi 52dp (di atas minimum 48dp) — aman untuk jempol kasir yang sibuk.
/// - Umpan balik haptik setiap ketukan (ringan untuk primer/teks,
///   sedang untuk bahaya).
/// - Status [memuat] menampilkan indikator putar dan menonaktifkan tombol.
/// - Tombol nonaktif memakai warna standar Material agar konsisten.
///
/// Semua warna diambil dari [Theme.of(context).colorScheme] sehingga
/// mengikuti mode terang/gelap otomatis.
class TombolWarkop extends StatelessWidget {
  const TombolWarkop({
    super.key,
    required this.label,
    required this.saatDitekan,
    this.varian = VarianTombol.primer,
    this.memuat = false,
    this.ikon,
    this.lebarPenuh = true,
  });

  /// Teks pada tombol.
  final String label;

  /// Aksi saat ditekan. `null` = tombol nonaktif.
  final VoidCallback? saatDitekan;

  /// Varian visual tombol.
  final VarianTombol varian;

  /// True saat operasi berjalan — tombol terkunci + indikator putar.
  final bool memuat;

  /// Ikon opsional di kiri label.
  final IconData? ikon;

  /// True = memenuhi lebar induk (default untuk aksi primer di 45% bawah layar).
  final bool lebarPenuh;

  bool get _nonaktif => saatDitekan == null || memuat;

  void _ketuk() {
    if (_nonaktif) return;
    if (varian == VarianTombol.bahaya) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    saatDitekan!.call();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme.labelLarge;

    final Color latar;
    final Color warnaIsi;
    switch (varian) {
      case VarianTombol.primer:
        latar = skema.primary;
        warnaIsi = skema.onPrimary;
      case VarianTombol.bahaya:
        latar = skema.error;
        warnaIsi = skema.onError;
      case VarianTombol.teks:
        latar = Colors.transparent;
        warnaIsi = skema.primary;
    }

    final tombol = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      decoration: BoxDecoration(
        color: _nonaktif && varian != VarianTombol.teks
            ? skema.onSurface.withValues(alpha: 0.12)
            : latar,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _nonaktif ? null : _ketuk,
          child: Center(
            child: memuat
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: varian == VarianTombol.teks
                          ? skema.primary
                          : warnaIsi,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ikon != null) ...[
                        Icon(ikon, size: 20, color: _warnaTeks(skema, warnaIsi)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: gayaTeks?.copyWith(
                          color: _warnaTeks(skema, warnaIsi),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!lebarPenuh) return tombol;
    return SizedBox(width: double.infinity, child: tombol);
  }

  Color _warnaTeks(ColorScheme skema, Color warnaIsi) {
    if (_nonaktif) return skema.onSurface.withValues(alpha: 0.38);
    return warnaIsi;
  }
}

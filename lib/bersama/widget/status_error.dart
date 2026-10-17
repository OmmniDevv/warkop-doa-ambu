import 'package:flutter/material.dart';

import 'tombol_warkop.dart';

/// Tampilan status error — mis. gagal memuat data dari database lokal.
///
/// Ikon peringatan + pesan error + tombol "Coba lagi".
/// Dipakai sebagai handler `error:` pada `AsyncValue.when()` untuk
/// menutup temuan audit `RIVERPOD_NO_ERROR_HANDLER`.
class StatusError extends StatelessWidget {
  const StatusError({
    super.key,
    this.pesan = 'Terjadi kesalahan. Coba lagi ya.',
    required this.saatCobaLagi,
    this.labelTombol = 'Coba lagi',
  });

  /// Pesan error yang ramah (Bahasa Indonesia, tidak teknis).
  final String pesan;

  /// Aksi saat tombol "Coba lagi" ditekan.
  final VoidCallback saatCobaLagi;

  /// Label tombol (default "Coba lagi").
  final String labelTombol;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skema.error.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: skema.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pesan,
              style: gayaTeks.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TombolWarkop(
              label: labelTombol,
              ikon: Icons.refresh_rounded,
              saatDitekan: saatCobaLagi,
              lebarPenuh: false,
            ),
          ],
        ),
      ),
    );
  }
}

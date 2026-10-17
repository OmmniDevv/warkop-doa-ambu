import 'package:flutter/material.dart';

import 'tombol_warkop.dart';

/// Tampilan status kosong — mis. menu belum ada, riwayat transaksi kosong.
///
/// Placeholder TIPOGRAFIS (huruf awal [inisial] berukuran besar dalam
/// lingkaran aksen) + judul + deskripsi + tombol aksi opsional.
/// Tidak memakai gambar agar tetap ringan & offline-first.
class StatusKosong extends StatelessWidget {
  const StatusKosong({
    super.key,
    required this.judul,
    required this.deskripsi,
    this.inisial = '•',
    this.labelAksi,
    this.saatAksi,
  });

  /// Judul status (mis. "Belum ada menu").
  final String judul;

  /// Penjelasan singkat + arahan (mis. "Tambah menu pertama dari dasbor owner.").
  final String deskripsi;

  /// Huruf placeholder (mis. inisial kategori). Default titik tengah.
  final String inisial;

  /// Label tombol aksi (opsional).
  final String? labelAksi;

  /// Aksi tombol (opsional — bila null, tombol tidak tampil).
  final VoidCallback? saatAksi;

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
                color: skema.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Text(
                inisial,
                style: gayaTeks.displayLarge?.copyWith(
                  color: skema.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              judul,
              style: gayaTeks.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              deskripsi,
              style: gayaTeks.bodyMedium?.copyWith(
                color: skema.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (labelAksi != null && saatAksi != null) ...[
              const SizedBox(height: 24),
              TombolWarkop(
                label: labelAksi!,
                saatDitekan: saatAksi,
                lebarPenuh: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

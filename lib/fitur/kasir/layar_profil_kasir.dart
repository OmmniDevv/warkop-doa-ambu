import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import 'penyedia_kasir.dart';

/// Layar akun kasir: info kasir, status shift, tutup shift, keluar.
///
/// Tidak ada akses ke fitur owner — hanya info & aksi kasir sendiri.
class LayarProfilKasir extends ConsumerWidget {
  const LayarProfilKasir({super.key});

  Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin mau keluar?'),
        content: const Text(
          'Kamu akan keluar dari akun kasir di perangkat ini.\n'
          'Pastikan shift sudah ditutup dulu ya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true || !context.mounted) return;

    HapticFeedback.mediumImpact();
    ref.read(sesiKasirProvider.notifier).ganti(null);
    ref.read(shiftAktifProvider.notifier).ganti(null);
    if (context.mounted) context.go(Rute.kasir);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kasir = ref.watch(sesiKasirProvider);
    final shift = ref.watch(shiftAktifProvider);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AKUN')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_outlined, size: 64, color: aksen),
                  const SizedBox(height: 16),
                  Text(
                    'Masuk dulu sebagai kasir untuk membuka akun.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  TombolKaca(
                    label: 'Masuk sebagai Kasir',
                    lebarPenuh: false,
                    saatDitekan: () => context.go(Rute.selamatDatang),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AKUN')),
      body: OrbLatar(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kartu info kasir.
                KartuKaca(
                  tanpaBlur: true,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              aksen,
                              WarnaWarkop.aksenGelapHover,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            kasir.nama.isNotEmpty
                                ? kasir.nama[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kasir.nama,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kasir',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: teksRedup),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Status shift.
                KartuKaca(
                  tanpaBlur: true,
                  child: Row(
                    children: [
                      Icon(
                        shift != null
                            ? Icons.lock_open_outlined
                            : Icons.lock_outline,
                        color: shift != null
                            ? WarnaWarkop.hijauAman
                            : teksRedup,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Shift',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: teksRedup),
                            ),
                            Text(
                              shift != null
                                  ? 'Shift dibuka'
                                  : 'Belum buka shift',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tombol tutup shift (hanya bila shift aktif).
                if (shift != null) ...[
                  TombolKaca(
                    label: 'Tutup Shift',
                    ikon: Icons.lock_outline,
                    saatDitekan: () => context.push(Rute.tutupShift),
                  ),
                  const SizedBox(height: 12),
                ],
                // Tombol keluar.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _konfirmasiKeluar(context, ref),
                    icon: const Icon(Icons.logout_outlined),
                    label: const Text('Keluar dari Akun Kasir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WarnaWarkop.merahMenyala,
                      side: BorderSide(
                        color: WarnaWarkop.merahMenyala.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

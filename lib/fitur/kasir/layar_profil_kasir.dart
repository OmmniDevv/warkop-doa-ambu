import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_warkop.dart';
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
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akun')),
        body: SafeArea(
          child: StatusKosong(
            judul: 'Belum masuk',
            deskripsi: 'Masuk dulu sebagai kasir untuk membuka akun.',
            inisial: '?',
            labelAksi: 'Masuk sebagai Kasir',
            saatAksi: () => context.go(Rute.selamatDatang),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kartu info kasir.
              KartuWarkop(
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: skema.primary,
                      ),
                      child: Text(
                        kasir.nama.isNotEmpty
                            ? kasir.nama[0].toUpperCase()
                            : '?',
                        style: gayaTeks.headlineSmall?.copyWith(
                          color: skema.onPrimary,
                          fontWeight: FontWeight.w700,
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
                            style: gayaTeks.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kasir',
                            style: gayaTeks.bodySmall?.copyWith(
                              color: skema.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Status shift.
              KartuWarkop(
                child: Row(
                  children: [
                    Icon(
                      shift != null
                          ? Icons.lock_open_outlined
                          : Icons.lock_outline,
                      color: shift != null
                          ? skema.secondary
                          : skema.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Shift',
                            style: gayaTeks.bodySmall?.copyWith(
                              color: skema.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            shift != null
                                ? 'Shift dibuka'
                                : 'Belum buka shift',
                            style: gayaTeks.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
                TombolWarkop(
                  label: 'Tutup Shift',
                  ikon: Icons.lock_outline,
                  saatDitekan: () => context.push(Rute.tutupShift),
                ),
                const SizedBox(height: 12),
              ],
              // Tombol keluar.
              TombolWarkop(
                label: 'Keluar dari Akun Kasir',
                ikon: Icons.logout_outlined,
                varian: VarianTombol.bahaya,
                saatDitekan: () => _konfirmasiKeluar(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

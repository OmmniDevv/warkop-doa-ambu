import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../bersama/widget/kartu_warkop.dart';

/// Peran warna ubin — diurai ke [ColorScheme] saat build agar benar
/// di mode terang maupun gelap.
enum _PeranWarna { aksen, sukses, peringatan, bahaya, netral }

/// Satu ubin menu: ikon + label + rute tujuan.
class _UbinLainnya {
  const _UbinLainnya({
    required this.label,
    required this.ikon,
    required this.path,
    required this.peran,
  });

  final String label;
  final IconData ikon;
  final String path;
  final _PeranWarna peran;
}

/// Menu "Lainnya": grid 2 kolom berisi seluruh modul pendukung warkop.
///
/// Setiap ubin memakai KartuWarkop (solid, hemat GPU di grid) dan
/// menavigasi ke rute modul yang bersangkutan.
class LayarLainnya extends ConsumerWidget {
  const LayarLainnya({super.key});

  static const _menu = <_UbinLainnya>[
    _UbinLainnya(
      label: 'Laporan',
      ikon: Icons.bar_chart_outlined,
      path: Rute.laporan,
      peran: _PeranWarna.aksen,
    ),
    _UbinLainnya(
      label: 'Daftar Belanja',
      ikon: Icons.shopping_cart_outlined,
      path: Rute.belanja,
      peran: _PeranWarna.sukses,
    ),
    _UbinLainnya(
      label: 'Kasbon',
      ikon: Icons.handshake_outlined,
      path: Rute.kasbon,
      peran: _PeranWarna.peringatan,
    ),
    _UbinLainnya(
      label: 'Kas Keluar',
      ikon: Icons.money_off_outlined,
      path: Rute.kasKeluar,
      peran: _PeranWarna.bahaya,
    ),
    _UbinLainnya(
      label: 'Kombo',
      ikon: Icons.layers_outlined,
      path: Rute.kombo,
      peran: _PeranWarna.aksen,
    ),
    _UbinLainnya(
      label: 'Kategori',
      ikon: Icons.category_outlined,
      path: Rute.kategori,
      peran: _PeranWarna.peringatan,
    ),
    // Resep dikelola per menu lewat form menu (BagianResep), jadi tidak
    // perlu ubin sendiri — ubin "Menu" di bawah sudah mencakupnya.
    _UbinLainnya(
      label: 'Menu',
      ikon: Icons.restaurant_menu_outlined,
      path: Rute.menu,
      peran: _PeranWarna.aksen,
    ),
    _UbinLainnya(
      label: 'Bahan',
      ikon: Icons.inventory_outlined,
      path: Rute.bahan,
      peran: _PeranWarna.sukses,
    ),
    _UbinLainnya(
      label: 'Stok Opname',
      ikon: Icons.fact_check_outlined,
      path: Rute.stokOpname,
      peran: _PeranWarna.bahaya,
    ),
    _UbinLainnya(
      label: 'Kelola Kasir',
      ikon: Icons.badge_outlined,
      path: Rute.akunKasir,
      peran: _PeranWarna.sukses,
    ),
    _UbinLainnya(
      label: 'Riwayat Shift',
      ikon: Icons.schedule_outlined,
      path: Rute.riwayatShift,
      peran: _PeranWarna.peringatan,
    ),
    _UbinLainnya(
      label: 'Pengaturan',
      ikon: Icons.settings_outlined,
      path: Rute.pengaturan,
      peran: _PeranWarna.netral,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Rute.beranda);
            }
          },
        ),
        title: const Text('LAINNYA'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Semua modul dalam satu genggaman.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
              ),
                const SizedBox(height: 16),
                GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  for (final item in _menu) _Ubin(menu: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu ubin: ikon warna + label, ketuk untuk navigasi.
class _Ubin extends StatelessWidget {
  const _Ubin({required this.menu});

  final _UbinLainnya menu;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = switch (menu.peran) {
      _PeranWarna.aksen => skema.primary,
      _PeranWarna.sukses => skema.secondary,
      _PeranWarna.peringatan => skema.tertiary,
      _PeranWarna.bahaya => skema.error,
      _PeranWarna.netral => skema.onSurfaceVariant,
    };

    return KartuWarkop(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      saatDitekan: () {
        HapticFeedback.lightImpact();
        context.push(menu.path);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(menu.ikon, color: warna, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            menu.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';

/// Satu ubin menu: ikon + label + rute tujuan.
class _UbinLainnya {
  const _UbinLainnya({
    required this.label,
    required this.ikon,
    required this.path,
    required this.warna,
  });

  final String label;
  final IconData ikon;
  final String path;
  final Color warna;
}

/// Menu "Lainnya": grid 2 kolom berisi seluruh modul pendukung warkop.
///
/// Setiap ubin memakai KartuKaca tanpaBlur (hemat GPU di grid) dan
/// menavigasi ke rute modul yang bersangkutan.
class LayarLainnya extends ConsumerWidget {
  const LayarLainnya({super.key});

  static const _menu = <_UbinLainnya>[
    _UbinLainnya(
      label: 'Laporan',
      ikon: Icons.bar_chart_outlined,
      path: Rute.laporan,
      warna: WarnaWarkop.aksenTerang,
    ),
    _UbinLainnya(
      label: 'Daftar Belanja',
      ikon: Icons.shopping_cart_outlined,
      path: Rute.daftarBelanja,
      warna: WarnaWarkop.hijauAman,
    ),
    _UbinLainnya(
      label: 'Kasbon',
      ikon: Icons.handshake_outlined,
      path: Rute.kasbon,
      warna: WarnaWarkop.kuningAntre,
    ),
    _UbinLainnya(
      label: 'Kas Keluar',
      ikon: Icons.money_off_outlined,
      path: Rute.kasKeluar,
      warna: WarnaWarkop.merahMenyala,
    ),
    _UbinLainnya(
      label: 'Kombo',
      ikon: Icons.layers_outlined,
      path: Rute.kombo,
      warna: WarnaWarkop.aksenTerang,
    ),
    _UbinLainnya(
      label: 'Kategori',
      ikon: Icons.category_outlined,
      path: Rute.katalog,
      warna: WarnaWarkop.emas,
    ),
    _UbinLainnya(
      label: 'Kelola Kasir',
      ikon: Icons.badge_outlined,
      path: Rute.akunKasir,
      warna: WarnaWarkop.hijauAman,
    ),
    _UbinLainnya(
      label: 'Pengaturan',
      ikon: Icons.settings_outlined,
      path: Rute.pengaturan,
      warna: WarnaWarkop.teksSekunderTerang,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: OrbLatar(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Semua modul dalam satu genggaman.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: teksSekunder),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(menu.path);
        },
        child: KartuKaca(
          tanpaBlur: true,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: menu.warna.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(menu.ikon, color: menu.warna, size: 28),
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
        ),
      ),
    );
  }
}

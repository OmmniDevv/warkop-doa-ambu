import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../bersama/widget/tombol_tema.dart';

/// Layar pembuka — pilih peran sebelum masuk.
///
/// Owner memakai email + kata sandi, kasir memakai PIN.
/// Pilihan peran menentukan layar login berikutnya.
class LayarSelamatDatang extends ConsumerWidget {
  const LayarSelamatDatang({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = ref.watch(penyediaModeGelap);
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WARKOP DOA AMBU'),
        actions: const [TombolTema()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'WARKOP\nDOA AMBU',
                textAlign: TextAlign.center,
                style: TipografiWarkop.judulBrand.copyWith(
                  fontSize: 40,
                  height: 1.15,
                  color: aksen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistem kasir warkop — pilih peranmu dulu ya.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              KartuKaca(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TombolKaca(
                      label: 'Saya Owner',
                      ikon: Icons.storefront_outlined,
                      saatDitekan: () => context.go(Rute.masuk),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk dengan email & kata sandi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    TombolKaca(
                      label: 'Saya Kasir',
                      ikon: Icons.point_of_sale_outlined,
                      saatDitekan: () => context.go(Rute.kasir),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih profil lalu masuk dengan PIN.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

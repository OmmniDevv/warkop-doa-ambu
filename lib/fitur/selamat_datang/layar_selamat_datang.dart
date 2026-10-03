import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
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
    final teksUtama = gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Scaffold(
      body: OrbLatar(
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                right: 16,
                child: TombolTema(),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand serif besar.
                      Text(
                        'Warkop\nDoa Ambu',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              color: teksUtama,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sistem kasir warkop — pilih peranmu.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: teksRedup),
                      ),
                      const SizedBox(height: 36),
                      KartuKaca(
                        tingkat: TingkatKaca.kuat,
                        radius: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _tombolPeran(
                              context,
                              label: 'Saya Owner',
                              deskripsi: 'Masuk dengan email & kata sandi.',
                              ikon: Icons.storefront_outlined,
                              aksen: aksen,
                              utama: true,
                              saatDitekan: () => context.go(Rute.masuk),
                            ),
                            const SizedBox(height: 16),
                            _tombolPeran(
                              context,
                              label: 'Saya Kasir',
                              deskripsi: 'Pilih profil lalu masuk dengan PIN.',
                              ikon: Icons.point_of_sale_outlined,
                              aksen: aksen,
                              saatDitekan: () => context.go(Rute.kasir),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolPeran(
    BuildContext context, {
    required String label,
    required String deskripsi,
    required IconData ikon,
    required Color aksen,
    bool utama = false,
    required VoidCallback saatDitekan,
  }) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        saatDitekan();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: utama
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [aksen, WarnaWarkop.aksenGelapHover],
                )
              : null,
          color: utama
              ? null
              : (gelap
                  ? WarnaWarkop.kacaGelapRingan
                  : WarnaWarkop.kacaTerangRingan),
          border: utama
              ? null
              : Border.all(
                  color: gelap
                      ? WarnaWarkop.borderKacaGelap
                      : WarnaWarkop.borderKacaTerang,
                ),
          boxShadow: utama
              ? [
                  BoxShadow(
                    color: aksen.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: utama
                    ? Colors.white.withValues(alpha: 0.2)
                    : aksen.withValues(alpha: 0.12),
              ),
              child: Icon(
                ikon,
                color: utama ? Colors.white : aksen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: utama
                          ? Colors.white
                          : (gelap
                              ? WarnaWarkop.teksGelap
                              : WarnaWarkop.teksTerang),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deskripsi,
                    style: TextStyle(
                      fontSize: 13,
                      color: utama
                          ? Colors.white.withValues(alpha: 0.85)
                          : (gelap
                              ? WarnaWarkop.teksSekunderGelap
                              : WarnaWarkop.teksSekunderTerang),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: utama
                  ? Colors.white.withValues(alpha: 0.7)
                  : (gelap
                      ? WarnaWarkop.teksSekunderGelap
                      : WarnaWarkop.teksSekunderTerang),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../bersama/widget/tombol_warkop.dart';

/// Layar pembuka — pilih peran sebelum masuk.
///
/// Owner memakai email + kata sandi, kasir memakai PIN.
/// Pilihan peran menentukan layar login berikutnya.
class LayarSelamatDatang extends ConsumerWidget {
  const LayarSelamatDatang({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
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
                      style: TipografiWarkop.judulBrand.copyWith(
                        fontSize: 44,
                        color: skema.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sistem kasir warkop — pilih peranmu.',
                      textAlign: TextAlign.center,
                      style: gayaTeks.bodyMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TombolWarkop(
                      label: 'Saya Owner',
                      ikon: Icons.storefront_outlined,
                      saatDitekan: () {
                        HapticFeedback.lightImpact();
                        context.go(Rute.masuk);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk dengan email & kata sandi.',
                      textAlign: TextAlign.center,
                      style: gayaTeks.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    KartuWarkop(
                      saatDitekan: () {
                        HapticFeedback.lightImpact();
                        context.go(Rute.kasir);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  skema.primary.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.point_of_sale_outlined,
                              color: skema.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saya Kasir',
                                  style: gayaTeks.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pilih profil lalu masuk dengan PIN.',
                                  style: gayaTeks.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: skema.onSurfaceVariant,
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
    );
  }
}

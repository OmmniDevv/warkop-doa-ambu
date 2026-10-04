import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/orb_latar.dart';

/// Layar penolakan akses ramah saat peran mencoba membuka rute
/// yang bukan haknya (mis. owner membuka POS, kasir membuka dasbor).
///
/// Parameter query:
/// - `untuk`: 'kasir' | 'owner' — peran yang boleh mengakses.
/// - `kembali`: path tujuan tombol kembali.
class LayarAksesDitolak extends StatelessWidget {
  const LayarAksesDitolak({super.key});

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final untuk = params['untuk'] ?? 'kasir';
    final kembali = params['kembali'] ?? Rute.selamatDatang;

    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    final judul = untuk == 'kasir'
        ? 'Halaman ini hanya untuk kasir'
        : 'Halaman ini hanya untuk owner';

    final penjelasan = untuk == 'kasir'
        ? 'Hanya kasir yang boleh membuat transaksi dan memproses '
            'pembayaran — biar jelas siapa yang jualan.'
        : 'Halaman dasbor, stok, dan laporan hanya bisa dibuka oleh owner.';

    return Scaffold(
      body: OrbLatar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: aksen,
                ),
                const SizedBox(height: 20),
                Text(
                  judul,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  penjelasan,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: teksRedup),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.go(kembali);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

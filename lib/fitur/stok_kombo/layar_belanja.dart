import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';
import '../../data/model/log_audit.dart';
import 'layar_bahan.dart' show penyediaDaftarBahan;

/// Saran jumlah beli = stok_minimum × 2 − stok (tidak pernah negatif).
double saranBeliBahan(Bahan bahan) {
  final saran = bahan.stokMinimum * 2 - bahan.stok;
  return saran < 0 ? 0 : saran;
}

/// Layar daftar belanja otomatis: bahan yang menipis beserta saran
/// jumlah beli. Tandai "Sudah dibeli" untuk menambah stok bahan.
class LayarBelanja extends ConsumerWidget {
  const LayarBelanja({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bahanAsync = ref.watch(penyediaDaftarBahan);

    return Scaffold(
      appBar: AppBar(title: const Text('DAFTAR BELANJA')),
      body: OrbLatar(
        child: SafeArea(
          child: bahanAsync.when(
            data: (daftar) {
              final menipis =
                  daftar.where((b) => b.menipis).toList();
              return _IsiBelanja(daftar: menipis);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Gagal memuat bahan: $e')),
          ),
        ),
      ),
    );
  }
}

class _IsiBelanja extends ConsumerWidget {
  const _IsiBelanja({required this.daftar});

  final List<Bahan> daftar;

  Future<void> _sudahDibeli(
    BuildContext context,
    WidgetRef ref,
    Bahan bahan,
  ) async {
    HapticFeedback.lightImpact();
    final saran = saranBeliBahan(bahan);
    final kontrol = TextEditingController(
      text: saran == saran.roundToDouble()
          ? '${saran.toInt()}'
          : '$saran',
    );

    final jumlah = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sudah dibeli: ${bahan.nama}',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Stok sekarang: ${_tampil(bahan.stok)} ${bahan.satuan}',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kontrol,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Jumlah dibeli (${bahan.satuan})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final nilai = double.tryParse(
                      kontrol.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                Navigator.of(ctx).pop(nilai);
              },
              child: const Text('Tambah ke Stok'),
            ),
          ],
        ),
      ),
    );

    if (jumlah == null || jumlah <= 0) return;

    try {
      final db = DatabaseLokal.instance;
      await db.perbaruiBahan(bahan.copyWith(stok: bahan.stok + jumlah));
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'belanja.dibeli',
          idReferensi: bahan.id,
          detail: '{"jumlah":$jumlah,"satuan":"${bahan.satuan}"}',
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarBahan);
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stok ${bahan.nama} + ${_tampil(jumlah)} ${bahan.satuan}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah stok: $e')),
        );
      }
    }
  }

  String _tampil(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (daftar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: KartuKaca(
          tanpaBlur: true,
          border: null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semua bahan aman 🎉',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Tidak ada bahan yang menipis. '
                'Daftar belanja akan muncul otomatis saat stok mencapai batas minimum.',
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: KartuKaca(
            tanpaBlur: true,
            border: WarnaWarkop.kuningAntre.withValues(alpha: 0.45),
            child: Text(
              '${daftar.length} bahan menipis — saran beli dihitung '
              'dari batas minimum × 2.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: daftar.length,
            itemBuilder: (ctx, i) {
              final b = daftar[i];
              final saran = saranBeliBahan(b);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KartuKaca(
                  tanpaBlur: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: WarnaWarkop.kuningAntre.withValues(alpha: 0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.nama,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WarnaWarkop.kuningAntre
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: WarnaWarkop.kuningAntre
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'Menipis',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: WarnaWarkop.kuningAntre,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stok: ${_tampil(b.stok)} ${b.satuan} · '
                        'min. ${_tampil(b.stokMinimum)} ${b.satuan}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saran beli: ${_tampil(saran)} ${b.satuan}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: WarnaWarkop.aksenTerang,
                            ),
                      ),
                      const SizedBox(height: 10),
                      TombolKaca(
                        label: 'Sudah Dibeli',
                        ikon: Icons.shopping_cart_outlined,
                        saatDitekan: () => _sudahDibeli(context, ref, b),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

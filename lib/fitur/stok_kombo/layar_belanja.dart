import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_warkop.dart';
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
      body: SafeArea(
        child: bahanAsync.when(
          data: (daftar) {
            final menipis = daftar.where((b) => b.menipis).toList();
            return _IsiBelanja(daftar: menipis);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => StatusError(
            saatCobaLagi: () => ref.invalidate(penyediaDaftarBahan),
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
      text: saran == saran.roundToDouble() ? '${saran.toInt()}' : '$saran',
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
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            TombolWarkop(
              label: 'Tambah ke Stok',
              saatDitekan: () {
                final nilai =
                    double.tryParse(kontrol.text.trim().replaceAll(',', '.')) ??
                    0;
                Navigator.of(ctx).pop(nilai);
              },
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menambah stok: $e')));
      }
    }
  }

  String _tampil(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    if (daftar.isEmpty) {
      return const StatusKosong(
        judul: 'Semua bahan aman',
        deskripsi:
            'Tidak ada bahan yang menipis. '
            'Daftar belanja akan muncul otomatis saat stok mencapai '
            'batas minimum.',
        inisial: 'B',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: skema.tertiary.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: KartuWarkop(
              margin: const EdgeInsets.all(1.5),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: skema.tertiary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${daftar.length} bahan perlu dibeli — saran jumlahnya '
                      'dihitung otomatis, tinggal sesuaikan.',
                      style: gayaTeks.bodyMedium,
                    ),
                  ),
                ],
              ),
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: skema.tertiary.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: KartuWarkop(
                    margin: const EdgeInsets.all(1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.nama,
                                style: gayaTeks.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: skema.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: skema.tertiary.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: skema.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Menipis',
                                    style: gayaTeks.labelSmall?.copyWith(
                                      color: skema.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stok: ${_tampil(b.stok)} ${b.satuan} · '
                          'min. ${_tampil(b.stokMinimum)} ${b.satuan}',
                          style: gayaTeks.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saran beli: ${_tampil(saran)} ${b.satuan}',
                          style: gayaTeks.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: skema.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TombolWarkop(
                          label: 'Sudah Dibeli',
                          ikon: Icons.shopping_cart_outlined,
                          saatDitekan: () => _sudahDibeli(context, ref, b),
                        ),
                      ],
                    ),
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

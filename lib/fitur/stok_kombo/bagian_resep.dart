import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';
import '../../data/model/resep.dart';
import 'layar_bahan.dart' show penyediaDaftarBahan;

/// Daftar resep satu menu, dengan nama & satuan bahan.
final _penyediaResepMenu = FutureProvider.family<List<ResepLengkap>, String>(
  (ref, idMenu) => DatabaseLokal.instance.daftarResepMenu(idMenu),
);

/// Bagian kelola resep di form menu: daftar bahan + takaran per menu.
///
/// [idMenu] harus sudah final (untuk menu baru, hasilkan `idBaru()` di awal
/// form lalu pakai id yang sama saat menyimpan menu).
class BagianResep extends ConsumerWidget {
  const BagianResep({super.key, required this.idMenu});

  final String idMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resepAsync = ref.watch(_penyediaResepMenu(idMenu));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resep',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _tambahResep(context, ref),
              icon: const Icon(Icons.add_outlined, size: 18),
              label: const Text('Tambah bahan'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        resepAsync.when(
          data: (daftar) => daftar.isEmpty
              ? const KartuKaca(
                  tanpaBlur: true,
                  child: Text(
                    'Belum ada resep. Menu ini tidak mengurangi stok bahan.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              : Column(
                  children: [
                    for (final r in daftar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BarisResep(
                          resep: r,
                          saatHapus: () => _hapusResep(context, ref, r),
                        ),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Gagal memuat resep: $e'),
        ),
      ],
    );
  }

  Future<void> _tambahResep(BuildContext context, WidgetRef ref) async {
    final bahanAsync = ref.read(penyediaDaftarBahan);
    final daftar = bahanAsync.asData?.value ?? <Bahan>[];
    if (daftar.isEmpty) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada bahan. Tambahkan bahan dulu di layar Bahan.',
            ),
          ),
        );
      }
      return;
    }

    final sudahAda =
        (ref.read(_penyediaResepMenu(idMenu)).asData?.value ?? [])
            .map((r) => r.resep.idBahan)
            .toSet();
    final pilihan =
        daftar.where((b) => !sudahAda.contains(b.id)).toList();

    String? idBahan = pilihan.isEmpty ? null : pilihan.first.id;
    final kontrolTakaran = TextEditingController(text: '1');

    final simpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                'Tambah Bahan ke Resep',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (pilihan.isEmpty)
                const Text('Semua bahan sudah masuk resep menu ini.')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: idBahan,
                  decoration: const InputDecoration(
                    labelText: 'Bahan',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final b in pilihan)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.nama} (${b.satuan})'),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => idBahan = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kontrolTakaran,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Takaran (dalam satuan bahan)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: pilihan.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(true),
                child: const Text('Tambah'),
              ),
            ],
          ),
        ),
      ),
    );

    if (simpan != true || idBahan == null) return;

    final takaran = double.tryParse(
          kontrolTakaran.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    if (takaran <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takaran harus lebih dari 0.')),
        );
      }
      return;
    }

    try {
      await DatabaseLokal.instance.simpanResep(
        Resep(
          id: idBaru(),
          idMenu: idMenu,
          idBahan: idBahan!,
          takaran: takaran,
          diperbaruiPada: DateTime.now(),
        ),
      );
      ref.invalidate(_penyediaResepMenu(idMenu));
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah resep: $e')),
        );
      }
    }
  }

  Future<void> _hapusResep(
    BuildContext context,
    WidgetRef ref,
    ResepLengkap resep,
  ) async {
    try {
      await DatabaseLokal.instance.hapusResep(resep.resep.id);
      ref.invalidate(_penyediaResepMenu(idMenu));
      HapticFeedback.lightImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus resep: $e')),
        );
      }
    }
  }
}

class _BarisResep extends StatelessWidget {
  const _BarisResep({required this.resep, required this.saatHapus});

  final ResepLengkap resep;
  final VoidCallback saatHapus;

  @override
  Widget build(BuildContext context) {
    final takaran = resep.resep.takaran;
    final takaranTeks = takaran == takaran.roundToDouble()
        ? '${takaran.toInt()}'
        : '$takaran';

    return KartuKaca(
      tanpaBlur: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              resep.namaBahan,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$takaranTeks ${resep.satuan}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: WarnaWarkop.aksenTerang,
                ),
          ),
          IconButton(
            tooltip: 'Hapus dari resep',
            icon: const Icon(Icons.close_outlined, size: 20),
            onPressed: saatHapus,
          ),
        ],
      ),
    );
  }
}

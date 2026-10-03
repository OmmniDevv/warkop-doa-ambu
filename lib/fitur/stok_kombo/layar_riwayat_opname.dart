import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/stok_opname.dart';

/// Riwayat opname yang pernah dilakukan.
final _penyediaRiwayatOpname = FutureProvider<List<StokOpname>>(
  (ref) => DatabaseLokal.instance.daftarOpname(),
);

/// Layar riwayat stok opname: daftar catatan sistem vs fisik per item,
/// terbaru di atas.
class LayarRiwayatOpname extends ConsumerWidget {
  const LayarRiwayatOpname({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayatAsync = ref.watch(_penyediaRiwayatOpname);

    return Scaffold(
      appBar: AppBar(title: const Text('RIWAYAT OPNAME')),
      body: OrbLatar(
        child: SafeArea(
          child: riwayatAsync.when(
            data: (daftar) => daftar.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: KartuKaca(
                      tanpaBlur: true,
                      child: Text(
                        'Belum ada opname yang dicatat. '
                        'Mulai dari layar Stok Opname.',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: daftar.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BarisRiwayat(opname: daftar[i]),
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Gagal memuat riwayat: $e')),
          ),
        ),
      ),
    );
  }
}

class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.opname});

  final StokOpname opname;

  String _tampil(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  String _tanggal(DateTime w) {
    final t = w.toLocal();
    final jam =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.day}/${t.month}/${t.year} $jam';
  }

  @override
  Widget build(BuildContext context) {
    final selisih = opname.selisih;
    final berubah = selisih != 0;
    final warnaSelisih = !berubah
        ? WarnaWarkop.hijauAman
        : selisih < 0
            ? WarnaWarkop.merahMenyala
            : WarnaWarkop.kuningAntre;

    return KartuKaca(
      tanpaBlur: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opname.namaSnapshot,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${opname.tipeItem == 'menu' ? 'Menu' : 'Bahan'} · '
                      '${_tanggal(opname.dibuatPada)} · oleh ${opname.dibuatOleh}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: warnaSelisih.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: warnaSelisih.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${selisih >= 0 ? '+' : ''}${_tampil(selisih)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: warnaSelisih,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sistem: ${_tampil(opname.stokSistem)} → '
            'Fisik: ${_tampil(opname.stokFisik)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (opname.catatan != null && opname.catatan!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '“${opname.catatan}”',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

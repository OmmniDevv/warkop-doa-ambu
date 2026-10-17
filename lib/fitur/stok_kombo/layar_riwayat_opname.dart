import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bersama/util/waktu_wib.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
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
      body: SafeArea(
        child: riwayatAsync.when(
          data: (daftar) => daftar.isEmpty
              ? const StatusKosong(
                  judul: 'Belum ada riwayat opname',
                  deskripsi: 'Mulai dari layar Stok Opname.',
                  inisial: 'R',
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
          error: (e, _) => StatusError(
            saatCobaLagi: () => ref.invalidate(_penyediaRiwayatOpname),
          ),
        ),
      ),
    );
  }
}

/// Badge selisih opname: warna + ikon + teks.
class _BadgeSelisih extends StatelessWidget {
  const _BadgeSelisih({required this.selisih, required this.teks});

  final double selisih;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    final cocok = selisih == 0;
    final warna = cocok
        ? skema.secondary
        : selisih < 0
        ? skema.error
        : skema.tertiary;
    final ikon = cocok
        ? Icons.check_rounded
        : selisih < 0
        ? Icons.remove_rounded
        : Icons.add_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 4),
          Text(
            teks,
            style: gayaTeks.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final t = keWib(w);
    final jam =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.day}/${t.month}/${t.year} $jam';
  }

  @override
  Widget build(BuildContext context) {
    final selisih = opname.selisih;
    final gayaTeks = Theme.of(context).textTheme;

    return KartuWarkop(
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
                      style: gayaTeks.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${opname.tipeItem == 'menu' ? 'Menu' : 'Bahan'} · '
                      '${_tanggal(opname.dibuatPada)} · oleh ${opname.dibuatOleh}',
                      style: gayaTeks.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _BadgeSelisih(
                selisih: selisih,
                teks: '${selisih >= 0 ? '+' : ''}${_tampil(selisih)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sistem: ${_tampil(opname.stokSistem)} → '
            'Fisik: ${_tampil(opname.stokFisik)}',
            style: gayaTeks.bodyMedium,
          ),
          if (opname.catatan != null && opname.catatan!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '“${opname.catatan}”',
              style: gayaTeks.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';

/// Bahan yang sudah menipis (stok <= stok minimum), urut nama.
///
/// Bumbu TIDAK dicatat — hanya bahan utama yang muncul di sini.
final penyediaBahanMenipis = FutureProvider<List<Bahan>>((ref) async {
  final db = await DatabaseLokal.instance.db;
  final baris = await db.query(
    'bahan',
    where: 'apakah_dihapus = 0',
    orderBy: 'nama ASC',
  );
  final semua = baris.map(Bahan.dariBaris).toList();
  return semua.where((b) => b.menipis).toList();
});

/// Saran jumlah pembelian agar stok kembali ke batas minimum.
String formatSaranBeli(Bahan bahan) {
  final kurang = bahan.stokMinimum - bahan.stok;
  if (kurang <= 0) return '${_tampilAngka(bahan.stokMinimum)} ${bahan.satuan}';
  return '${_tampilAngka(kurang)} ${bahan.satuan}';
}

String _tampilAngka(double nilai) {
  if (nilai == nilai.truncateToDouble()) return nilai.toInt().toString();
  return nilai.toStringAsFixed(1);
}

/// Daftar belanja otomatis: bahan yang stoknya sudah mencapai batas
/// minimum. Tiap kartu menampilkan stok saat ini dan saran jumlah beli.
class LayarDaftarBelanja extends ConsumerWidget {
  const LayarDaftarBelanja({super.key});

  Future<void> _muatUlang(WidgetRef ref) async {
    ref.invalidate(penyediaBahanMenipis);
    await ref.read(penyediaBahanMenipis.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final bahanAsync = ref.watch(penyediaBahanMenipis);

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
        title: const Text('DAFTAR BELANJA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => _muatUlang(ref),
          ),
        ],
      ),
      body: OrbLatar(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _muatUlang(ref),
            child: bahanAsync.when(
              data: (daftar) {
                if (daftar.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 60),
                      KartuKaca(
                        tanpaBlur: true,
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 44,
                              color: WarnaWarkop.hijauAman,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Semua bahan masih aman.\n'
                              'Belum ada yang perlu dibeli.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: daftar.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${daftar.length} bahan perlu dibeli.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: teksSekunder),
                        ),
                      );
                    }
                    return _KartuBahan(bahan: daftar[i - 1]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 60),
                  KartuKaca(
                    tanpaBlur: true,
                    child: Text(
                      'Gagal memuat daftar belanja.\nTarik ke bawah untuk mencoba lagi.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu kartu bahan: nama, stok saat ini, batas minimum, saran beli.
class _KartuBahan extends StatelessWidget {
  const _KartuBahan({required this.bahan});

  final Bahan bahan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final habis = bahan.stok <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KartuKaca(
        tanpaBlur: true,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (habis ? WarnaWarkop.merahMenyala : WarnaWarkop.kuningAntre)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                habis
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.shopping_cart_outlined,
                color: habis
                    ? WarnaWarkop.merahMenyala
                    : WarnaWarkop.kuningAntre,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bahan.nama,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${_tampilAngka(bahan.stok)} ${bahan.satuan} · '
                    'Min: ${_tampilAngka(bahan.stokMinimum)} ${bahan.satuan}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: teksSekunder),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Saran beli: ${formatSaranBeli(bahan)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: aksen,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (bahan.hargaBeli > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Harga beli terakhir: ${formatRupiah(bahan.hargaBeli)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: teksSekunder),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (habis
                        ? WarnaWarkop.merahMenyala
                        : WarnaWarkop.kuningAntre)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (habis
                          ? WarnaWarkop.merahMenyala
                          : WarnaWarkop.kuningAntre)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                habis ? 'Habis' : 'Menipis',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: habis
                          ? WarnaWarkop.merahMenyala
                          : WarnaWarkop.kuningAntre,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

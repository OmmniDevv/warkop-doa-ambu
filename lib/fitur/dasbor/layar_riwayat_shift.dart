import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/shift_kasir.dart';

/// Satu baris riwayat shift + nama kasir.
class BarisRiwayatShift {
  const BarisRiwayatShift({required this.shift, required this.namaKasir});

  final ShiftKasir shift;
  final String namaKasir;
}

/// Riwayat seluruh shift kasir untuk owner.
///
/// Menampilkan: tanggal, kasir, kas awal, kas akhir (sistem & fisik),
/// selisih, status. Penting untuk akuntabilitas uang.
final penyediaRiwayatShift =
    FutureProvider<List<BarisRiwayatShift>>((ref) async {
  final baris = await DatabaseLokal.instance.daftarRiwayatShift();
  return baris.map((b) {
    final peta = Map<String, Object?>.from(b)..remove('nama_kasir');
    return BarisRiwayatShift(
      shift: ShiftKasir.dariMap(peta),
      namaKasir: (b['nama_kasir'] as String?) ?? '-',
    );
  }).toList();
});

/// Layar riwayat shift (owner): daftar buka/tutup shift semua kasir.
class LayarRiwayatShift extends ConsumerWidget {
  const LayarRiwayatShift({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayatAsync = ref.watch(penyediaRiwayatShift);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RIWAYAT SHIFT'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Rute.dasbor);
            }
          },
        ),
      ),
      body: OrbLatar(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(penyediaRiwayatShift);
              await ref.read(penyediaRiwayatShift.future);
            },
            child: riwayatAsync.when(
              data: (daftar) {
                if (daftar.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: const [
                      SizedBox(height: 60),
                      KartuKaca(
                        tanpaBlur: true,
                        child: Text(
                          'Belum ada riwayat shift.\n'
                          'Shift tercatat setiap kasir buka/tutup shift.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  itemCount: daftar.length,
                  itemBuilder: (context, i) =>
                      _KartuShift(baris: daftar[i], aksen: aksen),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('Gagal memuat riwayat: $e'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuShift extends StatelessWidget {
  const _KartuShift({required this.baris, required this.aksen});

  final BarisRiwayatShift baris;
  final Color aksen;

  @override
  Widget build(BuildContext context) {
    final shift = baris.shift;
    final buka = shift.status == 'buka';
    final selisih = shift.selisih;
    final warnaSelisih = selisih == null
        ? null
        : selisih == 0
            ? WarnaWarkop.hijauAman
            : WarnaWarkop.merahMenyala;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KartuKaca(
        tanpaBlur: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    baris.namaKasir,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: (buka
                            ? WarnaWarkop.kuningAntre
                            : WarnaWarkop.hijauAman)
                        .withValues(alpha: 0.15),
                  ),
                  child: Text(
                    buka ? 'Buka' : 'Tutup',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: buka
                              ? WarnaWarkop.kuningAntre
                              : WarnaWarkop.hijauAman,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Buka: ${_formatTanggalWaktuStatic(shift.dibukaPada)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: teksRedup),
            ),
            if (shift.ditutupPada != null)
              Text(
                'Tutup: ${_formatTanggalWaktuStatic(shift.ditutupPada!)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: teksRedup),
              ),
            const Divider(height: 20),
            _BarisNominal(label: 'Kas awal', nilai: formatRupiah(shift.saldoAwal)),
            _BarisNominal(
              label: 'Kas akhir (sistem)',
              nilai: formatRupiah(shift.kasAkhirSistem),
            ),
            if (shift.kasAkhirFisik != null)
              _BarisNominal(
                label: 'Kas akhir (fisik)',
                nilai: formatRupiah(shift.kasAkhirFisik!),
              ),
            if (selisih != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selisih',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      formatRupiah(selisih),
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: warnaSelisih,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTanggalWaktuStatic(DateTime waktu) {
    final wib = keWib(waktu);
    final tgl =
        '${wib.day.toString().padLeft(2, '0')}/${wib.month.toString().padLeft(2, '0')}/${wib.year}';
    final jam = '${wib.hour.toString().padLeft(2, '0')}:'
        '${wib.minute.toString().padLeft(2, '0')}';
    return '$tgl $jam WIB';
  }
}

class _BarisNominal extends StatelessWidget {
  const _BarisNominal({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            nilai,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/open_bill.dart';
import '../../bersama/util/waktu_wib.dart';

/// Daftar open bill yang masih buka, terbaru dulu.
final daftarOpenBillProvider = FutureProvider<List<OpenBill>>((ref) async {
  return DatabaseLokal.instance.daftarOpenBillAktif();
});

/// Ringkasan satu tagihan: jumlah nota & total berjalan (nota void dikecualikan).
class RingkasanTagihan {
  const RingkasanTagihan({
    required this.jumlahPesanan,
    required this.totalBerjalan,
  });

  final int jumlahPesanan;
  final int totalBerjalan;
}

final ringkasanTagihanProvider =
    FutureProvider.family<RingkasanTagihan, String>((ref, idTagihan) async {
  final semua = await DatabaseLokal.instance.daftarPesanan();
  final milik = semua.where((p) => p.idOpenBill == idTagihan);
  final aktif = milik.where((p) => p.status != 'void');
  return RingkasanTagihan(
    jumlahPesanan: milik.length,
    totalBerjalan: aktif.fold(0, (jumlah, p) => jumlah + p.total),
  );
});

/// Waktu singkat: "4 Okt 00:18".
String formatWaktuSingkat(DateTime waktu) {
  const namaBulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final lokal = keWib(waktu);
  final jam = lokal.hour.toString().padLeft(2, '0');
  final menit = lokal.minute.toString().padLeft(2, '0');
  return '${lokal.day} ${namaBulan[lokal.month - 1]} $jam:$menit';
}

/// Daftar seluruh tagihan terbuka. Ketuk kartu untuk membuka detail.
class LayarDaftarTagihan extends ConsumerWidget {
  const LayarDaftarTagihan({super.key});

  Future<void> _muatUlang(WidgetRef ref) async {
    ref.invalidate(daftarOpenBillProvider);
    ref.invalidate(ringkasanTagihanProvider);
    // Tunggu data segar agar RefreshIndicator selesai tepat waktu.
    await ref.read(daftarOpenBillProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftarAsync = ref.watch(daftarOpenBillProvider);

    return Scaffold(
      // AppBar transparan di atas OrbLatar — desain kaca menyatu.
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
              // Layar ini hanya dipakai kasir (shell kasir).
              context.go(Rute.kasirTagihan);
            }
          },
        ),
        title: const Text('TAGIHAN TERBUKA'),
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
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _muatUlang(ref),
                  child: daftarAsync.when(
                    data: (daftar) {
                      if (daftar.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: const [
                            SizedBox(height: 60),
                            KartuKaca(
                              tanpaBlur: true,
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 44, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada tagihan terbuka.\n'
                                    'Buat tagihan baru untuk mulai mencatat.',
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        itemCount: daftar.length,
                        itemBuilder: (context, i) =>
                            _KartuTagihan(tagihan: daftar[i]),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: const [
                        SizedBox(height: 60),
                        KartuKaca(
                          tanpaBlur: true,
                          child: Text(
                            'Gagal memuat tagihan.\nTarik ke bawah untuk mencoba lagi.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: TombolKaca(
                  label: 'Tagihan Baru',
                  ikon: Icons.add,
                  saatDitekan: () {
                    HapticFeedback.lightImpact();
                    context.go(Rute.tagihanBaru);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu kartu tagihan: label, jumlah nota, total berjalan, waktu update.
class _KartuTagihan extends ConsumerWidget {
  const _KartuTagihan({required this.tagihan});

  final OpenBill tagihan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final ringkasanAsync = ref.watch(ringkasanTagihanProvider(tagihan.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/tagihan/${tagihan.id}');
          },
          child: KartuKaca(
            tanpaBlur: true,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tagihan.label,
                        style: TipografiWarkop.judulBrand.copyWith(
                          fontSize: 18,
                          color: aksen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ringkasanAsync.when(
                        data: (ringkasan) => Text(
                          '${ringkasan.jumlahPesanan} nota · '
                          '${formatRupiah(ringkasan.totalBerjalan)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: teksSekunder),
                        ),
                        loading: () => Text(
                          'Memuat…',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: teksSekunder),
                        ),
                        error: (_, __) => Text(
                          'Ringkasan gagal dimuat',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: teksSekunder),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diperbarui ${formatWaktuSingkat(tagihan.diperbaruiPada)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: teksSekunder),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: teksSekunder),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

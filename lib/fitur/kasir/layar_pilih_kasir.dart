import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../data/model/akun.dart';
import '../stok_kombo/mesin_sinkron.dart';
import '../../fitur/dasbor/util_tanggal.dart';

/// Layar pemilihan kasir — gerbang masuk sebelum PIN.
///
/// Menampilkan daftar akun dengan peran 'kasir' yang aktif sebagai kartu
/// daftar (avatar inisial + nama). Tap kartu → lanjut ke PIN kasir.
/// Saat dibuka, coba unduh akun terbaru dari server dulu (agar akun yang
/// dibuat owner tetap muncul setelah reinstall).
class LayarPilihKasir extends ConsumerWidget {
  const LayarPilihKasir({super.key});

  /// Muat daftar kasir + info sinkron akun terakhir (dibaca SETELAH
  /// sinkron selesai agar status "Terakhir sinkron" akurat).
  Future<({List<Akun> daftar, InfoUnduhAkun? info})> _muatKasir(
      WidgetRef ref) async {
    // Coba sinkron (termasuk unduh akun) dulu; gagal = lanjut offline.
    try {
      await MesinSinkron().sinkronkan();
    } catch (_) {
      // Abaikan — pakai data lokal.
    }
    final info = await MesinSinkron.bacaInfoUnduhAkun();
    final semua = await ref.read(penyediaDatabaseLokal).daftarAkun(
          hanyaAktif: true,
        );
    final daftar = semua
        .where((a) => a.peran == 'kasir' && a.aktif && !a.apakahDihapus)
        .toList();
    return (daftar: daftar, info: info);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PILIH KASIR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke beranda',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(Rute.selamatDatang);
          },
        ),
        actions: const [TombolTema()],
      ),
      body: SafeArea(
        child: FutureBuilder<({List<Akun> daftar, InfoUnduhAkun? info})>(
          future: _muatKasir(ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PesanTengah(
                ikon: Icons.cloud_off_outlined,
                judul: 'Gagal memuat daftar kasir.',
                tombol: const Text('Kembali'),
                // Layar ini dibuka via context.go (mengganti rute), jadi
                // tidak ada tumpukan untuk di-pop — kembali eksplisit.
                saatTombol: () => context.go(Rute.selamatDatang),
              );
            }

            final hasil = snapshot.data;
            final daftar = hasil?.daftar ?? [];
            final info = hasil?.info;
            if (daftar.isEmpty) {
              return _PesanTengah(
                ikon: Icons.person_add_alt_outlined,
                judul: 'Belum ada akun kasir.\n'
                    'Minta owner membuatnya di menu Kelola Akun.',
                tombol: const Text('Kembali'),
                saatTombol: () {
                  HapticFeedback.lightImpact();
                  context.go(Rute.selamatDatang);
                },
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Siapa yang bertugas hari ini?',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: aksen),
                  ),
                ),
                _StatusSinkronAkun(info: info),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: daftar.length,
                    itemBuilder: (context, i) {
                      final akun = daftar[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _KartuKasir(
                          akun: akun,
                          aksen: aksen,
                          saatTap: () {
                            HapticFeedback.lightImpact();
                            context.go('/kasir/pin/${akun.id}');
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Banner status unduhan akun kasir.
///
/// Agar user tahu daftar kasir fresh dari server — bukan data basi.
/// Menampilkan peringatan bila belum pernah mengunduh / gagal beruntun.
/// [info] dibaca SETELAH sinkron selesai agar akurat.
class _StatusSinkronAkun extends StatelessWidget {
  const _StatusSinkronAkun({required this.info});

  final InfoUnduhAkun? info;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksRedup = gelap
        ? WarnaWarkop.teksSekunderGelap
        : WarnaWarkop.teksSekunderTerang;

    late final String teks;
    late final IconData ikon;
    late final Color warna;
    if (info == null) {
      teks = 'Belum pernah ambil data kasir dari server';
      ikon = Icons.cloud_off_outlined;
      warna = WarnaWarkop.merahMenyala;
    } else if (info!.gagalBeruntun > 0) {
      teks = 'Gagal ambil data kasir ${info!.gagalBeruntun}x — '
          'dicoba lagi otomatis';
      ikon = Icons.sync_problem_outlined;
      warna = WarnaWarkop.merahMenyala;
    } else {
      teks = 'Terakhir ambil data: ${formatTanggalWaktu(info!.waktu)} '
          '• ${info!.jumlah} akun';
      ikon = Icons.cloud_done_outlined;
      warna = WarnaWarkop.hijauAman;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              teks,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: teksRedup),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu daftar satu kasir: avatar inisial + nama + panah.
class _KartuKasir extends StatelessWidget {
  const _KartuKasir({
    required this.akun,
    required this.aksen,
    required this.saatTap,
  });

  final Akun akun;
  final Color aksen;
  final VoidCallback saatTap;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final inisial =
        akun.nama.trim().isEmpty ? '?' : akun.nama.trim()[0].toUpperCase();

    return KartuKaca(
      tanpaBlur: true,
      bayangan: false,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: saatTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: aksen.withValues(alpha: 0.15),
                border: Border.all(color: aksen, width: 1.5),
              ),
              child: Text(
                inisial,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                akun.nama,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: gelap
                  ? WarnaWarkop.teksSekunderGelap
                  : WarnaWarkop.teksSekunderTerang,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pesan tengah layar dengan ikon + tombol aksi.
class _PesanTengah extends StatelessWidget {
  const _PesanTengah({
    required this.ikon,
    required this.judul,
    required this.tombol,
    required this.saatTombol,
  });

  final IconData ikon;
  final String judul;
  final Widget tombol;
  final VoidCallback saatTombol;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 64, color: aksen),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: saatTombol,
                style: OutlinedButton.styleFrom(
                  foregroundColor: aksen,
                  side: BorderSide(color: aksen),
                  minimumSize: const Size(0, 52),
                ),
                child: tombol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

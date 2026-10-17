import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
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
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Kasir'),
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
              // Layar ini dibuka via context.go (mengganti rute), jadi
              // tidak ada tumpukan untuk di-pop — kembali eksplisit.
              return StatusError(
                pesan: 'Gagal memuat daftar kasir.',
                labelTombol: 'Kembali',
                saatCobaLagi: () => context.go(Rute.selamatDatang),
              );
            }

            final hasil = snapshot.data;
            final daftar = hasil?.daftar ?? [];
            final info = hasil?.info;
            if (daftar.isEmpty) {
              return StatusKosong(
                judul: 'Belum ada akun kasir',
                deskripsi:
                    'Minta owner membuatnya di menu Kelola Akun.',
                inisial: '?',
                labelAksi: 'Kembali',
                saatAksi: () {
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
                    style: gayaTeks.titleMedium?.copyWith(
                      color: skema.primary,
                      fontWeight: FontWeight.w700,
                    ),
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
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    late final String teks;
    late final IconData ikon;
    late final Color warna;
    if (info == null) {
      teks = 'Belum pernah ambil data kasir dari server';
      ikon = Icons.cloud_off_outlined;
      warna = skema.error;
    } else if (info!.gagalBeruntun > 0) {
      teks = 'Gagal ambil data kasir ${info!.gagalBeruntun}x — '
          'dicoba lagi otomatis';
      ikon = Icons.sync_problem_outlined;
      warna = skema.error;
    } else {
      teks = 'Terakhir ambil data: ${formatTanggalWaktu(info!.waktu)} '
          '• ${info!.jumlah} akun';
      ikon = Icons.cloud_done_outlined;
      warna = skema.secondary;
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
              style: gayaTeks.bodySmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
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
    required this.saatTap,
  });

  final Akun akun;
  final VoidCallback saatTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;
    final inisial =
        akun.nama.trim().isEmpty ? '?' : akun.nama.trim()[0].toUpperCase();

    return KartuWarkop(
      saatDitekan: saatTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: skema.primary.withValues(alpha: 0.15),
              border: Border.all(color: skema.primary, width: 1.5),
            ),
            child: Text(
              inisial,
              style: gayaTeks.headlineSmall?.copyWith(
                color: skema.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              akun.nama,
              style: gayaTeks.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: skema.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

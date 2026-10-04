import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import 'layanan_izin.dart';

/// Layar penjelasan izin di awal setelah login.
///
/// Menampilkan daftar izin yang dibutuhkan beserta alasannya.
/// User bisa izinkan satu per satu atau lewati. Status "sudah ditampilkan"
/// disimpan agar tidak muncul berulang.
class LayarIzinAwal extends StatefulWidget {
  const LayarIzinAwal({super.key});

  @override
  State<LayarIzinAwal> createState() => _LayarIzinAwalState();
}

class _LayarIzinAwalState extends State<LayarIzinAwal> {
  late List<StatusIzin> _daftar;
  bool _memuat = true;
  bool _memproses = false;

  @override
  void initState() {
    super.initState();
    _muatStatus();
  }

  Future<void> _muatStatus() async {
    final daftar = LayananIzin.daftarIzin();
    final hasil = <StatusIzin>[];
    for (final item in daftar) {
      final status = await item.izin.status;
      hasil.add(item.salin(
        diberikan: status.isGranted || status.isLimited,
      ));
    }
    if (mounted) {
      setState(() {
        _daftar = hasil;
        _memuat = false;
      });
    }
  }

  Future<void> _mintaSemua() async {
    if (_memproses) return;
    setState(() => _memproses = true);
    final hasil = <StatusIzin>[];
    for (final item in _daftar) {
      final diberikan = await LayananIzin.minta(item.izin);
      hasil.add(item.salin(diberikan: diberikan));
    }
    if (mounted) {
      setState(() {
        _daftar = hasil;
        _memproses = false;
      });
    }
  }

  Future<void> _selesai() async {
    await LayananIzin.tandaiSudahDiminta();
    if (!mounted) return;
    // Lanjut ke tujuan semula (dari query ?lanjut=), default ke beranda.
    final lanjut =
        GoRouterState.of(context).uri.queryParameters['lanjut'];
    context.go(lanjut ?? Rute.selamatDatang);
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Scaffold(
      body: OrbLatar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.security_outlined, size: 56, color: aksen),
                const SizedBox(height: 16),
                Text(
                  'Izin Aplikasi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agar semua fitur berjalan lancar, '
                  'Warkop Doa Ambu butuh beberapa izin berikut.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: teksRedup),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _memuat
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _daftar.length,
                          itemBuilder: (context, i) {
                            final item = _daftar[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _KartuIzin(
                                item: item,
                                aksen: aksen,
                                teksRedup: teksRedup,
                                saatMinta: () async {
                                  final diberikan =
                                      await LayananIzin.minta(item.izin);
                                  if (mounted) {
                                    setState(() {
                                      _daftar[i] = item.salin(
                                        diberikan: diberikan,
                                      );
                                    });
                                  }
                                },
                                saatBukaPengaturan: () =>
                                    LayananIzin.bukaPengaturan(),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                TombolKaca(
                  label: 'Izinkan Semua',
                  ikon: Icons.check_circle_outline,
                  memuat: _memproses,
                  saatDitekan: _mintaSemua,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _selesai,
                  child: const Text('Lewati dulu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuIzin extends StatelessWidget {
  const _KartuIzin({
    required this.item,
    required this.aksen,
    required this.teksRedup,
    required this.saatMinta,
    required this.saatBukaPengaturan,
  });

  final StatusIzin item;
  final Color aksen;
  final Color teksRedup;
  final VoidCallback saatMinta;
  final VoidCallback saatBukaPengaturan;

  IconData _ikonUntuk(String nama) {
    return switch (nama) {
      'notifikasi' => Icons.notifications_outlined,
      'kamera' => Icons.camera_alt_outlined,
      'penyimpanan' => Icons.folder_outlined,
      _ => Icons.security_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      tanpaBlur: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: aksen.withValues(alpha: 0.12),
            ),
            child: Icon(_ikonUntuk(item.ikon), color: aksen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nama,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  item.penjelasan,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: teksRedup),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.diberikan)
            Icon(Icons.check_circle, color: WarnaWarkop.hijauAman)
          else
            FutureBuilder<bool>(
              future: LayananIzin.ditolakPermanen(item.izin),
              builder: (context, snapshot) {
                final permanen = snapshot.data ?? false;
                return TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (permanen) {
                      saatBukaPengaturan();
                    } else {
                      saatMinta();
                    }
                  },
                  child: Text(permanen ? 'Pengaturan' : 'Izinkan'),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../dasbor/direktori_ekspor.dart';

/// Status folder export pilihan user (untuk refresh tampilan).
final penyediaFolderEkspor =
    FutureProvider<String>((ref) async {
  return DirektoriEkspor.labelFolderAktif();
});

/// Kartu pengaturan folder penyimpanan laporan (PDF & Excel).
///
/// Menampilkan folder aktif + tombol pilih folder + kembalikan ke default.
class _KartuFolderEkspor extends ConsumerWidget {
  const _KartuFolderEkspor({required this.teksSekunder});

  final Color teksSekunder;

  Future<void> _pilihFolder(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Pilih folder penyimpanan laporan',
    );
    if (path == null) return; // User batal.
    await DirektoriEkspor.simpanFolderKustom(path);
    ref.invalidate(penyediaFolderEkspor);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder export: $path')),
      );
    }
  }

  Future<void> _kembalikanDefault(BuildContext context, WidgetRef ref) async {
    await DirektoriEkspor.simpanFolderKustom(null);
    ref.invalidate(penyediaFolderEkspor);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kembali ke folder default Documents/WarkopDoaAmbu')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderAsync = ref.watch(penyediaFolderEkspor);

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: WarnaWarkop.aksenTerang,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Folder Penyimpanan Laporan',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          folderAsync.when(
            data: (path) => Text(
              path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: teksSekunder,
                    fontFamily: 'monospace',
                  ),
            ),
            loading: () => const SizedBox(
              height: 16,
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('Gagal memuat folder.'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pilihFolder(context, ref),
                  icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
                  label: const Text('Pilih Folder'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _kembalikanDefault(context, ref),
                tooltip: 'Kembalikan ke default',
                icon: const Icon(Icons.restart_alt_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Layar pengaturan: tema, info profil warkop, dan keluar.
class LayarPengaturan extends ConsumerWidget {
  const LayarPengaturan({super.key});

  Future<void> _keluar(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Kamu akan keluar dari akun owner di perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true || !context.mounted) return;
    await ref.read(penyediaServiceAuthOwner).keluar();
    segarkanProfil(ref);
    if (context.mounted) context.go(Rute.masuk);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = ref.watch(penyediaModeGelap);
    final profilAsync = ref.watch(penyediaProfilPemilik);
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

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
        title: const Text('PENGATURAN'),
      ),
      body: OrbLatar(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Kartu profil warkop ────────────────────────────────
                profilAsync.when(
                  data: (profil) {
                    if (profil == null) return const SizedBox.shrink();
                    return KartuKaca(
                      tanpaBlur: true,
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: WarnaWarkop.aksenTerang
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.storefront_outlined,
                              color: WarnaWarkop.aksenTerang,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profil.namaWarkop,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${profil.namaPemilik}\n${profil.email}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: teksSekunder),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // ── Tema ─────────────────────────────────────────────
                KartuKaca(
                  tanpaBlur: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode Gelap'),
                    subtitle: Text(
                      gelap ? 'Mata lebih adem di malam hari.' : 'Terang dan bersih.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: teksSekunder),
                    ),
                    secondary: Icon(
                      gelap
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: WarnaWarkop.aksenTerang,
                    ),
                    value: gelap,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      ref.read(penyediaModeGelap.notifier).alihkan();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // ── Folder export laporan ────────────────────────────
                _KartuFolderEkspor(teksSekunder: teksSekunder),
                const SizedBox(height: 16),
                // ── Tentang ──────────────────────────────────────────
                KartuKaca(
                  tanpaBlur: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tentang Aplikasi',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Warkop Doa Ambu — kasir offline-first untuk warkop.\n'
                        'Data tersimpan di perangkat dan tersinkron ke cloud.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: teksSekunder),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Keluar ───────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: () => _keluar(context, ref),
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Keluar dari Akun Owner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WarnaWarkop.merahMenyala,
                    side: BorderSide(
                      color: WarnaWarkop.merahMenyala.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

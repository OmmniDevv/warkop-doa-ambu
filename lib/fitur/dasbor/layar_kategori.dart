import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/log_audit.dart';
import 'penyedia_katalog.dart';

/// Layar kategori owner: daftar + tambah + ganti nama (tap) +
/// aktif/nonaktif (switch).
///
/// Dipisah dari layar Menu agar tiap modul punya fokus sendiri.
class LayarKategori extends ConsumerWidget {
  const LayarKategori({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriAsync = ref.watch(penyediaDaftarKategori);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KATEGORI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Rute.lainnya);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: kategoriAsync.when(
                data: (daftar) {
                  if (daftar.isEmpty) {
                    return const Center(
                      child: Text('Belum ada kategori. Tambah dulu ya.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daftar.length,
                    itemBuilder: (context, i) =>
                        _BarisKategori(kategori: daftar[i]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Gagal memuat kategori: $e')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TombolKaca(
                label: 'Tambah Kategori',
                ikon: Icons.add_outlined,
                saatDitekan: () => _tambahKategori(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tambahKategori(BuildContext context, WidgetRef ref) async {
    final nama = await mintaNamaKategori(context, judul: 'Tambah Kategori');
    if (nama == null || nama.isEmpty) return;

    final db = DatabaseLokal.instance;
    try {
      final daftar = await db.daftarKategori();
      var urutan = 1;
      for (final k in daftar) {
        if (k.urutanTampil >= urutan) urutan = k.urutanTampil + 1;
      }
      final id = idBaru();
      await db.simpanKategori(
        KategoriMenu(
          id: id,
          nama: nama,
          urutanTampil: urutan,
          aktif: true,
          statusSinkron: 'tertunda',
          diperbaruiPada: DateTime.now(),
        ),
      );
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'tambah_kategori',
          idReferensi: id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarKategori);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah kategori: $e')),
        );
      }
    }
  }
}

class _BarisKategori extends ConsumerWidget {
  const _BarisKategori({required this.kategori});

  final KategoriMenu kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuKaca(
        tanpaBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            kategori.nama,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(kategori.aktif ? 'Aktif' : 'Nonaktif'),
          onTap: () => _gantiNama(context, ref),
          trailing: Switch.adaptive(
            value: kategori.aktif,
            onChanged: (nilai) => _alihkanAktif(context, ref, nilai),
          ),
        ),
      ),
    );
  }

  Future<void> _gantiNama(BuildContext context, WidgetRef ref) async {
    final nama = await mintaNamaKategori(
      context,
      judul: 'Ganti Nama Kategori',
      awal: kategori.nama,
    );
    if (nama == null || nama.isEmpty || nama == kategori.nama) return;

    final db = DatabaseLokal.instance;
    try {
      await db.perbaruiKategori(kategori.copyWith(nama: nama));
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'ubah_kategori',
          idReferensi: kategori.id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarKategori);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengganti nama: $e')),
        );
      }
    }
  }

  Future<void> _alihkanAktif(
    BuildContext context,
    WidgetRef ref,
    bool nilai,
  ) async {
    final db = DatabaseLokal.instance;
    try {
      await db.perbaruiKategori(kategori.copyWith(aktif: nilai));
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: nilai ? 'aktifkan_kategori' : 'nonaktifkan_kategori',
          idReferensi: kategori.id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarKategori);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    }
  }
}

/// Dialog input nama kategori; mengembalikan nama atau null bila batal.
Future<String?> mintaNamaKategori(
  BuildContext context, {
  String? awal,
  required String judul,
}) {
  final kontrol = TextEditingController(text: awal ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: TextField(
        controller: kontrol,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama kategori',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) {
          final teks = kontrol.text.trim();
          if (teks.isNotEmpty) Navigator.of(ctx).pop(teks);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final teks = kontrol.text.trim();
            if (teks.isEmpty) return;
            Navigator.of(ctx).pop(teks);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  ).whenComplete(kontrol.dispose);
}

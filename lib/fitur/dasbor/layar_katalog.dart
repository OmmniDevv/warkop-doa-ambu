import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/menu.dart';

/// Daftar kategori aktif, urut tampilan.
final penyediaDaftarKategori = FutureProvider<List<KategoriMenu>>((ref) async {
  return DatabaseLokal.instance.daftarKategori();
});

/// Seluruh menu; filter kategori dilakukan di UI agar invalidasi sederhana.
final penyediaSemuaMenu = FutureProvider<List<Menu>>((ref) async {
  return DatabaseLokal.instance.daftarMenu();
});

/// Layar katalog owner: kelola kategori & menu yang dijual.
///
/// Tab "Kategori": daftar + tambah + ganti nama (tap) + aktif/nonaktif.
/// Tab "Menu": filter chip kategori + daftar + tambah/ubah + nonaktifkan.
class LayarKatalog extends ConsumerWidget {
  const LayarKatalog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('KATALOG'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kategori'),
              Tab(text: 'Menu'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _TabKategori(),
              _TabMenu(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab Kategori ───────────────────────────────────────────────────

class _TabKategori extends ConsumerWidget {
  const _TabKategori();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriAsync = ref.watch(penyediaDaftarKategori);

    return Column(
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat kategori: $e')),
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
    );
  }

  Future<void> _tambahKategori(BuildContext context, WidgetRef ref) async {
    final nama = await _mintaNamaKategori(context, judul: 'Tambah Kategori');
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
        pakaiBlur: false,
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
    final nama = await _mintaNamaKategori(
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
Future<String?> _mintaNamaKategori(
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

// ── Tab Menu ───────────────────────────────────────────────────────

class _TabMenu extends ConsumerStatefulWidget {
  const _TabMenu();

  @override
  ConsumerState<_TabMenu> createState() => _TabMenuState();
}

class _TabMenuState extends ConsumerState<_TabMenu> {
  /// null = semua kategori.
  String? _idKategori;

  @override
  Widget build(BuildContext context) {
    final kategoriAsync = ref.watch(penyediaDaftarKategori);
    final menuAsync = ref.watch(penyediaSemuaMenu);

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: kategoriAsync.when(
            data: (kategori) => ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _ChipFilter(
                  label: 'Semua',
                  terpilih: _idKategori == null,
                  saatPilih: () => setState(() => _idKategori = null),
                ),
                for (final k in kategori)
                  _ChipFilter(
                    label: k.nama,
                    terpilih: _idKategori == k.id,
                    saatPilih: () => setState(() => _idKategori = k.id),
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: menuAsync.when(
            data: (semua) {
              final daftar = semua
                  .where(
                    (m) => _idKategori == null || m.idKategori == _idKategori,
                  )
                  .toList();
              if (daftar.isEmpty) {
                return const Center(
                  child: Text('Belum ada menu di sini. Tambah dulu ya.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: daftar.length,
                itemBuilder: (context, i) => _BarisMenu(
                  menu: daftar[i],
                  saatUbah: () => _bukaFormMenu(daftar[i]),
                  saatHapus: () => _nonaktifkanMenu(daftar[i]),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat menu: $e')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TombolKaca(
            label: 'Tambah Menu',
            ikon: Icons.add_outlined,
            saatDitekan: () => _bukaFormMenu(null),
          ),
        ),
      ],
    );
  }

  void _bukaFormMenu(Menu? menu) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormMenuSheet(menu: menu),
    );
  }

  Future<void> _nonaktifkanMenu(Menu menu) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Menu'),
        content: Text('Sembunyikan "${menu.nama}" dari daftar jual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    final db = DatabaseLokal.instance;
    try {
      await db.hapusMenuLunak(menu.id);
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'nonaktifkan_menu',
          idReferensi: menu.id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaSemuaMenu);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menonaktifkan menu: $e')),
        );
      }
    }
  }
}

class _ChipFilter extends StatelessWidget {
  const _ChipFilter({
    required this.label,
    required this.terpilih,
    required this.saatPilih,
  });

  final String label;
  final bool terpilih;
  final VoidCallback saatPilih;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: terpilih,
        onSelected: (_) => saatPilih(),
      ),
    );
  }
}

class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.menu,
    required this.saatUbah,
    required this.saatHapus,
  });

  final Menu menu;
  final VoidCallback saatUbah;
  final VoidCallback saatHapus;

  @override
  Widget build(BuildContext context) {
    final menipis = menu.stok <= menu.stokMinimum;
    final detail = StringBuffer(
      '${formatRupiah(menu.hargaSatuan)} • Stok: ${menu.stok}',
    );
    if (menipis) detail.write(' • Menipis!');
    if (!menu.tersedia) detail.write(' • Nonaktif');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuKaca(
        pakaiBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            menu.nama,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            detail.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: menipis ? WarnaWarkop.merahMenyala : null,
                ),
          ),
          onTap: saatUbah,
          trailing: IconButton(
            tooltip: 'Nonaktifkan',
            icon: const Icon(Icons.delete_outline),
            onPressed: saatHapus,
          ),
        ),
      ),
    );
  }
}

// ── Form tambah/ubah menu ──────────────────────────────────────────

/// Bottom sheet form menu: nama, kategori, harga, stok, stok minimum,
/// dan switch tersedia.
class _FormMenuSheet extends ConsumerStatefulWidget {
  const _FormMenuSheet({this.menu});

  /// null = tambah baru; terisi = ubah.
  final Menu? menu;

  @override
  ConsumerState<_FormMenuSheet> createState() => _FormMenuSheetState();
}

class _FormMenuSheetState extends ConsumerState<_FormMenuSheet> {
  late final TextEditingController _nama;
  late final TextEditingController _harga;
  late final TextEditingController _stok;
  late final TextEditingController _stokMin;
  String? _idKategori;
  bool _tersedia = true;
  bool _memuat = false;

  @override
  void initState() {
    super.initState();
    final m = widget.menu;
    _nama = TextEditingController(text: m?.nama ?? '');
    _harga =
        TextEditingController(text: m == null ? '' : '${m.hargaSatuan}');
    _stok = TextEditingController(text: m == null ? '' : '${m.stok}');
    _stokMin =
        TextEditingController(text: m == null ? '' : '${m.stokMinimum}');
    _idKategori = m?.idKategori;
    _tersedia = m?.tersedia ?? true;
  }

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _stok.dispose();
    _stokMin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kategoriAsync = ref.watch(penyediaDaftarKategori);
    final adalahUbah = widget.menu != null;
    final bawah = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bawah),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              adalahUbah ? 'Ubah Menu' : 'Tambah Menu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama menu',
                hintText: 'Contoh: Kopi Tubruk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            kategoriAsync.when(
              data: (kategori) => DropdownButtonFormField<String>(
                key: ValueKey(_idKategori),
                initialValue: kategori.any((k) => k.id == _idKategori)
                    ? _idKategori
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final k in kategori)
                    DropdownMenuItem(value: k.id, child: Text(k.nama)),
                ],
                onChanged: (v) => setState(() => _idKategori = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat kategori: $e'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _harga,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _stok,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stokMin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok minimum',
                      hintText: 'Batas peringatan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    value: _tersedia,
                    onChanged: (v) => setState(() => _tersedia = v),
                    title: const Text('Tersedia'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TombolKaca(
              label: adalahUbah ? 'Simpan Perubahan' : 'Tambah Menu',
              ikon: Icons.check_outlined,
              memuat: _memuat,
              saatDitekan: _simpan,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    final harga = int.tryParse(_harga.text.trim());
    final stok = int.tryParse(_stok.text.trim()) ?? 0;
    final stokMin = int.tryParse(_stokMin.text.trim()) ?? 0;

    String? galat;
    if (nama.isEmpty) {
      galat = 'Nama menu wajib diisi.';
    } else if (_idKategori == null) {
      galat = 'Pilih kategori dulu ya.';
    } else if (harga == null || harga <= 0) {
      galat = 'Harga harus angka lebih dari 0.';
    }
    if (galat != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(galat)),
      );
      return;
    }

    setState(() => _memuat = true);
    try {
      final db = DatabaseLokal.instance;
      final lama = widget.menu;
      final id = lama?.id ?? idBaru();
      final menu = Menu(
        id: id,
        idKategori: _idKategori!,
        nama: nama,
        hargaSatuan: harga!,
        stok: stok,
        stokMinimum: stokMin,
        tersedia: _tersedia,
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.now(),
      );
      if (lama == null) {
        await db.simpanMenu(menu);
      } else {
        await db.perbaruiMenu(menu);
      }
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: lama == null ? 'tambah_menu' : 'ubah_menu',
          idReferensi: id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaSemuaMenu);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan menu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }
}

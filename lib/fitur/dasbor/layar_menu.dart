import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/menu.dart';
import '../stok_kombo/bagian_resep.dart';
import '../stok_kombo/layanan_foto_menu.dart';
import 'penyedia_katalog.dart';

/// Layar menu owner: pencarian nama + filter chip kategori +
/// daftar + tambah/ubah + nonaktifkan.
///
/// Dipisah dari layar Kategori. Filter bersifat reaktif: mengetik di
/// kolom cari atau memilih chip langsung menyaring daftar.
class LayarMenu extends ConsumerStatefulWidget {
  const LayarMenu({super.key});

  @override
  ConsumerState<LayarMenu> createState() => _LayarMenuState();
}

class _LayarMenuState extends ConsumerState<LayarMenu> {
  /// null = semua kategori.
  String? _idKategori;
  String _kataKunci = '';
  final _pencarianCtrl = TextEditingController();

  @override
  void dispose() {
    _pencarianCtrl.dispose();
    super.dispose();
  }

  /// Saring daftar menu berdasarkan kata kunci (nama) dan kategori.
  List<Menu> _saring(List<Menu> semua) {
    final kunci = _kataKunci.trim().toLowerCase();
    return semua.where((m) {
      final cocokKategori = _idKategori == null || m.idKategori == _idKategori;
      final cocokNama =
          kunci.isEmpty || m.nama.toLowerCase().contains(kunci);
      return cocokKategori && cocokNama;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final kategoriAsync = ref.watch(penyediaDaftarKategori);
    final menuAsync = ref.watch(penyediaSemuaMenu);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MENU'),
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
            // ── Kolom pencarian ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _pencarianCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama menu...',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _kataKunci.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Bersihkan',
                          icon: const Icon(Icons.clear_outlined),
                          onPressed: () {
                            _pencarianCtrl.clear();
                            setState(() => _kataKunci = '');
                          },
                        ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  isDense: true,
                ),
                onChanged: (nilai) => setState(() => _kataKunci = nilai),
              ),
            ),
            // ── Chip filter kategori ───────────────────────────
            SizedBox(
              height: 56,
              child: kategoriAsync.when(
                data: (kategori) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
            // ── Daftar menu tersaring ──────────────────────────
            Expanded(
              child: menuAsync.when(
                data: (semua) {
                  final daftar = _saring(semua);
                  if (daftar.isEmpty) {
                    return Center(
                      child: Text(
                        _kataKunci.trim().isEmpty
                            ? 'Belum ada menu di sini. Tambah dulu ya.'
                            : 'Tidak ada menu yang cocok dengan pencarian.',
                      ),
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Gagal memuat menu: $e')),
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
        ),
      ),
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
        tanpaBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: _MiniaturFoto(url: menu.fotoUrl),
            ),
          ),
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

/// Miniatur foto menu 52×52: tampilkan foto bila ada, ikon bila belum.
class _MiniaturFoto extends StatelessWidget {
  const _MiniaturFoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      final gelap = Theme.of(context).brightness == Brightness.dark;
      final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
      return Container(
        color: aksen.withValues(alpha: 0.1),
        child: Icon(Icons.restaurant_menu_outlined, color: aksen),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (ctx, _, __) => Container(
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

/// Bottom sheet form menu: nama, kategori, harga, stok, stok minimum,
/// switch tersedia, foto, dan resep.
class _FormMenuSheet extends ConsumerStatefulWidget {
  const _FormMenuSheet({this.menu});

  /// null = tambah baru; terisi = ubah.
  final Menu? menu;

  @override
  ConsumerState<_FormMenuSheet> createState() => _FormMenuSheetState();
}

class _FormMenuSheetState extends ConsumerState<_FormMenuSheet> {
  late final String _idMenu;
  late final TextEditingController _nama;
  late final TextEditingController _harga;
  late final TextEditingController _stok;
  late final TextEditingController _stokMin;
  String? _idKategori;
  bool _tersedia = true;
  bool _memuat = false;
  String? _fotoUrl;
  String? _pathFotoBaru;
  bool _mengunggahFoto = false;

  @override
  void initState() {
    super.initState();
    final m = widget.menu;
    // ID final sejak awal: dipakai BagianResep agar resep bisa ditambah
    // bahkan sebelum menu baru disimpan.
    _idMenu = m?.id ?? idBaru();
    _nama = TextEditingController(text: m?.nama ?? '');
    _harga = TextEditingController(text: m == null ? '' : '${m.hargaSatuan}');
    _stok = TextEditingController(text: m == null ? '' : '${m.stok}');
    _stokMin =
        TextEditingController(text: m == null ? '' : '${m.stokMinimum}');
    _idKategori = m?.idKategori;
    _tersedia = m?.tersedia ?? true;
    _fotoUrl = m?.fotoUrl;
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
            _BagianFoto(
              pathBaru: _pathFotoBaru,
              urlLama: _fotoUrl,
              mengunggah: _mengunggahFoto,
              saatGanti: (path) => setState(() => _pathFotoBaru = path),
              saatHapus: () => setState(() {
                _pathFotoBaru = null;
                _fotoUrl = null;
              }),
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
            const SizedBox(height: 12),
            BagianResep(idMenu: _idMenu),
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
    final stokMin = int.tryParse(_stok.text.trim()) ?? 0;

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

      // Unggah foto baru (bila ada) sebelum menyimpan menu.
      String? fotoUrl = _fotoUrl;
      if (_pathFotoBaru != null) {
        setState(() => _mengunggahFoto = true);
        try {
          fotoUrl = await unggahFotoMenu(_pathFotoBaru!, _idMenu);
        } catch (_) {
          // Offline/gagal jaringan: menu tetap disimpan, foto menyusul
          // saat pengguna mengganti foto lagi.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Foto gagal diunggah (offline?). Menu disimpan tanpa foto baru.',
                ),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _mengunggahFoto = false);
        }
      }

      final menu = Menu(
        id: _idMenu,
        idKategori: _idKategori!,
        nama: nama,
        hargaSatuan: harga!,
        stok: stok,
        stokMinimum: stokMin,
        tersedia: _tersedia,
        fotoUrl: fotoUrl,
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
          idReferensi: _idMenu,
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

/// Bagian foto di form menu: pratinjau + tombol kamera/galeri/hapus.
class _BagianFoto extends StatelessWidget {
  const _BagianFoto({
    required this.pathBaru,
    required this.urlLama,
    required this.mengunggah,
    required this.saatGanti,
    required this.saatHapus,
  });

  final String? pathBaru;
  final String? urlLama;
  final bool mengunggah;
  final ValueChanged<String> saatGanti;
  final VoidCallback saatHapus;

  bool get _adaFoto =>
      (pathBaru != null) || (urlLama != null && urlLama!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 88,
            height: 88,
            child: mengunggah
                ? Container(
                    color: aksen.withValues(alpha: 0.1),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  )
                : pathBaru != null
                    ? Image.file(File(pathBaru!), fit: BoxFit.cover)
                    : _MiniaturFoto(url: urlLama),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => pilihFotoMenu(
                  context,
                  saatDipilih: (path) {
                    HapticFeedback.mediumImpact();
                    saatGanti(path);
                  },
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(_adaFoto ? 'Ganti Foto' : 'Tambah Foto'),
              ),
              if (_adaFoto)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    saatHapus();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus foto'),
                  style: TextButton.styleFrom(
                    foregroundColor: WarnaWarkop.merahMenyala,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

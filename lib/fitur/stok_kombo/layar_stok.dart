import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/tema/token_tipografi.dart';
import '../../../app/tema/token_warna.dart';
import '../../../bersama/util/id_unik.dart';
import '../../../bersama/widget/kartu_kaca.dart';
import '../../../bersama/widget/tombol_kaca.dart';
import '../../../data/lokal/database_lokal.dart';
import '../../../data/model/kategori_menu.dart';
import '../../../data/model/log_audit.dart';
import '../../../data/model/menu.dart';
import 'penyedia_stok.dart';

/// Layar pengelolaan stok (owner/kasir).
///
/// Daftar semua menu dikelompokkan per kategori. Setiap baris menampilkan
/// nama, stok saat ini (besar), dan badge "Menipis"/"Habis". Tap baris
/// membuka bottom sheet "Kelola Stok" di area bawah layar.
///
/// Baris shortcut di atas menuju modul bahan, stok opname, riwayat opname,
/// dan daftar belanja.
class LayarStok extends ConsumerWidget {
  const LayarStok({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(penyediaMenuStokBersama);
    final kategoriAsync = ref.watch(penyediaKategoriStokBersama);

    return Scaffold(
      appBar: AppBar(title: const Text('STOK')),
      body: SafeArea(
        child: menuAsync.when(
          data: (semuaMenu) => kategoriAsync.when(
            data: (kategoris) =>
                _IsiStok(semuaMenu: semuaMenu, kategoris: kategoris),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _PesanGalat(pesan: '$e'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _PesanGalat(pesan: '$e'),
        ),
      ),
    );
  }
}

class _IsiStok extends ConsumerWidget {
  const _IsiStok({required this.semuaMenu, required this.kategoris});

  final List<Menu> semuaMenu;
  final List<KategoriMenu> kategoris;

  bool _habis(Menu m) => m.stok <= 0;
  bool _menipis(Menu m) => !_habis(m) && m.stok <= m.stokMinimum;

  void _bukaKelolaStok(BuildContext context, WidgetRef ref, Menu menu) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LembarKelolaStok(
          menu: menu,
          saatSimpan: () => ref.invalidate(penyediaMenuStokBersama),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlahMenipis = semuaMenu.where(_menipis).length;
    final jumlahHabis = semuaMenu.where(_habis).length;

    final namaKategori = {for (final k in kategoris) k.id: k.nama};
    final perKategori = <String, List<Menu>>{};
    for (final menu in semuaMenu) {
      perKategori.putIfAbsent(menu.idKategori, () => []).add(menu);
    }
    final urutanIdKategori = [
      for (final k in kategoris)
        if (perKategori.containsKey(k.id)) k.id,
      for (final id in perKategori.keys)
        if (!namaKategori.containsKey(id)) id,
    ];
    final entri = <_EntriDaftar>[];
    for (final idKategori in urutanIdKategori) {
      entri.add(_EntriDaftar.header(namaKategori[idKategori] ?? 'Lainnya'));
      for (final menu in perKategori[idKategori]!) {
        entri.add(_EntriDaftar.menu(menu));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Ringkasan ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _KartuRingkasan(
                  label: 'Menipis',
                  jumlah: jumlahMenipis,
                  warna: WarnaWarkop.kuningAntre,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KartuRingkasan(
                  label: 'Habis',
                  jumlah: jumlahHabis,
                  warna: WarnaWarkop.merahMenyala,
                ),
              ),
            ],
          ),
        ),
        // ── Shortcut modul stok ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _TombolShortcut(
                  label: 'Bahan',
                  ikon: Icons.inventory_2_outlined,
                  saatTap: () => context.push(Rute.bahan),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TombolShortcut(
                  label: 'Opname',
                  ikon: Icons.fact_check_outlined,
                  saatTap: () => context.push(Rute.stokOpname),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TombolShortcut(
                  label: 'Riwayat',
                  ikon: Icons.history_outlined,
                  saatTap: () => context.push(Rute.riwayatOpname),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TombolShortcut(
                  label: 'Belanja',
                  ikon: Icons.shopping_cart_outlined,
                  saatTap: () => context.push(Rute.belanja),
                ),
              ),
            ],
          ),
        ),
        // ── Daftar per kategori ──────────────────────────────────
        Expanded(
          child: semuaMenu.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: KartuKaca(
                    tanpaBlur: true,
                    child: Text(
                      'Belum ada menu. Tambahkan menu dulu dari modul kasir.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: entri.length,
                  itemBuilder: (ctx, i) {
                    final item = entri[i];
                    if (item.judul != null) {
                      return _HeaderKategori(judul: item.judul!);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BarisMenu(
                        menu: item.menu!,
                        saatTap: () =>
                            _bukaKelolaStok(context, ref, item.menu!),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Satu entri daftar stok: header nama kategori atau baris menu.
class _EntriDaftar {
  const _EntriDaftar.header(this.judul) : menu = null;
  const _EntriDaftar.menu(this.menu) : judul = null;

  final String? judul;
  final Menu? menu;
}

/// Tombol shortcut kecil menuju modul stok lain (bahan/opname/belanja).
class _TombolShortcut extends StatelessWidget {
  const _TombolShortcut({
    required this.label,
    required this.ikon,
    required this.saatTap,
  });

  final String label;
  final IconData ikon;
  final VoidCallback saatTap;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        saatTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: aksen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: aksen.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 22, color: aksen),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: aksen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderKategori extends StatelessWidget {
  const _HeaderKategori({required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        judul.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({
    required this.label,
    required this.jumlah,
    required this.warna,
  });

  final String label;
  final int jumlah;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      tanpaBlur: true,
      border: warna.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$jumlah',
            style: TipografiWarkop.nominal.copyWith(
              fontSize: 30,
              color: warna,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'item $label',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BarisMenu extends StatelessWidget {
  const _BarisMenu({required this.menu, required this.saatTap});

  final Menu menu;
  final VoidCallback saatTap;

  @override
  Widget build(BuildContext context) {
    final habis = menu.stok <= 0;
    final menipis = !habis && menu.stok <= menu.stokMinimum;

    return GestureDetector(
      onTap: saatTap,
      behavior: HitTestBehavior.opaque,
      child: KartuKaca(
        tanpaBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          menu.nama,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (habis)
                        const _BadgeStok(
                          teks: 'Habis',
                          warna: WarnaWarkop.merahMenyala,
                        )
                      else if (menipis)
                        const _BadgeStok(
                          teks: 'Menipis',
                          warna: WarnaWarkop.kuningAntre,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'min. ${menu.stokMinimum} · '
                    '${menu.tersedia ? 'dijual' : 'tidak dijual'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${menu.stok}',
              style: TipografiWarkop.nominal.copyWith(
                fontSize: 26,
                color: habis
                    ? WarnaWarkop.merahMenyala
                    : menipis
                        ? WarnaWarkop.kuningAntre
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeStok extends StatelessWidget {
  const _BadgeStok({required this.teks, required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Text(
        teks,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PesanGalat extends StatelessWidget {
  const _PesanGalat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: KartuKaca(
        tanpaBlur: true,
        border: WarnaWarkop.merahMenyala.withValues(alpha: 0.45),
        child: Text('Gagal memuat stok: $pesan'),
      ),
    );
  }
}

/// Bottom sheet "Kelola Stok": ubah stok, stok minimum, dan status dijual.
class _LembarKelolaStok extends StatefulWidget {
  const _LembarKelolaStok({required this.menu, required this.saatSimpan});

  final Menu menu;
  final VoidCallback saatSimpan;

  @override
  State<_LembarKelolaStok> createState() => _LembarKelolaStokState();
}

class _LembarKelolaStokState extends State<_LembarKelolaStok> {
  late final TextEditingController _kontrolStok;
  late final TextEditingController _kontrolMinimum;
  late bool _tersedia;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _kontrolStok = TextEditingController(text: '${widget.menu.stok}');
    _kontrolMinimum =
        TextEditingController(text: '${widget.menu.stokMinimum}');
    _tersedia = widget.menu.tersedia;
  }

  @override
  void dispose() {
    _kontrolStok.dispose();
    _kontrolMinimum.dispose();
    super.dispose();
  }

  void _geserStok(int delta) {
    HapticFeedback.lightImpact();
    final sekarang = int.tryParse(_kontrolStok.text) ?? widget.menu.stok;
    final baru = (sekarang + delta).clamp(0, 999999);
    _kontrolStok.text = '$baru';
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    setState(() => _menyimpan = true);

    final stok = (int.tryParse(_kontrolStok.text) ?? widget.menu.stok)
        .clamp(0, 999999);
    final minimum =
        (int.tryParse(_kontrolMinimum.text) ?? widget.menu.stokMinimum)
            .clamp(0, 999999);

    final db = DatabaseLokal.instance;
    await db.perbaruiMenu(
      widget.menu.copyWith(
        stok: stok,
        stokMinimum: minimum,
        tersedia: _tersedia,
      ),
    );
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'stok.diubah',
        idReferensi: widget.menu.id,
        detail: '{"stok":$stok,"stok_minimum":$minimum}',
        dibuatPada: DateTime.now(),
      ),
    );

    if (!mounted) return;
    widget.saatSimpan();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stok diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: gelap ? WarnaWarkop.kertasGelap : WarnaWarkop.kertasTerang,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kelola Stok',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                widget.menu.nama,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 16),
              Text('Jumlah stok',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _kontrolStok,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TipografiWarkop.nominal.copyWith(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Isi jumlah stok, atau pakai tombol cepat',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final langkah in const [-10, -1, 1, 10])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _TombolGeser(
                          label: '${langkah > 0 ? '+' : ''}$langkah',
                          saatTap: () => _geserStok(langkah),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Stok minimum', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _kontrolMinimum,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TipografiWarkop.nominal.copyWith(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Batas peringatan menipis',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tersedia dijual'),
                value: _tersedia,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _tersedia = v);
                },
              ),
              const SizedBox(height: 8),
              TombolKaca(
                label: 'Simpan Stok',
                ikon: Icons.save_outlined,
                memuat: _menyimpan,
                saatDitekan: _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol geser stok cepat (+1/+10/-1/-10): animasi skala saat ditekan.
class _TombolGeser extends StatefulWidget {
  const _TombolGeser({required this.label, required this.saatTap});

  final String label;
  final VoidCallback saatTap;

  @override
  State<_TombolGeser> createState() => _TombolGeserState();
}

class _TombolGeserState extends State<_TombolGeser> {
  double _skala = 1.0;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.92),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: widget.saatTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aksen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: aksen.withValues(alpha: 0.35)),
          ),
          child: Text(
            widget.label,
            style: TipografiWarkop.nominal.copyWith(
              fontSize: 16,
              color: aksen,
            ),
          ),
        ),
      ),
    );
  }
}

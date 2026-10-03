import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/menu.dart';
import '../../data/model/paket_kombo.dart';
import '../../data/model/pesanan.dart';
import '../../data/model/pesanan_rincian.dart';
import '../kasir/penyedia_kasir.dart';
import 'model_keranjang.dart';
import 'penyedia_keranjang.dart';

/// Data master dimuat sekali dari SQLite; di-invalidate ulang setelah checkout.
final _penyediaKategori = FutureProvider<List<KategoriMenu>>(
  (ref) => DatabaseLokal.instance.daftarKategori(),
);
final _penyediaMenu = FutureProvider<List<Menu>>(
  (ref) => DatabaseLokal.instance.daftarMenu(),
);
final _penyediaPaket = FutureProvider<List<PaketKombo>>(
  (ref) => DatabaseLokal.instance.daftarPaket(),
);
final _penyediaLabelTagihan = FutureProvider.family<String?, String>(
  (ref, idTagihan) async =>
      (await DatabaseLokal.instance.ambilOpenBill(idTagihan))?.label,
);

/// Nilai khusus untuk chip kategori "Kombo".
const _idKategoriKombo = 'kombo';

/// Layar kasir POS: pilih menu/paket, masukkan keranjang, buat pesanan.
///
/// Jika [idTagihan] diisi, pesanan susulan ditempel ke open bill tersebut
/// (dipakai alur open bill fase 4).
class LayarPos extends ConsumerStatefulWidget {
  const LayarPos({super.key, this.idTagihan});

  final String? idTagihan;

  @override
  ConsumerState<LayarPos> createState() => _LayarPosState();
}

class _LayarPosState extends ConsumerState<LayarPos> {
  final _pencarianController = TextEditingController();
  String? _idKategoriTerpilih; // null = Semua
  String _kataKunci = '';

  @override
  void dispose() {
    _pencarianController.dispose();
    super.dispose();
  }

  bool get _modeKombo => _idKategoriTerpilih == _idKategoriKombo;

  void _keluar() {
    ref.read(sesiKasirProvider.notifier).ganti(null);
    ref.read(shiftAktifProvider.notifier).ganti(null);
    context.go('/kasir');
  }

  void _tambahMenu(Menu menu) {
    ref.read(penyediaKeranjang.notifier).tambahMenu(menu);
    HapticFeedback.lightImpact();
  }

  void _tambahPaket(PaketKombo paket) {
    ref.read(penyediaKeranjang.notifier).tambahPaket(paket);
    HapticFeedback.lightImpact();
  }

  /// Simpan pesanan + rinciannya ke SQLite. Mengembalikan id pesanan,
  /// atau null bila gagal / tidak ada yang bisa disimpan.
  Future<String?> _simpanPesanan() async {
    final kasir = ref.read(sesiKasirProvider);
    final baris = ref.read(penyediaKeranjang);
    if (kasir == null || baris.isEmpty) return null;
    try {
      final db = DatabaseLokal.instance;
      final sekarang = DateTime.now();
      final pesanan = Pesanan(
        id: idBaru(),
        nomorNota: await db.nomorNotaBerikutnya(),
        idAkun: kasir.id,
        idShift: ref.read(shiftAktifProvider)?.id,
        idOpenBill: widget.idTagihan,
        metodeBayar: 'tunai',
        status: 'baru',
        total: baris.totalHarga,
        bayar: 0,
        kembalian: 0,
        statusSinkron: 'tertunda',
        diperbaruiPada: sekarang,
        apakahDihapus: false,
      );
      await db.simpanPesanan(pesanan);
      for (final item in baris) {
        await db.simpanRincian(
          PesananRincian(
            id: idBaru(),
            idPesanan: pesanan.id,
            idMenu: item.idMenu,
            idPaket: item.idPaket,
            namaSnapshot: item.nama,
            hargaSnapshot: item.hargaSatuan,
            jumlah: item.jumlah,
            subtotal: item.subtotal,
            catatan: item.catatan,
            statusSinkron: 'tertunda',
            diperbaruiPada: sekarang,
            apakahDihapus: false,
          ),
        );
      }
      ref.read(penyediaKeranjang.notifier).kosongkan();
      ref.invalidate(_penyediaMenu);
      ref.invalidate(_penyediaPaket);
      return pesanan.id;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan pesanan. Coba lagi.'),
          ),
        );
      }
      return null;
    }
  }

  void _tampilkanKeranjang() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          // Blur (BackdropFilter) hanya diizinkan untuk bottom sheet.
          child: KartuKaca(
            pakaiBlur: true,
            radius: 24,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: _LembarKeranjang(
              simpanPesanan: _simpanPesanan,
              keLayarBayar: (idPesanan) {
                Navigator.of(sheetContext).pop();
                context.go('/bayar/$idPesanan');
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kasir = ref.watch(sesiKasirProvider);
    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kasir POS')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masuk sebagai kasir dulu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TombolKaca(
                label: 'Ke Layar Kasir',
                lebarPenuh: false,
                saatDitekan: () => context.go('/kasir'),
              ),
            ],
          ),
        ),
      );
    }

    final kategoriAsync = ref.watch(_penyediaKategori);
    final menuAsync = ref.watch(_penyediaMenu);
    final paketAsync = ref.watch(_penyediaPaket);

    final memuat = kategoriAsync.isLoading ||
        menuAsync.isLoading ||
        paketAsync.isLoading;
    final galat =
        kategoriAsync.error ?? menuAsync.error ?? paketAsync.error;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kasir POS'),
            Text(
              kasir.nama,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _keluar,
          ),
        ],
      ),
      floatingActionButton: _TombolKeranjang(
        saatDitekan: _tampilkanKeranjang,
      ),
      body: SafeArea(
        child: memuat
            ? const Center(child: CircularProgressIndicator())
            : galat != null
                ? _GalatMuat(
                    saatMuatUlang: () {
                      ref.invalidate(_penyediaKategori);
                      ref.invalidate(_penyediaMenu);
                      ref.invalidate(_penyediaPaket);
                    },
                  )
                : _bangunIsi(
                    daftarKategori: kategoriAsync.value ?? const [],
                    daftarMenu: menuAsync.value ?? const [],
                    daftarPaket: paketAsync.value ?? const [],
                  ),
      ),
    );
  }

  Widget _bangunIsi({
    required List<KategoriMenu> daftarKategori,
    required List<Menu> daftarMenu,
    required List<PaketKombo> daftarPaket,
  }) {
    final kategoriAktif = daftarKategori
        .where((kategori) => kategori.aktif)
        .toList()
      ..sort((a, b) => a.urutanTampil.compareTo(b.urutanTampil));

    final kataKunci = _kataKunci.trim().toLowerCase();
    final menuTampil = daftarMenu.where((menu) {
      final cocokKategori = _idKategoriTerpilih == null ||
          menu.idKategori == _idKategoriTerpilih;
      final cocokCari =
          kataKunci.isEmpty || menu.nama.toLowerCase().contains(kataKunci);
      return cocokKategori && cocokCari;
    }).toList();
    final paketTampil = daftarPaket
        .where((paket) =>
            paket.aktif &&
            (kataKunci.isEmpty ||
                paket.nama.toLowerCase().contains(kataKunci)))
        .toList();

    return Column(
      children: [
        if (widget.idTagihan != null) _ChipTagihan(idTagihan: widget.idTagihan!),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _pencarianController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Cari menu atau paket...',
              prefixIcon: Icon(Icons.search_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              isDense: true,
            ),
            onChanged: (nilai) => setState(() => _kataKunci = nilai),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ChipKategori(
                label: 'Semua',
                terpilih: _idKategoriTerpilih == null,
                saatDipilih: () =>
                    setState(() => _idKategoriTerpilih = null),
              ),
              _ChipKategori(
                label: 'Kombo',
                terpilih: _modeKombo,
                saatDipilih: () =>
                    setState(() => _idKategoriTerpilih = _idKategoriKombo),
              ),
              for (final kategori in kategoriAktif)
                _ChipKategori(
                  label: kategori.nama,
                  terpilih: _idKategoriTerpilih == kategori.id,
                  saatDipilih: () =>
                      setState(() => _idKategoriTerpilih = kategori.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _modeKombo
              ? _GridPaket(daftarPaket: paketTampil, saatTap: _tambahPaket)
              : _GridMenu(daftarMenu: menuTampil, saatTap: _tambahMenu),
        ),
      ],
    );
  }
}

/// Chip "Tagihan: <label>" saat layar dibuka dari open bill.
class _ChipTagihan extends ConsumerWidget {
  const _ChipTagihan({required this.idTagihan});

  final String idTagihan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelAsync = ref.watch(_penyediaLabelTagihan(idTagihan));
    final skema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(
            labelAsync.when(
              data: (label) => 'Tagihan: ${label ?? idTagihan}',
              loading: () => 'Tagihan: ...',
              error: (_, __) => 'Tagihan',
            ),
          ),
          backgroundColor: skema.secondaryContainer,
        ),
      ),
    );
  }
}

class _ChipKategori extends StatelessWidget {
  const _ChipKategori({
    required this.label,
    required this.terpilih,
    required this.saatDipilih,
  });

  final String label;
  final bool terpilih;
  final VoidCallback saatDipilih;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: terpilih,
        onSelected: (_) => saatDipilih(),
      ),
    );
  }
}

class _GalatMuat extends StatelessWidget {
  const _GalatMuat({required this.saatMuatUlang});

  final VoidCallback saatMuatUlang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gagal memuat data menu.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TombolKaca(
            label: 'Muat Ulang',
            lebarPenuh: false,
            saatDitekan: saatMuatUlang,
          ),
        ],
      ),
    );
  }
}

/// Grid 2 kolom kartu menu — TANPA BackdropFilter (hemat GPU).
class _GridMenu extends StatelessWidget {
  const _GridMenu({required this.daftarMenu, required this.saatTap});

  final List<Menu> daftarMenu;
  final void Function(Menu menu) saatTap;

  @override
  Widget build(BuildContext context) {
    if (daftarMenu.isEmpty) {
      return const Center(child: Text('Belum ada menu di kategori ini.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: daftarMenu.length,
      itemBuilder: (context, indeks) {
        final menu = daftarMenu[indeks];
        return _KartuMenu(menu: menu, saatTap: () => saatTap(menu));
      },
    );
  }
}

/// Grid 2 kolom kartu paket kombo — TANPA BackdropFilter.
class _GridPaket extends StatelessWidget {
  const _GridPaket({required this.daftarPaket, required this.saatTap});

  final List<PaketKombo> daftarPaket;
  final void Function(PaketKombo paket) saatTap;

  @override
  Widget build(BuildContext context) {
    if (daftarPaket.isEmpty) {
      return const Center(child: Text('Belum ada paket kombo.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: daftarPaket.length,
      itemBuilder: (context, indeks) {
        final paket = daftarPaket[indeks];
        return _KartuPaket(paket: paket, saatTap: () => saatTap(paket));
      },
    );
  }
}

/// Kartu menu solid (bukan kaca) dengan efek tekan scale kecil.
class _KartuMenu extends StatefulWidget {
  const _KartuMenu({required this.menu, required this.saatTap});

  final Menu menu;
  final VoidCallback saatTap;

  @override
  State<_KartuMenu> createState() => _KartuMenuState();
}

class _KartuMenuState extends State<_KartuMenu> {
  double _skala = 1.0;

  bool get _nonaktif =>
      !widget.menu.tersedia || widget.menu.stok <= 0;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    final badge = _nonaktif
        ? _LencanaStok(
            label: 'Habis',
            warna: WarnaWarkop.merahMenyala,
          )
        : (widget.menu.stok <= widget.menu.stokMinimum &&
                widget.menu.stokMinimum > 0)
            ? _LencanaStok(
                label: 'Menipis',
                warna: WarnaWarkop.kuningAntre,
              )
            : null;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: Opacity(
        opacity: _nonaktif ? 0.45 : 1.0,
        child: GestureDetector(
          onTapDown: _nonaktif ? null : (_) => setState(() => _skala = 0.96),
          onTapUp: _nonaktif ? null : (_) => setState(() => _skala = 1.0),
          onTapCancel: () => setState(() => _skala = 1.0),
          onTap: _nonaktif ? null : widget.saatTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Solid dari colorScheme — dilarang BackdropFilter di grid.
              color: skema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: skema.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  badge,
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: Text(
                    widget.menu.nama,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: teks.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatRupiah(widget.menu.hargaSatuan),
                  style: teks.titleMedium?.copyWith(
                    color: skema.primary,
                    fontWeight: FontWeight.bold,
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

class _KartuPaket extends StatefulWidget {
  const _KartuPaket({required this.paket, required this.saatTap});

  final PaketKombo paket;
  final VoidCallback saatTap;

  @override
  State<_KartuPaket> createState() => _KartuPaketState();
}

class _KartuPaketState extends State<_KartuPaket> {
  double _skala = 1.0;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.96),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: widget.saatTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: skema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: WarnaWarkop.emas.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LencanaStok(
                label: 'Paket',
                warna: WarnaWarkop.emas,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  widget.paket.nama,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: teks.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatRupiah(widget.paket.hargaPaket),
                style: teks.titleMedium?.copyWith(
                  color: skema.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LencanaStok extends StatelessWidget {
  const _LencanaStok({required this.label, required this.warna});

  final String label;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Tombol keranjang mengambang dengan badge jumlah item.
class _TombolKeranjang extends ConsumerWidget {
  const _TombolKeranjang({required this.saatDitekan});

  final VoidCallback saatDitekan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItem = ref.watch(penyediaKeranjang.select((baris) => baris.totalItem));
    return Badge(
      isLabelVisible: totalItem > 0,
      label: Text('$totalItem'),
      child: FloatingActionButton(
        tooltip: 'Keranjang',
        onPressed: saatDitekan,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

/// Isi bottom sheet keranjang: daftar baris, total, tombol "Buat Pesanan".
class _LembarKeranjang extends ConsumerStatefulWidget {
  const _LembarKeranjang({
    required this.simpanPesanan,
    required this.keLayarBayar,
  });

  /// Menyimpan pesanan; mengembalikan id pesanan atau null bila gagal.
  final Future<String?> Function() simpanPesanan;

  /// Dipanggil dengan id pesanan setelah sheet ditutup.
  final void Function(String idPesanan) keLayarBayar;

  @override
  ConsumerState<_LembarKeranjang> createState() => _LembarKeranjangState();
}

class _LembarKeranjangState extends ConsumerState<_LembarKeranjang> {
  bool _memuat = false;

  Future<void> _prosesCheckout() async {
    if (_memuat) return;
    setState(() => _memuat = true);
    final idPesanan = await widget.simpanPesanan();
    if (!mounted) return;
    setState(() => _memuat = false);
    if (idPesanan == null) return;
    widget.keLayarBayar(idPesanan);
  }

  @override
  Widget build(BuildContext context) {
    final baris = ref.watch(penyediaKeranjang);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: skema.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text('Keranjang', style: teks.titleLarge),
        const SizedBox(height: 12),
        Expanded(
          child: baris.isEmpty
              ? const Center(child: Text('Keranjang masih kosong.'))
              : ListView.builder(
                  itemCount: baris.length,
                  itemBuilder: (context, indeks) {
                    final item = baris[indeks];
                    return _UbinBarisKeranjang(
                      key: ValueKey(item.idBaris),
                      baris: item,
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: teks.titleMedium),
            Text(
              formatRupiah(baris.totalHarga),
              style: teks.titleLarge?.copyWith(
                color: skema.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TombolKaca(
          label: 'Buat Pesanan',
          ikon: Icons.receipt_long_outlined,
          memuat: _memuat,
          aktif: baris.isNotEmpty,
          saatDitekan: _prosesCheckout,
        ),
      ],
    );
  }
}

/// Satu baris keranjang: nama, harga, stepper, hapus, catatan.
class _UbinBarisKeranjang extends ConsumerStatefulWidget {
  const _UbinBarisKeranjang({super.key, required this.baris});

  final BarisKeranjang baris;

  @override
  ConsumerState<_UbinBarisKeranjang> createState() =>
      _UbinBarisKeranjangState();
}

class _UbinBarisKeranjangState extends ConsumerState<_UbinBarisKeranjang> {
  late final TextEditingController _catatanController;

  @override
  void initState() {
    super.initState();
    _catatanController =
        TextEditingController(text: widget.baris.catatan ?? '');
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifikasi = ref.read(penyediaKeranjang.notifier);
    final baris = widget.baris;
    final teks = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(baris.nama, style: teks.bodyLarge),
                    Text(
                      '${formatRupiah(baris.hargaSatuan)} × ${baris.jumlah} = ${formatRupiah(baris.subtotal)}',
                      style: teks.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kurangi',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  notifikasi.ubahJumlah(baris.idBaris, baris.jumlah - 1);
                  HapticFeedback.lightImpact();
                },
              ),
              Text('${baris.jumlah}', style: teks.titleMedium),
              IconButton(
                tooltip: 'Tambah',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  notifikasi.ubahJumlah(baris.idBaris, baris.jumlah + 1);
                  HapticFeedback.lightImpact();
                },
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  notifikasi.hapusBaris(baris.idBaris);
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _catatanController,
            decoration: const InputDecoration(
              hintText: 'Catatan (mis. es sedikit)',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: teks.bodySmall,
            onChanged: (nilai) =>
                notifikasi.ubahCatatan(baris.idBaris, nilai),
          ),
        ],
      ),
    );
  }
}

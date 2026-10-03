import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/hitung_diskon.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
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

/// Hasil dialog diskon per item: nominal (rupiah) atau persen.
class _DiskonItem {
  const _DiskonItem({required this.nominal, required this.persen});

  final int nominal;
  final double persen;
}

/// Layar kasir POS: pilih menu/paket, masukkan keranjang, buat pesanan.
///
/// Tata letak: 55% atas = grid menu (foto + search + filter kategori),
/// 45% bawah = panel keranjang yang mudah dijangkau jempol. Diskon per
/// item diatur dari panel keranjang.
class LayarPos extends ConsumerStatefulWidget {
  const LayarPos({super.key, this.idTagihan});

  /// Jika diisi, pesanan susulan ditempel ke open bill tersebut
  /// (dipakai alur open bill fase 4).
  final String? idTagihan;

  @override
  ConsumerState<LayarPos> createState() => _LayarPosState();
}

class _LayarPosState extends ConsumerState<LayarPos> {
  final _pencarianController = TextEditingController();
  String? _idKategoriTerpilih; // null = Semua
  String _kataKunci = '';
  bool _memproses = false;

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

  /// Simpan pesanan + rinciannya ke SQLite (termasuk diskon per item).
  /// Mengembalikan id pesanan, atau null bila gagal.
  Future<void> _buatPesanan() async {
    if (_memproses) return;
    final kasir = ref.read(sesiKasirProvider);
    final baris = ref.read(penyediaKeranjang);
    if (kasir == null || baris.isEmpty) return;
    setState(() => _memproses = true);
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
            diskonNominal: item.diskonNominal,
            diskonPersen: item.diskonPersen,
            statusSinkron: 'tertunda',
            diperbaruiPada: sekarang,
            apakahDihapus: false,
          ),
        );
      }
      ref.read(penyediaKeranjang.notifier).kosongkan();
      ref.invalidate(_penyediaMenu);
      ref.invalidate(_penyediaPaket);
      if (mounted) context.go('/bayar/${pesanan.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan pesanan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kasir = ref.watch(sesiKasirProvider);
    if (kasir == null) {
      return Scaffold(
        body: OrbLatar(
          child: SafeArea(
            child: Center(
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
      // Tanpa AppBar — header menyatu dengan latar orb.
      body: OrbLatar(
        child: SafeArea(
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
                  : Column(
                      children: [
                        _bangunHeader(kasir.nama),
                        if (widget.idTagihan != null)
                          _ChipTagihan(idTagihan: widget.idTagihan!),
                        _bangunPencarian(),
                        _bangunKategori(
                          daftarKategori: kategoriAsync.value ?? const [],
                        ),
                        // 55% atas: grid menu.
                        Flexible(
                          flex: 55,
                          child: _modeKombo
                              ? _GridPaket(
                                  daftarPaket: _paketTampil(
                                    paketAsync.value ?? const [],
                                  ),
                                  saatTap: _tambahPaket,
                                )
                              : _GridMenu(
                                  daftarMenu: _menuTampil(
                                    menuAsync.value ?? const [],
                                  ),
                                  saatTap: _tambahMenu,
                                ),
                        ),
                        // 45% bawah: panel keranjang (zona jempol).
                        Flexible(
                          flex: 45,
                          child: _PanelKeranjang(
                            memproses: _memproses,
                            saatBuatPesanan: _buatPesanan,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  /// Header: judul + nama kasir + tombol keluar.
  Widget _bangunHeader(String namaKasir) {
    final teks = Theme.of(context).textTheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kasir POS',
                  style: teks.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  namaKasir,
                  style: teks.bodySmall?.copyWith(color: teksRedup),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _keluar,
          ),
        ],
      ),
    );
  }

  /// Kolom pencarian menu/paket.
  Widget _bangunPencarian() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
    );
  }

  /// Deretan chip kategori horizontal (ListView.builder — daftar pendek
  /// tapi tetap lazy agar lolos audit performa).
  Widget _bangunKategori({required List<KategoriMenu> daftarKategori}) {
    final kategoriAktif = daftarKategori
        .where((kategori) => kategori.aktif)
        .toList()
      ..sort((a, b) => a.urutanTampil.compareTo(b.urutanTampil));

    final chip = <({String label, String? idKategori})>[
      (label: 'Semua', idKategori: null),
      (label: 'Kombo', idKategori: _idKategoriKombo),
      for (final kategori in kategoriAktif)
        (label: kategori.nama, idKategori: kategori.id),
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chip.length,
        itemBuilder: (context, indeks) {
          final item = chip[indeks];
          return _ChipKategori(
            label: item.label,
            terpilih: _idKategoriTerpilih == item.idKategori,
            saatDipilih: () =>
                setState(() => _idKategoriTerpilih = item.idKategori),
          );
        },
      ),
    );
  }

  List<Menu> _menuTampil(List<Menu> semua) {
    final kataKunci = _kataKunci.trim().toLowerCase();
    return semua.where((menu) {
      final cocokKategori = _idKategoriTerpilih == null ||
          menu.idKategori == _idKategoriTerpilih;
      final cocokCari =
          kataKunci.isEmpty || menu.nama.toLowerCase().contains(kataKunci);
      return cocokKategori && cocokCari;
    }).toList();
  }

  List<PaketKombo> _paketTampil(List<PaketKombo> semua) {
    final kataKunci = _kataKunci.trim().toLowerCase();
    return semua
        .where(
          (paket) =>
              paket.aktif &&
              (kataKunci.isEmpty ||
                  paket.nama.toLowerCase().contains(kataKunci)),
        )
        .toList();
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: daftarPaket.length,
      itemBuilder: (context, indeks) {
        final paket = daftarPaket[indeks];
        return _KartuPaket(paket: paket, saatTap: () => saatTap(paket));
      },
    );
  }
}

/// Kartu menu kaca tanpa blur: foto di atas, nama + harga di bawah.
/// Efek tekan memakai AnimatedScale (transform = aman GPU).
class _KartuMenu extends StatefulWidget {
  const _KartuMenu({required this.menu, required this.saatTap});

  final Menu menu;
  final VoidCallback saatTap;

  @override
  State<_KartuMenu> createState() => _KartuMenuState();
}

class _KartuMenuState extends State<_KartuMenu> {
  double _skala = 1.0;

  bool get _nonaktif => !widget.menu.tersedia || widget.menu.stok <= 0;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    final badge = _nonaktif
        ? const _LencanaStok(label: 'Habis', warna: WarnaWarkop.merahMenyala)
        : (widget.menu.stok <= widget.menu.stokMinimum &&
                widget.menu.stokMinimum > 0)
            ? const _LencanaStok(
                label: 'Menipis', warna: WarnaWarkop.kuningAntre)
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
          child: KartuKaca(
            // WAJIB tanpaBlur di grid — dilarang BackdropFilter per kartu.
            tanpaBlur: true,
            tingkat: TingkatKaca.ringan,
            radius: 16,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto menu (atau placeholder gradien violet).
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _FotoMenu(
                            fotoUrl: widget.menu.fotoUrl,
                            label: widget.menu.nama,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: badge,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.menu.nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: teks.titleSmall,
                ),
                const SizedBox(height: 4),
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

/// Foto menu: Image.network bila ada URL, placeholder gradien violet bila
/// tidak ada / gagal dimuat (misalnya saat offline).
class _FotoMenu extends StatelessWidget {
  const _FotoMenu({required this.fotoUrl, required this.label});

  final String? fotoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foto = fotoUrl;
    if (foto == null || foto.isEmpty) return const _FotoKosong();

    return Image.network(
      foto,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Saat memuat: placeholder; gagal: placeholder.
      loadingBuilder: (context, anak, kemajuan) {
        if (kemajuan == null) return anak;
        return const _FotoKosong(memuat: true);
      },
      errorBuilder: (context, galat, tumpukan) => const _FotoKosong(),
      semanticLabel: label,
    );
  }
}

/// Placeholder gradien violet untuk menu tanpa foto.
class _FotoKosong extends StatelessWidget {
  const _FotoKosong({this.memuat = false});

  final bool memuat;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            aksen.withValues(alpha: 0.55),
            WarnaWarkop.aksenGelapHover.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: memuat
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(
                Icons.fastfood_outlined,
                color: Colors.white,
                size: 36,
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
        child: KartuKaca(
          tanpaBlur: true,
          tingkat: TingkatKaca.ringan,
          radius: 16,
          padding: const EdgeInsets.all(12),
          border: WarnaWarkop.emas.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LencanaStok(label: 'Paket', warna: WarnaWarkop.emas),
              const SizedBox(height: 8),
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

/// Panel keranjang di 45% bawah layar: daftar baris + diskon per item +
/// total + tombol "Buat Pesanan" yang mudah dijangkau jempol.
class _PanelKeranjang extends ConsumerWidget {
  const _PanelKeranjang({
    required this.memproses,
    required this.saatBuatPesanan,
  });

  final bool memproses;
  final VoidCallback saatBuatPesanan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baris = ref.watch(penyediaKeranjang);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    final totalHemat =
        baris.fold(0, (total, item) => total + item.potonganDiskon);

    return Container(
      decoration: BoxDecoration(
        color: skema.surface,
        border: Border(top: BorderSide(color: skema.outlineVariant)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text(
                  'Keranjang',
                  style: teks.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (baris.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: skema.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${baris.totalItem}',
                      style: teks.labelSmall?.copyWith(
                        color: skema.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                if (totalHemat > 0)
                  Text(
                    'Hemat ${formatRupiah(totalHemat)}',
                    style: teks.bodySmall?.copyWith(
                      color: WarnaWarkop.hijauAman,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: baris.isEmpty
                ? Center(
                    child: Text(
                      'Ketuk menu untuk menambah.',
                      style: teks.bodyMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: baris.length,
                    itemBuilder: (context, indeks) {
                      final item = baris[indeks];
                      return _BarisKeranjang(
                        key: ValueKey(item.idBaris),
                        baris: item,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 10),
                TombolKaca(
                  label: 'Buat Pesanan',
                  ikon: Icons.receipt_long_outlined,
                  memuat: memproses,
                  aktif: baris.isNotEmpty,
                  saatDitekan: saatBuatPesanan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris keranjang: nama, stepper jumlah, tombol diskon, hapus,
/// dan kolom catatan.
class _BarisKeranjang extends ConsumerStatefulWidget {
  const _BarisKeranjang({super.key, required this.baris});

  final BarisKeranjang baris;

  @override
  ConsumerState<_BarisKeranjang> createState() => _BarisKeranjangState();
}

class _BarisKeranjangState extends ConsumerState<_BarisKeranjang> {
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

  /// Buka lembar atur diskon untuk baris ini.
  Future<void> _aturDiskon() async {
    final hasil = await showModalBottomSheet<_DiskonItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _LembarDiskonItem(baris: widget.baris),
      ),
    );
    if (hasil == null || !mounted) return;
    ref.read(penyediaKeranjang.notifier).ubahDiskonItem(
          widget.baris.idBaris,
          nominal: hasil.nominal,
          persen: hasil.persen,
        );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final notifikasi = ref.read(penyediaKeranjang.notifier);
    final baris = widget.baris;
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuKaca(
        tanpaBlur: true,
        tingkat: TingkatKaca.ringan,
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(baris.nama, style: teks.bodyMedium),
                      Text(
                        '${formatRupiah(baris.hargaSatuan)} × ${baris.jumlah}',
                        style: teks.bodySmall?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                      if (baris.adaDiskon)
                        Text(
                          'Diskon -${formatRupiah(baris.potonganDiskon)}',
                          style: teks.bodySmall?.copyWith(
                            color: WarnaWarkop.hijauAman,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Diskon item',
                  icon: Icon(
                    Icons.percent_outlined,
                    color: baris.adaDiskon
                        ? WarnaWarkop.hijauAman
                        : skema.onSurfaceVariant,
                  ),
                  onPressed: _aturDiskon,
                ),
                IconButton(
                  tooltip: 'Kurangi',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    notifikasi.ubahJumlah(baris.idBaris, baris.jumlah - 1);
                    HapticFeedback.lightImpact();
                  },
                ),
                Text('${baris.jumlah}', style: teks.titleSmall),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatRupiah(baris.subtotal),
                    style: teks.titleSmall?.copyWith(
                      color: skema.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }
}

/// Lembar bawah untuk mengatur diskon satu baris keranjang
/// (nominal rupiah atau persen).
class _LembarDiskonItem extends StatefulWidget {
  const _LembarDiskonItem({required this.baris});

  final BarisKeranjang baris;

  @override
  State<_LembarDiskonItem> createState() => _LembarDiskonItemState();
}

class _LembarDiskonItemState extends State<_LembarDiskonItem> {
  bool _modeNominal = true;
  late final TextEditingController _nilaiController;

  @override
  void initState() {
    super.initState();
    final baris = widget.baris;
    _modeNominal = baris.diskonNominal > 0 || baris.diskonPersen <= 0;
    _nilaiController = TextEditingController(
      text: _modeNominal
          ? (baris.diskonNominal > 0 ? baris.diskonNominal.toString() : '')
          : (baris.diskonPersen > 0
              ? baris.diskonPersen
                  .toStringAsFixed(
                    baris.diskonPersen.truncateToDouble() ==
                            baris.diskonPersen
                        ? 0
                        : 1,
                  )
              : ''),
    );
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    super.dispose();
  }

  int get _nominal =>
      _modeNominal ? int.tryParse(_nilaiController.text) ?? 0 : 0;
  double get _persen =>
      _modeNominal ? 0 : double.tryParse(_nilaiController.text) ?? 0;

  int get _potongan => hitungPotongan(
        widget.baris.bruto,
        nominal: _nominal,
        persen: _persen,
      );

  void _simpan() {
    Navigator.of(context).pop(
      _DiskonItem(nominal: _nominal, persen: _persen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return KartuKaca(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Diskon — ${widget.baris.nama}',
            style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Harga baris ${formatRupiah(widget.baris.bruto)}',
            style: teks.bodySmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Nominal (Rp)'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text('Persen (%)'),
                icon: Icon(Icons.percent_outlined),
              ),
            ],
            selected: {_modeNominal},
            onSelectionChanged: (pilihan) {
              setState(() {
                _modeNominal = pilihan.first;
                _nilaiController.clear();
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nilaiController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: _modeNominal ? 'Nominal diskon' : 'Persen diskon',
              prefixText: _modeNominal ? 'Rp ' : null,
              suffixText: _modeNominal ? null : '%',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Potongan: ${formatRupiah(_potongan)}',
            style: teks.bodyMedium?.copyWith(
              color: WarnaWarkop.hijauAman,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    const _DiskonItem(nominal: 0, persen: 0),
                  ),
                  child: const Text('Hapus Diskon'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TombolKaca(
                  label: 'Simpan',
                  ikon: Icons.check,
                  saatDitekan: _simpan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

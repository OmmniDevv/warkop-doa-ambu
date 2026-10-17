import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/hitung_diskon.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/chip_warkop.dart';
import '../../bersama/widget/indikator_sinkron.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/lembar_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_warkop.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/kategori_menu.dart';
import '../../data/model/menu.dart';
import '../../data/model/open_bill.dart';
import '../../data/model/paket_kombo.dart';
import '../../data/model/pesanan.dart';
import '../../data/model/pesanan_rincian.dart';
import '../kasir/penyedia_kasir.dart';
import '../stok_kombo/penyedia_sinkron.dart';
import 'model_keranjang.dart';
import 'penyedia_keranjang.dart';

/// Data master dimuat sekali dari SQLite; di-invalidate ulang setelah checkout.
final penyediaKategoriPos = FutureProvider<List<KategoriMenu>>(
  (ref) => DatabaseLokal.instance.daftarKategori(),
);
final penyediaMenuPos = FutureProvider<List<Menu>>(
  (ref) => DatabaseLokal.instance.daftarMenu(),
);
final penyediaPaketPos = FutureProvider<List<PaketKombo>>(
  (ref) => DatabaseLokal.instance.daftarPaket(),
);
final penyediaLabelTagihanPos = FutureProvider.family<String?, String>(
  (ref, idTagihan) async =>
      (await DatabaseLokal.instance.ambilOpenBill(idTagihan))?.label,
);

/// Jumlah baris menunggu sinkron (untuk angka pada indikator).
/// Hanya baca-tampil; tidak mengubah alur sinkron.
final penyediaAntreSinkronPos = FutureProvider<int>((ref) async {
  final db = await DatabaseLokal.instance.db;
  var total = 0;
  const tabel = [
    'pesanan',
    'pesanan_rincian',
    'pesanan_bayar',
    'open_bill',
    'shift_kasir',
    'kasbon',
    'kas_keluar',
  ];
  for (final nama in tabel) {
    try {
      final hasil = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM $nama WHERE status_sinkron = 'tertunda'",
      );
      final nilai = hasil.first['c'];
      total += nilai is int ? nilai : int.tryParse('$nilai') ?? 0;
    } catch (_) {
      // Tabel tanpa kolom status_sinkron — lewati.
    }
  }
  return total;
});

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
/// Tata letak: header (sinkron + kasir) → pencarian → chip kategori →
/// grid menu 2 kolom → bilah keranjang mengambang → lembar nota.
/// Diskon per item diatur dari lembar nota.
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

  /// Keluar dari sesi kasir: dialog konfirmasi → bersihkan sesi & shift
  /// → kembali ke layar awal.
  Future<void> _keluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin mau keluar?'),
        content: const Text(
          'Sesi kasir akan diakhiri dan kamu kembali ke layar awal.',
        ),
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
    if (yakin != true || !mounted) return;
    ref.read(sesiKasirProvider.notifier).ganti(null);
    ref.read(shiftAktifProvider.notifier).ganti(null);
    if (mounted) context.go(Rute.selamatDatang);
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
  /// Mengembalikan id pesanan, atau null bila gagal / dibatalkan.
  Future<String?> _simpanPesanan(String? idBill) async {
    if (_memproses) return null;
    final kasir = ref.read(sesiKasirProvider);
    final baris = ref.read(penyediaKeranjang);
    if (kasir == null || baris.isEmpty) return null;
    setState(() => _memproses = true);
    try {
      final db = DatabaseLokal.instance;
      final sekarang = DateTime.now();
      final pesanan = Pesanan(
        id: idBaru(),
        nomorNota: await db.nomorNotaBerikutnya(),
        idAkun: kasir.id,
        idShift: ref.read(shiftAktifProvider)?.id,
        idOpenBill: idBill,
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
      ref.invalidate(penyediaMenuPos);
      ref.invalidate(penyediaPaketPos);
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
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  /// Alur normal: buat pesanan lalu lanjut ke layar bayar.
  Future<void> _buatPesanan() async {
    final id = await _simpanPesanan(widget.idTagihan);
    if (id != null && mounted) context.go('/bayar/$id');
  }

  /// Simpan keranjang sebagai tagihan "belum bayar" (open bill baru).
  /// Pelanggan bisa nambah pesanan lagi nanti dari daftar tagihan.
  Future<void> _simpanBelumBayar() async {
    if (_memproses) return;
    if (ref.read(penyediaKeranjang).isEmpty) return;
    if (ref.read(sesiKasirProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk sebagai kasir dulu.')),
      );
      return;
    }
    final label = await tampilkanLembarWarkop<String>(
      context,
      judul: 'Simpan Belum Bayar',
      child: const _IsiLembarLabelTagihan(),
    );
    if (label == null || label.isEmpty || !mounted) return;
    try {
      final idBill = idBaru();
      await DatabaseLokal.instance.simpanOpenBill(
        OpenBill(
          id: idBill,
          label: label,
          status: 'buka',
          idAkun: ref.read(sesiKasirProvider)!.id,
          statusSinkron: 'tertunda',
          diperbaruiPada: DateTime.now(),
          apakahDihapus: false,
        ),
      );
      final idPesanan = await _simpanPesanan(idBill);
      if (idPesanan != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tersimpan sebagai belum bayar: $label')),
        );
        context.go('/tagihan/$idBill');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan tagihan. Coba lagi.')),
        );
      }
    }
  }

  /// Buka lembar nota: daftar item + total + tombol bayar.
  Future<void> _bukaNota() async {
    HapticFeedback.lightImpact();
    await tampilkanLembarWarkop<void>(
      context,
      judul: 'Nota',
      child: _LembarNota(
        memproses: _memproses,
        saatBuatPesanan: _buatPesanan,
        saatSimpanBelumBayar:
            widget.idTagihan == null ? _simpanBelumBayar : null,
      ),
    );
  }

  /// Sinkron manual saat indikator diketuk.
  Future<void> _sinkronManual() async {
    final notifikasi = ref.read(penyediaStatusSinkron.notifier);
    notifikasi.ubah('Menyinkronkan...');
    try {
      final hasil = await ref.read(penyediaMesinSinkron).sinkronkan();
      if (hasil.gagal == 0) {
        notifikasi.ubah('Tersinkron');
      } else if (hasil.berhasil == 0) {
        notifikasi.ubah('Offline');
      } else {
        notifikasi.ubah('Sebagian gagal');
      }
    } catch (_) {
      notifikasi.ubah('Offline');
    }
    ref.invalidate(penyediaAntreSinkronPos);
  }

  void _muatUlang() {
    ref.invalidate(penyediaKategoriPos);
    ref.invalidate(penyediaMenuPos);
    ref.invalidate(penyediaPaketPos);
    ref.invalidate(penyediaAntreSinkronPos);
  }

  @override
  Widget build(BuildContext context) {
    final kasir = ref.watch(sesiKasirProvider);
    if (kasir == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Masuk sebagai kasir dulu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TombolWarkop(
                  label: 'Ke Layar Kasir',
                  lebarPenuh: false,
                  saatDitekan: () => context.go('/kasir'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final kategoriAsync = ref.watch(penyediaKategoriPos);
    final menuAsync = ref.watch(penyediaMenuPos);
    final paketAsync = ref.watch(penyediaPaketPos);

    final memuat = kategoriAsync.isLoading ||
        menuAsync.isLoading ||
        paketAsync.isLoading;
    final galat =
        kategoriAsync.error ?? menuAsync.error ?? paketAsync.error;

    return Scaffold(
      body: SafeArea(
        // Cek galat DULU: Riverpod menandai provider yang gagal saat
        // loading awal sebagai isLoading + hasError (bukan murni error),
        // sehingga tanpa urutan ini user terjebak di spinner selamanya.
        child: galat != null
            ? StatusError(
                pesan: 'Gagal memuat data menu. Coba lagi ya.',
                saatCobaLagi: _muatUlang,
              )
            : memuat
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _HeaderKasir(
                        namaKasir: kasir.nama,
                        saatKeluar: _keluar,
                        saatSinkron: _sinkronManual,
                      ),
                      if (widget.idTagihan != null)
                        _ChipTagihan(idTagihan: widget.idTagihan!),
                      _bangunPencarian(),
                      _bangunKategori(
                        daftarKategori: kategoriAsync.value ?? const [],
                      ),
                      // Grid menu mengisi ruang sisa; bilah keranjang
                      // mengambang di bawah saat ada isi.
                      Expanded(
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
                      _BilahKeranjang(saatBuka: _bukaNota),
                    ],
                  ),
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
          isDense: true,
        ),
        onChanged: (nilai) => setState(() => _kataKunci = nilai),
      ),
    );
  }

  /// Deretan chip kategori horizontal.
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
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chip.length,
        itemBuilder: (context, indeks) {
          final item = chip[indeks];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChipWarkop(
              label: item.label,
              terpilih: _idKategoriTerpilih == item.idKategori,
              saatDitekan: () =>
                  setState(() => _idKategoriTerpilih = item.idKategori),
            ),
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

/// Header: judul + nama kasir + indikator sinkron + tombol keluar.
class _HeaderKasir extends ConsumerWidget {
  const _HeaderKasir({
    required this.namaKasir,
    required this.saatKeluar,
    required this.saatSinkron,
  });

  final String namaKasir;
  final VoidCallback saatKeluar;
  final VoidCallback saatSinkron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final statusTeks = ref.watch(penyediaStatusSinkron);
    final antreAsync = ref.watch(penyediaAntreSinkronPos);

    final StatusSinkron status;
    switch (statusTeks) {
      case 'Menyinkronkan...':
        status = StatusSinkron.antre;
      case 'Sebagian gagal':
      case 'Offline':
        status = StatusSinkron.gagal;
      default:
        status = StatusSinkron.aman;
    }
    final jumlahAntre = antreAsync.value ?? 0;
    // Bila antre tapi jumlah belum termuat, anggap aman agar tidak
    // menampilkan "Antre 0" yang membingungkan.
    final statusTampil =
        (status == StatusSinkron.antre && antreAsync.isLoading)
            ? StatusSinkron.aman
            : status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kasir POS',
                  style: teks.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Keluar dari sesi kasir',
                icon: const Icon(Icons.logout_outlined, size: 20),
                color: skema.error,
                style: IconButton.styleFrom(
                  backgroundColor: skema.error.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: skema.error.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  saatKeluar();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  namaKasir,
                  style: teks.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IndikatorSinkron(
                status: statusTampil,
                jumlahAntre: jumlahAntre,
                saatDitekan: saatSinkron,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip "Tagihan: <label>" saat layar dibuka dari open bill.
class _ChipTagihan extends ConsumerWidget {
  const _ChipTagihan({required this.idTagihan});

  final String idTagihan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelAsync = ref.watch(penyediaLabelTagihanPos(idTagihan));
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
          backgroundColor: skema.primaryContainer,
        ),
      ),
    );
  }
}

/// Grid 2 kolom kartu menu — permukaan solid, tanpa blur (hemat GPU).
class _GridMenu extends StatelessWidget {
  const _GridMenu({required this.daftarMenu, required this.saatTap});

  final List<Menu> daftarMenu;
  final void Function(Menu menu) saatTap;

  @override
  Widget build(BuildContext context) {
    if (daftarMenu.isEmpty) {
      return const StatusKosong(
        judul: 'Belum ada menu',
        deskripsi:
            'Tidak ada menu di kategori ini. Coba kata kunci lain atau tambah menu dari dasbor owner.',
        inisial: 'M',
      );
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

/// Grid 2 kolom kartu paket kombo.
class _GridPaket extends StatelessWidget {
  const _GridPaket({required this.daftarPaket, required this.saatTap});

  final List<PaketKombo> daftarPaket;
  final void Function(PaketKombo paket) saatTap;

  @override
  Widget build(BuildContext context) {
    if (daftarPaket.isEmpty) {
      return const StatusKosong(
        judul: 'Belum ada paket kombo',
        deskripsi:
            'Paket kombo promo bisa dibuat dari dasbor owner, lalu muncul di sini.',
        inisial: 'K',
      );
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

/// Kartu menu: foto di atas, nama + harga di bawah.
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

  bool get _habis => !widget.menu.tersedia || widget.menu.stok <= 0;
  bool get _menipis =>
      !_habis &&
      widget.menu.stokMinimum > 0 &&
      widget.menu.stok <= widget.menu.stokMinimum;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    final badge = _habis
        ? const _LencanaStok.menipis(label: 'Habis', habis: true)
        : _menipis
            ? const _LencanaStok.menipis(label: 'Menipis')
            : null;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: Opacity(
        opacity: _habis ? 0.45 : 1.0,
        child: GestureDetector(
          onTapDown: _habis ? null : (_) => setState(() => _skala = 0.96),
          onTapUp: _habis ? null : (_) => setState(() => _skala = 1.0),
          onTapCancel: () => setState(() => _skala = 1.0),
          onTap: _habis
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.saatTap();
                },
          child: KartuWarkop(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto menu (atau placeholder tipografis).
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _FotoMenu(
                            fotoUrl: widget.menu.fotoUrl,
                            nama: widget.menu.nama,
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
                  style: teks.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(widget.menu.hargaSatuan),
                  style: TipografiWarkop.nominal.copyWith(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
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

/// Foto menu: berkas lokal bila path lokal, jaringan bila URL,
/// placeholder tipografis bila tidak ada / gagal dimuat (offline).
class _FotoMenu extends StatelessWidget {
  const _FotoMenu({required this.fotoUrl, required this.nama});

  final String? fotoUrl;
  final String nama;

  @override
  Widget build(BuildContext context) {
    final foto = fotoUrl;
    if (foto == null || foto.isEmpty) return _PlaceholderFoto(nama: nama);

    final Widget gambar = foto.startsWith('http')
        ? Image.network(
            foto,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, anak, kemajuan) {
              if (kemajuan == null) return anak;
              return _PlaceholderFoto(nama: nama, memuat: true);
            },
            errorBuilder: (context, galat, tumpukan) =>
                _PlaceholderFoto(nama: nama),
            semanticLabel: nama,
          )
        : Image.file(
            File(foto),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, galat, tumpukan) =>
                _PlaceholderFoto(nama: nama),
            semanticLabel: nama,
          );
    return gambar;
  }
}

/// Placeholder tipografis: inisial menu + warna kategori yang konsisten.
class _PlaceholderFoto extends StatelessWidget {
  const _PlaceholderFoto({required this.nama, this.memuat = false});

  final String nama;
  final bool memuat;

  /// Warna kategori deterministik dari nama menu (stabil antar render).
  Color _warnaKategori(ColorScheme skema) {
    final palet = [
      skema.primary,
      skema.secondary,
      skema.tertiary,
    ];
    var kode = 0;
    for (final unit in nama.codeUnits) {
      kode = (kode * 31 + unit) % 997;
    }
    return palet[kode % palet.length];
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = _warnaKategori(skema);
    final inisial =
        nama.trim().isEmpty ? '•' : nama.trim()[0].toUpperCase();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: warna.withValues(alpha: 0.18),
      child: Center(
        child: memuat
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: warna,
                ),
              )
            : Text(
                inisial,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: warna),
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
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.96),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.saatTap();
        },
        child: KartuWarkop(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LencanaStok.paket(),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.paket.nama,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: teks.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatRupiah(widget.paket.hargaPaket),
                style: TipografiWarkop.nominal.copyWith(
                  fontSize: 16,
                  color: skema.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lencana status: selalu tiga sinyal — warna + ikon + teks.
class _LencanaStok extends StatelessWidget {
  const _LencanaStok.menipis({required this.label, this.habis = false})
      : _paket = false;
  const _LencanaStok.paket()
      : label = 'Paket',
        habis = false,
        _paket = true;

  final String label;
  final bool habis;
  final bool _paket;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final Color latar;
    final Color isi;
    final IconData ikon;
    if (_paket) {
      latar = skema.primary.withValues(alpha: 0.15);
      isi = skema.primary;
      ikon = Icons.local_offer_outlined;
    } else if (habis) {
      latar = skema.error.withValues(alpha: 0.15);
      isi = skema.error;
      ikon = Icons.remove_shopping_cart_outlined;
    } else {
      latar = skema.tertiaryContainer;
      isi = skema.onTertiaryContainer;
      ikon = Icons.warning_amber_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: isi),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isi,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Bilah keranjang mengambang: total menonjol + jumlah item.
/// Muncul hanya saat keranjang ada isi; ketuk untuk buka lembar nota.
class _BilahKeranjang extends ConsumerWidget {
  const _BilahKeranjang({required this.saatBuka});

  final VoidCallback saatBuka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baris = ref.watch(penyediaKeranjang);
    if (baris.isEmpty) return const SizedBox.shrink();

    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: saatBuka,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          decoration: BoxDecoration(
            color: skema.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: skema.shadow.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Keranjang • ${baris.totalItem} item',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: skema.onPrimary),
                    ),
                    Text(
                      formatRupiah(baris.totalHarga),
                      style: TipografiWarkop.nominal.copyWith(
                        fontSize: 20,
                        color: skema.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: skema.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nota',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            color: skema.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: skema.onPrimary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isi lembar nota: daftar item + total + tombol bayar.
/// Dibuka via [tampilkanLembarWarkop] (blur latar, max 85% layar).
class _LembarNota extends ConsumerWidget {
  const _LembarNota({
    required this.memproses,
    required this.saatBuatPesanan,
    this.saatSimpanBelumBayar,
  });

  final bool memproses;
  final VoidCallback saatBuatPesanan;
  final VoidCallback? saatSimpanBelumBayar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baris = ref.watch(penyediaKeranjang);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    final totalHemat =
        baris.fold(0, (total, item) => total + item.potonganDiskon);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Nota', style: teks.titleLarge),
              const SizedBox(width: 8),
              if (baris.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: skema.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${baris.totalItem} item',
                    style: teks.labelLarge?.copyWith(
                      color: skema.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              if (totalHemat > 0)
                Text(
                  'Hemat ${formatRupiah(totalHemat)}',
                  style: teks.labelLarge?.copyWith(
                    color: skema.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (baris.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Ketuk menu untuk menambah ke nota.',
                textAlign: TextAlign.center,
                style: teks.bodyLarge?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in baris)
                  _BarisNota(
                    key: ValueKey(item.idBaris),
                    baris: item,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Total', style: teks.titleLarge),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  formatRupiah(baris.totalHarga),
                  style: TipografiWarkop.nominal.copyWith(
                    fontSize: 32,
                    color: skema.primary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TombolWarkop(
            label: 'Bayar',
            ikon: Icons.receipt_long_outlined,
            memuat: memproses,
            saatDitekan: baris.isEmpty ? null : saatBuatPesanan,
          ),
          if (saatSimpanBelumBayar != null) ...[
            const SizedBox(height: 12),
            TombolWarkop(
              label: 'Simpan Belum Bayar',
              ikon: Icons.bookmark_add_outlined,
              varian: VarianTombol.teks,
              memuat: memproses,
              saatDitekan: baris.isEmpty ? null : saatSimpanBelumBayar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris nota: nama, stepper jumlah, diskon, hapus, catatan.
class _BarisNota extends ConsumerStatefulWidget {
  const _BarisNota({super.key, required this.baris});

  final BarisKeranjang baris;

  @override
  ConsumerState<_BarisNota> createState() => _BarisNotaState();
}

class _BarisNotaState extends ConsumerState<_BarisNota> {
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
    final hasil = await tampilkanLembarWarkop<_DiskonItem>(
      context,
      judul: 'Diskon — ${widget.baris.nama}',
      child: _IsiLembarDiskon(baris: widget.baris),
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
      child: KartuWarkop(
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
                      Text(baris.nama, style: teks.labelLarge),
                      Text(
                        '${formatRupiah(baris.hargaSatuan)} × ${baris.jumlah}',
                        style: teks.bodySmall,
                      ),
                      if (baris.adaDiskon)
                        Text(
                          'Diskon -${formatRupiah(baris.potonganDiskon)}',
                          style: teks.bodySmall?.copyWith(
                            color: skema.secondary,
                            fontWeight: FontWeight.w700,
                          ),
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
                Text(
                  '${baris.jumlah}',
                  style: TipografiWarkop.nominal.copyWith(fontSize: 16),
                ),
                IconButton(
                  tooltip: 'Tambah',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    notifikasi.ubahJumlah(baris.idBaris, baris.jumlah + 1);
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
                    style: TipografiWarkop.nominal.copyWith(
                      fontSize: 16,
                      color: skema.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Diskon item',
                  icon: Icon(
                    Icons.percent_outlined,
                    color: baris.adaDiskon
                        ? skema.secondary
                        : skema.onSurfaceVariant,
                  ),
                  onPressed: _aturDiskon,
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
            const SizedBox(height: 6),
            TextField(
              controller: _catatanController,
              decoration: const InputDecoration(
                hintText: 'Catatan (mis. es sedikit)',
                isDense: true,
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

/// Isi lembar atur diskon satu baris (nominal rupiah atau persen).
class _IsiLembarDiskon extends StatefulWidget {
  const _IsiLembarDiskon({required this.baris});

  final BarisKeranjang baris;

  @override
  State<_IsiLembarDiskon> createState() => _IsiLembarDiskonState();
}

class _IsiLembarDiskonState extends State<_IsiLembarDiskon> {
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
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Potongan: ${formatRupiah(_potongan)}',
            style: TipografiWarkop.nominal.copyWith(
              fontSize: 14,
              color: skema.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TombolWarkop(
                  label: 'Hapus Diskon',
                  varian: VarianTombol.teks,
                  saatDitekan: () => Navigator.of(context).pop(
                    const _DiskonItem(nominal: 0, persen: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TombolWarkop(
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

/// Isi lembar pilih label tagihan saat menyimpan sebagai "belum bayar".
/// Mengembalikan label final (nama ketikan menang atas pilihan meja),
/// atau null bila dibatalkan.
class _IsiLembarLabelTagihan extends StatefulWidget {
  const _IsiLembarLabelTagihan();

  static const daftarMeja = <String>[
    'Meja 1',
    'Meja 2',
    'Meja 3',
    'Meja 4',
    'Meja 5',
    'Meja 6',
    'Meja 7',
    'Meja 8',
    'Meja 9',
    'Meja 10',
    'Meja 11',
    'Meja 12',
  ];

  @override
  State<_IsiLembarLabelTagihan> createState() =>
      _IsiLembarLabelTagihanState();
}

class _IsiLembarLabelTagihanState extends State<_IsiLembarLabelTagihan> {
  final _kontrolNama = TextEditingController();
  String _mejaTerpilih = 'Meja 1';

  @override
  void dispose() {
    _kontrolNama.dispose();
    super.dispose();
  }

  String get _labelFinal {
    final ketikan = _kontrolNama.text.trim();
    return ketikan.isNotEmpty ? ketikan : _mejaTerpilih;
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pesanan dicatat dulu, pelanggan bisa nambah lagi nanti.',
            style: teks.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Pilih Meja',
            style: teks.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final meja in _IsiLembarLabelTagihan.daftarMeja)
                ChipWarkop(
                  label: meja,
                  terpilih: _mejaTerpilih == meja,
                  saatDitekan: () => setState(() => _mejaTerpilih = meja),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kontrolNama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama pelanggan (opsional)',
              hintText: 'cth: Pak Budi',
            ),
          ),
          const SizedBox(height: 16),
          TombolWarkop(
            label: 'Simpan: $_labelFinal',
            ikon: Icons.bookmark_add_outlined,
            saatDitekan: () => Navigator.of(context).pop(_labelFinal),
          ),
        ],
      ),
    );
  }
}

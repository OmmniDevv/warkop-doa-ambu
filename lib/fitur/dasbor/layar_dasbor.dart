import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../printer/layanan_printer.dart';
import 'util_tanggal.dart';

/// Ringkasan angka dasbor owner untuk hari ini.
class RingkasanDasbor {
  const RingkasanDasbor({
    required this.omzetHariIni,
    required this.jumlahPesananHariIni,
    required this.kasbonAktif,
    required this.stokMenipis,
  });

  final int omzetHariIni;
  final int jumlahPesananHariIni;
  final int kasbonAktif;
  final int stokMenipis;
}

/// Hitung ringkasan dari database lokal (offline-first).
final penyediaRingkasanDasbor = FutureProvider<RingkasanDasbor>((ref) async {
  final db = DatabaseLokal.instance;
  final sekarang = DateTime.now();

  final pesanan = await db.daftarPesanan();
  final pesananHariIni = pesanan
      .where((p) => apakahHariYangSama(p.diperbaruiPada, sekarang))
      .toList();
  final omzet = pesananHariIni
      .where((p) => p.status == 'lunas')
      .fold<int>(0, (jumlah, p) => jumlah + p.total);

  final menu = await db.daftarMenu();
  final menipis = menu.where((m) => m.stok <= m.stokMinimum).length;

  final kasbon = await db.daftarKasbon(status: 'belum_lunas');

  return RingkasanDasbor(
    omzetHariIni: omzet,
    jumlahPesananHariIni: pesananHariIni.length,
    kasbonAktif: kasbon.length,
    stokMenipis: menipis,
  );
});

/// Layar dasbor owner: ringkasan harian + menu modul + uji printer.
///
/// Guard: bila belum ada profil pemilik ([penyediaProfilPemilik] null),
/// tampilkan pesan ramah — JANGAN crash.
class LayarDasbor extends ConsumerWidget {
  const LayarDasbor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(penyediaProfilPemilik);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DASBOR OWNER'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _keluar(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: profilAsync.when(
          data: (profil) {
            if (profil == null) {
              return const _PesanProfilKosong();
            }
            return _IsiDasbor(namaWarkop: profil.namaWarkop);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
        ),
      ),
    );
  }

  Future<void> _keluar(BuildContext context, WidgetRef ref) async {
    await ref.read(penyediaServiceAuthOwner).keluar();
    segarkanProfil(ref);
    if (context.mounted) context.go(Rute.masuk);
  }
}

/// Pesan ramah saat profil pemilik belum ada (belum daftar/masuk).
class _PesanProfilKosong extends StatelessWidget {
  const _PesanProfilKosong();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada profil pemilik.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Masuk dulu ya biar dasbor bisa dibuka.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TombolKaca(
            label: 'Ke Halaman Masuk',
            ikon: Icons.login_outlined,
            saatDitekan: () => context.go(Rute.masuk),
          ),
        ],
      ),
    );
  }
}

class _IsiDasbor extends ConsumerWidget {
  const _IsiDasbor({required this.namaWarkop});

  final String namaWarkop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringkasanAsync = ref.watch(penyediaRingkasanDasbor);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(penyediaRingkasanDasbor);
        await ref.read(penyediaRingkasanDasbor.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              namaWarkop,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.merge(TipografiWarkop.judulBrand),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan ${formatTanggalPendek(DateTime.now())}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _JudulBagian('Ringkasan Hari Ini'),
            ringkasanAsync.when(
              data: (r) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _KartuStatistik(
                    judul: 'Omzet Hari Ini',
                    nilai: formatRupiah(r.omzetHariIni),
                    ikon: Icons.payments_outlined,
                    warna: WarnaWarkop.emas,
                  ),
                  _KartuStatistik(
                    judul: 'Pesanan Hari Ini',
                    nilai: '${r.jumlahPesananHariIni}',
                    ikon: Icons.receipt_long_outlined,
                    warna: Theme.of(context).colorScheme.primary,
                  ),
                  _KartuStatistik(
                    judul: 'Kasbon Aktif',
                    nilai: '${r.kasbonAktif}',
                    ikon: Icons.handshake_outlined,
                    warna: WarnaWarkop.kuningAntre,
                  ),
                  _KartuStatistik(
                    judul: 'Stok Menipis',
                    nilai: '${r.stokMenipis}',
                    ikon: Icons.warning_amber_outlined,
                    warna: WarnaWarkop.merahMenyala,
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Gagal memuat ringkasan: $e'),
            ),
            const SizedBox(height: 20),
            const _JudulBagian('Menu Owner'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                for (final item in _menuOwner) _UbinMenu(item: item),
              ],
            ),
            const SizedBox(height: 20),
            TombolKaca(
              label: 'Cetak Uji Printer',
              ikon: Icons.print_outlined,
              saatDitekan: () => _bukaUjiPrinter(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _bukaUjiPrinter(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LembarUjiPrinter(),
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        teks,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: aksen,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _KartuStatistik extends StatelessWidget {
  const _KartuStatistik({
    required this.judul,
    required this.nilai,
    required this.ikon,
    required this.warna,
  });

  final String judul;
  final String nilai;
  final IconData ikon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      pakaiBlur: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ikon, color: warna, size: 26),
          const SizedBox(height: 10),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.merge(TipografiWarkop.nominal)
                .copyWith(color: warna),
          ),
          const SizedBox(height: 4),
          Text(
            judul,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ItemMenu {
  const _ItemMenu(this.label, this.ikon, this.path);

  final String label;
  final IconData ikon;
  final String path;
}

const _menuOwner = <_ItemMenu>[
  _ItemMenu('Katalog', Icons.restaurant_menu_outlined, '/katalog'),
  _ItemMenu('Laporan', Icons.receipt_long_outlined, '/laporan'),
  _ItemMenu('Jejak Audit', Icons.history_outlined, '/audit'),
  _ItemMenu('Akun Kasir', Icons.badge_outlined, '/akun-kasir'),
  _ItemMenu('Stok', Icons.inventory_2_outlined, '/stok'),
  _ItemMenu('Kombo', Icons.layers_outlined, '/kombo'),
  _ItemMenu('Kasbon', Icons.handshake_outlined, '/kasbon'),
  _ItemMenu('Kas Keluar', Icons.money_off_outlined, '/kas-keluar'),
];

class _UbinMenu extends StatelessWidget {
  const _UbinMenu({required this.item});

  final _ItemMenu item;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(item.path);
        },
        child: KartuKaca(
          pakaiBlur: false,
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.ikon, color: aksen, size: 30),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet uji printer: pindai → pilih perangkat → hubungkan → cetak.
///
/// Memiliki instance [PrinterBluetooth] sendiri yang dibuang saat sheet
/// ditutup agar resource BLE tidak bocor.
class _LembarUjiPrinter extends ConsumerStatefulWidget {
  const _LembarUjiPrinter();

  @override
  ConsumerState<_LembarUjiPrinter> createState() => _LembarUjiPrinterState();
}

class _LembarUjiPrinterState extends ConsumerState<_LembarUjiPrinter> {
  late final PrinterBluetooth _printer;
  late Stream<List<PerangkatPrinter>> _aliranPindai;
  PerangkatPrinter? _terpilih;
  bool _menghubungkan = false;
  bool _mencetak = false;

  @override
  void initState() {
    super.initState();
    _printer = PrinterBluetooth();
    _aliranPindai = _printer.pindai();
  }

  @override
  void dispose() {
    _printer.buang();
    super.dispose();
  }

  void _pindaiUlang() {
    HapticFeedback.lightImpact();
    setState(() {
      _terpilih = null;
      _aliranPindai = _printer.pindai();
    });
  }

  Future<void> _hubungkan() async {
    final perangkat = _terpilih;
    if (perangkat == null || _menghubungkan) return;
    setState(() => _menghubungkan = true);
    try {
      await _printer.hubungkan(perangkat);
      HapticFeedback.mediumImpact();
    } on PesanPrinter catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.pesan)),
        );
      }
    } finally {
      if (mounted) setState(() => _menghubungkan = false);
    }
  }

  Future<void> _cetakUji() async {
    if (_mencetak) return;
    setState(() => _mencetak = true);
    try {
      await _printer.cetakTeks(
        'Uji cetak Warkop Doa Ambu\n'
        '${formatTanggalWaktu(DateTime.now())}\n'
        'Printer terhubung!',
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teks uji terkirim ke printer.')),
        );
      }
    } on PesanPrinter catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.pesan)),
        );
      }
    } finally {
      if (mounted) setState(() => _mencetak = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Uji Printer Bluetooth',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<PerangkatPrinter>>(
            stream: _aliranPindai,
            initialData: const [],
            builder: (context, snapshot) {
              final daftar = snapshot.data ?? const [];
              final nilai = daftar.any((p) => p.id == _terpilih?.id)
                  ? _terpilih
                  : null;
              return DropdownButtonFormField<PerangkatPrinter>(
                key: ValueKey(nilai?.id),
                initialValue: nilai,
                decoration: const InputDecoration(
                  labelText: 'Perangkat printer',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in daftar)
                    DropdownMenuItem(
                      value: p,
                      child: Text(
                        p.nama,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (p) => setState(() => _terpilih = p),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TombolKaca(
                  label: 'Pindai Ulang',
                  ikon: Icons.refresh_outlined,
                  saatDitekan: _pindaiUlang,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TombolKaca(
                  label: 'Hubungkan',
                  ikon: Icons.bluetooth_outlined,
                  memuat: _menghubungkan,
                  aktif: _terpilih != null,
                  saatDitekan: _hubungkan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<bool>(
            stream: _printer.terhubung,
            initialData: false,
            builder: (context, snapshot) {
              final tersambung = snapshot.data ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        tersambung
                            ? Icons.bluetooth_connected_outlined
                            : Icons.bluetooth_disabled_outlined,
                        color: tersambung
                            ? WarnaWarkop.hijauAman
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tersambung ? 'Terhubung' : 'Belum terhubung',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TombolKaca(
                    label: 'Cetak Teks Uji',
                    ikon: Icons.print_outlined,
                    memuat: _mencetak,
                    aktif: tersambung,
                    saatDitekan: _cetakUji,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

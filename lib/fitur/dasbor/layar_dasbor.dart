import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/waktu_wib.dart';
import '../../bersama/izin/layanan_izin.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';
import '../printer/layanan_printer.dart';
import 'util_tanggal.dart';
import 'diagram_omzet.dart';
import '../kasir/penyedia_kasir.dart';

/// Ringkasan angka dasbor owner.
///
/// Batas periode memakai Asia/Jakarta (WIB) eksplisit:
/// hari = 00:00–24:00 WIB, minggu = Senin–Minggu WIB,
/// bulan = kalender berjalan WIB.
class RingkasanDasbor {
  const RingkasanDasbor({
    required this.omzetHariIni,
    required this.jumlahPesananHariIni,
    required this.kasbonAktif,
    required this.stokMenipis,
    required this.omzetKemarin,
    required this.omzetMingguIni,
    required this.jumlahPesananMingguIni,
    required this.omzetBulanIni,
    required this.jumlahPesananBulanIni,
    required this.bahanMenipis,
  });

  final int omzetHariIni;
  final int jumlahPesananHariIni;
  final int kasbonAktif;
  final int stokMenipis;

  final int omzetKemarin;
  final int omzetMingguIni;
  final int jumlahPesananMingguIni;
  final int omzetBulanIni;
  final int jumlahPesananBulanIni;
  final List<Bahan> bahanMenipis;
}

/// Hitung ringkasan dari database lokal (offline-first).
/// Semua batas waktu dalam WIB (Asia/Jakarta).
final penyediaRingkasanDasbor = FutureProvider<RingkasanDasbor>((ref) async {
  final db = DatabaseLokal.instance;
  final sekarang = sekarangWib();
  final awalHari = awalHariWib(sekarang);
  final awalBesok = awalHari.add(const Duration(days: 1));
  final awalKemarin = awalHari.subtract(const Duration(days: 1));
  final awalMinggu = awalMingguWib(sekarang);
  final awalBulan = awalBulanWib(sekarang);

  bool dalamRentang(DateTime waktu, DateTime awal, DateTime akhir) {
    // Perbandingan instant: waktu DB (UTC) vs batas WIB — valid karena
    // DateTime.isBefore membandingkan titik waktu absolut.
    return !waktu.isBefore(awal) && waktu.isBefore(akhir);
  }

  final pesanan = await db.daftarPesanan();
  int omzet(DateTime awal, DateTime akhir) => pesanan
      .where((p) =>
          p.status == 'lunas' && dalamRentang(p.diperbaruiPada, awal, akhir))
      .fold<int>(0, (jumlah, p) => jumlah + p.total);
  int hitungPesanan(DateTime awal, DateTime akhir) => pesanan
      .where((p) => dalamRentang(p.diperbaruiPada, awal, akhir))
      .length;

  final menu = await db.daftarMenu();
  final menipis = menu.where((m) => m.stok <= m.stokMinimum).length;

  final kasbon = await db.daftarKasbon(status: 'belum_lunas');

  final bahan = await db.daftarBahan();
  final bahanMenipis = bahan.where((b) => b.menipis).toList();

  return RingkasanDasbor(
    omzetHariIni: omzet(awalHari, awalBesok),
    jumlahPesananHariIni: hitungPesanan(awalHari, awalBesok),
    kasbonAktif: kasbon.length,
    stokMenipis: menipis,
    omzetKemarin: omzet(awalKemarin, awalHari),
    omzetMingguIni: omzet(awalMinggu, awalBesok),
    jumlahPesananMingguIni: hitungPesanan(awalMinggu, awalBesok),
    omzetBulanIni: omzet(awalBulan, awalBesok),
    jumlahPesananBulanIni: hitungPesanan(awalBulan, awalBesok),
    bahanMenipis: bahanMenipis,
  );
});

/// Layar dasbor owner: sapaan, omzet hero, statistik periode,
/// peringatan bahan, dan aksi cepat.
///
/// Guard: bila belum ada profil pemilik ([penyediaProfilPemilik] null),
/// tampilkan pesan ramah — JANGAN crash.
class LayarDasbor extends ConsumerWidget {
  const LayarDasbor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(penyediaProfilPemilik);

    return profilAsync.when(
      data: (profil) {
        if (profil == null) {
          return const Scaffold(
            body: OrbLatar(
              child: SafeArea(child: _PesanProfilKosong()),
            ),
          );
        }
        return _IsiDasbor(namaWarkop: profil.namaWarkop);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Gagal memuat profil: $e'))),
    );
  }
}

/// Pesan ramah saat profil pemilik belum ada (belum daftar/masuk).
class _PesanProfilKosong extends StatelessWidget {
  const _PesanProfilKosong();

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 72,
            color: gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang,
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

    return Scaffold(
      body: OrbLatar(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(penyediaRingkasanDasbor);
              await ref.read(penyediaRingkasanDasbor.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KepalaDasbor(namaWarkop: namaWarkop),
                  const SizedBox(height: 20),
                  ringkasanAsync.when(
                    data: (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _KartuOmzetHero(ringkasan: r),
                        const SizedBox(height: 12),
                        _BarisStatistik(ringkasan: r),
                        const SizedBox(height: 12),
                        const GrafikOmzet7Hari(),
                        const SizedBox(height: 12),
                        const GrafikJamSibuk(),
                        if (r.bahanMenipis.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _PeringatanBahan(ringkasan: r),
                        ],
                        if (r.kasbonAktif > 0 ||
                            (r.bahanMenipis.isEmpty && r.stokMenipis > 0)) ...[
                          const SizedBox(height: 12),
                          _InfoPerhatian(ringkasan: r),
                        ],
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Gagal memuat ringkasan: $e'),
                  ),
                  const SizedBox(height: 20),
                  const _JudulBagian('Aksi Cepat'),
                  const _AksiCepat(),
                  const SizedBox(height: 24),
                  const _TombolKeluarDasbor(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keluar: role-aware — kalau sesi kasir aktif, keluar HANYA sebagai kasir
/// (sesi owner TIDAK tersentuh). Kalau tidak, keluar sebagai owner.
Future<void> _keluarDariDasbor(BuildContext context, WidgetRef ref) async {
  final adalahKasir = ref.read(sesiKasirProvider) != null;
  final yakin = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Yakin mau keluar?'),
      content: Text(
        adalahKasir
            ? 'Kamu akan keluar dari akun kasir di perangkat ini. Sesi owner tidak terganggu.'
            : 'Kamu akan keluar dari akun owner di perangkat ini.',
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
  if (yakin != true || !context.mounted) return;
  if (adalahKasir) {
    ref.read(sesiKasirProvider.notifier).ganti(null);
    ref.read(shiftAktifProvider.notifier).ganti(null);
    if (context.mounted) context.go(Rute.kasir);
    return;
  }
  await ref.read(penyediaServiceAuthOwner).keluar();
  segarkanProfil(ref);
  if (context.mounted) context.go(Rute.selamatDatang);
}

/// Tombol keluar di bagian bawah dasbor — merah agar gampang ditemukan.
class _TombolKeluarDasbor extends ConsumerWidget {
  const _TombolKeluarDasbor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        _keluarDariDasbor(context, ref);
      },
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
    );
  }
}

/// Kepala: sapaan waktu + nama warkop + tanggal + toggle tema + keluar.
class _KepalaDasbor extends ConsumerWidget {
  const _KepalaDasbor({required this.namaWarkop});

  final String namaWarkop;

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam >= 5 && jam < 11) return 'Selamat pagi';
    if (jam >= 11 && jam < 15) return 'Selamat siang';
    if (jam >= 15 && jam < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksRedup = gelap
        ? WarnaWarkop.teksSekunderGelap
        : WarnaWarkop.teksSekunderTerang;
    final teksUtama =
        gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sapaan(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: teksRedup),
              ),
              const SizedBox(height: 2),
              Text(
                namaWarkop,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.merge(
                      TipografiWarkop.judulBrand.copyWith(color: teksUtama),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                formatTanggalPendek(DateTime.now()),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: teksRedup),
              ),
            ],
          ),
        ),
        const TombolTema(),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.lightImpact();
              _keluarDariDasbor(context, ref);
            },
            child: Tooltip(
              message: 'Keluar dari akun owner',
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      WarnaWarkop.merahMenyala.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WarnaWarkop.merahMenyala
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.logout_outlined,
                  color: WarnaWarkop.merahMenyala,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartu hero: angka omzet hari ini + perbandingan vs kemarin.
///
/// Dulu memakai cincin animasi; diganti kartu angka yang bersih karena
/// user meminta "statistik yang seperti diagram, bukan bulet".
/// Diagram batangnya ada di [GrafikOmzet7Hari] dan [GrafikJamSibuk].
class _KartuOmzetHero extends StatelessWidget {
  const _KartuOmzetHero({required this.ringkasan});

  final RingkasanDasbor ringkasan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup = gelap
        ? WarnaWarkop.teksSekunderGelap
        : WarnaWarkop.teksSekunderTerang;

    return KartuKaca(
      tingkat: TingkatKaca.kuat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OMZET HARI INI',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: aksen,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
              const Spacer(),
              _ChipDelta(ringkasan: ringkasan),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatRupiah(ringkasan.omzetHariIni),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ringkasan.jumlahPesananHariIni} transaksi • vs kemarin',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: teksRedup),
          ),
        ],
      ),
    );
  }
}

/// Pil perbandingan omzet vs kemarin.
class _ChipDelta extends StatelessWidget {
  const _ChipDelta({required this.ringkasan});

  final RingkasanDasbor ringkasan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final r = ringkasan;

    late final String teks;
    late final Color warna;
    late final IconData ikon;
    if (r.omzetKemarin <= 0) {
      if (r.omzetHariIni <= 0) {
        teks = 'Belum ada penjualan';
        warna = gelap
            ? WarnaWarkop.teksSekunderGelap
            : WarnaWarkop.teksSekunderTerang;
        ikon = Icons.remove_rounded;
      } else {
        teks = 'Mulai tercatat hari ini';
        warna = WarnaWarkop.hijauAman;
        ikon = Icons.spa_outlined;
      }
    } else {
      final persen =
          ((r.omzetHariIni - r.omzetKemarin) / r.omzetKemarin * 100).round();
      if (persen > 0) {
        teks = '+$persen%';
        warna = WarnaWarkop.hijauAman;
        ikon = Icons.trending_up_rounded;
      } else if (persen < 0) {
        teks = '$persen%';
        warna = WarnaWarkop.merahMenyala;
        ikon = Icons.trending_down_rounded;
      } else {
        teks = '±0%';
        warna = gelap
            ? WarnaWarkop.teksSekunderGelap
            : WarnaWarkop.teksSekunderTerang;
        ikon = Icons.trending_flat_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 6),
          Text(
            teks,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warna,
                ),
          ),
        ],
      ),
    );
  }
}

/// Tiga kartu statistik periode: hari / minggu / bulan ini.
class _BarisStatistik extends StatelessWidget {
  const _BarisStatistik({required this.ringkasan});

  final RingkasanDasbor ringkasan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KartuPeriode(
            judul: 'HARI INI',
            omzet: ringkasan.omzetHariIni,
            transaksi: ringkasan.jumlahPesananHariIni,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KartuPeriode(
            judul: 'MINGGU INI',
            omzet: ringkasan.omzetMingguIni,
            transaksi: ringkasan.jumlahPesananMingguIni,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KartuPeriode(
            judul: 'BULAN INI',
            omzet: ringkasan.omzetBulanIni,
            transaksi: ringkasan.jumlahPesananBulanIni,
          ),
        ),
      ],
    );
  }
}

class _KartuPeriode extends StatelessWidget {
  const _KartuPeriode({
    required this.judul,
    required this.omzet,
    required this.transaksi,
  });

  final String judul;
  final int omzet;
  final int transaksi;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksRedup = gelap
        ? WarnaWarkop.teksSekunderGelap
        : WarnaWarkop.teksSekunderTerang;

    return KartuKaca(
      tanpaBlur: true,
      tingkat: TingkatKaca.ringan,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: aksen,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiahRingkas(omzet),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.merge(TipografiWarkop.nominal),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$transaksi transaksi',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: teksRedup),
          ),
        ],
      ),
    );
  }
}

/// Peringatan bahan baku yang menipis — dari tabel bahan lokal.
class _PeringatanBahan extends StatelessWidget {
  const _PeringatanBahan({required this.ringkasan});

  final RingkasanDasbor ringkasan;

  String _formatStok(double nilai) {
    final teks = nilai.toStringAsFixed(1).replaceAll('.', ',');
    return teks.endsWith(',0') ? teks.substring(0, teks.length - 2) : teks;
  }

  @override
  Widget build(BuildContext context) {
    final bahan = ringkasan.bahanMenipis;

    return KartuKaca(
      tanpaBlur: true,
      tingkat: TingkatKaca.ringan,
      radius: 16,
      border: WarnaWarkop.emas.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: WarnaWarkop.emas,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bahan menipis',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WarnaWarkop.emas.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${bahan.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: WarnaWarkop.emas,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final b in bahan.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    'sisa ${_formatStok(b.stok)} ${b.satuan}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.merge(TipografiWarkop.nominal)
                        .copyWith(color: WarnaWarkop.emas),
                  ),
                ],
              ),
            ),
          if (bahan.length > 4)
            Text(
              '+${bahan.length - 4} bahan lainnya',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go(Rute.stok);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Cek Stok'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info singkat yang perlu perhatian: kasbon & menu hampir habis.
class _InfoPerhatian extends StatelessWidget {
  const _InfoPerhatian({required this.ringkasan});

  final RingkasanDasbor ringkasan;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      tanpaBlur: true,
      tingkat: TingkatKaca.ringan,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (ringkasan.kasbonAktif > 0)
            _BarisInfo(
              ikon: Icons.handshake_outlined,
              warna: WarnaWarkop.kuningAntre,
              teks: '${ringkasan.kasbonAktif} kasbon belum lunas',
              saatDitekan: () => context.push(Rute.kasbon),
            ),
          if (ringkasan.bahanMenipis.isEmpty && ringkasan.stokMenipis > 0)
            _BarisInfo(
              ikon: Icons.inventory_2_outlined,
              warna: WarnaWarkop.merahMenyala,
              teks: '${ringkasan.stokMenipis} menu hampir habis',
              saatDitekan: () => context.go(Rute.stok),
            ),
        ],
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  const _BarisInfo({
    required this.ikon,
    required this.warna,
    required this.teks,
    required this.saatDitekan,
  });

  final IconData ikon;
  final Color warna;
  final String teks;
  final VoidCallback saatDitekan;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          saatDitekan();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(ikon, color: warna, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  teks,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aksi cepat: Laporan (primer), Kelola Kasir, Stok, Uji Printer.
class _AksiCepat extends StatelessWidget {
  const _AksiCepat();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TombolAksiBesar(
                label: 'Laporan',
                ikon: Icons.assessment_rounded,
                saatDitekan: () => context.go(Rute.laporan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TombolAksiKaca(
                label: 'Kelola Kasir',
                ikon: Icons.manage_accounts_outlined,
                saatDitekan: () => context.go(Rute.akunKasir),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TombolAksiKaca(
                label: 'Stok',
                ikon: Icons.inventory_2_outlined,
                saatDitekan: () => context.go(Rute.stok),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TombolAksiKaca(
                label: 'Uji Printer',
                ikon: Icons.print_outlined,
                saatDitekan: () => _bukaUjiPrinter(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tombol primer gradien violet — satu-satunya elemen solid.
class _TombolAksiBesar extends StatelessWidget {
  const _TombolAksiBesar({
    required this.label,
    required this.ikon,
    required this.saatDitekan,
  });

  final String label;
  final IconData ikon;
  final VoidCallback saatDitekan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        saatDitekan();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [aksen, WarnaWarkop.aksenGelapHover],
          ),
          boxShadow: [
            BoxShadow(
              color: aksen.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol aksi gaya kaca — tinggi tetap agar sejajar dalam baris.
class _TombolAksiKaca extends StatelessWidget {
  const _TombolAksiKaca({
    required this.label,
    required this.ikon,
    required this.saatDitekan,
  });

  final String label;
  final IconData ikon;
  final VoidCallback saatDitekan;

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
          saatDitekan();
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: gelap
                ? WarnaWarkop.kacaGelapSedang
                : WarnaWarkop.kacaTerangSedang,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gelap
                  ? WarnaWarkop.borderKacaGelap
                  : WarnaWarkop.borderKacaTerang,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: aksen, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: gelap
                          ? WarnaWarkop.teksGelap
                          : WarnaWarkop.teksTerang,
                    ),
              ),
            ],
          ),
        ),
      ),
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

void _bukaUjiPrinter(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LembarUjiPrinter(),
  );
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
  Stream<List<PerangkatPrinter>>? _aliranPindai;
  PerangkatPrinter? _terpilih;
  bool _menghubungkan = false;
  bool _mencetak = false;

  @override
  void initState() {
    super.initState();
    _printer = PrinterBluetooth();
    _siapkanPindai();
  }

  /// Minta izin Bluetooth (Android 12+) sebelum pindai printer.
  Future<void> _siapkanPindai() async {
    await LayananIzin.mintaIzinBluetooth();
    if (mounted) {
      setState(() => _aliranPindai = _printer.pindai());
    }
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

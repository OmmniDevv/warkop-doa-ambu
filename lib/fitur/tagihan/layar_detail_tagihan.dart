import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/open_bill.dart';
import '../../data/model/pesanan.dart';
import '../../data/model/pesanan_rincian.dart';
import '../../data/model/shift_kasir.dart';
import '../kasir/penyedia_kasir.dart';
import '../void_kasbon/dialog_void.dart';
import 'layar_daftar_tagihan.dart' show formatWaktuSingkat;

/// Satu tagihan terbuka.
final openBillProvider =
    FutureProvider.family<OpenBill?, String>((ref, idTagihan) async {
  return DatabaseLokal.instance.ambilOpenBill(idTagihan);
});

/// Seluruh nota milik satu tagihan, terbaru dulu.
///
/// Tidak ada query khusus di database — penyaringan `idOpenBill` dilakukan
/// di Dart sesuai kontrak.
final daftarPesananTagihanProvider =
    FutureProvider.family<List<Pesanan>, String>((ref, idTagihan) async {
  final semua = await DatabaseLokal.instance.daftarPesanan();
  return semua.where((p) => p.idOpenBill == idTagihan).toList();
});

/// Rincian item satu nota.
final rincianPesananProvider =
    FutureProvider.family<List<PesananRincian>, String>(
        (ref, idPesanan) async {
  return DatabaseLokal.instance.daftarRincianPesanan(idPesanan);
});

/// Detail satu tagihan: daftar nota, bayar per nota, pisah nota, tutup.
class LayarDetailTagihan extends ConsumerStatefulWidget {
  const LayarDetailTagihan({super.key, required this.idTagihan});

  final String idTagihan;

  @override
  ConsumerState<LayarDetailTagihan> createState() =>
      _LayarDetailTagihanState();
}

class _LayarDetailTagihanState extends ConsumerState<LayarDetailTagihan> {
  bool _modePisah = false;
  final _terpilih = <String>{};
  bool _memuat = false;
  bool _memisah = false;

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  void _kembali() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tagihan');
    }
  }

  void _segarkan() {
    ref.invalidate(openBillProvider(widget.idTagihan));
    ref.invalidate(daftarPesananTagihanProvider(widget.idTagihan));
    ref.invalidate(rincianPesananProvider);
  }

  /// Ambil id shift aktif bila tersedia; null bila tidak ada / gagal baca.
  ///
  /// [shiftAktifProvider] adalah NotifierProvider<..., ShiftKasir?>
  /// (Riverpod 3.4.3, tanpa StateProvider) — dibaca langsung, bukan
  /// AsyncValue.
  String? _idShiftAktif() {
    final ShiftKasir? shift = ref.read(shiftAktifProvider);
    return shift?.id;
  }

  Future<void> _tutupTagihan(OpenBill tagihan, List<Pesanan> daftar) async {
    if (_memuat) return;
    if (daftar.any((p) => p.status == 'baru')) {
      _pesan('Masih ada nota yang belum dibayar. Selesaikan dulu ya.');
      return;
    }
    setState(() => _memuat = true);
    try {
      await DatabaseLokal.instance
          .perbaruiOpenBill(tagihan.copyWith(status: 'tutup'));
      if (!mounted) return;
      context.go('/tagihan');
    } catch (_) {
      _pesan('Gagal menutup tagihan. Coba lagi ya.');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _voidPesanan(Pesanan pesanan) async {
    HapticFeedback.lightImpact();
    final hasil = await tampilkanDialogVoid(
      context,
      ref,
      idPesanan: pesanan.id,
      nomorNota: pesanan.nomorNota,
    );
    if (hasil == true && mounted) {
      _pesan('Nota ${pesanan.nomorNota} dibatalkan.');
      _segarkan();
    }
  }

  /// Pisah nota: item terpilih dipindah ke nota mandiri baru.
  Future<void> _pisahNotaTerpilih(List<Pesanan> daftarBaru) async {
    if (_memisah || _terpilih.isEmpty) return;

    final kasir = ref.read(sesiKasirProvider);
    if (kasir == null) {
      _pesan('Masuk sebagai kasir dulu.');
      return;
    }

    setState(() => _memisah = true);
    try {
      final db = DatabaseLokal.instance;

      // Kumpulkan rincian terpilih beserta nota asalnya.
      final pindah = <({Pesanan pesanan, PesananRincian rincian})>[];
      for (final p in daftarBaru) {
        final semua = await ref.read(rincianPesananProvider(p.id).future);
        for (final r in semua) {
          if (_terpilih.contains(r.id)) {
            pindah.add((pesanan: p, rincian: r));
          }
        }
      }
      if (pindah.isEmpty) {
        _pesan('Pilih dulu item yang mau dipisah.');
        return;
      }

      final totalBaru = pindah.fold<int>(0, (s, e) => s + e.rincian.subtotal);
      final nomorNota = await db.nomorNotaBerikutnya();
      final idPesananBaru = idBaru();
      final sekarang = DateTime.now();

      final pesananBaru = Pesanan(
        id: idPesananBaru,
        nomorNota: nomorNota,
        idAkun: kasir.id,
        idShift: _idShiftAktif(),
        idOpenBill: null, // nota pisah berdiri mandiri
        metodeBayar: 'tunai', // dikoreksi saat pembayaran
        status: 'baru',
        total: totalBaru,
        bayar: 0,
        kembalian: 0,
        statusSinkron: 'tertunda',
        diperbaruiPada: sekarang,
        apakahDihapus: false,
      );
      await db.simpanPesanan(pesananBaru);

      // Pindahkan rincian & sesuaikan total nota lama.
      final kurangPerNota = <String, int>{};
      for (final e in pindah) {
        final r = e.rincian;
        await db.simpanRincian(PesananRincian(
          id: idBaru(),
          idPesanan: idPesananBaru,
          idMenu: r.idMenu,
          idPaket: r.idPaket,
          namaSnapshot: r.namaSnapshot,
          hargaSnapshot: r.hargaSnapshot,
          jumlah: r.jumlah,
          subtotal: r.subtotal,
          catatan: r.catatan,
          statusSinkron: 'tertunda',
          diperbaruiPada: sekarang,
          apakahDihapus: false,
        ));
        await db.hapusRincian(r.id);
        kurangPerNota[e.pesanan.id] =
            (kurangPerNota[e.pesanan.id] ?? 0) + r.subtotal;
      }
      for (final p in daftarBaru) {
        final kurang = kurangPerNota[p.id];
        if (kurang != null) {
          await db.perbaruiPesanan(p.copyWith(total: p.total - kurang));
        }
      }

      await db.catatAudit(LogAudit(
        id: idBaru(),
        aksi: 'split_bill',
        idAkun: kasir.id,
        idReferensi: widget.idTagihan,
        detail: '{"nota_baru":"$nomorNota",'
            '"jumlah_item":${pindah.length},"total":$totalBaru}',
        dibuatPada: sekarang,
      ));

      if (!mounted) return;
      setState(() {
        _modePisah = false;
        _terpilih.clear();
      });
      _segarkan();
      _pesan('Nota $nomorNota berhasil dipisah.');
    } catch (_) {
      _pesan('Gagal memisah nota. Coba lagi ya.');
    } finally {
      if (mounted) setState(() => _memisah = false);
    }
  }

  void _tampilkanRincian(Pesanan pesanan) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LembarRincian(pesanan: pesanan),
      ),
    );
  }

  void _masukModePisah() {
    HapticFeedback.lightImpact();
    setState(() {
      _modePisah = true;
      _terpilih.clear();
    });
  }

  void _keluarModePisah() {
    setState(() {
      _modePisah = false;
      _terpilih.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagihanAsync = ref.watch(openBillProvider(widget.idTagihan));
    final pesananAsync =
        ref.watch(daftarPesananTagihanProvider(widget.idTagihan));

    return PopScope(
      canPop: !_modePisah,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _modePisah) _keluarModePisah();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_modePisah) {
                _keluarModePisah();
              } else {
                _kembali();
              }
            },
          ),
          title: Text(_modePisah ? 'PISAH NOTA' : 'DETAIL TAGIHAN'),
        ),
        body: SafeArea(
          child: tagihanAsync.when(
            data: (tagihan) {
              if (tagihan == null) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: KartuKaca(
                    child: Text(
                      'Tagihan tidak ditemukan.\n'
                      'Mungkin sudah dihapus dari perangkat ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return pesananAsync.when(
                data: (daftar) => _modePisah
                    ? _tampilanPisah(tagihan, daftar)
                    : _tampilanNormal(tagihan, daftar),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: KartuKaca(
                    child: Text(
                      'Gagal memuat nota tagihan. Coba lagi ya.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(20),
              child: KartuKaca(
                child: Text(
                  'Gagal memuat tagihan. Coba lagi ya.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan normal: ringkasan + daftar nota + aksi bawah.
  Widget _tampilanNormal(OpenBill tagihan, List<Pesanan> daftar) {
    final daftarBaru = daftar.where((p) => p.status == 'baru').toList();
    final totalTagihan = daftar
        .where((p) => p.status != 'void')
        .fold<int>(0, (s, p) => s + p.total);
    final bisaTutup = tagihan.status == 'buka' && daftarBaru.isEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            itemCount: daftar.isEmpty ? 2 : daftar.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _KartuRingkasan(
                    tagihan: tagihan,
                    jumlahNota: daftar.length,
                    totalTagihan: totalTagihan,
                  ),
                );
              }
              if (daftar.isEmpty) {
                return const KartuKaca(
                  tanpaBlur: true,
                  child: Text(
                    'Belum ada nota di tagihan ini.\n'
                    'Tambah pesanan lewat tombol di bawah.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final p = daftar[i - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KartuPesanan(
                  pesanan: p,
                  saatRincian: () => _tampilkanRincian(p),
                  saatBayar: () {
                    HapticFeedback.lightImpact();
                    context.go('/bayar/${p.id}');
                  },
                  saatVoid: () => _voidPesanan(p),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TombolKaca(
                label: 'Tambah Pesanan',
                ikon: Icons.add_shopping_cart,
                saatDitekan: () {
                  HapticFeedback.lightImpact();
                  context.go('/pos/tagihan/${widget.idTagihan}');
                },
              ),
              const SizedBox(height: 12),
              if (bisaTutup)
                TombolKaca(
                  label: 'Tutup Tagihan',
                  ikon: Icons.lock_outline,
                  memuat: _memuat,
                  saatDitekan: () => _tutupTagihan(tagihan, daftar),
                )
              else
                Text(
                  daftarBaru.isEmpty
                      ? 'Tagihan sudah ${tagihan.status == 'tutup' ? 'ditutup' : 'selesai'}.'
                      : 'Tutup tagihan aktif setelah semua nota lunas atau void.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (daftarBaru.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _masukModePisah,
                  icon: const Icon(Icons.call_split),
                  label: const Text('Pisah Nota'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Tampilan mode pisah: checklist rincian dari semua nota 'baru'.
  Widget _tampilanPisah(OpenBill tagihan, List<Pesanan> daftar) {
    final daftarBaru = daftar.where((p) => p.status == 'baru').toList();

    return Column(
      children: [
        Expanded(
          child: daftarBaru.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: KartuKaca(
                    tanpaBlur: true,
                    child: Text(
                      'Tidak ada nota aktif untuk dipisah.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _DaftarPisah(
                  daftarBaru: daftarBaru,
                  terpilih: _terpilih,
                  saatUbah: (idRincian, nilai) {
                    setState(() {
                      if (nilai) {
                        _terpilih.add(idRincian);
                      } else {
                        _terpilih.remove(idRincian);
                      }
                    });
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TombolKaca(
                label: _terpilih.isEmpty
                    ? 'Pilih Item Dulu'
                    : 'Pisah ${_terpilih.length} Item',
                ikon: Icons.call_split,
                aktif: _terpilih.isNotEmpty,
                memuat: _memisah,
                saatDitekan: () => _pisahNotaTerpilih(daftarBaru),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _keluarModePisah,
                child: const Text('Batalkan Mode Pisah'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu ringkasan: label, status, jumlah nota, total berjalan, waktu.
class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({
    required this.tagihan,
    required this.jumlahNota,
    required this.totalTagihan,
  });

  final OpenBill tagihan;
  final int jumlahNota;
  final int totalTagihan;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tagihan.label,
                  style: TipografiWarkop.judulBrand.copyWith(
                    fontSize: 22,
                    color: aksen,
                  ),
                ),
              ),
              _ChipStatus(
                label: tagihan.status == 'buka' ? 'Terbuka' : 'Tutup',
                warna: tagihan.status == 'buka'
                    ? WarnaWarkop.hijauAman
                    : teksSekunder,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                    label: 'Nota', nilai: jumlahNota.toString()),
              ),
              Expanded(
                child: _StatMini(
                  label: 'Total Berjalan',
                  nilai: formatRupiah(totalTagihan),
                  sorot: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Diperbarui ${formatWaktuSingkat(tagihan.diperbaruiPada)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: teksSekunder),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.nilai,
    this.sorot = false,
  });

  final String label;
  final String nilai;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: teksSekunder),
        ),
        const SizedBox(height: 2),
        Text(
          nilai,
          style: (sorot
                  ? TipografiWarkop.nominal
                  : Theme.of(context).textTheme.titleLarge!)
              .copyWith(
            fontWeight: FontWeight.w700,
            color: sorot ? aksen : null,
          ),
        ),
      ],
    );
  }
}

/// Satu kartu nota: nomor, status, total, tombol rincian/bayar/void.
class _KartuPesanan extends ConsumerWidget {
  const _KartuPesanan({
    required this.pesanan,
    required this.saatRincian,
    required this.saatBayar,
    required this.saatVoid,
  });

  final Pesanan pesanan;
  final VoidCallback saatRincian;
  final VoidCallback saatBayar;
  final VoidCallback saatVoid;

  Color _warnaStatus(String status) {
    return switch (status) {
      'lunas' => WarnaWarkop.hijauAman,
      'void' => WarnaWarkop.merahMenyala,
      _ => WarnaWarkop.kuningAntre,
    };
  }

  String _labelStatus(String status) {
    return switch (status) {
      'lunas' => 'Lunas',
      'void' => 'Void',
      _ => 'Baru',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masihBaru = pesanan.status == 'baru';

    return KartuKaca(
      tanpaBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pesanan.nomorNota,
                  style: TipografiWarkop.nominal.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _ChipStatus(
                label: _labelStatus(pesanan.status),
                warna: _warnaStatus(pesanan.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(pesanan.total),
            style: TipografiWarkop.nominal.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saatRincian,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Rincian'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              if (masihBaru) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saatBayar,
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('Bayar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: saatVoid,
                  icon: const Icon(Icons.delete_outline),
                  color: WarnaWarkop.merahMenyala,
                  tooltip: 'Void nota',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Pil status kecil berwarna semantik.
class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.label, required this.warna});

  final String label;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Bottom sheet daftar rincian satu nota (nama × jumlah = subtotal + catatan).
class _LembarRincian extends ConsumerWidget {
  const _LembarRincian({required this.pesanan});

  final Pesanan pesanan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rincianAsync = ref.watch(rincianPesananProvider(pesanan.id));
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Container(
      margin: const EdgeInsets.all(16),
      child: KartuKaca(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rincian ${pesanan.nomorNota}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: rincianAsync.when(
                  data: (daftar) {
                    if (daftar.isEmpty) {
                      return Text(
                        'Nota ini belum punya item.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: teksSekunder),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: daftar.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final r = daftar[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.namaSnapshot} × ${r.jumlah}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                  if (r.catatan != null &&
                                      r.catatan!.isNotEmpty)
                                    Text(
                                      r.catatan!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: teksSekunder),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatRupiah(r.subtotal),
                              style: TipografiWarkop.nominal,
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text(
                    'Gagal memuat rincian. Coba lagi ya.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatRupiah(pesanan.total),
                    style: TipografiWarkop.nominal.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar checklist mode pisah: rincian semua nota 'baru' dikelompokkan
/// per nota.
class _DaftarPisah extends StatelessWidget {
  const _DaftarPisah({
    required this.daftarBaru,
    required this.terpilih,
    required this.saatUbah,
  });

  final List<Pesanan> daftarBaru;
  final Set<String> terpilih;
  final void Function(String idRincian, bool nilai) saatUbah;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      itemCount: daftarBaru.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Centang item yang mau dipisah ke nota baru.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final p = daftarBaru[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _KelompokPisah(
            pesanan: p,
            terpilih: terpilih,
            saatUbah: saatUbah,
          ),
        );
      },
    );
  }
}

class _KelompokPisah extends ConsumerWidget {
  const _KelompokPisah({
    required this.pesanan,
    required this.terpilih,
    required this.saatUbah,
  });

  final Pesanan pesanan;
  final Set<String> terpilih;
  final void Function(String idRincian, bool nilai) saatUbah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;
    final rincianAsync = ref.watch(rincianPesananProvider(pesanan.id));

    return rincianAsync.when(
      data: (daftar) {
        if (daftar.isEmpty) return const SizedBox.shrink();
        return KartuKaca(
          tanpaBlur: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  pesanan.nomorNota,
                  style: TipografiWarkop.nominal.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final r in daftar)
                CheckboxListTile(
                  value: terpilih.contains(r.id),
                  onChanged: (nilai) {
                    HapticFeedback.selectionClick();
                    saatUbah(r.id, nilai ?? false);
                  },
                  activeColor: aksen,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '${r.namaSnapshot} × ${r.jumlah}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: (r.catatan != null && r.catatan!.isNotEmpty)
                      ? Text(
                          r.catatan!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: teksSekunder),
                        )
                      : null,
                  secondary: Text(
                    formatRupiah(r.subtotal),
                    style: TipografiWarkop.nominal,
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

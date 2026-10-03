import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/open_bill.dart';
import '../kasir/penyedia_kasir.dart';

/// Formulir tagihan baru (open bill).
///
/// Label bisa dipilih cepat dari "Meja 1"–"Meja 12" atau diketik manual
/// sebagai nama pelanggan. Pembuatan butuh sesi kasir yang aktif.
class LayarTagihanBaru extends ConsumerStatefulWidget {
  const LayarTagihanBaru({super.key});

  @override
  ConsumerState<LayarTagihanBaru> createState() => _LayarTagihanBaruState();
}

class _LayarTagihanBaruState extends ConsumerState<LayarTagihanBaru> {
  static const _daftarMeja =
      <String>['Meja 1', 'Meja 2', 'Meja 3', 'Meja 4', 'Meja 5', 'Meja 6',
        'Meja 7', 'Meja 8', 'Meja 9', 'Meja 10', 'Meja 11', 'Meja 12'];

  final _kontrolNama = TextEditingController();
  String _mejaTerpilih = 'Meja 1';
  bool _memuat = false;

  @override
  void dispose() {
    _kontrolNama.dispose();
    super.dispose();
  }

  /// Label final: nama ketikan menang atas pilihan meja.
  String get _labelFinal {
    final ketikan = _kontrolNama.text.trim();
    return ketikan.isNotEmpty ? ketikan : _mejaTerpilih;
  }

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

  Future<void> _buatTagihan() async {
    if (_memuat) return;

    final kasir = ref.read(sesiKasirProvider);
    if (kasir == null) {
      _pesan('Masuk sebagai kasir dulu.');
      return;
    }

    setState(() => _memuat = true);
    try {
      final id = idBaru();
      final tagihan = OpenBill(
        id: id,
        label: _labelFinal,
        status: 'buka',
        idAkun: kasir.id,
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.now(),
        apakahDihapus: false,
      );
      await DatabaseLokal.instance.simpanOpenBill(tagihan);
      if (!mounted) return;
      context.go('/tagihan/$id');
    } catch (_) {
      _pesan('Gagal membuat tagihan. Coba lagi ya.');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _kembali,
        ),
        title: const Text('TAGIHAN BARU'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pilih Meja',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final meja in _daftarMeja)
                          _ChipMeja(
                            label: meja,
                            terpilih: _kontrolNama.text.isEmpty &&
                                meja == _mejaTerpilih,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _mejaTerpilih = meja;
                                _kontrolNama.clear();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Atau Nama Pelanggan',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    KartuKaca(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      radius: 16,
                      tanpaBlur: true,
                      child: TextField(
                        controller: _kontrolNama,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'cth: Pak Budi',
                          hintStyle: TextStyle(color: teksSekunder),
                          border: InputBorder.none,
                          suffixIcon: _kontrolNama.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () =>
                                      setState(_kontrolNama.clear),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Isi nama untuk menandai tagihan selain nomor meja.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: teksSekunder),
                    ),
                    const SizedBox(height: 24),
                    KartuKaca(
                      tanpaBlur: true,
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: aksen, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Label tagihan',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: teksSekunder),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _labelFinal,
                                  style: TipografiWarkop.judulBrand.copyWith(
                                    fontSize: 20,
                                    color: aksen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: TombolKaca(
                label: 'Buat Tagihan',
                ikon: Icons.add_circle_outline,
                memuat: _memuat,
                saatDitekan: _buatTagihan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip pilihan meja — visual kaca, tanpa animasi layout.
class _ChipMeja extends StatelessWidget {
  const _ChipMeja({
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final teksSekunder =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: terpilih ? 1.0 : 0.75,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: terpilih
                ? aksen.withValues(alpha: 0.14)
                : (gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: terpilih
                  ? aksen
                  : (gelap
                      ? WarnaWarkop.borderKacaGelap
                      : WarnaWarkop.borderKacaTerang),
              width: terpilih ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: terpilih ? aksen : teksSekunder,
                  fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_tipografi.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/lembar_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_warkop.dart';
import '../../data/model/kas_keluar.dart';
import '../../data/model/log_audit.dart';
import '../kasir/penyedia_kasir.dart';
import '../../bersama/util/waktu_wib.dart';

/// Kategori pengeluaran yang bisa dipilih saat mencatat kas keluar.
const _daftarKategori = [
  'Belanja',
  'Gaji',
  'Sewa',
  'Listrik/Air',
  'Lainnya',
];

/// Nama bulan Bahasa Indonesia untuk format tanggal manual (tanpa intl).
const _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Format tanggal Indonesia: 4 Okt 2026 14:30.
String _formatTanggalJam(DateTime tanggal) {
  final lokal = keWib(tanggal);
  final jam = lokal.hour.toString().padLeft(2, '0');
  final menit = lokal.minute.toString().padLeft(2, '0');
  return '${lokal.day} ${_namaBulan[lokal.month - 1]} ${lokal.year} $jam:$menit';
}

/// Layar daftar kas keluar (pengeluaran di luar penjualan).
///
/// Tombol "Catat Kas Keluar" di area bawah layar; nominal via keypad
/// angka in-app; kategori lewat dropdown.
class LayarKasKeluar extends ConsumerStatefulWidget {
  const LayarKasKeluar({super.key});

  @override
  ConsumerState<LayarKasKeluar> createState() => _LayarKasKeluarState();
}

class _LayarKasKeluarState extends ConsumerState<LayarKasKeluar> {
  Future<List<KasKeluar>>? _daftar;

  @override
  void initState() {
    super.initState();
    _muatUlang();
  }

  void _muatUlang() {
    setState(() {
      _daftar = ref.read(penyediaDatabaseLokal).daftarKasKeluar();
    });
  }

  Future<void> _bukaFormulir() async {
    final tersimpan = await tampilkanLembarWarkop<bool>(
      context,
      judul: 'Catat Kas Keluar',
      child: const _IsiFormKasKeluar(),
    );
    if (tersimpan == true) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KAS KELUAR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _muatUlang(),
          child: FutureBuilder<List<KasKeluar>>(
            future: _daftar,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 64),
                  itemCount: 1,
                  itemBuilder: (context, _) => StatusError(
                    pesan:
                        'Gagal memuat kas keluar. Coba lagi ya.',
                    saatCobaLagi: _muatUlang,
                  ),
                );
              }
              final daftar = snapshot.data ?? [];
              if (daftar.isEmpty) {
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 64),
                  itemCount: 1,
                  itemBuilder: (context, _) => const StatusKosong(
                    judul: 'Belum ada pengeluaran',
                    deskripsi: 'Belum ada pengeluaran tercatat hari ini. '
                        'Catat lewat tombol di bawah ya.',
                    inisial: 'K',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: daftar.length,
                itemBuilder: (context, i) =>
                    _KartuKasKeluar(kasKeluar: daftar[i]),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TombolWarkop(
            label: 'Catat Kas Keluar',
            ikon: Icons.remove_circle_outline_rounded,
            saatDitekan: _bukaFormulir,
          ),
        ),
      ),
    );
  }
}

/// Chip kategori pengeluaran.
class _ChipKategori extends StatelessWidget {
  const _ChipKategori({required this.kategori});

  final String kategori;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: skema.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kategori,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: skema.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Kartu satu pengeluaran: kategori, nominal, catatan, waktu terjadi.
class _KartuKasKeluar extends StatelessWidget {
  const _KartuKasKeluar({required this.kasKeluar});

  final KasKeluar kasKeluar;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final catatan = kasKeluar.catatan?.trim();

    return KartuWarkop(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ChipKategori(kategori: kasKeluar.kategori),
              const Spacer(),
              Text(
                '-${formatRupiah(kasKeluar.nominal)}',
                style: TipografiWarkop.nominal.copyWith(
                  fontSize: 18,
                  color: skema.error,
                ),
              ),
            ],
          ),
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              catatan,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                size: 16,
                color: skema.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _formatTanggalJam(kasKeluar.terjadiPada),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Isi lembar "Catat Kas Keluar": kategori, nominal via keypad, catatan.
///
/// Dibuka via [tampilkanLembarWarkop].
/// Kasir wajib masuk ([sesiKasirProvider]); id shift diambil dari
/// [shiftAktifProvider] bila ada shift yang sedang buka.
class _IsiFormKasKeluar extends ConsumerStatefulWidget {
  const _IsiFormKasKeluar();

  @override
  ConsumerState<_IsiFormKasKeluar> createState() =>
      _IsiFormKasKeluarState();
}

class _IsiFormKasKeluarState
    extends ConsumerState<_IsiFormKasKeluar> {
  final _kontrolCatatan = TextEditingController();

  String _kategori = _daftarKategori.first;
  String _nominalTeks = '';
  String? _pesanError;
  bool _menyimpan = false;

  @override
  void dispose() {
    _kontrolCatatan.dispose();
    super.dispose();
  }

  int get _nominal => int.tryParse(_nominalTeks) ?? 0;

  void _saatAngka(String angka) {
    if (_nominalTeks.length >= 12) return;
    setState(() {
      _nominalTeks += angka;
      _pesanError = null;
    });
  }

  void _saatHapus() {
    if (_nominalTeks.isEmpty) return;
    setState(() {
      _nominalTeks =
          _nominalTeks.substring(0, _nominalTeks.length - 1);
      _pesanError = null;
    });
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (_nominal <= 0) {
      setState(() =>
          _pesanError = 'Nominal harus lebih dari Rp0.');
      return;
    }

    final idAkun = ref.read(sesiKasirProvider)?.id;
    if (idAkun == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masuk sebagai kasir dulu ya.'),
        ),
      );
      return;
    }

    setState(() => _menyimpan = true);
    final id = idBaru();
    final catatan = _kontrolCatatan.text.trim();
    final db = ref.read(penyediaDatabaseLokal);
    await db.simpanKasKeluar(
      KasKeluar(
        id: id,
        idAkun: idAkun,
        idShift: ref.read(shiftAktifProvider)?.id,
        kategori: _kategori,
        nominal: _nominal,
        catatan: catatan.isEmpty ? null : catatan,
        terjadiPada: DateTime.now(),
        diperbaruiPada: DateTime.now(),
      ),
    );
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'catat_kas_keluar',
        idAkun: idAkun,
        idReferensi: id,
        detail: '$_kategori ${formatRupiah(_nominal)}',
        dibuatPada: DateTime.now(),
      ),
    );

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kas keluar ${formatRupiah(_nominal)} tercatat.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            decoration: InputDecoration(
              labelText: 'Kategori',
              prefixIcon:
                  const Icon(Icons.category_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              for (final k in _daftarKategori)
                DropdownMenuItem(value: k, child: Text(k)),
            ],
            onChanged: _menyimpan
                ? null
                : (nilai) {
                    if (nilai != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _kategori = nilai);
                    }
                  },
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '-${formatRupiah(_nominal)}',
              style: TipografiWarkop.nominal.copyWith(
                fontSize: 30,
                color: skema.error,
              ),
            ),
          ),
          Text(
            'Nominal pengeluaran',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          KeypadAngka(
            saatAngka: _saatAngka,
            saatHapus: _saatHapus,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kontrolCatatan,
            enabled: !_menyimpan,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: belanja gula & kopi',
              prefixIcon:
                  const Icon(Icons.edit_note_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_pesanError != null) ...[
            const SizedBox(height: 4),
            Text(
              _pesanError!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: skema.error),
            ),
          ],
          const SizedBox(height: 12),
          TombolWarkop(
            label: 'Simpan Pengeluaran',
            ikon: Icons.save_outlined,
            memuat: _menyimpan,
            saatDitekan: _menyimpan ? null : _simpan,
          ),
        ],
      ),
    );
  }
}

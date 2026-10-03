import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/model/kas_keluar.dart';
import '../../data/model/log_audit.dart';
import '../kasir/penyedia_kasir.dart';

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
  final lokal = tanggal.toLocal();
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
    final tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _LembarFormKasKeluar(),
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
                return _KeadaanKosong(
                  ikon: Icons.cloud_off_outlined,
                  pesan: 'Gagal memuat kas keluar. Tarik ke bawah '
                      'untuk coba lagi ya.',
                  saatMuatUlang: _muatUlang,
                );
              }
              final daftar = snapshot.data ?? [];
              if (daftar.isEmpty) {
                return const _KeadaanKosong(
                  ikon: Icons.money_off_outlined,
                  pesan: 'Belum ada pengeluaran tercatat hari ini.',
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
          child: TombolKaca(
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KartuKaca(
        tanpaBlur: true,
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}

/// Keadaan kosong / gagal muat — pesan ramah Bahasa Indonesia.
class _KeadaanKosong extends StatelessWidget {
  const _KeadaanKosong({
    required this.ikon,
    required this.pesan,
    this.saatMuatUlang,
  });

  final IconData ikon;
  final String pesan;
  final VoidCallback? saatMuatUlang;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(ikon, size: 64, color: skema.onSurfaceVariant),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            pesan,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
          ),
        ),
        if (saatMuatUlang != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: saatMuatUlang,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat Ulang'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lembar bawah "Catat Kas Keluar": kategori, nominal via keypad, catatan.
///
/// Kasir wajib masuk ([sesiKasirProvider]); id shift diambil dari
/// [shiftAktifProvider] bila ada shift yang sedang buka.
class _LembarFormKasKeluar extends ConsumerStatefulWidget {
  const _LembarFormKasKeluar();

  @override
  ConsumerState<_LembarFormKasKeluar> createState() =>
      _LembarFormKasKeluarState();
}

class _LembarFormKasKeluarState
    extends ConsumerState<_LembarFormKasKeluar> {
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
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final warnaKaca =
        gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;

    return Container(
      decoration: BoxDecoration(
        color: warnaKaca,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  color: skema.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Catat Kas Keluar',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
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
                    ?.copyWith(color: WarnaWarkop.merahMenyala),
              ),
            ],
            const SizedBox(height: 12),
            TombolKaca(
              label: 'Simpan Pengeluaran',
              ikon: Icons.save_outlined,
              memuat: _menyimpan,
              saatDitekan: _menyimpan ? null : _simpan,
            ),
          ],
        ),
      ),
    );
  }
}

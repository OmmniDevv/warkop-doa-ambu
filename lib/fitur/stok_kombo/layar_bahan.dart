import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';
import '../../data/model/log_audit.dart';

/// Pilihan satuan bahan.
const daftarSatuanBahan = [
  'pcs',
  'gram',
  'kg',
  'ml',
  'liter',
  'bungkus',
  'ikat',
];

/// Daftar seluruh bahan aktif, urut nama.
final penyediaDaftarBahan = FutureProvider<List<Bahan>>(
  (ref) => DatabaseLokal.instance.daftarBahan(),
);

/// Layar kelola bahan baku: daftar + tambah/ubah/hapus.
///
/// Bumbu TIDAK dicatat — hanya bahan utama yang memengaruhi stok.
class LayarBahan extends ConsumerWidget {
  const LayarBahan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bahanAsync = ref.watch(penyediaDaftarBahan);

    return Scaffold(
      appBar: AppBar(title: const Text('BAHAN')),
      body: OrbLatar(
        child: SafeArea(
          child: bahanAsync.when(
            data: (daftar) => _IsiBahan(daftar: daftar),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat bahan: $e')),
          ),
        ),
      ),
    );
  }
}

class _IsiBahan extends ConsumerWidget {
  const _IsiBahan({required this.daftar});

  final List<Bahan> daftar;

  void _bukaForm(BuildContext context, WidgetRef ref, Bahan? bahan) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LembarBahan(
          bahan: bahan,
          saatSimpan: () => ref.invalidate(penyediaDaftarBahan),
        ),
      ),
    );
  }

  Future<void> _hapus(BuildContext context, WidgetRef ref, Bahan bahan) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Bahan'),
        content: Text('Hapus "${bahan.nama}" dari daftar bahan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    try {
      final db = DatabaseLokal.instance;
      await db.hapusBahanLunak(bahan.id);
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: 'hapus_bahan',
          idReferensi: bahan.id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarBahan);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus bahan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlahMenipis = daftar.where((b) => b.menipis).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Ringkasan ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: KartuKaca(
            tanpaBlur: true,
            border: WarnaWarkop.kuningAntre.withValues(alpha: 0.45),
            child: Row(
              children: [
                Text(
                  '$jumlahMenipis',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: WarnaWarkop.kuningAntre,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'bahan menipis (stok ≤ batas minimum)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Daftar ───────────────────────────────────────────────
        Expanded(
          child: daftar.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: KartuKaca(
                    tanpaBlur: true,
                    child: Text(
                      'Belum ada bahan. Tambahkan bahan utama dulu '
                      '(bumbu tidak dicatat).',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  itemCount: daftar.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BarisBahan(
                      bahan: daftar[i],
                      saatTap: () => _bukaForm(context, ref, daftar[i]),
                      saatHapus: () => _hapus(context, ref, daftar[i]),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TombolKaca(
            label: 'Tambah Bahan',
            ikon: Icons.add_outlined,
            saatDitekan: () => _bukaForm(context, ref, null),
          ),
        ),
      ],
    );
  }
}

class _BarisBahan extends StatelessWidget {
  const _BarisBahan({
    required this.bahan,
    required this.saatTap,
    required this.saatHapus,
  });

  final Bahan bahan;
  final VoidCallback saatTap;
  final VoidCallback saatHapus;

  String _tampilAngka(double nilai) {
    if (nilai == nilai.roundToDouble()) return '${nilai.toInt()}';
    return '$nilai';
  }

  @override
  Widget build(BuildContext context) {
    final menipis = bahan.menipis;

    return GestureDetector(
      onTap: saatTap,
      behavior: HitTestBehavior.opaque,
      child: KartuKaca(
        tanpaBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: menipis
            ? WarnaWarkop.kuningAntre.withValues(alpha: 0.5)
            : null,
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
                          bahan.nama,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (menipis)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: WarnaWarkop.kuningAntre
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: WarnaWarkop.kuningAntre
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'Menipis',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: WarnaWarkop.kuningAntre,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Min: ${_tampilAngka(bahan.stokMinimum)} ${bahan.satuan} · '
                    'Harga: ${formatRupiah(bahan.hargaBeli)}/${bahan.satuan}',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _tampilAngka(bahan.stok),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: menipis
                            ? WarnaWarkop.kuningAntre
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                Text(
                  bahan.satuan,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: saatHapus,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet form tambah/ubah bahan.
class _LembarBahan extends StatefulWidget {
  const _LembarBahan({required this.bahan, required this.saatSimpan});

  /// null = tambah baru.
  final Bahan? bahan;
  final VoidCallback saatSimpan;

  @override
  State<_LembarBahan> createState() => _LembarBahanState();
}

class _LembarBahanState extends State<_LembarBahan> {
  late final TextEditingController _nama;
  late final TextEditingController _stok;
  late final TextEditingController _stokMin;
  late final TextEditingController _harga;
  late String _satuan;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bahan;
    _nama = TextEditingController(text: b?.nama ?? '');
    _stok = TextEditingController(text: b == null ? '' : _angka(b.stok));
    _stokMin =
        TextEditingController(text: b == null ? '' : _angka(b.stokMinimum));
    _harga = TextEditingController(text: b == null ? '' : '${b.hargaBeli}');
    _satuan = b?.satuan ?? 'pcs';
  }

  String _angka(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  @override
  void dispose() {
    _nama.dispose();
    _stok.dispose();
    _stokMin.dispose();
    _harga.dispose();
    super.dispose();
  }

  double _bacaDesimal(TextEditingController kontrol) =>
      double.tryParse(kontrol.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama bahan wajib diisi.')),
      );
      return;
    }
    if (_menyimpan) return;
    setState(() => _menyimpan = true);

    try {
      final db = DatabaseLokal.instance;
      final lama = widget.bahan;
      final bahan = Bahan(
        id: lama?.id ?? idBaru(),
        nama: nama,
        satuan: _satuan,
        stok: _bacaDesimal(_stok).clamp(0, 9999999),
        stokMinimum: _bacaDesimal(_stokMin).clamp(0, 9999999),
        hargaBeli: (int.tryParse(_harga.text.trim()) ?? 0).clamp(0, 999999999),
        statusSinkron: 'tertunda',
        diperbaruiPada: DateTime.now(),
      );
      if (lama == null) {
        await db.simpanBahan(bahan);
      } else {
        await db.perbaruiBahan(bahan);
      }
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: lama == null ? 'tambah_bahan' : 'ubah_bahan',
          idReferensi: bahan.id,
          dibuatPada: DateTime.now(),
        ),
      );
      if (!mounted) return;
      widget.saatSimpan();
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(lama == null ? 'Bahan ditambahkan' : 'Bahan diperbarui'),
        ),
      );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan bahan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final adalahUbah = widget.bahan != null;

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
                adalahUbah ? 'Ubah Bahan' : 'Tambah Bahan',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Hanya bahan utama — bumbu tidak dicatat.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama bahan',
                  hintText: 'Contoh: Kopi Robusta',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _satuan,
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in daftarSatuanBahan)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _satuan = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stok,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Stok ($_satuan)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stokMin,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Stok minimum ($_satuan)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _harga,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Harga beli (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TombolKaca(
                label: adalahUbah ? 'Simpan Perubahan' : 'Tambah Bahan',
                ikon: Icons.check_outlined,
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

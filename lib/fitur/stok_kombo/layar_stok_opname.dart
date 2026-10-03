import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/token_warna.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/bahan.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/menu.dart';
import '../../data/model/stok_opname.dart';
import '../kasir/penyedia_kasir.dart';
import 'layar_bahan.dart' show penyediaDaftarBahan;
import 'penyedia_stok.dart';

/// Layar stok opname: cocokkan stok sistem dengan stok fisik.
///
/// Pilih tipe (Menu/Bahan), isi stok fisik per baris, selisih dihitung
/// otomatis (fisik − sistem). Saat disimpan: tiap baris dicatat ke tabel
/// `stok_opname`, stok sistem disesuaikan ke stok fisik, dan tiap baris
/// dicatat ke `log_audit`.
class LayarStokOpname extends ConsumerStatefulWidget {
  const LayarStokOpname({super.key});

  @override
  ConsumerState<LayarStokOpname> createState() => _LayarStokOpnameState();
}

enum _TipeOpname { menu, bahan }

class _LayarStokOpnameState extends ConsumerState<LayarStokOpname> {
  _TipeOpname _tipe = _TipeOpname.menu;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(penyediaMenuStokBersama);
    final bahanAsync = ref.watch(penyediaDaftarBahan);

    return Scaffold(
      appBar: AppBar(title: const Text('STOK OPNAME')),
      body: OrbLatar(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SegmentedButton<_TipeOpname>(
                  segments: const [
                    ButtonSegment(
                      value: _TipeOpname.menu,
                      label: Text('Menu'),
                      icon: Icon(Icons.restaurant_menu_outlined),
                    ),
                    ButtonSegment(
                      value: _TipeOpname.bahan,
                      label: Text('Bahan'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_tipe},
                  onSelectionChanged: (pilihan) {
                    HapticFeedback.lightImpact();
                    setState(() => _tipe = pilihan.first);
                  },
                ),
              ),
              Expanded(
                child: _tipe == _TipeOpname.menu
                    ? menuAsync.when(
                        data: (daftar) => _DaftarOpnameMenu(daftar: daftar),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Gagal memuat menu: $e')),
                      )
                    : bahanAsync.when(
                        data: (daftar) => _DaftarOpnameBahan(daftar: daftar),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Gagal memuat bahan: $e')),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris input opname generik (menu maupun bahan).
class _EntriFisik {
  _EntriFisik({
    required this.id,
    required this.nama,
    required this.stokSistem,
    required this.satuan,
  });

  final String id;
  final String nama;
  final double stokSistem;
  final String satuan;
  final kontrol = TextEditingController();

  void pasangNilaiAwal() => kontrol.text = _tampil(stokSistem);

  static String _tampil(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  double get stokFisik =>
      double.tryParse(kontrol.text.trim().replaceAll(',', '.')) ?? stokSistem;

  double get selisih => stokFisik - stokSistem;

  void buang() => kontrol.dispose();
}

/// Daftar opname untuk menu (stok bilangan bulat).
class _DaftarOpnameMenu extends StatefulWidget {
  const _DaftarOpnameMenu({required this.daftar});

  final List<Menu> daftar;

  @override
  State<_DaftarOpnameMenu> createState() => _DaftarOpnameMenuState();
}

class _DaftarOpnameMenuState extends State<_DaftarOpnameMenu> {
  late final List<_EntriFisik> _entri;
  final _kontrolCatatan = TextEditingController();
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _entri = [
      for (final m in widget.daftar)
        _EntriFisik(
          id: m.id,
          nama: m.nama,
          stokSistem: m.stok.toDouble(),
          satuan: 'pcs',
        ),
    ];
    for (final e in _entri) {
      e.pasangNilaiAwal();
      e.kontrol.addListener(_segarkan);
    }
  }

  void _segarkan() => setState(() {});

  @override
  void dispose() {
    for (final e in _entri) {
      e.kontrol.removeListener(_segarkan);
      e.buang();
    }
    _kontrolCatatan.dispose();
    super.dispose();
  }

  Future<void> _simpan(WidgetRef ref) async {
    if (_menyimpan) return;
    setState(() => _menyimpan = true);

    final db = DatabaseLokal.instance;
    final dibuatOleh = ref.read(sesiKasirProvider)?.nama ?? 'owner';
    final catatan = _kontrolCatatan.text.trim().isEmpty
        ? null
        : _kontrolCatatan.text.trim();
    var tersimpan = 0;

    try {
      for (final e in _entri) {
        final fisik = e.stokFisik.round().clamp(0, 999999);
        final sistem = e.stokSistem.round();
        await db.catatOpname(
          StokOpname(
            id: idBaru(),
            tipeItem: 'menu',
            idItem: e.id,
            namaSnapshot: e.nama,
            stokSistem: sistem.toDouble(),
            stokFisik: fisik.toDouble(),
            selisih: (fisik - sistem).toDouble(),
            catatan: catatan,
            dibuatOleh: dibuatOleh,
            dibuatPada: DateTime.now(),
          ),
        );
        final menu = widget.daftar.firstWhere((m) => m.id == e.id);
        await db.perbaruiMenu(menu.copyWith(stok: fisik));
        await db.catatAudit(
          LogAudit(
            id: idBaru(),
            aksi: 'stok_opname',
            idReferensi: e.id,
            detail:
                '{"tipe":"menu","stok_sistem":$sistem,"stok_fisik":$fisik}',
            dibuatPada: DateTime.now(),
          ),
        );
        tersimpan++;
      }

      ref
        ..invalidate(penyediaMenuStokBersama)
        ..invalidate(penyediaDaftarBahan);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tersimpan item opname tersimpan')),
      );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan opname: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => _BadanOpname(
        entri: _entri,
        kontrolCatatan: _kontrolCatatan,
        menyimpan: _menyimpan,
        jumlahBerubah: _entri.where((e) => e.selisih != 0).length,
        saatSimpan: () => _simpan(ref),
        kunciAngka: [FilteringTextInputFormatter.digitsOnly],
        tipeKeyboard: TextInputType.number,
      ),
    );
  }
}

/// Daftar opname untuk bahan (stok desimal + satuan).
class _DaftarOpnameBahan extends StatefulWidget {
  const _DaftarOpnameBahan({required this.daftar});

  final List<Bahan> daftar;

  @override
  State<_DaftarOpnameBahan> createState() => _DaftarOpnameBahanState();
}

class _DaftarOpnameBahanState extends State<_DaftarOpnameBahan> {
  late final List<_EntriFisik> _entri;
  final _kontrolCatatan = TextEditingController();
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _entri = [
      for (final b in widget.daftar)
        _EntriFisik(
          id: b.id,
          nama: b.nama,
          stokSistem: b.stok,
          satuan: b.satuan,
        ),
    ];
    for (final e in _entri) {
      e.pasangNilaiAwal();
      e.kontrol.addListener(_segarkan);
    }
  }

  void _segarkan() => setState(() {});

  @override
  void dispose() {
    for (final e in _entri) {
      e.kontrol.removeListener(_segarkan);
      e.buang();
    }
    _kontrolCatatan.dispose();
    super.dispose();
  }

  Future<void> _simpan(WidgetRef ref) async {
    if (_menyimpan) return;
    setState(() => _menyimpan = true);

    final db = DatabaseLokal.instance;
    final dibuatOleh = ref.read(sesiKasirProvider)?.nama ?? 'owner';
    final catatan = _kontrolCatatan.text.trim().isEmpty
        ? null
        : _kontrolCatatan.text.trim();
    var tersimpan = 0;

    try {
      for (final e in _entri) {
        final fisik = e.stokFisik.clamp(0, 9999999).toDouble();
        await db.catatOpname(
          StokOpname(
            id: idBaru(),
            tipeItem: 'bahan',
            idItem: e.id,
            namaSnapshot: e.nama,
            stokSistem: e.stokSistem,
            stokFisik: fisik,
            selisih: fisik - e.stokSistem,
            catatan: catatan,
            dibuatOleh: dibuatOleh,
            dibuatPada: DateTime.now(),
          ),
        );
        final bahan = widget.daftar.firstWhere((b) => b.id == e.id);
        await db.perbaruiBahan(bahan.copyWith(stok: fisik));
        await db.catatAudit(
          LogAudit(
            id: idBaru(),
            aksi: 'stok_opname',
            idReferensi: e.id,
            detail:
                '{"tipe":"bahan","stok_sistem":${e.stokSistem},"stok_fisik":$fisik}',
            dibuatPada: DateTime.now(),
          ),
        );
        tersimpan++;
      }

      ref
        ..invalidate(penyediaMenuStokBersama)
        ..invalidate(penyediaDaftarBahan);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tersimpan bahan opname tersimpan')),
      );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan opname: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => _BadanOpname(
        entri: _entri,
        kontrolCatatan: _kontrolCatatan,
        menyimpan: _menyimpan,
        jumlahBerubah: _entri.where((e) => e.selisih != 0).length,
        saatSimpan: () => _simpan(ref),
        kunciAngka: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        tipeKeyboard: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}

/// Badan daftar opname bersama: daftar entri + catatan + tombol simpan.
class _BadanOpname extends StatelessWidget {
  const _BadanOpname({
    required this.entri,
    required this.kontrolCatatan,
    required this.menyimpan,
    required this.jumlahBerubah,
    required this.saatSimpan,
    required this.kunciAngka,
    required this.tipeKeyboard,
  });

  final List<_EntriFisik> entri;
  final TextEditingController kontrolCatatan;
  final bool menyimpan;
  final int jumlahBerubah;
  final VoidCallback saatSimpan;
  final List<TextInputFormatter> kunciAngka;
  final TextInputType tipeKeyboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: KartuKaca(
            tanpaBlur: true,
            child: Text(
              jumlahBerubah == 0
                  ? 'Semua stok cocok dengan sistem. Ubah angka fisik bila ada selisih.'
                  : '$jumlahBerubah item memiliki selisih — akan disesuaikan ke stok fisik.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: entri.isEmpty
              ? const Center(child: Text('Belum ada item.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: entri.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BarisOpname(
                      entri: entri[i],
                      kunciAngka: kunciAngka,
                      tipeKeyboard: tipeKeyboard,
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: kontrolCatatan,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: opname tutup warung',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TombolKaca(
            label: 'Simpan Opname',
            ikon: Icons.check_outlined,
            memuat: menyimpan,
            saatDitekan: saatSimpan,
          ),
        ),
      ],
    );
  }
}

/// Satu baris opname: nama, stok sistem, input fisik, badge selisih.
class _BarisOpname extends StatelessWidget {
  const _BarisOpname({
    required this.entri,
    required this.kunciAngka,
    required this.tipeKeyboard,
  });

  final _EntriFisik entri;
  final List<TextInputFormatter> kunciAngka;
  final TextInputType tipeKeyboard;

  String _tampil(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  @override
  Widget build(BuildContext context) {
    final selisih = entri.selisih;
    final berubah = selisih != 0;
    final warnaSelisih = !berubah
        ? WarnaWarkop.hijauAman
        : selisih < 0
            ? WarnaWarkop.merahMenyala
            : WarnaWarkop.kuningAntre;

    return KartuKaca(
      tanpaBlur: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: berubah ? warnaSelisih.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entri.nama,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: warnaSelisih.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: warnaSelisih.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${selisih >= 0 ? '+' : ''}${_tampil(selisih)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: warnaSelisih,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistem',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      '${_tampil(entri.stokSistem)} ${entri.satuan}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: entri.kontrol,
                  keyboardType: tipeKeyboard,
                  inputFormatters: kunciAngka,
                  decoration: InputDecoration(
                    labelText: 'Fisik (${entri.satuan})',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

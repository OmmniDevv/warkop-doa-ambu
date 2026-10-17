import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_tipografi.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/chip_warkop.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/lembar_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_warkop.dart';
import '../../data/model/kasbon.dart';
import '../../data/model/log_audit.dart';
import '../kasir/penyedia_kasir.dart';
import '../../bersama/util/waktu_wib.dart';

/// Nama bulan Bahasa Indonesia untuk format tanggal manual (tanpa intl).
const _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _formatTanggal(DateTime tanggal) =>
    '${tanggal.day} ${_namaBulan[tanggal.month - 1]} ${tanggal.year}';

/// Layar daftar kasbon (catatan utang pelanggan).
///
/// Filter status + tombol "Catat Kasbon" di area bawah layar.
/// Aksi per kartu (belum lunas): bayar cicilan via keypad angka.
class LayarKasbon extends ConsumerStatefulWidget {
  const LayarKasbon({super.key});

  @override
  ConsumerState<LayarKasbon> createState() => _LayarKasbonState();
}

class _LayarKasbonState extends ConsumerState<LayarKasbon> {
  static const _labelFilter = ['Semua', 'Belum Lunas', 'Lunas'];
  static const _statusFilter = [null, 'belum_lunas', 'lunas'];

  int _filterAktif = 0;
  Future<List<Kasbon>>? _daftar;

  @override
  void initState() {
    super.initState();
    _muatUlang();
  }

  void _muatUlang() {
    setState(() {
      _daftar = ref
          .read(penyediaDatabaseLokal)
          .daftarKasbon(status: _statusFilter[_filterAktif]);
    });
  }

  Future<void> _bukaFormulirKasbon() async {
    final tersimpan = await tampilkanLembarWarkop<bool>(
      context,
      judul: 'Catat Kasbon Baru',
      child: const _IsiFormKasbon(),
    );
    if (tersimpan == true) _muatUlang();
  }

  Future<void> _bukaBayarCicilan(Kasbon kasbon) async {
    final terbayar = await tampilkanLembarWarkop<bool>(
      context,
      judul: 'Bayar Cicilan',
      child: _IsiBayarKasbon(kasbon: kasbon),
    );
    if (terbayar == true) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KASBON'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  for (var i = 0; i < _labelFilter.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChipWarkop(
                        label: _labelFilter[i],
                        terpilih: _filterAktif == i,
                        saatDitekan: () {
                          setState(() => _filterAktif = i);
                          _muatUlang();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _muatUlang(),
                child: FutureBuilder<List<Kasbon>>(
                  future: _daftar,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 64),
                        itemCount: 1,
                        itemBuilder: (context, _) => StatusError(
                          pesan: 'Gagal memuat kasbon. Coba lagi ya.',
                          saatCobaLagi: _muatUlang,
                        ),
                      );
                    }
                    final daftar = snapshot.data ?? [];
                    if (daftar.isEmpty) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 64),
                        itemCount: 1,
                        itemBuilder: (context, _) => StatusKosong(
                          judul: 'Belum ada kasbon',
                          deskripsi: _filterAktif == 0
                              ? 'Belum ada catatan kasbon. Catat lewat '
                                  'tombol di bawah ya.'
                              : 'Tidak ada kasbon pada filter ini. '
                                  'Coba filter lain.',
                          inisial: 'K',
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          16, 8, 16, 16),
                      itemCount: daftar.length,
                      itemBuilder: (context, i) =>
                          _KartuKasbon(
                        kasbon: daftar[i],
                        saatBayar: () =>
                            _bukaBayarCicilan(daftar[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TombolWarkop(
            label: 'Catat Kasbon',
            ikon: Icons.note_add_outlined,
            saatDitekan: _bukaFormulirKasbon,
          ),
        ),
      ),
    );
  }
}

/// Chip status kasbon: belum lunas (kuning) / lunas (hijau).
class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lunas = status == 'lunas';
    final skema = Theme.of(context).colorScheme;
    final warna = lunas ? skema.secondary : skema.tertiary;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Text(
        lunas ? 'Lunas' : 'Belum Lunas',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Kartu satu kasbon: nama, sisa, status, jatuh tempo, aksi bayar.
class _KartuKasbon extends StatelessWidget {
  const _KartuKasbon({
    required this.kasbon,
    required this.saatBayar,
  });

  final Kasbon kasbon;
  final VoidCallback saatBayar;

  @override
  Widget build(BuildContext context) {
    final sisa = kasbon.nominal - kasbon.sudahBayar;
    final belumLunas = kasbon.status == 'belum_lunas';
    final skema = Theme.of(context).colorScheme;

    return KartuWarkop(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kasbon.namaPelanggan,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _ChipStatus(status: kasbon.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Sisa ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                formatRupiah(sisa),
                style: TipografiWarkop.nominal.copyWith(
                  fontSize: 20,
                  color: belumLunas ? skema.tertiary : skema.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total ${formatRupiah(kasbon.nominal)} · '
            'terbayar ${formatRupiah(kasbon.sudahBayar)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
          ),
          if (kasbon.jatuhTempo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: skema.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Jatuh tempo: ${_formatTanggal(keWib(kasbon.jatuhTempo!))}',
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: skema.onSurfaceVariant,
                          ),
                ),
              ],
            ),
          ],
          if (belumLunas) ...[
            const SizedBox(height: 12),
            TombolWarkop(
              label: 'Bayar Cicilan',
              ikon: Icons.payments_outlined,
              saatDitekan: saatBayar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Isi lembar "Catat Kasbon": nama, nominal via keypad, jatuh tempo.
///
/// Dibuka via [tampilkanLembarWarkop] — keypad in-app agar keyboard
/// OS tidak menutupi antarmuka.
class _IsiFormKasbon extends ConsumerStatefulWidget {
  const _IsiFormKasbon();

  @override
  ConsumerState<_IsiFormKasbon> createState() => _IsiFormKasbonState();
}

class _IsiFormKasbonState extends ConsumerState<_IsiFormKasbon> {
  final _kontrolNama = TextEditingController();

  String _nominalTeks = '';
  DateTime? _jatuhTempo;
  String? _pesanError;
  bool _menyimpan = false;

  @override
  void dispose() {
    _kontrolNama.dispose();
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

  Future<void> _pilihJatuhTempo() async {
    final sekarang = DateTime.now();
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _jatuhTempo ?? sekarang.add(const Duration(days: 7)),
      firstDate: sekarang,
      lastDate: sekarang.add(const Duration(days: 365 * 2)),
      helpText: 'Pilih jatuh tempo',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (dipilih != null) {
      HapticFeedback.selectionClick();
      setState(() => _jatuhTempo = dipilih);
    }
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    final nama = _kontrolNama.text.trim();

    if (nama.isEmpty) {
      setState(() =>
          _pesanError = 'Nama pelanggan wajib diisi ya.');
      return;
    }
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
    final db = ref.read(penyediaDatabaseLokal);
    await db.simpanKasbon(
      Kasbon(
        id: id,
        namaPelanggan: nama,
        nominal: _nominal,
        sudahBayar: 0,
        jatuhTempo: _jatuhTempo,
        status: 'belum_lunas',
        idAkun: idAkun,
        diperbaruiPada: DateTime.now(),
      ),
    );
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'catat_kasbon',
        idAkun: idAkun,
        idReferensi: id,
        detail: 'Kasbon $nama ${formatRupiah(_nominal)}',
        dibuatPada: DateTime.now(),
      ),
    );

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
          TextField(
            controller: _kontrolNama,
            enabled: !_menyimpan,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama pelanggan',
              hintText: 'Contoh: Pak Budi',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              formatRupiah(_nominal),
              style: TipografiWarkop.nominal.copyWith(fontSize: 30),
            ),
          ),
          Text(
            'Nominal kasbon',
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
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 20,
                color: skema.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _jatuhTempo == null
                      ? 'Jatuh tempo: belum dipilih (opsional)'
                      : 'Jatuh tempo: ${_formatTanggal(_jatuhTempo!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: _menyimpan ? null : _pilihJatuhTempo,
                child: const Text('Pilih'),
              ),
            ],
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
            label: 'Simpan Kasbon',
            ikon: Icons.save_outlined,
            memuat: _menyimpan,
            saatDitekan: _menyimpan ? null : _simpan,
          ),
        ],
      ),
    );
  }
}

/// Isi lembar "Bayar Cicilan": nominal via keypad, validasi ≤ sisa.
///
/// Dibuka via [tampilkanLembarWarkop].
/// Saat cicilan menutup sisa → status jadi 'lunas' (sudahBayar = nominal).
class _IsiBayarKasbon extends ConsumerStatefulWidget {
  const _IsiBayarKasbon({required this.kasbon});

  final Kasbon kasbon;

  @override
  ConsumerState<_IsiBayarKasbon> createState() => _IsiBayarKasbonState();
}

class _IsiBayarKasbonState extends ConsumerState<_IsiBayarKasbon> {
  String _nominalTeks = '';
  String? _pesanError;
  bool _menyimpan = false;

  int get _sisa => widget.kasbon.nominal - widget.kasbon.sudahBayar;
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

  Future<void> _bayar() async {
    if (_menyimpan) return;
    if (_nominal <= 0) {
      setState(() =>
          _pesanError = 'Nominal harus lebih dari Rp0.');
      return;
    }
    if (_nominal > _sisa) {
      setState(() => _pesanError =
          'Melebihi sisa ${formatRupiah(_sisa)}. Kurangi ya.');
      return;
    }

    setState(() => _menyimpan = true);
    final totalBayar = widget.kasbon.sudahBayar + _nominal;
    final lunas = totalBayar >= widget.kasbon.nominal;
    final db = ref.read(penyediaDatabaseLokal);
    await db.perbaruiKasbon(
      widget.kasbon.copyWith(
        sudahBayar: lunas ? widget.kasbon.nominal : totalBayar,
        status: lunas ? 'lunas' : 'belum_lunas',
        diperbaruiPada: DateTime.now(),
      ),
    );
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'bayar_kasbon',
        idAkun: ref.read(sesiKasirProvider)?.id,
        idReferensi: widget.kasbon.id,
        detail: 'Cicilan ${formatRupiah(_nominal)}'
            '${lunas ? ' — LUNAS' : ''}',
        dibuatPada: DateTime.now(),
      ),
    );

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lunas
              ? 'Kasbon ${widget.kasbon.namaPelanggan} lunas! 🎉'
              : 'Cicilan ${formatRupiah(_nominal)} tercatat.',
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
          Text(
            '${widget.kasbon.namaPelanggan} · '
            'sisa ${formatRupiah(_sisa)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              formatRupiah(_nominal),
              style: TipografiWarkop.nominal.copyWith(fontSize: 30),
            ),
          ),
          const SizedBox(height: 12),
          KeypadAngka(
            saatAngka: _saatAngka,
            saatHapus: _saatHapus,
          ),
          if (_pesanError != null) ...[
            const SizedBox(height: 8),
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
            label: 'Bayar ${formatRupiah(_nominal)}',
            ikon: Icons.payments_outlined,
            memuat: _menyimpan,
            saatDitekan: _menyimpan ? null : _bayar,
          ),
        ],
      ),
    );
  }
}

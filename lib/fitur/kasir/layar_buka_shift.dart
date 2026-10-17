import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_warkop.dart';
import '../../data/model/akun.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/shift_kasir.dart';
import 'penyedia_kasir.dart';

/// Layar buka shift: kasir mencatat saldo awal kas (uang modal di laci).
///
/// Input [saldoAwal] lewat keypad in-app dengan nilai [formatRupiah] live.
/// Setelah disimpan, sesi shift aktif di [shiftAktifProvider] dan aksi
/// tercatat di [LogAudit].
class LayarBukaShift extends ConsumerStatefulWidget {
  const LayarBukaShift({super.key});

  @override
  ConsumerState<LayarBukaShift> createState() => _LayarBukaShiftState();
}

class _LayarBukaShiftState extends ConsumerState<LayarBukaShift> {
  String _nominal = '';
  bool _memproses = false;

  int get _nilai => _nominal.isEmpty ? 0 : int.parse(_nominal);

  void _saatAngka(String angka) {
    if (_memproses) return;
    if (_nominal.length >= 10) return;
    setState(() {
      // Hindari angka nol di depan.
      _nominal = (_nominal == '0') ? angka : _nominal + angka;
    });
  }

  void _saatHapus() {
    if (_nominal.isEmpty || _memproses) return;
    setState(() => _nominal = _nominal.substring(0, _nominal.length - 1));
  }

  Future<void> _bukaShift(Akun kasir) async {
    if (_memproses) return;
    setState(() => _memproses = true);

    final sekarang = DateTime.now().toUtc();
    final shift = ShiftKasir(
      id: idBaru(),
      idAkun: kasir.id,
      dibukaPada: sekarang,
      saldoAwal: _nilai,
      kasAkhirSistem: _nilai,
      status: 'buka',
      statusSinkron: 'tertunda',
      diperbaruiPada: sekarang,
      apakahDihapus: false,
    );

    final db = ref.read(penyediaDatabaseLokal);
    await db.simpanShift(shift);
    await db.catatAudit(LogAudit(
      id: idBaru(),
      aksi: 'buka_shift',
      idAkun: kasir.id,
      idReferensi: shift.id,
      dibuatPada: sekarang,
    ));

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ref.read(shiftAktifProvider.notifier).ganti(shift);
    setState(() => _memproses = false);
    context.go(Rute.kasirPos);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;
    final kasir = ref.watch(sesiKasirProvider);

    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Buka Shift'),
          actions: const [TombolTema()],
        ),
        body: SafeArea(
          child: StatusKosong(
            judul: 'Belum masuk',
            deskripsi: 'Kamu belum masuk sebagai kasir.',
            inisial: '!',
            labelAksi: 'Pilih Kasir',
            saatAksi: () {
              HapticFeedback.lightImpact();
              context.go('/kasir');
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buka Shift'),
        actions: const [TombolTema()],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: KartuWarkop(
                  child: Column(
                    children: [
                      Text(
                        'Saldo Awal Kas',
                        style: gayaTeks.titleMedium?.copyWith(
                          color: skema.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Halo, ${kasir.nama}! Hitung uang di laci lalu masukkan nominalnya.',
                        textAlign: TextAlign.center,
                        style: gayaTeks.bodyMedium?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: skema.primary.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          formatRupiah(_nilai),
                          textAlign: TextAlign.center,
                          style: gayaTeks.headlineMedium?.copyWith(
                            color: skema.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Area bawah (45%): keypad + tombol utama — terjangkau jempol.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: KeypadAngka(
                saatAngka: _saatAngka,
                saatHapus: _saatHapus,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: TombolWarkop(
                label: 'Buka Shift',
                ikon: Icons.lock_open_outlined,
                memuat: _memproses,
                saatDitekan: () => _bukaShift(kasir),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

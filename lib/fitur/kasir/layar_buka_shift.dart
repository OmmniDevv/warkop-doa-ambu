import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_kaca.dart';
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
    context.go('/pos');
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final kasir = ref.watch(sesiKasirProvider);

    if (kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('BUKA SHIFT'), actions: const [TombolTema()]),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: aksen),
                  const SizedBox(height: 16),
                  Text(
                    'Kamu belum masuk sebagai kasir.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/kasir');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: aksen,
                        side: BorderSide(color: aksen),
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('Pilih Kasir'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BUKA SHIFT'), actions: const [TombolTema()]),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: KartuKaca(
                  pakaiBlur: false,
                  bayangan: false,
                  child: Column(
                    children: [
                      Text(
                        'Saldo Awal Kas',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: aksen),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Halo, ${kasir.nama}! Hitung uang di laci lalu masukkan nominalnya.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: aksen.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          formatRupiah(_nilai),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: aksen,
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
              child: TombolKaca(
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/format/format_uang.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/model/akun.dart';
import '../../data/model/log_audit.dart';
import '../../data/model/shift_kasir.dart';
import 'penyedia_kasir.dart';

/// Ringkasan angka rekonsiliasi kas saat tutup shift.
class _RingkasanShift {
  const _RingkasanShift({
    required this.penjualanTunai,
    required this.kasKeluar,
    required this.kasSistem,
  });

  final int penjualanTunai;
  final int kasKeluar;
  final int kasSistem;
}

/// Layar tutup shift: rekonsiliasi kas sistem vs kas fisik.
///
/// kasAkhirSistem = saldoAwal + totalTunai − totalKasKeluar.
/// Selisih = fisik − sistem ditampilkan dengan warna: hijau (0), merah (!=0).
class LayarTutupShift extends ConsumerStatefulWidget {
  const LayarTutupShift({super.key});

  @override
  ConsumerState<LayarTutupShift> createState() => _LayarTutupShiftState();
}

class _LayarTutupShiftState extends ConsumerState<LayarTutupShift> {
  String _fisik = '';
  bool _memproses = false;

  int get _nilaiFisik => _fisik.isEmpty ? 0 : int.parse(_fisik);

  Future<_RingkasanShift> _muatRingkasan(ShiftKasir shift) async {
    final db = ref.read(penyediaDatabaseLokal);
    final pesanan = await db.daftarPesanan(status: 'lunas');
    final kasKeluar = await db.daftarKasKeluar(idShift: shift.id);

    var penjualanTunai = 0;
    for (final p in pesanan) {
      if (p.idShift == shift.id && p.metodeBayar == 'tunai') {
        penjualanTunai += p.total;
      }
    }
    var totalKasKeluar = 0;
    for (final k in kasKeluar) {
      totalKasKeluar += k.nominal;
    }
    return _RingkasanShift(
      penjualanTunai: penjualanTunai,
      kasKeluar: totalKasKeluar,
      kasSistem: shift.saldoAwal + penjualanTunai - totalKasKeluar,
    );
  }

  void _saatAngka(String angka) {
    if (_memproses || _fisik.length >= 10) return;
    setState(() {
      _fisik = (_fisik == '0') ? angka : _fisik + angka;
    });
  }

  void _saatHapus() {
    if (_fisik.isEmpty || _memproses) return;
    setState(() => _fisik = _fisik.substring(0, _fisik.length - 1));
  }

  Future<void> _tutupShift(
    ShiftKasir shift,
    Akun kasir,
    _RingkasanShift ringkasan,
  ) async {
    if (_memproses) return;
    setState(() => _memproses = true);

    final sekarang = DateTime.now().toUtc();
    final sistem = ringkasan.kasSistem;
    final fisik = _nilaiFisik;
    final selisih = fisik - sistem;

    final db = ref.read(penyediaDatabaseLokal);
    await db.perbaruiShift(shift.copyWith(
      ditutupPada: sekarang,
      kasAkhirSistem: sistem,
      kasAkhirFisik: fisik,
      selisih: selisih,
      status: 'tutup',
      diperbaruiPada: sekarang,
    ));
    await db.catatAudit(LogAudit(
      id: idBaru(),
      aksi: 'tutup_shift',
      idAkun: kasir.id,
      idReferensi: shift.id,
      detail: jsonEncode({'selisih': selisih}),
      dibuatPada: sekarang,
    ));

    if (!mounted) return;
    if (selisih == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    ref.read(shiftAktifProvider.notifier).ganti(null);
    setState(() => _memproses = false);
    context.go('/kasir');
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;
    final shift = ref.watch(shiftAktifProvider);
    final kasir = ref.watch(sesiKasirProvider);

    if (shift == null || kasir == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TUTUP SHIFT')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined, size: 64, color: aksen),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada shift yang sedang dibuka.',
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
      appBar: AppBar(title: const Text('TUTUP SHIFT')),
      body: SafeArea(
        child: FutureBuilder<_RingkasanShift>(
          future: _muatRingkasan(shift),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Gagal menghitung ringkasan shift. Coba lagi ya.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            }

            final ringkasan = snapshot.data!;
            final selisih = _nilaiFisik - ringkasan.kasSistem;
            final warnaSelisih = selisih == 0
                ? WarnaWarkop.hijauAman
                : WarnaWarkop.merahMenyala;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        KartuKaca(
                          pakaiBlur: false,
                          bayangan: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Ringkasan Kas',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: aksen),
                              ),
                              const SizedBox(height: 12),
                              _BarisRingkasan(
                                label: 'Saldo awal',
                                nilai: formatRupiah(shift.saldoAwal),
                              ),
                              _BarisRingkasan(
                                label: 'Penjualan tunai',
                                nilai:
                                    formatRupiah(ringkasan.penjualanTunai),
                              ),
                              _BarisRingkasan(
                                label: 'Kas keluar',
                                nilai:
                                    '-${formatRupiah(ringkasan.kasKeluar)}',
                              ),
                              const Divider(height: 24),
                              _BarisRingkasan(
                                label: 'Kas sistem',
                                nilai: formatRupiah(ringkasan.kasSistem),
                                sorot: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        KartuKaca(
                          pakaiBlur: false,
                          bayangan: false,
                          child: Column(
                            children: [
                              Text(
                                'Kas Fisik (hitung di laci)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: aksen),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                formatRupiah(_nilaiFisik),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: warnaSelisih.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: warnaSelisih,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selisih == 0
                                          ? Icons.check_circle_outline
                                          : Icons.warning_amber_rounded,
                                      color: warnaSelisih,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Selisih: ${formatRupiah(selisih)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: warnaSelisih,
                                            fontWeight: FontWeight.bold,
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
                    label: 'Tutup Shift',
                    ikon: Icons.lock_outline,
                    memuat: _memproses,
                    saatDitekan: () => _tutupShift(shift, kasir, ringkasan),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Satu baris label + nominal pada ringkasan.
class _BarisRingkasan extends StatelessWidget {
  const _BarisRingkasan({
    required this.label,
    required this.nilai,
    this.sorot = false,
  });

  final String label;
  final String nilai;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final gaya = sorot
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: gaya),
          Text(nilai, style: gaya),
        ],
      ),
    );
  }
}

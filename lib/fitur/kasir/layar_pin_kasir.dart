import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../bersama/izin/layanan_izin.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/titik_pin.dart';
import '../../data/model/akun.dart';
import 'keamanan_pin_kasir.dart';
import 'penyedia_kasir.dart';

/// Layar verifikasi PIN kasir 6-digit.
///
/// Pola mengikuti [LayarSetupPinOwner]: TitikPin + KeypadAngka +
/// PembungkusGoyang untuk feedback salah. Setelah benar: sesi kasir
/// diset, lalu cek shift aktif — ada → '/pos', tidak ada → '/shift/buka'.
class LayarPinKasir extends ConsumerStatefulWidget {
  const LayarPinKasir({super.key, required this.idAkun});

  final String idAkun;

  @override
  ConsumerState<LayarPinKasir> createState() => _LayarPinKasirState();
}

class _LayarPinKasirState extends ConsumerState<LayarPinKasir> {
  final _goyang = PengendaliGoyang();

  String _masukan = '';
  bool _tampilkanError = false;
  bool _memproses = false;

  @override
  void dispose() {
    _goyang.dispose();
    super.dispose();
  }

  void _saatAngka(String angka) {
    if (_masukan.length >= 6 || _memproses) return;
    setState(() {
      _masukan += angka;
      _tampilkanError = false;
    });
    if (_masukan.length == 6) {
      Future.delayed(const Duration(milliseconds: 250), _verifikasiPin);
    }
  }

  void _saatHapus() {
    if (_masukan.isEmpty || _memproses) return;
    setState(() {
      _masukan = _masukan.substring(0, _masukan.length - 1);
      _tampilkanError = false;
    });
  }

  Future<void> _verifikasiPin() async {
    if (!mounted || _masukan.length != 6 || _memproses) return;
    setState(() => _memproses = true);

    final db = ref.read(penyediaDatabaseLokal);
    final terdaftar = await db.ambilAkun(widget.idAkun);
    if (!mounted) return;

    final cocok = terdaftar != null &&
        terdaftar.aktif &&
        !terdaftar.apakahDihapus &&
        cocokHashPinKasir(
          pin: _masukan,
          idAkun: widget.idAkun,
          hashTersimpan: terdaftar.pinHash ?? '',
        );

    if (terdaftar != null && cocok) {
      HapticFeedback.mediumImpact();
      ref.read(sesiKasirProvider.notifier).ganti(terdaftar);

      final shift = await db.ambilShiftAktif(terdaftar.id);
      if (!mounted) return;
      ref.read(shiftAktifProvider.notifier).ganti(shift);
      // Mampir ke layar izin dulu bila belum pernah ditampilkan.
      final tujuan = shift != null ? Rute.kasirPos : '/shift/buka';
      context.go(await LayananIzin.tujuanSetelahMasuk(tujuan));
      return;
    }

    _goyang.goyang();
    HapticFeedback.heavyImpact();
    setState(() {
      _tampilkanError = true;
      _masukan = '';
      _memproses = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN salah. Coba lagi ya.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN Kasir'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke pilih kasir',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(Rute.kasir);
          },
        ),
        actions: const [TombolTema()],
      ),
      body: SafeArea(
        child: FutureBuilder<Akun?>(
          future: ref.read(penyediaDatabaseLokal).ambilAkun(widget.idAkun),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final akun = snapshot.data;
            if (snapshot.hasError || akun == null || !akun.aktif) {
              return StatusKosong(
                judul: 'Akun tidak ditemukan',
                deskripsi:
                    'Akun kasir tidak ditemukan atau nonaktif.',
                inisial: '?',
                labelAksi: 'Pilih Kasir Lagi',
                saatAksi: () => context.go('/kasir'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PembungkusGoyang(
                pengendali: _goyang,
                child: KartuWarkop(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: skema.primary.withValues(alpha: 0.15),
                          border:
                              Border.all(color: skema.primary, width: 1.5),
                        ),
                        child: Text(
                          akun.nama.trim().isEmpty
                              ? '?'
                              : akun.nama.trim()[0].toUpperCase(),
                          style: gayaTeks.headlineSmall?.copyWith(
                            color: skema.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Halo, ${akun.nama}!',
                        style: gayaTeks.titleLarge?.copyWith(
                          color: skema.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Masukkan 6 digit PIN kasirmu.',
                        textAlign: TextAlign.center,
                        style: gayaTeks.bodyMedium?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TitikPin(
                        terisi: _masukan.length,
                        tampilkanError: _tampilkanError,
                      ),
                      const SizedBox(height: 28),
                      if (_memproses)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(),
                        )
                      else
                        KeypadAngka(
                          saatAngka: _saatAngka,
                          saatHapus: _saatHapus,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

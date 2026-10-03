import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
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
      context.go(shift != null ? '/pos' : '/shift/buka');
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
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(title: const Text('PIN KASIR'), actions: const [TombolTema()]),
      body: SafeArea(
        child: FutureBuilder<Akun?>(
          future: ref.read(penyediaDatabaseLokal).ambilAkun(widget.idAkun),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final akun = snapshot.data;
            if (snapshot.hasError || akun == null || !akun.aktif) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined, size: 64, color: aksen),
                      const SizedBox(height: 16),
                      Text(
                        'Akun kasir tidak ditemukan atau nonaktif.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/kasir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: aksen,
                            side: BorderSide(color: aksen),
                            minimumSize: const Size(0, 52),
                          ),
                          child: const Text('Pilih Kasir Lagi'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PembungkusGoyang(
                pengendali: _goyang,
                child: KartuKaca(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: aksen.withValues(alpha: 0.15),
                          border: Border.all(color: aksen, width: 1.5),
                        ),
                        child: Text(
                          akun.nama.trim().isEmpty
                              ? '?'
                              : akun.nama.trim()[0].toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: aksen,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Halo, ${akun.nama}!',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: aksen),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Masukkan 6 digit PIN kasirmu.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
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

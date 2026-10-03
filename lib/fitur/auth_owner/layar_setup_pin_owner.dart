import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/titik_pin.dart';
import '../../bersama/widget/tombol_kaca.dart';

/// Layar pembuatan Master PIN 6-digit + aktivasi biometrik.
///
/// Tahap 1: masukkan PIN baru. Tahap 2: konfirmasi PIN.
/// PIN disimpan sebagai hash SHA-256 (bukan teks polos).
/// Terakhir: opsi glass switch untuk biometrik.
class LayarSetupPinOwner extends ConsumerStatefulWidget {
  const LayarSetupPinOwner({super.key});

  @override
  ConsumerState<LayarSetupPinOwner> createState() => _LayarSetupPinOwnerState();
}

class _LayarSetupPinOwnerState extends ConsumerState<LayarSetupPinOwner> {
  final _goyang = PengendaliGoyang();

  String _pinBaru = '';
  String _masukan = '';
  bool _tahapKonfirmasi = false;
  bool _tampilkanError = false;
  bool _pinTersimpan = false;
  bool _biometrikAktif = false;
  bool _dukungBiometrik = false;
  bool _memuat = false;

  @override
  void initState() {
    super.initState();
    _cekBiometrik();
  }

  @override
  void dispose() {
    _goyang.dispose();
    super.dispose();
  }

  Future<void> _cekBiometrik() async {
    final dukung =
        await ref.read(penyediaServiceAuthOwner).perangkatMendukungBiometrik();
    if (mounted) setState(() => _dukungBiometrik = dukung);
  }

  void _saatAngka(String angka) {
    if (_masukan.length >= 6 || _pinTersimpan) return;
    setState(() {
      _masukan += angka;
      _tampilkanError = false;
    });
    if (_masukan.length == 6) {
      Future.delayed(const Duration(milliseconds: 250), _prosesEnamDigit);
    }
  }

  void _saatHapus() {
    if (_masukan.isEmpty || _pinTersimpan) return;
    setState(() {
      _masukan = _masukan.substring(0, _masukan.length - 1);
      _tampilkanError = false;
    });
  }

  Future<void> _prosesEnamDigit() async {
    if (!mounted || _masukan.length != 6) return;

    if (!_tahapKonfirmasi) {
      // Tahap 1 selesai → lanjut konfirmasi.
      setState(() {
        _pinBaru = _masukan;
        _masukan = '';
        _tahapKonfirmasi = true;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    // Tahap 2: cocokkan.
    if (_masukan != _pinBaru) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      setState(() {
        _tampilkanError = true;
        _masukan = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN tidak cocok. Ulangi dari awal ya.'),
        ),
      );
      // Kembali ke tahap 1 setelah jeda singkat.
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() {
          _tahapKonfirmasi = false;
          _pinBaru = '';
          _tampilkanError = false;
        });
      }
      return;
    }

    await _simpanPin();
  }

  Future<void> _simpanPin() async {
    setState(() => _memuat = true);
    final profil = await ref.read(penyediaDatabaseLokal).ambilPemilik();
    if (profil == null) {
      if (!mounted) return;
      setState(() => _memuat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil owner tidak ditemukan. Daftar ulang ya.'),
        ),
      );
      context.go(Rute.daftar);
      return;
    }

    await ref.read(penyediaServiceAuthOwner).simpanPinMaster(
          idPemilik: profil.id,
          pin: _masukan,
        );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _memuat = false;
      _pinTersimpan = true;
      _masukan = '';
    });
    segarkanProfil(ref);
  }

  Future<void> _alihkanBiometrik(bool nilai) async {
    if (!nilai) {
      setState(() => _biometrikAktif = false);
      return;
    }
    HapticFeedback.lightImpact();
    final ok =
        await ref.read(penyediaServiceAuthOwner).aktifkanBiometrik();
    if (!mounted) return;
    setState(() => _biometrikAktif = ok);
    if (ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrik gagal diaktifkan. Coba lagi ya.'),
        ),
      );
    }
  }

  void _selesai() {
    HapticFeedback.lightImpact();
    context.go(Rute.beranda);
  }

  @override
  Widget build(BuildContext context) {
    final gelap = ref.watch(penyediaModeGelap);
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    final judul = _pinTersimpan
        ? 'PIN Tersimpan!'
        : _tahapKonfirmasi
            ? 'Konfirmasi PIN'
            : 'Buat Master PIN';
    final subjudul = _pinTersimpan
        ? 'Kunci pengaman offline warkopmu sudah aktif.'
        : _tahapKonfirmasi
            ? 'Masukkan ulang 6 digit PIN yang sama.'
            : '6 digit untuk otorisasi void & data sensitif.';

    return Scaffold(
      appBar: AppBar(title: const Text('SETUP PIN OWNER')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PembungkusGoyang(
                pengendali: _goyang,
                child: KartuKaca(
                  child: Column(
                    children: [
                      Text(
                        judul,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: aksen),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subjudul,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      if (!_pinTersimpan) ...[
                        TitikPin(
                          terisi: _masukan.length,
                          tampilkanError: _tampilkanError,
                        ),
                        const SizedBox(height: 28),
                        if (_memuat)
                          const CircularProgressIndicator()
                        else
                          KeypadAngka(
                            saatAngka: _saatAngka,
                            saatHapus: _saatHapus,
                          ),
                      ] else ...[
                        _IkonSukses(aksen: aksen),
                        if (_dukungBiometrik) ...[
                          const SizedBox(height: 20),
                          _SaklarBiometrik(
                            aktif: _biometrikAktif,
                            saatUbah: _alihkanBiometrik,
                          ),
                        ],
                        const SizedBox(height: 24),
                        TombolKaca(
                          label: 'Mulai Kelola Warkop',
                          ikon: Icons.storefront_outlined,
                          saatDitekan: _selesai,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_pinTersimpan && _tahapKonfirmasi) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _tahapKonfirmasi = false;
                    _pinBaru = '';
                    _masukan = '';
                  }),
                  child: Text(
                    'Ulangi dari awal',
                    style: TextStyle(color: aksen),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lingkaran centang emas dengan animasi membal.
class _IkonSukses extends StatefulWidget {
  const _IkonSukses({required this.aksen});

  final Color aksen;

  @override
  State<_IkonSukses> createState() => _IkonSuksesState();
}

class _IkonSuksesState extends State<_IkonSukses>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol;
  late final Animation<double> _skala;

  @override
  void initState() {
    super.initState();
    _kontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _skala = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _kontrol, curve: Curves.elasticOut),
    );
    _kontrol.forward();
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _skala,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WarnaWarkop.emas.withValues(alpha: 0.15),
          border: Border.all(color: WarnaWarkop.emas, width: 2),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 44,
          color: WarnaWarkop.emas,
        ),
      ),
    );
  }
}

/// Glass switch untuk aktivasi biometrik.
class _SaklarBiometrik extends StatelessWidget {
  const _SaklarBiometrik({
    required this.aktif,
    required this.saatUbah,
  });

  final bool aktif;
  final ValueChanged<bool> saatUbah;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final border =
        gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint_outlined, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masuk Cepat Biometrik',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  'Sidik jari / Face Unlock',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: aktif,
            activeThumbColor: WarnaWarkop.emas,
            onChanged: saatUbah,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../bersama/izin/layanan_izin.dart';
import '../../bersama/widget/input_warkop.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/tombol_tema.dart';
import '../../bersama/widget/tombol_warkop.dart';

/// Layar masuk owner — untuk email yang sudah terdaftar.
///
/// Setelah masuk, profil diunduh ke SQLite lokal. Jika Master PIN belum
/// dibuat, lanjut ke setup PIN; jika sudah, langsung ke beranda.
class LayarMasukOwner extends ConsumerStatefulWidget {
  const LayarMasukOwner({super.key});

  @override
  ConsumerState<LayarMasukOwner> createState() => _LayarMasukOwnerState();
}

class _LayarMasukOwnerState extends ConsumerState<LayarMasukOwner> {
  final _goyang = PengendaliGoyang();
  late final _emailCtrl = TextEditingController();
  late final _sandiCtrl = TextEditingController();

  bool _sandiTerlihat = false;
  bool _memuat = false;
  String? _errorEmail;
  String? _errorSandi;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sandiCtrl.dispose();
    _goyang.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (_memuat) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final sandi = _sandiCtrl.text;
    var adaError = false;
    setState(() {
      _errorEmail = email.isEmpty ? 'Email wajib diisi' : null;
      _errorSandi = sandi.isEmpty ? 'Kata sandi wajib diisi' : null;
      adaError = _errorEmail != null || _errorSandi != null;
    });
    if (adaError) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _memuat = true);
    final hasil = await ref
        .read(penyediaServiceAuthOwner)
        .masuk(email: email, kataSandi: sandi);
    if (!mounted) return;
    setState(() => _memuat = false);

    if (!hasil.ok) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasil.galat ?? 'Gagal masuk. Periksa email & kata sandi.',
          ),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    segarkanProfil(ref);
    final profil = await ref.read(penyediaDatabaseLokal).ambilPemilik();
    if (!mounted) return;
    if (profil == null || profil.hashPinMaster.isEmpty) {
      context.go(Rute.setupPin);
    } else {
      // Mampir ke layar izin dulu bila belum pernah ditampilkan.
      context.go(await LayananIzin.tujuanSetelahMasuk(Rute.dasbor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(Rute.selamatDatang);
          },
        ),
        actions: const [TombolTema()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PembungkusGoyang(
              pengendali: _goyang,
              child: KartuWarkop(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat datang\nkembali',
                      style: gayaTeks.displaySmall?.copyWith(
                        color: skema.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk untuk mengelola warkopmu.',
                      style: gayaTeks.bodyMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    InputWarkop(
                      label: 'Email',
                      petunjuk: 'nama@email.com',
                      controller: _emailCtrl,
                      ikonDepan: Icons.email_outlined,
                      tipeKeyboard: TextInputType.emailAddress,
                      teksError: _errorEmail,
                      saatBerubah: (_) =>
                          setState(() => _errorEmail = null),
                    ),
                    const SizedBox(height: 16),
                    InputWarkop(
                      label: 'Kata Sandi',
                      petunjuk: 'Kata sandimu',
                      controller: _sandiCtrl,
                      obscureText: !_sandiTerlihat,
                      ikonDepan: _sandiTerlihat
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      aksiIkonDepan: () => setState(
                        () => _sandiTerlihat = !_sandiTerlihat,
                      ),
                      teksError: _errorSandi,
                      saatBerubah: (_) =>
                          setState(() => _errorSandi = null),
                      aksiSelesai: TextInputAction.done,
                    ),
                    const SizedBox(height: 28),
                    TombolWarkop(
                      label: 'Masuk',
                      ikon: Icons.login_outlined,
                      memuat: _memuat,
                      saatDitekan: _masuk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

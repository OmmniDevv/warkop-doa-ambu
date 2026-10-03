import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/tombol_kaca.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _goyang = PengendaliGoyang();
  late final _emailCtrl = TextEditingController();
  late final _sandiCtrl = TextEditingController();

  bool _sandiTerlihat = false;
  bool _memuat = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sandiCtrl.dispose();
    _goyang.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _memuat = true);
    final ok = await ref.read(penyediaServiceAuthOwner).masuk(
          email: _emailCtrl.text,
          kataSandi: _sandiCtrl.text,
        );
    if (!mounted) return;
    setState(() => _memuat = false);

    if (!ok) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal masuk. Periksa email & kata sandi.'),
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
      context.go(Rute.dasbor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gelap = ref.watch(penyediaModeGelap);
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MASUK OWNER'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: PembungkusGoyang(
            pengendali: _goyang,
            child: KartuKaca(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat datang kembali',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: aksen),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profilmu akan diunduh ke HP ini.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Email wajib diisi'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _sandiCtrl,
                      obscureText: !_sandiTerlihat,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Kata sandi wajib diisi'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _sandiTerlihat
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _sandiTerlihat = !_sandiTerlihat,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TombolKaca(
                      label: 'Masuk & Unduh Profil',
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

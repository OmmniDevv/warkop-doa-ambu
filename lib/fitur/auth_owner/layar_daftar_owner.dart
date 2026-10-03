import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/tombol_kaca.dart';
import 'service_auth_owner.dart';

/// Layar pendaftaran akun Owner — portrait, Vintage Glassmorphism.
///
/// Alur: isi formulir → Supabase Auth `signUp` → layar setup Master PIN.
/// Jika email sudah terdaftar: notifikasi ramah → arahkan ke layar masuk.
class LayarDaftarOwner extends ConsumerStatefulWidget {
  const LayarDaftarOwner({super.key});

  @override
  ConsumerState<LayarDaftarOwner> createState() => _LayarDaftarOwnerState();
}

class _LayarDaftarOwnerState extends ConsumerState<LayarDaftarOwner> {
  final _formKey = GlobalKey<FormState>();
  final _goyang = PengendaliGoyang();

  // Kredensial default sesuai spesifikasi.
  late final _namaCtrl = TextEditingController();
  late final _warkopCtrl = TextEditingController(text: 'WARKOP DOA AMBU');
  late final _emailCtrl = TextEditingController(text: 'rega@warbu.id');
  late final _sandiCtrl = TextEditingController(text: 'rega123');
  late final _konfirmasiCtrl = TextEditingController(text: 'rega123');
  late final _kontakCtrl = TextEditingController();

  bool _sandiTerlihat = false;
  bool _konfirmasiTerlihat = false;
  bool _memuat = false;

  static final _polaEmail =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _namaCtrl.dispose();
    _warkopCtrl.dispose();
    _emailCtrl.dispose();
    _sandiCtrl.dispose();
    _konfirmasiCtrl.dispose();
    _kontakCtrl.dispose();
    _goyang.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _memuat = true);
    final hasil = await ref.read(penyediaServiceAuthOwner).daftar(
          namaPemilik: _namaCtrl.text,
          namaWarkop: _warkopCtrl.text,
          email: _emailCtrl.text,
          kataSandi: _sandiCtrl.text,
          nomorKontak:
              _kontakCtrl.text.isEmpty ? null : _kontakCtrl.text,
        );
    if (!mounted) return;
    setState(() => _memuat = false);

    switch (hasil) {
      case HasilDaftar.berhasil:
        HapticFeedback.lightImpact();
        segarkanProfil(ref);
        context.go(Rute.setupPin);
      case HasilDaftar.sudahTerdaftar:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email ini sudah terdaftar. Yuk langsung masuk aja — '
              'profilmu akan diunduh ke HP ini.',
            ),
          ),
        );
        context.go(Rute.masuk);
      case HasilDaftar.gagal:
        _goyang.goyang();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pendaftaran gagal. Cek koneksi internet lalu coba lagi ya.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gelap = ref.watch(penyediaModeGelap);
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderLogo(aksen: aksen),
                  const SizedBox(height: 24),
                  PembungkusGoyang(
                    pengendali: _goyang,
                    child: KartuKaca(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Daftar Akun Owner',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: aksen),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Satu akun untuk seluruh kendali warkopmu.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            _KolomInput(
                              label: 'Nama Lengkap Pemilik',
                              ctrl: _namaCtrl,
                              ikon: Icons.person_outline,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Nama wajib diisi'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _KolomInput(
                              label: 'Nama Warkop',
                              ctrl: _warkopCtrl,
                              ikon: Icons.storefront_outlined,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Nama warkop wajib diisi'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _KolomInput(
                              label: 'Email',
                              ctrl: _emailCtrl,
                              ikon: Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email wajib diisi';
                                }
                                if (!_polaEmail.hasMatch(v.trim())) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _KolomInput(
                              label: 'Kata Sandi',
                              ctrl: _sandiCtrl,
                              ikon: Icons.lock_outline,
                              samarkan: !_sandiTerlihat,
                              akhir: IconButton(
                                icon: Icon(
                                  _sandiTerlihat
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _sandiTerlihat = !_sandiTerlihat,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'Minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _KolomInput(
                              label: 'Konfirmasi Kata Sandi',
                              ctrl: _konfirmasiCtrl,
                              ikon: Icons.lock_reset_outlined,
                              samarkan: !_konfirmasiTerlihat,
                              akhir: IconButton(
                                icon: Icon(
                                  _konfirmasiTerlihat
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _konfirmasiTerlihat =
                                      !_konfirmasiTerlihat,
                                ),
                              ),
                              validator: (v) {
                                if (v != _sandiCtrl.text) {
                                  return 'Konfirmasi tidak cocok';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _KolomInput(
                              label: 'Nomor WhatsApp Toko (opsional)',
                              ctrl: _kontakCtrl,
                              ikon: Icons.chat_outlined,
                              keyboard: TextInputType.phone,
                            ),
                            const SizedBox(height: 24),
                            TombolKaca(
                              label: 'Daftar Akun Owner',
                              ikon: Icons.app_registration_outlined,
                              memuat: _memuat,
                              saatDitekan: _daftar,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go(Rute.masuk),
                              child: Text(
                                'Sudah punya akun? Masuk di sini',
                                style: TextStyle(color: aksen),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Toggle tema mengambang — kanan atas.
            Positioned(
              top: 8,
              right: 12,
              child: _TombolTema(gelap: gelap),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header logo dalam bingkai vintage.
class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.aksen});

  final Color aksen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: aksen.withValues(alpha: 0.5), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/icon/icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.coffee_outlined,
                size: 48,
                color: aksen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'WARKOP DOA AMBU',
          style: TipografiWarkop.judulBrand.copyWith(
            fontSize: 24,
            color: aksen,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'KOPI · TEH · MIE',
          style: TextStyle(
            letterSpacing: 6,
            fontSize: 11,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

/// Satu kolom input form dengan label di atasnya.
class _KolomInput extends StatelessWidget {
  const _KolomInput({
    required this.label,
    required this.ctrl,
    required this.ikon,
    this.validator,
    this.samarkan = false,
    this.akhir,
    this.keyboard,
  });

  final String label;
  final TextEditingController ctrl;
  final IconData ikon;
  final String? Function(String?)? validator;
  final bool samarkan;
  final Widget? akhir;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                ),
          ),
        ),
        TextFormField(
          controller: ctrl,
          obscureText: samarkan,
          keyboardType: keyboard,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            prefixIcon: Icon(ikon, size: 20),
            suffixIcon: akhir,
          ),
        ),
      ],
    );
  }
}

/// Toggle switch kaca untuk mode gelap/terang.
class _TombolTema extends ConsumerWidget {
  const _TombolTema({required this.gelap});

  final bool gelap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border =
        gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang;
    final kaca = gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(penyediaModeGelap.notifier).alihkan();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: kaca,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Icon(
            gelap ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(gelap),
            color: gelap ? WarnaWarkop.emas : WarnaWarkop.aksenTerang,
          ),
        ),
      ),
    );
  }
}

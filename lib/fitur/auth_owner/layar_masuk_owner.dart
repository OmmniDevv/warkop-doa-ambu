import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/penyedia.dart';
import '../../app/router.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/orb_latar.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/tombol_tema.dart';

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
    final hasil = await ref.read(penyediaServiceAuthOwner).masuk(
          email: _emailCtrl.text,
          kataSandi: _sandiCtrl.text,
        );
    if (!mounted) return;
    setState(() => _memuat = false);

    if (!hasil.ok) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasil.galat ?? 'Gagal masuk. Periksa email & kata sandi.'),
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
    final teksUtama = gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang;
    final teksRedup =
        gelap ? WarnaWarkop.teksSekunderGelap : WarnaWarkop.teksSekunderTerang;

    return Scaffold(
      // Tanpa AppBar — judul menyatu dengan kartu kaca.
      body: OrbLatar(
        child: SafeArea(
          child: Stack(
            children: [
              // Toggle tema mengambang kanan atas.
              const Positioned(
                top: 8,
                right: 16,
                child: TombolTema(),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PembungkusGoyang(
                    pengendali: _goyang,
                    child: KartuKaca(
                      tingkat: TingkatKaca.kuat,
                      radius: 28,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Judul serif.
                            Text(
                              'Selamat datang\nkembali',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    color: teksUtama,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Masuk untuk mengelola warkopmu.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: teksRedup),
                            ),
                            const SizedBox(height: 28),
                            _kolomInput(
                              context,
                              controller: _emailCtrl,
                              label: 'Email',
                              ikon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Email wajib diisi'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            _kolomInput(
                              context,
                              controller: _sandiCtrl,
                              label: 'Kata Sandi',
                              ikon: Icons.lock_outline,
                              obscureText: !_sandiTerlihat,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Kata sandi wajib diisi'
                                  : null,
                              suffix: IconButton(
                                icon: Icon(
                                  _sandiTerlihat
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _sandiTerlihat = !_sandiTerlihat,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _tombolMasuk(context, aksen),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kolom input kaca — clean, border halus, fokus menyala violet.
  Widget _kolomInput(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData ikon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        color: gelap ? WarnaWarkop.teksGelap : WarnaWarkop.teksTerang,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, size: 20, color: aksen),
        suffixIcon: suffix,
        filled: true,
        fillColor: gelap
            ? WarnaWarkop.kacaGelapRingan
            : WarnaWarkop.kacaTerangRingan,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: gelap
                ? WarnaWarkop.borderKacaGelap
                : WarnaWarkop.borderKacaTerang,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: gelap
                ? WarnaWarkop.borderKacaGelap
                : WarnaWarkop.borderKacaTerang,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: aksen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WarnaWarkop.merahMenyala),
        ),
      ),
    );
  }

  /// Tombol masuk gradien violet — satu-satunya elemen solid di layar.
  Widget _tombolMasuk(BuildContext context, Color aksen) {
    return GestureDetector(
      onTap: _memuat ? null : _masuk,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _memuat ? 0.7 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [aksen, WarnaWarkop.aksenGelapHover],
            ),
            boxShadow: [
              BoxShadow(
                color: aksen.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _memuat
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_outlined,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Masuk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kompresi_foto.dart';

/// Memotret foto menu lewat kamera in-app.
///
/// Membuka [_HalamanKameraMenu] fullscreen dan mengembalikan path lokal
/// berkas JPG yang sudah dikompresi (100–180 KB), atau `null` bila
/// pengguna batal/gagal.
Future<String?> ambilFotoMenu(BuildContext context) {
  // Halaman transien yang mengembalikan hasil — Navigator 1.0 dipakai di
  // sini karena GoRouter tidak punya konsep "push lalu tunggu hasil".
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _HalamanKameraMenu(),
    ),
  );
}

/// Halaman kamera fullscreen khusus memotret foto menu.
///
/// Hanya kamera belakang, resolusi sedang. Tanpa audio sama sekali —
/// [enableAudio] dimatikan agar tidak meminta izin mikrofon.
class _HalamanKameraMenu extends StatefulWidget {
  const _HalamanKameraMenu();

  @override
  State<_HalamanKameraMenu> createState() => _HalamanKameraMenuState();
}

class _HalamanKameraMenuState extends State<_HalamanKameraMenu> {
  CameraController? _pengendali;
  late final Future<void> _siap;
  bool _memotret = false;
  bool _snackbarGalatTerkirim = false;

  @override
  void initState() {
    super.initState();
    _siap = _siapkanKamera();
  }

  /// Inisialisasi kamera belakang beresolusi sedang.
  Future<void> _siapkanKamera() async {
    final daftar = await availableCameras();
    if (daftar.isEmpty) {
      throw CameraException(
        'TidakAdaKamera',
        'Perangkat ini tidak punya kamera.',
      );
    }
    final belakang = daftar.firstWhere(
      (kamera) => kamera.lensDirection == CameraLensDirection.back,
      orElse: () => daftar.first,
    );
    final pengendali = CameraController(
      belakang,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await pengendali.initialize();
    _pengendali = pengendali;
  }

  /// Menampilkan Snackbar galat (mis. izin ditolak) tepat satu kali.
  void _tampilkanGalatSekali(Object? galat) {
    if (_snackbarGalatTerkirim) return;
    _snackbarGalatTerkirim = true;
    final pesan = galat is CameraException &&
            galat.code == 'CameraAccessDenied'
        ? 'Izin kamera ditolak. Aktifkan izin kamera di Pengaturan agar bisa memotret.'
        : 'Kamera tidak dapat dibuka. Coba lagi nanti.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesan)),
      );
    });
  }

  /// Jepret → kompresi → simpan → kembali dengan path lokal.
  Future<void> _jepret() async {
    final pengendali = _pengendali;
    if (pengendali == null || _memotret) return;
    setState(() => _memotret = true);
    HapticFeedback.mediumImpact();
    try {
      final hasil = await pengendali.takePicture();
      final pathLokal = await kompresFotoMenu(hasil.path, 'menu');
      if (!mounted) return;
      Navigator.of(context).pop(pathLokal);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _memotret = false);
    }
  }

  @override
  void dispose() {
    _pengendali?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _siap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Latar hitam = jendela bidik, bukan warna tema.
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        if (snapshot.hasError) {
          _tampilkanGalatSekali(snapshot.error);
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: Text(
                'Kamera tidak tersedia.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        final pengendali = _pengendali;
        if (pengendali == null || !pengendali.value.isInitialized) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: pengendali.value.aspectRatio,
                      child: CameraPreview(pengendali),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: GestureDetector(
                    onTap: _jepret,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: _memotret
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

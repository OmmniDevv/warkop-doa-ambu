import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Memotret bukti pembayaran lewat kamera in-app.
///
/// Membuka [_HalamanKameraBukti] fullscreen dan mengembalikan path lokal
/// berkas JPG yang sudah dikompresi, atau `null` bila pengguna batal/gagal.
Future<String?> ambilFotoBukti(BuildContext context) {
  // Halaman transien yang mengembalikan hasil — Navigator 1.0 dipakai di
  // sini karena GoRouter tidak punya konsep "push lalu tunggu hasil".
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _HalamanKameraBukti(),
    ),
  );
}

/// Halaman kamera fullscreen khusus memotret bukti pembayaran.
///
/// Hanya kamera belakang, resolusi sedang. Tanpa audio sama sekali —
/// [enableAudio] dimatikan agar tidak meminta izin mikrofon.
class _HalamanKameraBukti extends StatefulWidget {
  const _HalamanKameraBukti();

  @override
  State<_HalamanKameraBukti> createState() => _HalamanKameraBuktiState();
}

class _HalamanKameraBuktiState extends State<_HalamanKameraBukti> {
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
        ? 'Izin kamera ditolak. Aktifkan izin kamera di Pengaturan agar bisa memotret bukti.'
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
      final pathLokal = await _kompresiDanSimpan(hasil.path);
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

  /// Kompresi JPG: sisi terpanjang <= 1280 px, quality menurun 85 → 60 → 40
  /// sampai ukuran 100–180 KB.
  ///
  /// Catatan: bila pada quality 40 ukuran masih di atas 180 KB, berkas
  /// diterima apa adanya — bukti tetap tersimpan dan dapat diunggah.
  Future<String> _kompresiDanSimpan(String pathMentah) async {
    final mentah = await File(pathMentah).readAsBytes();
    final gambar = img.decodeImage(mentah);
    if (gambar == null) {
      throw const FormatException('Berkas foto tidak terbaca.');
    }

    img.Image olahan = gambar;
    final sisiTerpanjang =
        gambar.width > gambar.height ? gambar.width : gambar.height;
    if (sisiTerpanjang > 1280) {
      final skala = 1280 / sisiTerpanjang;
      olahan = img.copyResize(
        gambar,
        width: (gambar.width * skala).round(),
        height: (gambar.height * skala).round(),
      );
    }

    var terkompresi = img.encodeJpg(olahan, quality: 85);
    for (final quality in const [60, 40]) {
      if (terkompresi.length <= 180 * 1024) break;
      terkompresi = img.encodeJpg(olahan, quality: quality);
    }

    final dokumen = await getApplicationDocumentsDirectory();
    final folder = Directory('${dokumen.path}/bukti');
    await folder.create(recursive: true);
    final tujuan = File(
      '${folder.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tujuan.writeAsBytes(terkompresi);

    // Hapus berkas mentah kamera — yang disimpan hanya hasil kompresi.
    try {
      await File(pathMentah).delete();
    } catch (_) {
      // Abaikan: berkas mentah di cache sistem dibersihkan oleh OS.
    }
    return tujuan.path;
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
        final pengendali = _pengendali;
        if (snapshot.hasError || pengendali == null) {
          _tampilkanGalatSekali(snapshot.error);
          return Scaffold(
            appBar: AppBar(title: const Text('FOTO BUKTI')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak dapat dibuka. Periksa izin kamera di Pengaturan.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // Jendela bidik memenuhi layar.
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: pengendali.value.previewSize!.height,
                      height: pengendali.value.previewSize!.width,
                      child: CameraPreview(pengendali),
                    ),
                  ),
                ),
                // Bilah atas: tutup + judul.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Batal',
                      ),
                      const Text(
                        'FOTO BUKTI PEMBAYARAN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 140,
                  child: Text(
                    'Arahkan ke bukti pembayaran',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                // Tombol rana besar di tengah bawah — area jempol.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(
                    child: _TombolRana(
                      memotret: _memotret,
                      saatDitekan: _jepret,
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

/// Tombol rana lingkaran besar dengan efek tekan membal (skala).
class _TombolRana extends StatefulWidget {
  const _TombolRana({
    required this.memotret,
    required this.saatDitekan,
  });

  final bool memotret;
  final VoidCallback saatDitekan;

  @override
  State<_TombolRana> createState() => _TombolRanaState();
}

class _TombolRanaState extends State<_TombolRana> {
  double _skala = 1.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.88),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: widget.memotret ? null : widget.saatDitekan,
        child: Opacity(
          opacity: widget.memotret ? 0.5 : 1.0,
          // Putih = elemen jendela bidik, bukan warna tema.
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: widget.memotret
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: Colors.black87,
                    size: 36,
                  ),
          ),
        ),
      ),
    );
  }
}

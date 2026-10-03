import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/penyedia.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/titik_pin.dart';
import '../../data/model/log_audit.dart';
import '../auth_owner/service_auth_owner.dart';
import '../kasir/penyedia_kasir.dart';

/// Menampilkan dialog void: wajib PIN owner + alasan wajib.
///
/// Mengembalikan true jika pesanan berhasil di-void.
///
/// Kontrak final — dipakai modul open-bill & laporan; jangan ubah signature.
Future<bool> tampilkanDialogVoid(
  BuildContext context,
  WidgetRef ref, {
  required String idPesanan,
  required String nomorNota,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: _IsiDialogVoid(
          idPesanan: idPesanan,
          nomorNota: nomorNota,
        ),
      ),
    ),
  );
  return hasil ?? false;
}

/// Isi dialog void: peringatan, alasan wajib, PIN owner 6 digit via keypad.
///
/// Alur: alasan valid + [ServiceAuthOwner.verifikasiPinMaster] benar →
/// status pesanan jadi 'void' → [DatabaseLokal.catatAudit] → tutup (true).
class _IsiDialogVoid extends ConsumerStatefulWidget {
  const _IsiDialogVoid({
    required this.idPesanan,
    required this.nomorNota,
  });

  final String idPesanan;
  final String nomorNota;

  @override
  ConsumerState<_IsiDialogVoid> createState() => _IsiDialogVoidState();
}

class _IsiDialogVoidState extends ConsumerState<_IsiDialogVoid> {
  final _goyang = PengendaliGoyang();
  final _kontrolAlasan = TextEditingController();

  String _pin = '';
  bool _errorPin = false;
  bool _errorAlasan = false;
  bool _memuat = false;

  @override
  void dispose() {
    _goyang.dispose();
    _kontrolAlasan.dispose();
    super.dispose();
  }

  void _saatAngka(String angka) {
    if (_pin.length >= 6 || _memuat) return;
    setState(() {
      _pin += angka;
      _errorPin = false;
    });
  }

  void _saatHapus() {
    if (_pin.isEmpty || _memuat) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorPin = false;
    });
  }

  Future<void> _prosesVoid() async {
    if (_memuat) return;
    final alasan = _kontrolAlasan.text.trim();

    var gagal = false;
    if (alasan.length < 3) {
      setState(() => _errorAlasan = true);
      gagal = true;
    }
    if (_pin.length != 6) {
      _goyang.goyang();
      setState(() => _errorPin = true);
      gagal = true;
    }
    if (gagal) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _memuat = true);

    // Verifikasi PIN master owner (hash SHA-256 + salt di service).
    final pinBenar =
        await ServiceAuthOwner().verifikasiPinMaster(_pin);
    if (!mounted) return;
    if (!pinBenar) {
      HapticFeedback.heavyImpact();
      _goyang.goyang();
      setState(() {
        _memuat = false;
        _errorPin = true;
        _pin = '';
      });
      return;
    }

    final db = ref.read(penyediaDatabaseLokal);
    final pesanan = await db.ambilPesanan(widget.idPesanan);
    if (!mounted) return;
    if (pesanan == null) {
      setState(() => _memuat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan tidak ditemukan. Mungkin sudah dihapus.'),
        ),
      );
      return;
    }

    await db.perbaruiPesanan(
      pesanan.copyWith(
        status: 'void',
        voidAlasan: alasan,
        voidDisetujuiOwner: true,
      ),
    );
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'void_pesanan',
        idAkun: ref.read(sesiKasirProvider)?.id,
        idReferensi: widget.idPesanan,
        alasan: alasan,
        dibuatPada: DateTime.now(),
      ),
    );

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _batal() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final merah = WarnaWarkop.merahMenyala;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final warnaKaca =
        gelap ? WarnaWarkop.kacaGelap : WarnaWarkop.kacaTerang;
    final warnaBorder =
        gelap ? WarnaWarkop.borderKacaGelap : WarnaWarkop.borderKacaTerang;

    return Container(
      decoration: BoxDecoration(
        color: warnaKaca,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: warnaBorder, width: 1),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kepala peringatan merah.
            Row(
              children: [
                Icon(Icons.warning_rounded, color: merah, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Void Pesanan ${widget.nomorNota}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: merah, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan tidak dihapus — dicatat sebagai void dengan '
              'persetujuanmu. Tindakan ini tidak bisa dibatalkan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kontrolAlasan,
              enabled: !_memuat,
              maxLines: 2,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              onChanged: (_) =>
                  setState(() => _errorAlasan = false),
              decoration: InputDecoration(
                labelText: 'Alasan void',
                hintText: 'Contoh: pelanggan salah pesan',
                prefixIcon: const Icon(Icons.edit_note_outlined),
                errorText: _errorAlasan
                    ? 'Alasan wajib diisi, minimal 3 karakter.'
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PIN Master Owner',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            PembungkusGoyang(
              pengendali: _goyang,
              child: TitikPin(
                terisi: _pin.length,
                tampilkanError: _errorPin,
              ),
            ),
            if (_errorPin) ...[
              const SizedBox(height: 8),
              Text(
                'PIN salah. Coba lagi ya.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: merah),
              ),
            ],
            const SizedBox(height: 8),
            KeypadAngka(
              saatAngka: _saatAngka,
              saatHapus: _saatHapus,
            ),
            const SizedBox(height: 12),
            if (_memuat)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _batal,
                      child: Text(
                        'Batal',
                        style: TextStyle(color: skema.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _TombolVoid(saatDitekan: _prosesVoid),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol aksi destruktif — kaca merah dengan getaran berat saat ditekan.
class _TombolVoid extends StatefulWidget {
  const _TombolVoid({required this.saatDitekan});

  final VoidCallback saatDitekan;

  @override
  State<_TombolVoid> createState() => _TombolVoidState();
}

class _TombolVoidState extends State<_TombolVoid> {
  double _skala = 1.0;

  @override
  Widget build(BuildContext context) {
    final merah = WarnaWarkop.merahMenyala;

    return AnimatedScale(
      scale: _skala,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _skala = 0.95),
        onTapUp: (_) => setState(() => _skala = 1.0),
        onTapCancel: () => setState(() => _skala = 1.0),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.saatDitekan();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: merah.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: merah.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever_outlined,
                  color: merah, size: 20),
              const SizedBox(width: 8),
              Text(
                'Void Sekarang',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: merah,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

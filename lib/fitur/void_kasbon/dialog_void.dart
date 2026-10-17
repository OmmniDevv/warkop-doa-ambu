import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/penyedia.dart';
import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/titik_pin.dart';
import '../../bersama/widget/tombol_warkop.dart';
import '../auth_owner/service_auth_owner.dart';
import '../kasir/penyedia_kasir.dart';
import 'layanan_void.dart';

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
    final galat = await jalankanVoid(
      db,
      idPesanan: widget.idPesanan,
      alasan: alasan,
      idAkun: ref.read(sesiKasirProvider)?.id,
    );
    if (!mounted) return;
    if (galat != null) {
      setState(() => _memuat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(galat)),
      );
      return;
    }

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
    final merah = skema.error;

    return KartuWarkop(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
                    child: TombolWarkop(
                      label: 'Batal',
                      varian: VarianTombol.teks,
                      saatDitekan: _batal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TombolWarkop(
                      label: 'Void Sekarang',
                      varian: VarianTombol.bahaya,
                      ikon: Icons.delete_forever_outlined,
                      saatDitekan: _prosesVoid,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

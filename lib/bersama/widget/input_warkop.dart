import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kolom input teks standar Warkop Doa Ambu.
///
/// - Label di atas, teks bantuan/error di bawah — pola formulir yang konsisten.
/// - Memakai [InputDecorationTheme] dari tema (radius 14, warna isi netral).
/// - Tinggi area sentuh minimal 48dp.
///
/// Catatan keyboard: widget ini TIDAK menutup keyboard sendiri. Induk yang
/// memakai input di dalam scroll harus menambahkan padding
/// `MediaQuery.of(context).viewInsets.bottom` agar kolom tidak tertutup
/// keyboard (lihat `tampilkanLembarWarkop` yang sudah menanganinya).
class InputWarkop extends StatelessWidget {
  const InputWarkop({
    super.key,
    this.label,
    this.petunjuk,
    this.controller,
    this.teksError,
    this.ikonDepan,
    this.aksiIkonDepan,
    this.tipeKeyboard,
    this.aksiSelesai,
    this.obscureText = false,
    this.hanyaAngka = false,
    this.barisMaks = 1,
    this.panjangMaks,
    this.saatBerubah,
    this.fokusNode,
    this.aktif = true,
    this.otomatisFokus = false,
  });

  /// Label di atas kolom (mis. "Nama pelanggan").
  final String? label;

  /// Teks petunjuk di dalam kolom saat kosong.
  final String? petunjuk;

  /// Pengendali teks (opsional — bila null, widget mengelola sendiri).
  final TextEditingController? controller;

  /// Pesan error di bawah kolom. `null` = tidak ada error.
  final String? teksError;

  /// Ikon di kiri dalam kolom.
  final IconData? ikonDepan;

  /// Aksi saat ikon depan diketuk (mis. tombol lihat kata sandi).
  final VoidCallback? aksiIkonDepan;

  /// Jenis keyboard OS.
  final TextInputType? tipeKeyboard;

  /// Aksi tombol keyboard (selesai/lanjut).
  final TextInputAction? aksiSelesai;

  /// True untuk input kata sandi/PIN teks.
  final bool obscureText;

  /// True = hanya digit (menambahkan [FilteringTextInputFormatter.digitsOnly]).
  final bool hanyaAngka;

  /// Jumlah baris maksimal.
  final int barisMaks;

  /// Batas panjang karakter.
  final int? panjangMaks;

  /// Dipanggil setiap teks berubah.
  final ValueChanged<String>? saatBerubah;

  /// Node fokus eksternal (opsional).
  final FocusNode? fokusNode;

  /// False = kolom nonaktif (abu).
  final bool aktif;

  /// True = langsung fokus saat tampil.
  final bool otomatisFokus;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: gayaTeks.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: teksError != null ? skema.error : skema.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          focusNode: fokusNode,
          enabled: aktif,
          autofocus: otomatisFokus,
          obscureText: obscureText,
          maxLines: barisMaks,
          maxLength: panjangMaks,
          keyboardType: tipeKeyboard,
          textInputAction: aksiSelesai,
          onChanged: saatBerubah,
          inputFormatters:
              hanyaAngka ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: gayaTeks.bodyLarge,
          decoration: InputDecoration(
            hintText: petunjuk,
            errorText: teksError,
            prefixIcon: ikonDepan == null
                ? null
                : IconButton(
                    icon: Icon(ikonDepan),
                    onPressed: aksiIkonDepan,
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

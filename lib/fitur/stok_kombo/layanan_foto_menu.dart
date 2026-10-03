import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kamera_menu.dart';
import 'kompresi_foto.dart';

/// Hasil pilihan foto menu: path lokal hasil kompresi.
typedef FotoMenuDipilih = void Function(String pathLokal);

/// Bottom sheet pilihan sumber foto: kamera in-app atau galeri.
///
/// Memanggil [saatDipilih] dengan path lokal JPG yang sudah dikompresi
/// (100–180 KB), lalu menutup sheet.
Future<void> pilihFotoMenu(
  BuildContext context, {
  required FotoMenuDipilih saatDipilih,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Ambil dari kamera'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final path = await ambilFotoMenu(context);
              if (path != null) saatDipilih(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final path = await _dariGaleri(context);
              if (path != null) saatDipilih(path);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Ambil foto dari galeri lalu kompres ke 100–180 KB.
Future<String?> _dariGaleri(BuildContext context) async {
  try {
    final dipilih = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (dipilih == null) return null;
    return await kompresFotoMenu(dipilih.path, 'menu');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto dari galeri.')),
      );
    }
    return null;
  }
}

/// Mengunggah foto menu ke Storage Supabase (bucket `foto-menu`, publik).
///
/// Mengembalikan URL publik yang disimpan ke `menu.foto_url`.
/// Melempar bila client belum init / offline / gagal jaringan — pemanggil
/// memutuskan fallback-nya (mis. simpan menu tanpa foto dulu).
Future<String> unggahFotoMenu(String pathLokal, String idMenu) async {
  final klien = Supabase.instance.client;
  final cap = DateTime.now().millisecondsSinceEpoch;
  final namaBerkas = 'menu/${idMenu}_$cap.jpg';
  await klien.storage.from('foto-menu').upload(
        namaBerkas,
        File(pathLokal),
        fileOptions: const FileOptions(upsert: true),
      );
  return klien.storage.from('foto-menu').getPublicUrl(namaBerkas);
}

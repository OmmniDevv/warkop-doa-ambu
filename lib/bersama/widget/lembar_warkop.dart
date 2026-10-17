import 'dart:ui';

import 'package:flutter/material.dart';

/// Menampilkan bottom sheet standar Warkop Doa Ambu.
///
/// - Latar belakang di-blur (satu-satunya tempat blur diizinkan selain
///   elemen mengambang — sesuai DESIGN.md).
/// - Radius atas 24, tinggi maksimal 85% layar.
/// - Ada gagang tarik (drag handle) di atas.
/// - Padding bawah otomatis mengikuti keyboard (`viewInsets`) agar input
///   tidak tertutup.
///
/// Mengembalikan nilai dari `Navigator.pop` seperti bottom sheet biasa.
///
/// Contoh:
/// ```dart
/// final hasil = await tampilkanLembarWarkop<bool>(
///   context,
///   judul: 'Rincian Pesanan',
///   child: const IsiNota(),
/// );
/// ```
Future<T?> tampilkanLembarWarkop<T>(
  BuildContext context, {
  required Widget child,
  String? judul,
  bool bisaDigulir = true,
}) {
  final skema = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: skema.scrim.withValues(alpha: 0.4),
    builder: (ctx) {
      final tinggiMaks = MediaQuery.of(ctx).size.height * 0.85;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: BoxConstraints(maxHeight: tinggiMaks),
          decoration: BoxDecoration(
            color: skema.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: skema.shadow.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: skema.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (judul != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        judul,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Flexible(
                    child: bisaDigulir
                        ? SingleChildScrollView(child: child)
                        : child,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

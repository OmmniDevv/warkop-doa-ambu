import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/penyedia.dart';

/// Tombol alih mode terang/gelap — taruh di `actions` AppBar mana pun.
class TombolTema extends ConsumerWidget {
  const TombolTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = ref.watch(penyediaModeGelap);
    return IconButton(
      tooltip: gelap ? 'Mode terang' : 'Mode gelap',
      icon: Icon(
        gelap ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(penyediaModeGelap.notifier).alihkan();
      },
    );
  }
}

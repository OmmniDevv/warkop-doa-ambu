import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Build #9: secrets final.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/penyedia.dart';
import 'app/router.dart';
import 'app/tema/tema_app.dart';
import 'fitur/stok_kombo/penyedia_sinkron.dart';

/// Titik masuk aplikasi Warkop Doa Ambu.
///
/// - Mengunci orientasi portrait.
/// - Memuat `.env` (toleran jika belum ada → mode offline).
/// - Inisialisasi Supabase hanya jika kredensial terisi (bukan placeholder).
/// - Nilai .env di-trim defensif karena secret tempelan web kadang membawa
///   spasi/newline yang membuat API key/URL ditolak.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  var supabaseSiap = false;
  try {
    await dotenv.load(fileName: '.env');
    // Trim defensif: secret yang ditempel via web kadang membawa spasi/
    // newline di ujung yang membuat API key ditolak server.
    final url = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    final anonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
    if (url.isNotEmpty &&
        anonKey.isNotEmpty &&
        !url.contains('contoh') &&
        !anonKey.contains('isi_')) {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      supabaseSiap = true;
    }
  } catch (_) {
    // .env belum ada / rusak — aplikasi tetap jalan offline-first.
  }

  runApp(
    ProviderScope(
      child: AplikasiWarkop(supabaseSiap: supabaseSiap),
    ),
  );
}

/// Root aplikasi — tema mengikuti [penyediaModeGelap].
class AplikasiWarkop extends ConsumerWidget {
  const AplikasiWarkop({super.key, required this.supabaseSiap});

  final bool supabaseSiap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = ref.watch(penyediaModeGelap);
    // Hidupkan sinkronisasi otomatis selama aplikasi berjalan.
    ref.watch(pemicuSinkronOtomatis);

    return MaterialApp.router(
      title: 'Warkop Doa Ambu',
      debugShowCheckedModeBanner: false,
      theme: bangunTema(gelap: false),
      darkTheme: bangunTema(gelap: true),
      themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
      routerConfig: bangunRouter(),
      builder: (context, child) {
        // Banner kecil saat Supabase belum dikonfigurasi.
        if (supabaseSiap || child == null) return child!;
        return Column(
          children: [
            Expanded(child: child),
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                'Mode offline — isi .env untuk Supabase',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
          ],
        );
      },
    );
  }
}

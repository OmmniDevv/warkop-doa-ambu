import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/model/pemilik.dart';
import '../../app/penyedia.dart';
import '../../app/tema/token_tipografi.dart';
import '../../app/tema/token_warna.dart';
import '../../bersama/widget/kartu_kaca.dart';

/// Beranda sementara — diganti modul kasir pada tahap berikutnya.
///
/// Menampilkan profil owner yang tersimpan di perangkat sebagai bukti
/// alur pendaftaran → PIN → biometrik berjalan ujung ke ujung.
class LayarBeranda extends ConsumerWidget {
  const LayarBeranda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(penyediaProfilPemilik);
    final gelap = ref.watch(penyediaModeGelap);
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    return Scaffold(
      appBar: AppBar(title: const Text('BERANDA')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WARKOP DOA AMBU',
                style: TipografiWarkop.judulBrand.copyWith(
                  fontSize: 26,
                  color: aksen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Modul pendaftaran owner selesai 🎉',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              profilAsync.when(
                data: (profil) => profil == null
                    ? const KartuKaca(
                        child: Text('Belum ada profil tersimpan.'),
                      )
                    : _DetailProfil(profil: profil),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => KartuKaca(child: Text('Error: $e')),
              ),
              const SizedBox(height: 16),
              KartuKaca(
                tanpaBlur: true,
                child: Text(
                  'Tahap berikutnya: modul kasir (grid menu, keranjang, '
                  'open bill, shift, kasbon, kas keluar, void PIN owner, '
                  'kamera bukti transfer, cetak Bluetooth).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailProfil extends StatelessWidget {
  const _DetailProfil({required this.profil});

  final Pemilik profil;

  @override
  Widget build(BuildContext context) {
    return KartuKaca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Baris(label: 'Nama Pemilik', nilai: profil.namaPemilik),
          _Baris(label: 'Nama Warkop', nilai: profil.namaWarkop),
          _Baris(label: 'Email', nilai: profil.email),
          if (profil.nomorKontak != null)
            _Baris(label: 'Kontak', nilai: profil.nomorKontak!),
          _Baris(
            label: 'Master PIN',
            nilai: profil.hashPinMaster.isEmpty
                ? 'belum dibuat'
                : 'tersimpan (hash SHA-256)',
          ),
          _Baris(
            label: 'Biometrik',
            nilai: profil.apakahBiometrikAktif ? 'aktif' : 'nonaktif',
          ),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

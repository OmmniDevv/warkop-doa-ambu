import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/penyedia.dart';
import '../../bersama/util/id_unik.dart';
import '../../bersama/widget/kartu_kaca.dart';
import '../../bersama/widget/keypad_angka.dart';
import '../../bersama/widget/pembungkus_goyang.dart';
import '../../bersama/widget/titik_pin.dart';
import '../../bersama/widget/tombol_kaca.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/akun.dart';
import '../../data/model/log_audit.dart';
import '../kasir/keamanan_pin_kasir.dart';

/// Daftar akun berperang 'kasir' — tanpa akun owner.
final penyediaDaftarKasir = FutureProvider<List<Akun>>((ref) async {
  final semua = await DatabaseLokal.instance.daftarAkun();
  return semua.where((a) => a.peran == 'kasir').toList();
});

/// Layar akun kasir: daftar + aktif/nonaktif + reset PIN + tambah kasir.
class LayarAkunKasir extends ConsumerWidget {
  const LayarAkunKasir({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kasirAsync = ref.watch(penyediaDaftarKasir);

    return Scaffold(
      appBar: AppBar(title: const Text('AKUN KASIR')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: kasirAsync.when(
                data: (daftar) {
                  if (daftar.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada akun kasir.\nTambah lewat tombol di bawah ya.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daftar.length,
                    itemBuilder: (context, i) =>
                        _BarisKasir(akun: daftar[i]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Gagal memuat akun kasir: $e')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TombolKaca(
                label: 'Tambah Kasir',
                ikon: Icons.person_add_outlined,
                saatDitekan: () => _bukaLembarPin(context, null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bukaLembarPin(BuildContext context, Akun? akun) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LembarPinKasir(akun: akun),
    );
  }
}

class _BarisKasir extends ConsumerWidget {
  const _BarisKasir({required this.akun});

  final Akun akun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuKaca(
        pakaiBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            backgroundColor: skema.primaryContainer,
            child: Text(
              akun.nama.isEmpty ? '?' : akun.nama[0].toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: skema.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          title: Text(akun.nama),
          subtitle: Text(akun.aktif ? 'Aktif' : 'Nonaktif'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _LembarPinKasir(akun: akun),
                  );
                },
                child: const Text('Reset PIN'),
              ),
              Switch.adaptive(
                value: akun.aktif,
                onChanged: (nilai) => _alihkanAktif(context, ref, nilai),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _alihkanAktif(
    BuildContext context,
    WidgetRef ref,
    bool nilai,
  ) async {
    final db = DatabaseLokal.instance;
    try {
      await db.perbaruiAkun(akun.copyWith(aktif: nilai));
      await db.catatAudit(
        LogAudit(
          id: idBaru(),
          aksi: nilai ? 'aktifkan_kasir' : 'nonaktifkan_kasir',
          idReferensi: akun.id,
          dibuatPada: DateTime.now(),
        ),
      );
      ref.invalidate(penyediaDaftarKasir);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    }
  }
}

/// Bottom sheet PIN kasir 6 digit via keypad in-app (2 tahap konfirmasi).
///
/// [akun] null = tambah kasir baru (minta nama dulu);
/// terisi = reset PIN akun tersebut.
class _LembarPinKasir extends ConsumerStatefulWidget {
  const _LembarPinKasir({this.akun});

  final Akun? akun;

  @override
  ConsumerState<_LembarPinKasir> createState() => _LembarPinKasirState();
}

class _LembarPinKasirState extends ConsumerState<_LembarPinKasir> {
  final _goyang = PengendaliGoyang();
  late final TextEditingController _kontrolNama;

  /// Tambah: 0 = nama, 1 = PIN, 2 = konfirmasi. Reset: 1 = PIN, 2 = konfirmasi.
  late int _tahap;
  String _pinBaru = '';
  String _masukan = '';
  bool _tampilkanError = false;
  bool _memuat = false;

  bool get _adalahTambah => widget.akun == null;

  @override
  void initState() {
    super.initState();
    _kontrolNama = TextEditingController();
    _tahap = _adalahTambah ? 0 : 1;
  }

  @override
  void dispose() {
    _goyang.dispose();
    _kontrolNama.dispose();
    super.dispose();
  }

  void _lanjutDariNama() {
    if (_kontrolNama.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kasir wajib diisi.')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _tahap = 1);
  }

  void _saatAngka(String angka) {
    if (_masukan.length >= 6 || _memuat) return;
    setState(() {
      _masukan += angka;
      _tampilkanError = false;
    });
    if (_masukan.length == 6) {
      Future.delayed(const Duration(milliseconds: 250), _prosesEnamDigit);
    }
  }

  void _saatHapus() {
    if (_masukan.isEmpty || _memuat) return;
    setState(() {
      _masukan = _masukan.substring(0, _masukan.length - 1);
      _tampilkanError = false;
    });
  }

  Future<void> _prosesEnamDigit() async {
    if (!mounted || _masukan.length != 6) return;

    if (_tahap == 1) {
      // Tahap 1 selesai → lanjut konfirmasi.
      setState(() {
        _pinBaru = _masukan;
        _masukan = '';
        _tahap = 2;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    // Tahap 2: cocokkan.
    if (_masukan != _pinBaru) {
      _goyang.goyang();
      HapticFeedback.heavyImpact();
      setState(() {
        _tampilkanError = true;
        _masukan = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN tidak cocok. Ulangi dari awal ya.'),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() {
          _tahap = 1;
          _pinBaru = '';
          _tampilkanError = false;
        });
      }
      return;
    }

    await _simpan();
  }

  Future<void> _simpan() async {
    setState(() => _memuat = true);
    try {
      final db = DatabaseLokal.instance;
      final idPemilik = ref.read(penyediaProfilPemilik).maybeWhen(
            data: (profil) => profil?.id,
            orElse: () => null,
          );

      if (_adalahTambah) {
        final id = idBaru();
        await db.simpanAkun(
          Akun(
            id: id,
            nama: _kontrolNama.text.trim(),
            pinHash: buatHashPinKasir(idAkun: id, pin: _masukan),
            peran: 'kasir',
            aktif: true,
            statusSinkron: 'tertunda',
            diperbaruiPada: DateTime.now(),
            apakahDihapus: false,
          ),
        );
        await db.catatAudit(
          LogAudit(
            id: idBaru(),
            aksi: 'buat_akun_kasir',
            idAkun: idPemilik,
            idReferensi: id,
            dibuatPada: DateTime.now(),
          ),
        );
      } else {
        final akun = widget.akun!;
        await db.perbaruiAkun(
          akun.copyWith(
            pinHash: buatHashPinKasir(idAkun: akun.id, pin: _masukan),
          ),
        );
        await db.catatAudit(
          LogAudit(
            id: idBaru(),
            aksi: 'reset_pin_kasir',
            idAkun: idPemilik,
            idReferensi: akun.id,
            dibuatPada: DateTime.now(),
          ),
        );
      }

      ref.invalidate(penyediaDaftarKasir);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _adalahTambah
                  ? 'Akun kasir "${_kontrolNama.text.trim()}" dibuat.'
                  : 'PIN kasir "${widget.akun!.nama}" direset.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bawah = MediaQuery.of(context).viewInsets.bottom;
    final judul = _tahap == 0
        ? 'Nama Kasir Baru'
        : _tahap == 1
            ? (_adalahTambah ? 'Buat PIN Kasir' : 'PIN Baru Kasir')
            : 'Konfirmasi PIN';
    final subjudul = _tahap == 0
        ? 'Nama tampil yang dipakai kasir saat masuk.'
        : _tahap == 1
            ? 'Masukkan 6 digit PIN untuk kasir.'
            : 'Masukkan ulang 6 digit PIN yang sama.';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bawah),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              subjudul,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (_tahap == 0) ...[
              TextField(
                controller: _kontrolNama,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama kasir',
                  hintText: 'Contoh: Budi',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _lanjutDariNama(),
              ),
              const SizedBox(height: 16),
              TombolKaca(
                label: 'Lanjut',
                ikon: Icons.arrow_forward_outlined,
                saatDitekan: _lanjutDariNama,
              ),
            ] else
              PembungkusGoyang(
                pengendali: _goyang,
                child: Column(
                  children: [
                    TitikPin(
                      terisi: _masukan.length,
                      tampilkanError: _tampilkanError,
                    ),
                    const SizedBox(height: 20),
                    if (_memuat)
                      const CircularProgressIndicator()
                    else
                      KeypadAngka(
                        saatAngka: _saatAngka,
                        saatHapus: _saatHapus,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

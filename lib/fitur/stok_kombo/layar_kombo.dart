import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/token_tipografi.dart';
import '../../../app/tema/token_warna.dart';
import '../../../bersama/format/format_uang.dart';
import '../../../bersama/util/id_unik.dart';
import '../../../bersama/widget/kartu_kaca.dart';
import '../../../bersama/widget/tombol_kaca.dart';
import '../../../data/lokal/database_lokal.dart';
import '../../../data/model/log_audit.dart';
import '../../../data/model/menu.dart';
import '../../../data/model/paket_kombo.dart';
import '../../../data/model/paket_kombo_rincian.dart';

/// Daftar seluruh menu untuk pemilih isi paket.
final _penyediaMenuKombo = FutureProvider<List<Menu>>(
  (ref) => DatabaseLokal.instance.daftarMenu(),
);

/// Satu paket kombo beserta rincian isinya.
class _PaketDenganIsi {
  const _PaketDenganIsi({required this.paket, required this.rincian});

  final PaketKombo paket;
  final List<PaketKomboRincian> rincian;
}

/// Daftar paket kombo beserta jumlah isinya masing-masing.
final _penyediaPaketKombo = FutureProvider<List<_PaketDenganIsi>>((ref) async {
  final db = DatabaseLokal.instance;
  final daftar = await db.daftarPaket();
  return Future.wait(
    daftar.map(
      (paket) async => _PaketDenganIsi(
        paket: paket,
        rincian: await db.daftarPaketRincian(paket.id),
      ),
    ),
  );
});

/// Layar kelola paket kombo: daftar paket, buat baru, ubah, nonaktifkan,
/// atau hapus (lunak).
class LayarKombo extends ConsumerWidget {
  const LayarKombo({super.key});

  void _bukaPaketBaru(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LembarPaketBaru(
          saatSimpan: () => ref.invalidate(_penyediaPaketKombo),
        ),
      ),
    );
  }

  void _bukaUbahPaket(
    BuildContext context,
    WidgetRef ref,
    _PaketDenganIsi data,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LembarUbahPaket(
          data: data,
          saatSimpan: () => ref.invalidate(_penyediaPaketKombo),
        ),
      ),
    );
  }

  Future<void> _toggleAktif(
    WidgetRef ref,
    BuildContext context,
    _PaketDenganIsi data,
  ) async {
    HapticFeedback.lightImpact();
    final db = DatabaseLokal.instance;
    await db.perbaruiPaket(data.paket.copyWith(aktif: !data.paket.aktif));
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: data.paket.aktif ? 'paket.dinonaktifkan' : 'paket.diaktifkan',
        idReferensi: data.paket.id,
        dibuatPada: DateTime.now(),
      ),
    );
    ref.invalidate(_penyediaPaketKombo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paketAsync = ref.watch(_penyediaPaketKombo);

    return Scaffold(
      appBar: AppBar(title: const Text('KOMBO')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: paketAsync.when(
                data: (daftar) => _IsiDaftarPaket(
                  daftar: daftar,
                  saatTap: (data) => _bukaUbahPaket(context, ref, data),
                  saatToggle: (data) => _toggleAktif(ref, context, data),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _GalatPaket(pesan: '$e'),
              ),
            ),
            // ── Aksi utama di area bawah layar ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: TombolKaca(
                label: 'Paket Baru',
                ikon: Icons.add_circle_outline,
                saatDitekan: () => _bukaPaketBaru(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IsiDaftarPaket extends StatelessWidget {
  const _IsiDaftarPaket({
    required this.daftar,
    required this.saatTap,
    required this.saatToggle,
  });

  final List<_PaketDenganIsi> daftar;
  final ValueChanged<_PaketDenganIsi> saatTap;
  final ValueChanged<_PaketDenganIsi> saatToggle;

  @override
  Widget build(BuildContext context) {
    if (daftar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: KartuKaca(
          tanpaBlur: true,
          child: Text(
            'Belum ada paket kombo. Ketuk "Paket Baru" '
            'di bawah untuk membuat paket pertama.',
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      itemCount: daftar.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _BarisPaket(
          data: daftar[i],
          saatTap: () => saatTap(daftar[i]),
          saatToggle: () => saatToggle(daftar[i]),
        ),
      ),
    );
  }
}

class _GalatPaket extends StatelessWidget {
  const _GalatPaket({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: KartuKaca(
        tanpaBlur: true,
        border: WarnaWarkop.merahMenyala.withValues(alpha: 0.45),
        child: Text('Gagal memuat paket: $pesan'),
      ),
    );
  }
}

class _BarisPaket extends StatelessWidget {
  const _BarisPaket({
    required this.data,
    required this.saatTap,
    required this.saatToggle,
  });

  final _PaketDenganIsi data;
  final VoidCallback saatTap;
  final VoidCallback saatToggle;

  @override
  Widget build(BuildContext context) {
    final paket = data.paket;

    return GestureDetector(
      onTap: saatTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: paket.aktif ? 1.0 : 0.6,
        child: KartuKaca(
          tanpaBlur: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paket.nama,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatRupiah(paket.hargaPaket)} · '
                      'isi ${data.rincian.length} menu',
                      style: TipografiWarkop.nominal.copyWith(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: paket.aktif,
                onChanged: (_) => saatToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangka bottom sheet modul kombo: pegangan + tinggi 88% + tombol di bawah.
class _BingkaiLembar extends StatelessWidget {
  const _BingkaiLembar({
    required this.judul,
    required this.subjudul,
    required this.child,
  });

  final String judul;
  final String subjudul;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: gelap ? WarnaWarkop.kertasGelap : WarnaWarkop.kertasTerang,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                judul,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                subjudul,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Stepper jumlah isi paket per menu (0 = tidak ikut paket).
class _StepperJumlah extends StatelessWidget {
  const _StepperJumlah({
    required this.jumlah,
    required this.saatUbah,
  });

  final int jumlah;
  final ValueChanged<int> saatUbah;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final aksen = gelap ? WarnaWarkop.aksenGelap : WarnaWarkop.aksenTerang;

    Widget tombol(String label, VoidCallback aksi) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          aksi();
        },
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aksen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: aksen.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TipografiWarkop.nominal.copyWith(
              fontSize: 18,
              color: aksen,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tombol('−', () => saatUbah((jumlah - 1).clamp(0, 99))),
        SizedBox(
          width: 36,
          child: Text(
            '$jumlah',
            textAlign: TextAlign.center,
            style: TipografiWarkop.nominal.copyWith(fontSize: 16),
          ),
        ),
        tombol('+', () => saatUbah((jumlah + 1).clamp(0, 99))),
      ],
    );
  }
}

/// Baris pemilih menu untuk komposisi paket.
class _BarisPilihMenu extends StatelessWidget {
  const _BarisPilihMenu({
    required this.menu,
    required this.jumlah,
    required this.saatUbah,
  });

  final Menu menu;
  final int jumlah;
  final ValueChanged<int> saatUbah;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KartuKaca(
        tanpaBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: jumlah > 0
            ? (Theme.of(context).brightness == Brightness.dark
                    ? WarnaWarkop.aksenGelap
                    : WarnaWarkop.aksenTerang)
                .withValues(alpha: 0.5)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.nama,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    formatRupiah(menu.hargaSatuan),
                    style: TipografiWarkop.nominal.copyWith(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            _StepperJumlah(jumlah: jumlah, saatUbah: saatUbah),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet "Paket Baru": memuat daftar menu, lalu menampilkan formulir.
class _LembarPaketBaru extends ConsumerWidget {
  const _LembarPaketBaru({required this.saatSimpan});

  final VoidCallback saatSimpan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(_penyediaMenuKombo);

    return menuAsync.when(
      data: _lembarIsi,
      loading: _lembarMemuat,
      error: _lembarGalat,
    );
  }

  Widget _lembarIsi(List<Menu> semuaMenu) => _BingkaiLembar(
        judul: 'Paket Baru',
        subjudul: 'Isi nama, harga, lalu pilih menu sebagai isi paket.',
        child: _FormulirPaketBaru(
          semuaMenu: semuaMenu,
          saatSimpan: saatSimpan,
        ),
      );

  Widget _lembarMemuat() => const _BingkaiLembar(
        judul: 'Paket Baru',
        subjudul: 'Isi nama, harga, lalu pilih menu sebagai isi paket.',
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _lembarGalat(Object e, StackTrace _) => _BingkaiLembar(
        judul: 'Paket Baru',
        subjudul: 'Isi nama, harga, lalu pilih menu sebagai isi paket.',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Gagal memuat menu: $e'),
        ),
      );
}

/// Formulir paket baru: nama + harga + stepper isi paket + tombol simpan.
class _FormulirPaketBaru extends StatefulWidget {
  const _FormulirPaketBaru({
    required this.semuaMenu,
    required this.saatSimpan,
  });

  final List<Menu> semuaMenu;
  final VoidCallback saatSimpan;

  @override
  State<_FormulirPaketBaru> createState() => _FormulirPaketBaruState();
}

class _FormulirPaketBaruState extends State<_FormulirPaketBaru> {
  final _kontrolNama = TextEditingController();
  final _kontrolHarga = TextEditingController();
  final _jumlah = <String, int>{};
  String? _galat;
  bool _menyimpan = false;

  @override
  void dispose() {
    _kontrolNama.dispose();
    _kontrolHarga.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;

    final nama = _kontrolNama.text.trim();
    final harga = int.tryParse(_kontrolHarga.text) ?? 0;
    final dipilih = _jumlah.entries.where((e) => e.value > 0).toList();

    if (nama.isEmpty) {
      setState(() => _galat = 'Nama paket wajib diisi.');
      return;
    }
    if (harga <= 0) {
      setState(() => _galat = 'Harga paket harus lebih dari Rp0.');
      return;
    }
    if (dipilih.isEmpty) {
      setState(() => _galat = 'Pilih minimal satu menu sebagai isi paket.');
      return;
    }

    setState(() {
      _menyimpan = true;
      _galat = null;
    });

    final db = DatabaseLokal.instance;
    final idPaket = idBaru();
    final sekarang = DateTime.now();
    await db.simpanPaket(
      PaketKombo(
        id: idPaket,
        nama: nama,
        hargaPaket: harga,
        diperbaruiPada: sekarang,
      ),
    );
    for (final entri in dipilih) {
      await db.simpanPaketRincian(
        PaketKomboRincian(
          id: idBaru(),
          idPaket: idPaket,
          idMenu: entri.key,
          jumlah: entri.value,
          diperbaruiPada: sekarang,
        ),
      );
    }
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'paket.dibuat',
        idReferensi: idPaket,
        detail: '{"nama":"$nama","harga_paket":$harga}',
        dibuatPada: sekarang,
      ),
    );

    if (!mounted) return;
    widget.saatSimpan();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Paket "$nama" dibuat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _kontrolNama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama paket *',
              hintText: 'mis. Paket Hemat Sarapan',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _kontrolHarga,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TipografiWarkop.nominal,
            decoration: const InputDecoration(
              labelText: 'Harga paket (Rp) *',
              hintText: 'mis. 25000',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ISI PAKET',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: widget.semuaMenu.length,
            itemBuilder: (ctx, i) {
              final menu = widget.semuaMenu[i];
              return _BarisPilihMenu(
                menu: menu,
                jumlah: _jumlah[menu.id] ?? 0,
                saatUbah: (v) => setState(() => _jumlah[menu.id] = v),
              );
            },
          ),
        ),
        if (_galat != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _galat!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WarnaWarkop.merahMenyala,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TombolKaca(
            label: 'Simpan Paket',
            ikon: Icons.save_outlined,
            memuat: _menyimpan,
            saatDitekan: _simpan,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet ubah paket: memuat daftar menu, lalu menampilkan formulir.
class _LembarUbahPaket extends ConsumerWidget {
  const _LembarUbahPaket({required this.data, required this.saatSimpan});

  final _PaketDenganIsi data;
  final VoidCallback saatSimpan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(_penyediaMenuKombo);

    return menuAsync.when(
      data: _lembarIsi,
      loading: _lembarMemuat,
      error: _lembarGalat,
    );
  }

  Widget _lembarIsi(List<Menu> semuaMenu) => _BingkaiLembar(
        judul: 'Ubah Paket',
        subjudul: 'Ubah nama, harga, status, atau komposisi isi paket.',
        child: _FormulirUbahPaket(
          data: data,
          semuaMenu: semuaMenu,
          saatSimpan: saatSimpan,
        ),
      );

  Widget _lembarMemuat() => const _BingkaiLembar(
        judul: 'Ubah Paket',
        subjudul: 'Ubah nama, harga, status, atau komposisi isi paket.',
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _lembarGalat(Object e, StackTrace _) => _BingkaiLembar(
        judul: 'Ubah Paket',
        subjudul: 'Ubah nama, harga, status, atau komposisi isi paket.',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Gagal memuat menu: $e'),
        ),
      );
}

/// Formulir ubah paket: nama, harga, status aktif, komposisi, tombol hapus.
class _FormulirUbahPaket extends StatefulWidget {
  const _FormulirUbahPaket({
    required this.data,
    required this.semuaMenu,
    required this.saatSimpan,
  });

  final _PaketDenganIsi data;
  final List<Menu> semuaMenu;
  final VoidCallback saatSimpan;

  @override
  State<_FormulirUbahPaket> createState() => _FormulirUbahPaketState();
}

class _FormulirUbahPaketState extends State<_FormulirUbahPaket> {
  late final TextEditingController _kontrolNama;
  late final TextEditingController _kontrolHarga;
  late bool _aktif;
  final _jumlah = <String, int>{};
  bool _menyimpan = false;
  bool _menghapus = false;

  @override
  void initState() {
    super.initState();
    _kontrolNama = TextEditingController(text: widget.data.paket.nama);
    _kontrolHarga =
        TextEditingController(text: '${widget.data.paket.hargaPaket}');
    _aktif = widget.data.paket.aktif;
    for (final r in widget.data.rincian) {
      _jumlah[r.idMenu] = r.jumlah;
    }
  }

  @override
  void dispose() {
    _kontrolNama.dispose();
    _kontrolHarga.dispose();
    super.dispose();
  }

  Future<void> _simpanPerubahan() async {
    if (_menyimpan) return;
    final nama = _kontrolNama.text.trim();
    final harga = int.tryParse(_kontrolHarga.text) ?? 0;
    if (nama.isEmpty || harga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan harga paket yang valid wajib diisi.'),
        ),
      );
      return;
    }

    setState(() => _menyimpan = true);
    final db = DatabaseLokal.instance;
    final sekarang = DateTime.now();
    await db.perbaruiPaket(
      widget.data.paket.copyWith(nama: nama, hargaPaket: harga, aktif: _aktif),
    );
    for (final r in widget.data.rincian) {
      await db.hapusPaketRincian(r.id);
    }
    for (final entri in _jumlah.entries) {
      if (entri.value <= 0) continue;
      await db.simpanPaketRincian(
        PaketKomboRincian(
          id: idBaru(),
          idPaket: widget.data.paket.id,
          idMenu: entri.key,
          jumlah: entri.value,
          diperbaruiPada: sekarang,
        ),
      );
    }
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'paket.diubah',
        idReferensi: widget.data.paket.id,
        detail: '{"nama":"$nama","harga_paket":$harga}',
        dibuatPada: sekarang,
      ),
    );

    if (!mounted) return;
    widget.saatSimpan();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paket diperbarui')),
    );
  }

  Future<void> _konfirmasiHapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus paket?'),
        content: Text(
          'Paket "${widget.data.paket.nama}" akan dihapus dan tidak lagi '
          'muncul di kasir. Tindakan ini dicatat di audit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    setState(() => _menghapus = true);
    final db = DatabaseLokal.instance;
    await db.hapusPaketLunak(widget.data.paket.id);
    await db.catatAudit(
      LogAudit(
        id: idBaru(),
        aksi: 'paket.dihapus',
        idReferensi: widget.data.paket.id,
        dibuatPada: DateTime.now(),
      ),
    );

    if (!mounted) return;
    widget.saatSimpan();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paket dihapus')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _kontrolNama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama paket'),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _kontrolHarga,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TipografiWarkop.nominal,
            decoration: const InputDecoration(labelText: 'Harga paket (Rp)'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paket aktif'),
            value: _aktif,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _aktif = v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ISI PAKET',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: widget.semuaMenu.length,
            itemBuilder: (ctx, i) {
              final menu = widget.semuaMenu[i];
              return _BarisPilihMenu(
                menu: menu,
                jumlah: _jumlah[menu.id] ?? 0,
                saatUbah: (v) => setState(() => _jumlah[menu.id] = v),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TombolKaca(
            label: 'Simpan Perubahan',
            ikon: Icons.save_outlined,
            memuat: _menyimpan,
            saatDitekan: _simpanPerubahan,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TombolKaca(
            label: 'Hapus Paket',
            ikon: Icons.delete_outline,
            memuat: _menghapus,
            saatDitekan: _konfirmasiHapus,
          ),
        ),
      ],
    );
  }
}

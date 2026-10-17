import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status sinkronisasi untuk [IndikatorSinkron].
enum StatusSinkron {
  /// Semua data sudah tersinkron — aman.
  aman,

  /// Ada [jumlahAntre] baris menunggu diunggah.
  antre,

  /// Sinkron terakhir gagal.
  gagal,
}

/// Indikator status sinkron offline-first.
///
/// Selalu memberi TIGA sinyal sekaligus (warna + ikon + teks) agar tidak
/// mengandalkan warna saja:
///
/// | Status | Warna | Ikon | Teks |
/// |---|---|---|---|
/// | aman | aksen ([ColorScheme.primary]) | cloud_done | "Tersinkron" |
/// | antre | sekunder ([ColorScheme.secondary]) | cloud_upload | "Antre N" |
/// | gagal | merah ([ColorScheme.error]) | cloud_off | "Gagal sinkron" |
///
/// Status antre memakai denyut halus sesuai PRD §5 ("awan berdenyut + angka") —
/// ini sinyal perhatian kontinu, bukan transisi UI (yang dibatasi ≤ 200 ms).
/// Ketuk untuk memicu sinkron manual via [saatDitekan].
class IndikatorSinkron extends StatefulWidget {
  const IndikatorSinkron({
    super.key,
    required this.status,
    this.jumlahAntre = 0,
    this.saatDitekan,
  });

  /// Status sinkron saat ini.
  final StatusSinkron status;

  /// Jumlah baris menunggu (hanya dipakai saat [status] = antre).
  final int jumlahAntre;

  /// Aksi sinkron manual saat diketuk.
  final VoidCallback? saatDitekan;

  @override
  State<IndikatorSinkron> createState() => _IndikatorSinkronState();
}

class _IndikatorSinkronState extends State<IndikatorSinkron>
    with SingleTickerProviderStateMixin {
  late final AnimationController _denyut;

  @override
  void initState() {
    super.initState();
    // Denyut perhatian untuk status antre (PRD §5) — lambat & tenang.
    _denyut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.status == StatusSinkron.antre) _denyut.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(IndikatorSinkron oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == StatusSinkron.antre && !_denyut.isAnimating) {
      _denyut.repeat(reverse: true);
    } else if (widget.status != StatusSinkron.antre && _denyut.isAnimating) {
      _denyut.stop();
    }
  }

  @override
  void dispose() {
    _denyut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final gayaTeks = Theme.of(context).textTheme;

    final Color warna;
    final IconData ikon;
    final String teks;
    switch (widget.status) {
      case StatusSinkron.aman:
        warna = skema.primary;
        ikon = Icons.cloud_done_outlined;
        teks = 'Tersinkron';
      case StatusSinkron.antre:
        warna = skema.secondary;
        ikon = Icons.cloud_upload_outlined;
        teks = 'Antre ${widget.jumlahAntre}';
      case StatusSinkron.gagal:
        warna = skema.error;
        ikon = Icons.cloud_off_outlined;
        teks = 'Gagal sinkron';
    }

    final isi = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _denyut,
          builder: (context, child) {
            final skala = widget.status == StatusSinkron.antre
                ? 1.0 + (_denyut.value * 0.12)
                : 1.0;
            return Transform.scale(scale: skala, child: child);
          },
          child: Icon(ikon, size: 20, color: warna),
        ),
        const SizedBox(width: 6),
        Text(
          teks,
          style: gayaTeks.labelLarge?.copyWith(
            color: warna,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final bungkus = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: warna.withValues(alpha: 0.4)),
      ),
      child: isi,
    );

    return GestureDetector(
      onTap: widget.saatDitekan == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.saatDitekan!.call();
            },
      child: bungkus,
    );
  }
}

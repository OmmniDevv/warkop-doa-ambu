import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bersama/widget/kartu_warkop.dart';
import '../../bersama/widget/status_error.dart';
import '../../bersama/widget/status_kosong.dart';
import '../../data/lokal/database_lokal.dart';
import '../../data/model/log_audit.dart';
import 'util_tanggal.dart';

/// 200 baris log audit terbaru — query mentah sesuai kontrak fase 8.
final penyediaLogAudit = FutureProvider<List<LogAudit>>((ref) async {
  final db = await DatabaseLokal.instance.db;
  final baris = await db.rawQuery(
    'SELECT * FROM log_audit ORDER BY dibuat_pada DESC LIMIT 200',
  );
  return baris.map(LogAudit.dariMap).toList();
});

/// Layar jejak audit: daftar log terbaru dulu + cari berdasar aksi.
class LayarAudit extends ConsumerStatefulWidget {
  const LayarAudit({super.key});

  @override
  ConsumerState<LayarAudit> createState() => _LayarAuditState();
}

class _LayarAuditState extends ConsumerState<LayarAudit> {
  final _kontrolCari = TextEditingController();
  String _kataKunci = '';

  @override
  void dispose() {
    _kontrolCari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(penyediaLogAudit);

    return Scaffold(
      appBar: AppBar(title: const Text('JEJAK AUDIT')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _kontrolCari,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Cari jejak…',
                  hintText: 'mis. void, kasbon, stok, menu',
                  prefixIcon: const Icon(Icons.search_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _kataKunci.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.clear_outlined),
                          onPressed: () {
                            _kontrolCari.clear();
                            setState(() => _kataKunci = '');
                          },
                        ),
                ),
                onChanged: (nilai) =>
                    setState(() => _kataKunci = nilai.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: logAsync.when(
                data: (semua) {
                  final daftar = _kataKunci.isEmpty
                      ? semua
                      : semua
                          .where(
                            (l) =>
                                l.aksi.toLowerCase().contains(_kataKunci),
                          )
                          .toList();
                  if (daftar.isEmpty) {
                    return StatusKosong(
                      judul: _kataKunci.isEmpty
                          ? 'Belum ada jejak audit'
                          : 'Tidak ada hasil',
                      deskripsi: _kataKunci.isEmpty
                          ? 'Aktivitas kasir dan owner akan tercatat di sini.'
                          : 'Coba kata kunci lain ya.',
                      inisial: 'A',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: daftar.length,
                    itemBuilder: (context, i) =>
                        _BarisAudit(log: daftar[i]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => StatusError(
                  saatCobaLagi: () =>
                      ref.invalidate(penyediaLogAudit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisAudit extends StatelessWidget {
  const _BarisAudit({required this.log});

  final LogAudit log;

  @override
  Widget build(BuildContext context) {
    final aksen = Theme.of(context).colorScheme.primary;
    final referensi = log.idReferensi ?? '-';
    final refPendek =
        referensi.length > 8 ? '${referensi.substring(0, 8)}…' : referensi;
    final keterangan = log.alasan ?? log.detail ?? '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuWarkop(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: aksen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: aksen.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      log.aksi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: aksen,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatTanggalWaktu(log.dibuatPada),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ref: $refPendek',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              keterangan,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

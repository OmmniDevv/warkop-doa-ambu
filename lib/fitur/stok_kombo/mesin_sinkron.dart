import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/lokal/database_lokal.dart';

/// Hasil satu putaran sinkronisasi: jumlah baris yang berhasil dan gagal.
class HasilSinkron {
  const HasilSinkron({this.berhasil = 0, this.gagal = 0});

  final int berhasil;
  final int gagal;
}

/// Mesin sinkronisasi: mengunggah baris lokal 'tertunda' ke Supabase
/// DAN mengunduh data master (akun kasir) dari Supabase ke lokal.
/// Tidak pernah menghapus data lokal dan tidak pernah melempar exception.
class MesinSinkron {
  /// Kolom boolean per tabel: SQLite menyimpan 0/1, Supabase butuh
  /// true/false. Tabel di luar daftar ini diunggah apa adanya.
  static const Map<String, Set<String>> _kolomBoolean = {
    'akun': {'aktif', 'apakah_dihapus'},
    'kategori_menu': {'aktif', 'apakah_dihapus'},
    'menu': {'tersedia', 'apakah_dihapus'},
    'paket_kombo': {'aktif', 'apakah_dihapus'},
    'paket_kombo_rincian': {'apakah_dihapus'},
    'open_bill': {'apakah_dihapus'},
    'shift_kasir': {'apakah_dihapus'},
    'pesanan': {'void_disetujui_owner', 'apakah_dihapus'},
    'pesanan_rincian': {'apakah_dihapus'},
    'pesanan_bayar': <String>{},
    'bahan': {'apakah_dihapus'},
    'resep': <String>{},
    'stok_opname': <String>{},
    'kasbon': {'apakah_dihapus'},
    'kas_keluar': {'apakah_dihapus'},
    'pemilik': {'apakah_biometrik_aktif', 'apakah_dihapus'},
  };

  /// Tabel yang ikut antrean sinkron (nama sama persis di SQLite & Supabase).
  static const List<String> _daftarTabel = [
    'akun',
    'kategori_menu',
    'menu',
    'paket_kombo',
    'paket_kombo_rincian',
    'open_bill',
    'shift_kasir',
    'pesanan',
    'pesanan_rincian',
    'pesanan_bayar',
    'bahan',
    'resep',
    'stok_opname',
    'kasbon',
    'kas_keluar',
    'pemilik',
  ];

  /// Kunci watermark log_audit di SharedPreferences (ISO8601 terbesar
  /// yang sudah terunggah).
  static const String _kunciWatermarkAudit = 'wda_audit_sinkron_sampai';

  /// Unggah semua baris 'tertunda' ke Supabase.
  ///
  /// Sukses per baris → tandai 'tersinkron'; gagal → tandai 'gagal'.
  /// Jika client Supabase tidak tersedia (belum init / offline), semua
  /// baris dibiarkan 'tertunda' untuk dicoba lagi nanti.
  /// Tidak pernah throw.
  Future<HasilSinkron> sinkronkan() async {
    try {
      final db = DatabaseLokal.instance;

      SupabaseClient client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        // Belum diinisialisasi atau offline — biarkan 'tertunda', coba lagi nanti.
        return const HasilSinkron();
      }

      var berhasil = 0;
      var gagal = 0;

      for (final tabel in _daftarTabel) {
        final tertunda = await db.daftarTertunda(tabel);
        for (final baris in tertunda) {
          final id = baris['id'];
          if (id is! String || id.isEmpty) continue;
          try {
            await client
                .from(tabel)
                .upsert(_kePayloadSupabase(tabel, baris), onConflict: 'id');
            await db.tandaiTersinkron(tabel, id);
            berhasil++;
          } catch (_) {
            await db.tandaiGagal(tabel, id);
            gagal++;
          }
        }
      }

      await _sinkronkanLogAudit(client);

      // Unduh akun kasir dari server (agar akun yang dibuat owner di
      // perangkat lain / sebelum reinstall tetap muncul).
      await _unduhAkun(client);

      return HasilSinkron(berhasil: berhasil, gagal: gagal);
    } catch (_) {
      return const HasilSinkron();
    }
  }

  /// Mengunduh daftar akun dari Supabase ke SQLite lokal.
  ///
  /// Dipakai agar akun kasir yang dibuat owner tetap muncul setelah
  /// reinstall / di perangkat lain. Baris lokal berstatus 'tertunda'
  /// (perubahan belum terunggah) TIDAK ditimpa — perubahan lokal menang.
  /// Tidak pernah throw.
  Future<void> _unduhAkun(SupabaseClient client) async {
    try {
      final db = DatabaseLokal.instance;
      final remote = await client
          .from('akun')
          .select()
          .eq('apakah_dihapus', false);

      final dbBuka = await db.db;
      for (final baris in (remote as List)) {
        final peta = Map<String, Object?>.from(baris as Map);
        final id = peta['id'] as String?;
        if (id == null || id.isEmpty) continue;

        // Jangan timpa perubahan lokal yang belum terunggah.
        final lokal = await dbBuka.query(
          'akun',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (lokal.isNotEmpty &&
            lokal.first['status_sinkron'] == 'tertunda') {
          continue;
        }

        // Konversi boolean Supabase (true/false) ke SQLite (1/0).
        final barisLokal = <String, Object?>{
          'id': id,
          'nama': peta['nama'],
          'pin_hash': peta['pin_hash'],
          'peran': peta['peran'],
          'aktif': (peta['aktif'] as bool? ?? true) ? 1 : 0,
          'status_sinkron': 'tersinkron',
          'diperbarui_pada': peta['diperbarui_pada'] ??
              peta['diperbaruiPada'] ??
              DateTime.now().toUtc().toIso8601String(),
          'apakah_dihapus': (peta['apakah_dihapus'] as bool? ?? false) ? 1 : 0,
        };
        await dbBuka.insert(
          'akun',
          barisLokal,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {
      // Lewati diam-diam — dicoba lagi pada putaran berikutnya.
    }
  }

  /// Ubah baris SQLite menjadi payload Supabase: nama kolom sudah
  /// snake_case; kolom boolean 0/1 dikonversi menjadi true/false.
  Map<String, dynamic> _kePayloadSupabase(
    String tabel,
    Map<String, Object?> baris,
  ) {
    final kolomBoolean = _kolomBoolean[tabel] ?? const <String>{};
    final payload = <String, dynamic>{};
    for (final entri in baris.entries) {
      final nilai = entri.value;
      if (kolomBoolean.contains(entri.key) && nilai is int) {
        payload[entri.key] = nilai == 1;
      } else {
        payload[entri.key] = nilai;
      }
    }
    return payload;
  }

  /// Unggah log_audit yang lebih baru dari watermark (append-only, tanpa
  /// kolom status_sinkron). Jika semua terunggah, watermark dimajukan ke
  /// dibuat_pada terbesar. Client gagal → dilewati diam-diam.
  Future<void> _sinkronkanLogAudit(SupabaseClient client) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watermark = prefs.getString(_kunciWatermarkAudit);

      final db = await DatabaseLokal.instance.db;
      final baris = await db.rawQuery(
        'SELECT * FROM log_audit WHERE dibuat_pada > ? ORDER BY dibuat_pada ASC',
        [watermark ?? ''],
      );
      if (baris.isEmpty) return;

      for (final log in baris) {
        await client.from('log_audit').insert(Map<String, dynamic>.from(log));
      }

      final terbesar = baris.last['dibuat_pada'];
      if (terbesar is String && terbesar.isNotEmpty) {
        await prefs.setString(_kunciWatermarkAudit, terbesar);
      }
    } catch (_) {
      // Lewati diam-diam — dicoba lagi pada putaran berikutnya.
    }
  }
}

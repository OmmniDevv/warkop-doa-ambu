import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../model/pemilik.dart';

/// Helper SQLite lokal — sumber kebenaran saat offline.
///
/// Skema memakai Bahasa Indonesia penuh, mengikuti `docs/SKEMA_DATABASE.md`.
class DatabaseLokal {
  DatabaseLokal._();
  static final DatabaseLokal instance = DatabaseLokal._();

  static const _namaDb = 'warkop_doa_ambu.db';
  static const _versi = 1;

  Database? _db;

  Future<Database> get db async {
    final tersedia = _db;
    if (tersedia != null) return tersedia;
    final dibuat = await _buka();
    _db = dibuat;
    return dibuat;
  }

  Future<Database> _buka() async {
    final direktori = await getDatabasesPath();
    return openDatabase(
      p.join(direktori, _namaDb),
      version: _versi,
      onCreate: _buatSkema,
    );
  }

  Future<void> _buatSkema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pemilik (
        id TEXT PRIMARY KEY,
        nama_pemilik TEXT NOT NULL,
        nama_warkop TEXT NOT NULL DEFAULT 'WARKOP DOA AMBU',
        email TEXT UNIQUE NOT NULL,
        nomor_kontak TEXT,
        hash_pin_master TEXT NOT NULL,
        apakah_biometrik_aktif INTEGER NOT NULL DEFAULT 0,
        dibuat_pada TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tersinkron'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pemilik_email ON pemilik(email)',
    );
  }

  // ── Profil pemilik ───────────────────────────────────────────────

  /// Simpan / timpa profil pemilik (satu baris per perangkat kasir).
  Future<void> simpanPemilik(Pemilik pemilik) async {
    final db = await this.db;
    await db.insert(
      'pemilik',
      pemilik.keMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil profil pemilik yang tersimpan di perangkat ini (jika ada).
  Future<Pemilik?> ambilPemilik() async {
    final db = await this.db;
    final baris = await db.query('pemilik', limit: 1);
    if (baris.isEmpty) return null;
    return Pemilik.dariMap(baris.first);
  }

  /// Perbarui hash PIN master milik pemilik.
  Future<void> perbaruiPinMaster(String id, String hashPinBaru) async {
    final db = await this.db;
    await db.update(
      'pemilik',
      {'hash_pin_master': hashPinBaru, 'status_sinkron': 'tersinkron'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Aktif / nonaktifkan biometrik.
  Future<void> perbaruiBiometrik(String id, bool aktif) async {
    final db = await this.db;
    await db.update(
      'pemilik',
      {'apakah_biometrik_aktif': aktif ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus seluruh data lokal (untuk keluar akun / reset).
  Future<void> bersihkan() async {
    final db = await this.db;
    await db.delete('pemilik');
  }
}

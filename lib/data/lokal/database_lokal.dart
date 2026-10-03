import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../model/akun.dart';
import '../model/bahan.dart';
import '../model/kas_keluar.dart';
import '../model/kasbon.dart';
import '../model/kategori_menu.dart';
import '../model/log_audit.dart';
import '../model/menu.dart';
import '../model/open_bill.dart';
import '../model/paket_kombo.dart';
import '../model/paket_kombo_rincian.dart';
import '../model/pemilik.dart';
import '../model/pesanan.dart';
import '../model/pesanan_bayar.dart';
import '../model/pesanan_rincian.dart';
import '../model/resep.dart';
import '../model/shift_kasir.dart';
import '../model/stok_opname.dart';

/// Helper SQLite lokal — sumber kebenaran saat offline.
///
/// Skema memakai Bahasa Indonesia penuh, mengikuti
/// `supabase/migrasi_001_skema_awal.sql`. ID baris selalu dibawa oleh
/// model (lihat `lib/bersama/util/id_unik.dart`); helper ini tidak pernah
/// membuat ID sendiri.
class DatabaseLokal {
  DatabaseLokal._();
  static final DatabaseLokal instance = DatabaseLokal._();

  static const _namaDb = 'warkop_doa_ambu.db';
  static const _versi = 4;

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
      onUpgrade: _onUpgrade,
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
    await _buatSkemaOperasional(db);
  }

  /// Upgrade skema: idempoten, aman dipanggil berulang.
  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _buatSkemaOperasional(db);
    }
    if (oldVersion < 3) {
      await _upgradeKe3(db);
    }
    if (oldVersion < 4) {
      await _upgradeKe4(db);
    }
  }

  /// Migrasi v4: pastikan kolom diskon ada di instalasi lama yang dibuat
  /// langsung di v3 (skema fresh v3 lupa menyertakan kolom diskon,
  /// menyebabkan "Gagal menyimpan pesanan" saat checkout).
  /// Idempoten via [_tambahKolomJikaBelumAda].
  Future<void> _upgradeKe4(Database db) async {
    await _tambahKolomJikaBelumAda(
        db, 'pesanan', 'diskon_nota_nominal', 'INTEGER NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan', 'diskon_nota_persen', 'REAL NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(db, 'pesanan', 'alasan_diskon', 'TEXT');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan_rincian', 'diskon_nominal', 'INTEGER NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan_rincian', 'diskon_persen', 'REAL NOT NULL DEFAULT 0');
  }

  /// Migrasi v3: tabel bahan/resep/bayar/opname + kolom diskon.
  Future<void> _upgradeKe3(Database db) async {
    // Tabel baru (IF NOT EXISTS aman untuk DB yang sudah punya dari _buatSkema).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bahan (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        satuan TEXT NOT NULL DEFAULT 'pcs',
        stok REAL NOT NULL DEFAULT 0,
        stok_minimum REAL NOT NULL DEFAULT 0,
        harga_beli INTEGER NOT NULL DEFAULT 0,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resep (
        id TEXT PRIMARY KEY,
        id_menu TEXT NOT NULL,
        id_bahan TEXT NOT NULL,
        takaran REAL NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        UNIQUE (id_menu, id_bahan)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pesanan_bayar (
        id TEXT PRIMARY KEY,
        id_pesanan TEXT NOT NULL,
        metode TEXT NOT NULL,
        nominal INTEGER NOT NULL DEFAULT 0,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        dibuat_pada TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stok_opname (
        id TEXT PRIMARY KEY,
        tipe_item TEXT NOT NULL,
        id_item TEXT NOT NULL,
        nama_snapshot TEXT NOT NULL,
        stok_sistem REAL NOT NULL DEFAULT 0,
        stok_fisik REAL NOT NULL DEFAULT 0,
        selisih REAL NOT NULL DEFAULT 0,
        catatan TEXT,
        dibuat_oleh TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        dibuat_pada TEXT NOT NULL
      )
    ''');
    // Kolom diskon (tambah bila belum ada).
    await _tambahKolomJikaBelumAda(
        db, 'pesanan', 'diskon_nota_nominal', 'INTEGER NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan', 'diskon_nota_persen', 'REAL NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(db, 'pesanan', 'alasan_diskon', 'TEXT');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan_rincian', 'diskon_nominal', 'INTEGER NOT NULL DEFAULT 0');
    await _tambahKolomJikaBelumAda(
        db, 'pesanan_rincian', 'diskon_persen', 'REAL NOT NULL DEFAULT 0');
  }

  /// Tambah kolom hanya bila belum ada (cek via PRAGMA table_info).
  Future<void> _tambahKolomJikaBelumAda(
    Database db,
    String tabel,
    String kolom,
    String definisi,
  ) async {
    final info =
        await db.rawQuery('PRAGMA table_info($tabel)');
    final ada = info.any((baris) => baris['name'] == kolom);
    if (!ada) {
      await db.execute('ALTER TABLE $tabel ADD COLUMN $kolom $definisi');
    }
  }

  /// Membuat 12 tabel operasional + indeks + seed awal.
  ///
  /// Kolom mengikuti persis `supabase/migrasi_001_skema_awal.sql`:
  /// boolean → INTEGER 0/1, tanggal → TEXT ISO8601 UTC.
  Future<void> _buatSkemaOperasional(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS akun (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        pin_hash TEXT,
        peran TEXT NOT NULL,
        aktif INTEGER NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kategori_menu (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL UNIQUE,
        urutan_tampil INTEGER NOT NULL DEFAULT 0,
        aktif INTEGER NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu (
        id TEXT PRIMARY KEY,
        id_kategori TEXT NOT NULL,
        nama TEXT NOT NULL,
        harga_satuan INTEGER NOT NULL DEFAULT 0,
        stok INTEGER NOT NULL DEFAULT 0,
        stok_minimum INTEGER NOT NULL DEFAULT 0,
        tersedia INTEGER NOT NULL DEFAULT 1,
        foto_url TEXT,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paket_kombo (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        harga_paket INTEGER NOT NULL DEFAULT 0,
        aktif INTEGER NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paket_kombo_rincian (
        id TEXT PRIMARY KEY,
        id_paket TEXT NOT NULL,
        id_menu TEXT NOT NULL,
        jumlah INTEGER NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS open_bill (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'buka',
        id_akun TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_kasir (
        id TEXT PRIMARY KEY,
        id_akun TEXT NOT NULL,
        dibuka_pada TEXT NOT NULL,
        ditutup_pada TEXT,
        saldo_awal INTEGER NOT NULL DEFAULT 0,
        kas_akhir_sistem INTEGER NOT NULL DEFAULT 0,
        kas_akhir_fisik INTEGER,
        selisih INTEGER,
        status TEXT NOT NULL DEFAULT 'buka',
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pesanan (
        id TEXT PRIMARY KEY,
        nomor_nota TEXT NOT NULL UNIQUE,
        id_akun TEXT NOT NULL,
        id_shift TEXT,
        id_open_bill TEXT,
        metode_bayar TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'baru',
        total INTEGER NOT NULL DEFAULT 0,
        bayar INTEGER NOT NULL DEFAULT 0,
        kembalian INTEGER NOT NULL DEFAULT 0,
        foto_bukti_lokal TEXT,
        foto_bukti_remote TEXT,
        void_alasan TEXT,
        void_disetujui_owner INTEGER NOT NULL DEFAULT 0,
        diskon_nota_nominal INTEGER NOT NULL DEFAULT 0,
        diskon_nota_persen REAL NOT NULL DEFAULT 0,
        alasan_diskon TEXT,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pesanan_rincian (
        id TEXT PRIMARY KEY,
        id_pesanan TEXT NOT NULL,
        id_menu TEXT,
        id_paket TEXT,
        nama_snapshot TEXT NOT NULL,
        harga_snapshot INTEGER NOT NULL DEFAULT 0,
        jumlah INTEGER NOT NULL DEFAULT 1,
        subtotal INTEGER NOT NULL DEFAULT 0,
        catatan TEXT,
        diskon_nominal INTEGER NOT NULL DEFAULT 0,
        diskon_persen REAL NOT NULL DEFAULT 0,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kasbon (
        id TEXT PRIMARY KEY,
        nama_pelanggan TEXT NOT NULL,
        nominal INTEGER NOT NULL DEFAULT 0,
        sudah_bayar INTEGER NOT NULL DEFAULT 0,
        jatuh_tempo TEXT,
        status TEXT NOT NULL DEFAULT 'belum_lunas',
        id_akun TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kas_keluar (
        id TEXT PRIMARY KEY,
        id_akun TEXT NOT NULL,
        id_shift TEXT,
        kategori TEXT NOT NULL,
        nominal INTEGER NOT NULL DEFAULT 0,
        catatan TEXT,
        terjadi_pada TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // log_audit: append-only, tanpa kolom sinkron.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_audit (
        id TEXT PRIMARY KEY,
        aksi TEXT NOT NULL,
        id_akun TEXT,
        id_referensi TEXT,
        detail TEXT,
        alasan TEXT,
        dibuat_pada TEXT NOT NULL
      )
    ''');
    // ── Migrasi 002: bahan, resep, diskon, bayar gabungan, stok opname ──
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bahan (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        satuan TEXT NOT NULL DEFAULT 'pcs',
        stok REAL NOT NULL DEFAULT 0,
        stok_minimum REAL NOT NULL DEFAULT 0,
        harga_beli INTEGER NOT NULL DEFAULT 0,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        apakah_dihapus INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resep (
        id TEXT PRIMARY KEY,
        id_menu TEXT NOT NULL,
        id_bahan TEXT NOT NULL,
        takaran REAL NOT NULL DEFAULT 1,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        diperbarui_pada TEXT NOT NULL,
        UNIQUE (id_menu, id_bahan)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pesanan_bayar (
        id TEXT PRIMARY KEY,
        id_pesanan TEXT NOT NULL,
        metode TEXT NOT NULL,
        nominal INTEGER NOT NULL DEFAULT 0,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        dibuat_pada TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stok_opname (
        id TEXT PRIMARY KEY,
        tipe_item TEXT NOT NULL,
        id_item TEXT NOT NULL,
        nama_snapshot TEXT NOT NULL,
        stok_sistem REAL NOT NULL DEFAULT 0,
        stok_fisik REAL NOT NULL DEFAULT 0,
        selisih REAL NOT NULL DEFAULT 0,
        catatan TEXT,
        dibuat_oleh TEXT NOT NULL,
        status_sinkron TEXT NOT NULL DEFAULT 'tertunda',
        dibuat_pada TEXT NOT NULL
      )
    ''');

    // Indeks mengikuti migrasi SQL.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_menu_id_kategori ON menu(id_kategori)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pesanan_diperbarui '
      'ON pesanan(diperbarui_pada)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pesanan_status_sinkron '
      'ON pesanan(status_sinkron)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pesanan_nomor_nota ON pesanan(nomor_nota)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pesanan_rincian_id_pesanan '
      'ON pesanan_rincian(id_pesanan)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_paket_rincian_id_paket '
      'ON paket_kombo_rincian(id_paket)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shift_id_akun ON shift_kasir(id_akun)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kasbon_id_akun ON kasbon(id_akun)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kas_keluar_id_akun '
      'ON kas_keluar(id_akun)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_open_bill_id_akun ON open_bill(id_akun)',
    );

    await _seedAwal(db);
  }

  /// Seed kategori + menu awal; idempoten (id tetap, hanya jika kosong).
  Future<void> _seedAwal(Database db) async {
    final hitung = await db.rawQuery(
      'SELECT COUNT(*) AS jumlah FROM kategori_menu',
    );
    if (((hitung.first['jumlah'] as int?) ?? 0) > 0) return;

    final sekarang = _sekarangUtc();
    const statusSeed = 'tersinkron';

    final kategori = <List<Object>>[
      ['seed-kat-kopi', 'Kopi', 1],
      ['seed-kat-minuman-dingin', 'Minuman Dingin', 2],
      ['seed-kat-snack', 'Snack', 3],
      ['seed-kat-makanan', 'Makanan', 4],
    ];

    // id, id_kategori, nama, harga, stok, stok_minimum
    final menu = <List<Object>>[
      ['seed-menu-kopi-tubruk', 'seed-kat-kopi', 'Kopi Tubruk', 8000, 50, 10],
      ['seed-menu-kopi-susu', 'seed-kat-kopi', 'Kopi Susu', 12000, 50, 10],
      ['seed-menu-kopi-hitam-es', 'seed-kat-kopi', 'Kopi Hitam Es', 10000, 50, 10],
      ['seed-menu-es-teh-manis', 'seed-kat-minuman-dingin', 'Es Teh Manis', 5000, 50, 10],
      ['seed-menu-es-jeruk', 'seed-kat-minuman-dingin', 'Es Jeruk', 7000, 50, 10],
      ['seed-menu-pisang-goreng', 'seed-kat-snack', 'Pisang Goreng', 10000, 30, 5],
      ['seed-menu-tahu-isi', 'seed-kat-snack', 'Tahu Isi', 8000, 30, 5],
      ['seed-menu-indomie-goreng', 'seed-kat-makanan', 'Indomie Goreng', 12000, 30, 5],
      ['seed-menu-nasi-goreng', 'seed-kat-makanan', 'Nasi Goreng', 15000, 20, 5],
    ];

    final batch = db.batch();
    for (final k in kategori) {
      batch.insert('kategori_menu', {
        'id': k[0],
        'nama': k[1],
        'urutan_tampil': k[2],
        'aktif': 1,
        'status_sinkron': statusSeed,
        'diperbarui_pada': sekarang,
        'apakah_dihapus': 0,
      });
    }
    for (final m in menu) {
      batch.insert('menu', {
        'id': m[0],
        'id_kategori': m[1],
        'nama': m[2],
        'harga_satuan': m[3],
        'stok': m[4],
        'stok_minimum': m[5],
        'tersedia': 1,
        'foto_url': null,
        'status_sinkron': statusSeed,
        'diperbarui_pada': sekarang,
        'apakah_dihapus': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  // ── Pembantu sinkron ─────────────────────────────────────────────

  /// Waktu sekarang dalam ISO8601 UTC.
  String _sekarangUtc() => DateTime.now().toUtc().toIso8601String();

  /// Insert baris baru: selalu tandai 'tertunda' + stempel waktu baru.
  Future<void> _simpan(String namaTabel, Map<String, Object?> map) async {
    final db = await this.db;
    await db.insert(
      namaTabel,
      map
        ..['status_sinkron'] = 'tertunda'
        ..['diperbarui_pada'] = _sekarangUtc(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update baris: tandai 'tertunda' agar ikut antrean sinkron.
  Future<void> _perbarui(
    String namaTabel,
    Map<String, Object?> map,
    String id,
  ) async {
    final db = await this.db;
    await db.update(
      namaTabel,
      map
        ..remove('id')
        ..['status_sinkron'] = 'tertunda'
        ..['diperbarui_pada'] = _sekarangUtc(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete: sembunyikan lokal, tandai 'tertunda' agar sinkron hapus.
  Future<void> _hapusLunak(String namaTabel, String id) async {
    final db = await this.db;
    await db.update(
      namaTabel,
      {
        'apakah_dihapus': 1,
        'status_sinkron': 'tertunda',
        'diperbarui_pada': _sekarangUtc(),
      },
      where: 'id = ?',
      whereArgs: [id],
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

  // ── Akun ─────────────────────────────────────────────────────────

  /// Simpan akun baru (owner/kasir).
  Future<void> simpanAkun(Akun akun) => _simpan('akun', akun.keMap());

  /// Daftar akun; [hanyaAktif] menyaring yang aktif saja.
  Future<List<Akun>> daftarAkun({bool hanyaAktif = false}) async {
    final db = await this.db;
    final baris = await db.query(
      'akun',
      where: hanyaAktif ? 'apakah_dihapus = 0 AND aktif = 1' : 'apakah_dihapus = 0',
      orderBy: 'nama ASC',
    );
    return baris.map(Akun.dariMap).toList();
  }

  /// Ambil satu akun berdasarkan id.
  Future<Akun?> ambilAkun(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'akun',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return Akun.dariMap(baris.first);
  }

  /// Perbarui data akun.
  Future<void> perbaruiAkun(Akun akun) =>
      _perbarui('akun', akun.keMap(), akun.id);

  /// Hapus lunak akun.
  Future<void> hapusAkunLunak(String id) => _hapusLunak('akun', id);

  // ── Kategori menu ────────────────────────────────────────────────

  /// Simpan kategori menu baru.
  Future<void> simpanKategori(KategoriMenu kategori) =>
      _simpan('kategori_menu', kategori.keMap());

  /// Daftar kategori aktif, urut tampilan.
  Future<List<KategoriMenu>> daftarKategori() async {
    final db = await this.db;
    final baris = await db.query(
      'kategori_menu',
      where: 'apakah_dihapus = 0',
      orderBy: 'urutan_tampil ASC',
    );
    return baris.map(KategoriMenu.dariMap).toList();
  }

  /// Perbarui kategori menu.
  Future<void> perbaruiKategori(KategoriMenu kategori) =>
      _perbarui('kategori_menu', kategori.keMap(), kategori.id);

  /// Hapus lunak kategori menu.
  Future<void> hapusKategoriLunak(String id) => _hapusLunak('kategori_menu', id);

  // ── Menu ─────────────────────────────────────────────────────────

  /// Simpan item menu baru.
  Future<void> simpanMenu(Menu menu) => _simpan('menu', menu.keMap());

  /// Daftar menu; saring per [idKategori] bila diisi. Urut nama.
  Future<List<Menu>> daftarMenu({String? idKategori}) async {
    final db = await this.db;
    final baris = await db.query(
      'menu',
      where: idKategori == null
          ? 'apakah_dihapus = 0'
          : 'apakah_dihapus = 0 AND id_kategori = ?',
      whereArgs: idKategori == null ? null : [idKategori],
      orderBy: 'nama ASC',
    );
    return baris.map(Menu.dariMap).toList();
  }

  /// Ambil satu menu berdasarkan id.
  Future<Menu?> ambilMenu(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'menu',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return Menu.dariMap(baris.first);
  }

  /// Perbarui item menu.
  Future<void> perbaruiMenu(Menu menu) =>
      _perbarui('menu', menu.keMap(), menu.id);

  /// Hapus lunak item menu.
  Future<void> hapusMenuLunak(String id) => _hapusLunak('menu', id);

  /// Kurangi stok menu sebanyak [jumlah] (atomik).
  Future<void> kurangiStok(String idMenu, int jumlah) async {
    final db = await this.db;
    await db.rawUpdate(
      '''
      UPDATE menu
      SET stok = stok - ?,
          status_sinkron = 'tertunda',
          diperbarui_pada = ?
      WHERE id = ?
      ''',
      [jumlah, _sekarangUtc(), idMenu],
    );
  }

  // ── Bahan (Fase stok redesign) ───────────────────────────────────

  /// Seluruh bahan aktif, urut nama.
  Future<List<Bahan>> daftarBahan() async {
    final db = await this.db;
    final baris = await db.query(
      'bahan',
      where: 'apakah_dihapus = 0',
      orderBy: 'nama COLLATE NOCASE ASC',
    );
    return [for (final b in baris) Bahan.dariBaris(b)];
  }

  /// Bahan yang stoknya sudah di batas minimum atau di bawahnya.
  Future<List<Bahan>> daftarBahanMenipis() async {
    final db = await this.db;
    final baris = await db.query(
      'bahan',
      where: 'apakah_dihapus = 0 AND stok <= stok_minimum',
      orderBy: 'nama COLLATE NOCASE ASC',
    );
    return [for (final b in baris) Bahan.dariBaris(b)];
  }

  /// Simpan bahan baru.
  Future<void> simpanBahan(Bahan bahan) => _simpan('bahan', bahan.keBaris());

  /// Perbarui bahan (tandai 'tertunda' agar ikut antrean sinkron).
  Future<void> perbaruiBahan(Bahan bahan) =>
      _perbarui('bahan', bahan.keBaris(), bahan.id);

  /// Hapus lunak bahan.
  Future<void> hapusBahanLunak(String id) => _hapusLunak('bahan', id);

  // ── Resep (menu ↔ bahan) ─────────────────────────────────────────

  /// Resep satu menu beserta nama & satuan bahannya.
  Future<List<ResepLengkap>> daftarResepMenu(String idMenu) async {
    final db = await this.db;
    final baris = await db.rawQuery(
      '''
      SELECT r.*, b.nama AS nama_bahan, b.satuan AS satuan_bahan
      FROM resep r
      JOIN bahan b ON b.id = r.id_bahan
      WHERE r.id_menu = ? AND b.apakah_dihapus = 0
      ORDER BY b.nama COLLATE NOCASE ASC
      ''',
      [idMenu],
    );
    return [
      for (final b in baris)
        ResepLengkap(
          resep: Resep.dariBaris(b),
          namaBahan: b['nama_bahan'] as String,
          satuan: b['satuan_bahan'] as String? ?? 'pcs',
        ),
    ];
  }

  /// Simpan satu baris resep (id_menu + id_bahan unik).
  Future<void> simpanResep(Resep resep) => _simpan('resep', resep.keBaris());

  /// Hapus keras satu baris resep (relasi, tanpa soft-delete).
  Future<void> hapusResep(String id) async {
    final db = await this.db;
    await db.delete('resep', where: 'id = ?', whereArgs: [id]);
  }

  // ── Stok opname ──────────────────────────────────────────────────

  /// Catat satu baris hasil opname.
  ///
  /// Tabel `stok_opname` tidak punya kolom `diperbarui_pada`, jadi tidak
  /// memakai [_simpan]; insert langsung dengan status 'tertunda'.
  Future<void> catatOpname(StokOpname opname) async {
    final db = await this.db;
    await db.insert(
      'stok_opname',
      opname.keBaris()..['status_sinkron'] = 'tertunda',
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Riwayat opname terbaru → terlama.
  Future<List<StokOpname>> daftarOpname({int batas = 300}) async {
    final db = await this.db;
    final baris = await db.query(
      'stok_opname',
      orderBy: 'dibuat_pada DESC',
      limit: batas,
    );
    return [for (final b in baris) StokOpname.dariBaris(b)];
  }

  // ── Paket kombo ──────────────────────────────────────────────────

  /// Simpan paket kombo baru.
  Future<void> simpanPaket(PaketKombo paket) =>
      _simpan('paket_kombo', paket.keMap());

  /// Daftar paket kombo, urut nama.
  Future<List<PaketKombo>> daftarPaket() async {
    final db = await this.db;
    final baris = await db.query(
      'paket_kombo',
      where: 'apakah_dihapus = 0',
      orderBy: 'nama ASC',
    );
    return baris.map(PaketKombo.dariMap).toList();
  }

  /// Ambil satu paket kombo berdasarkan id.
  Future<PaketKombo?> ambilPaket(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'paket_kombo',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return PaketKombo.dariMap(baris.first);
  }

  /// Perbarui paket kombo.
  Future<void> perbaruiPaket(PaketKombo paket) =>
      _perbarui('paket_kombo', paket.keMap(), paket.id);

  /// Hapus lunak paket kombo.
  Future<void> hapusPaketLunak(String id) => _hapusLunak('paket_kombo', id);

  /// Simpan satu baris rincian isi paket.
  Future<void> simpanPaketRincian(PaketKomboRincian rincian) =>
      _simpan('paket_kombo_rincian', rincian.keMap());

  /// Daftar isi paket [idPaket].
  Future<List<PaketKomboRincian>> daftarPaketRincian(String idPaket) async {
    final db = await this.db;
    final baris = await db.query(
      'paket_kombo_rincian',
      where: 'id_paket = ? AND apakah_dihapus = 0',
      whereArgs: [idPaket],
      orderBy: 'rowid ASC',
    );
    return baris.map(PaketKomboRincian.dariMap).toList();
  }

  /// Hapus satu baris rincian paket (hapus permanen lokal).
  Future<void> hapusPaketRincian(String id) async {
    final db = await this.db;
    await db.delete('paket_kombo_rincian', where: 'id = ?', whereArgs: [id]);
  }

  // ── Pesanan ──────────────────────────────────────────────────────

  /// Simpan pesanan (nota) baru.
  Future<void> simpanPesanan(Pesanan pesanan) =>
      _simpan('pesanan', pesanan.keMap());

  /// Ambil satu pesanan berdasarkan id.
  Future<Pesanan?> ambilPesanan(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'pesanan',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return Pesanan.dariMap(baris.first);
  }

  /// Daftar pesanan; saring [status] bila diisi. Terbaru dulu.
  Future<List<Pesanan>> daftarPesanan({String? status}) async {
    final db = await this.db;
    final baris = await db.query(
      'pesanan',
      where: status == null
          ? 'apakah_dihapus = 0'
          : 'apakah_dihapus = 0 AND status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'diperbarui_pada DESC',
    );
    return baris.map(Pesanan.dariMap).toList();
  }

  /// Perbarui pesanan.
  Future<void> perbaruiPesanan(Pesanan pesanan) =>
      _perbarui('pesanan', pesanan.keMap(), pesanan.id);

  /// Nomor nota berikutnya: "WDA-YYYYMMDD-XXXX", XXXX = urutan hari ini.
  Future<String> nomorNotaBerikutnya() async {
    final db = await this.db;
    final sekarang = DateTime.now();
    final tanggal = '${sekarang.year}'
        '${sekarang.month.toString().padLeft(2, '0')}'
        '${sekarang.day.toString().padLeft(2, '0')}';
    final awalan = 'WDA-$tanggal-';
    final hasil = await db.rawQuery(
      'SELECT COUNT(*) AS jumlah FROM pesanan WHERE nomor_nota LIKE ?',
      ['$awalan%'],
    );
    final jumlah = (hasil.first['jumlah'] as int?) ?? 0;
    return '$awalan${(jumlah + 1).toString().padLeft(4, '0')}';
  }

  // ── Rincian pesanan ──────────────────────────────────────────────

  /// Simpan satu baris rincian pesanan.
  Future<void> simpanRincian(PesananRincian rincian) =>
      _simpan('pesanan_rincian', rincian.keMap());

  /// Daftar seluruh rincian milik [idPesanan].
  Future<List<PesananRincian>> daftarRincianPesanan(String idPesanan) async {
    final db = await this.db;
    final baris = await db.query(
      'pesanan_rincian',
      where: 'id_pesanan = ? AND apakah_dihapus = 0',
      whereArgs: [idPesanan],
      orderBy: 'rowid ASC',
    );
    return baris.map(PesananRincian.dariMap).toList();
  }

  /// Hapus satu baris rincian pesanan (hapus permanen lokal).
  Future<void> hapusRincian(String id) async {
    final db = await this.db;
    await db.delete('pesanan_rincian', where: 'id = ?', whereArgs: [id]);
  }

  // ── Pembayaran gabungan ──────────────────────────────────────────

  /// Simpan satu baris pembayaran (komponen bayar gabungan).
  Future<void> simpanPembayaran(PesananBayar bayar) async {
    final db = await this.db;
    await db.insert('pesanan_bayar', bayar.keBaris());
  }

  /// Daftar seluruh baris pembayaran milik [idPesanan].
  Future<List<PesananBayar>> daftarPembayaranPesanan(String idPesanan) async {
    final db = await this.db;
    final baris = await db.query(
      'pesanan_bayar',
      where: 'id_pesanan = ?',
      whereArgs: [idPesanan],
      orderBy: 'dibuat_pada ASC',
    );
    return baris.map(PesananBayar.dariBaris).toList();
  }

  // ── Bahan & resep ────────────────────────────────────────────────

  /// Ambil satu bahan baku berdasarkan [id].
  Future<Bahan?> ambilBahan(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'bahan',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
    );
    if (baris.isEmpty) return null;
    return Bahan.dariBaris(baris.first);
  }

  /// Kurangi stok bahan sesuai resep [idMenu] × [jumlahMenu] terjual.
  ///
  /// Mengembalikan bahan-bahan yang stoknya kini menipis
  /// (stok <= stok_minimum) untuk ditampilkan sebagai peringatan.
  Future<List<Bahan>> kurangiStokBahanResep(
    String idMenu,
    int jumlahMenu,
  ) async {
    final resep = await daftarResepMenu(idMenu);
    if (resep.isEmpty) return const [];
    final db = await this.db;
    final sekarang = _sekarangUtc();
    final menipis = <Bahan>[];
    for (final lengkap in resep) {
      final baris = lengkap.resep;
      await db.rawUpdate(
        '''
        UPDATE bahan
        SET stok = stok - ?,
            status_sinkron = 'tertunda',
            diperbarui_pada = ?
        WHERE id = ?
        ''',
        [baris.takaran * jumlahMenu, sekarang, baris.idBahan],
      );
      final bahan = await ambilBahan(baris.idBahan);
      if (bahan != null && bahan.menipis) menipis.add(bahan);
    }
    return menipis;
  }

  // ── Open bill ────────────────────────────────────────────────────

  /// Simpan open bill baru.
  Future<void> simpanOpenBill(OpenBill openBill) =>
      _simpan('open_bill', openBill.keMap());

  /// Daftar open bill yang masih buka.
  Future<List<OpenBill>> daftarOpenBillAktif() async {
    final db = await this.db;
    final baris = await db.query(
      'open_bill',
      where: "status = 'buka' AND apakah_dihapus = 0",
      orderBy: 'diperbarui_pada DESC',
    );
    return baris.map(OpenBill.dariMap).toList();
  }

  /// Ambil satu open bill berdasarkan id.
  Future<OpenBill?> ambilOpenBill(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'open_bill',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return OpenBill.dariMap(baris.first);
  }

  /// Perbarui open bill.
  Future<void> perbaruiOpenBill(OpenBill openBill) =>
      _perbarui('open_bill', openBill.keMap(), openBill.id);

  // ── Shift kasir ──────────────────────────────────────────────────

  /// Simpan shift baru (saat kasir membuka shift).
  Future<void> simpanShift(ShiftKasir shift) =>
      _simpan('shift_kasir', shift.keMap());

  /// Ambil shift yang masih buka milik [idAkun] (jika ada).
  Future<ShiftKasir?> ambilShiftAktif(String idAkun) async {
    final db = await this.db;
    final baris = await db.query(
      'shift_kasir',
      where: "id_akun = ? AND status = 'buka' AND apakah_dihapus = 0",
      whereArgs: [idAkun],
      orderBy: 'dibuka_pada DESC',
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return ShiftKasir.dariMap(baris.first);
  }

  /// Perbarui shift (misalnya saat tutup shift).
  Future<void> perbaruiShift(ShiftKasir shift) =>
      _perbarui('shift_kasir', shift.keMap(), shift.id);

  // ── Kasbon ───────────────────────────────────────────────────────

  /// Simpan catatan kasbon baru.
  Future<void> simpanKasbon(Kasbon kasbon) => _simpan('kasbon', kasbon.keMap());

  /// Daftar kasbon; saring [status] bila diisi. Urut status lalu nama.
  Future<List<Kasbon>> daftarKasbon({String? status}) async {
    final db = await this.db;
    final baris = await db.query(
      'kasbon',
      where: status == null
          ? 'apakah_dihapus = 0'
          : 'apakah_dihapus = 0 AND status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'status ASC, nama_pelanggan ASC',
    );
    return baris.map(Kasbon.dariMap).toList();
  }

  /// Ambil satu kasbon berdasarkan id.
  Future<Kasbon?> ambilKasbon(String id) async {
    final db = await this.db;
    final baris = await db.query(
      'kasbon',
      where: 'id = ? AND apakah_dihapus = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return Kasbon.dariMap(baris.first);
  }

  /// Perbarui kasbon (misalnya catat cicilan).
  Future<void> perbaruiKasbon(Kasbon kasbon) =>
      _perbarui('kasbon', kasbon.keMap(), kasbon.id);

  // ── Kas keluar ───────────────────────────────────────────────────

  /// Simpan catatan kas keluar baru.
  Future<void> simpanKasKeluar(KasKeluar kasKeluar) =>
      _simpan('kas_keluar', kasKeluar.keMap());

  /// Daftar kas keluar; saring [idShift] bila diisi. Terbaru dulu.
  Future<List<KasKeluar>> daftarKasKeluar({String? idShift}) async {
    final db = await this.db;
    final baris = await db.query(
      'kas_keluar',
      where: idShift == null
          ? 'apakah_dihapus = 0'
          : 'apakah_dihapus = 0 AND id_shift = ?',
      whereArgs: idShift == null ? null : [idShift],
      orderBy: 'terjadi_pada DESC',
    );
    return baris.map(KasKeluar.dariMap).toList();
  }

  /// Perbarui catatan kas keluar.
  Future<void> perbaruiKasKeluar(KasKeluar kasKeluar) =>
      _perbarui('kas_keluar', kasKeluar.keMap(), kasKeluar.id);

  // ── Audit (append-only) ──────────────────────────────────────────

  /// Catat satu baris log audit. Hanya INSERT — tanpa update/delete.
  Future<void> catatAudit(LogAudit log) async {
    final db = await this.db;
    await db.insert('log_audit', log.keMap());
  }

  // ── Antrean sinkron ──────────────────────────────────────────────

  /// Tandai baris sudah tersinkron ke Supabase.
  Future<void> tandaiTersinkron(String namaTabel, String id) async {
    final db = await this.db;
    await db.update(
      namaTabel,
      {'status_sinkron': 'tersinkron'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Tandai baris gagal tersinkron.
  Future<void> tandaiGagal(String namaTabel, String id) async {
    final db = await this.db;
    await db.update(
      namaTabel,
      {'status_sinkron': 'gagal'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Daftar baris yang menunggu sinkron (mentah, untuk diunggah).
  Future<List<Map<String, Object?>>> daftarTertunda(String namaTabel) async {
    final db = await this.db;
    // Sengaja TIDAK memfilter apakah_dihapus: baris yang dihapus lunak pun
    // harus terunggah agar penghapusan tersinkron ke Supabase.
    return db.query(
      namaTabel,
      where: "status_sinkron = 'tertunda'",
    );
  }
}

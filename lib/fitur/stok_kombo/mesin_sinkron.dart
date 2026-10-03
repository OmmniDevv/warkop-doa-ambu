import 'package:flutter/foundation.dart';
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

/// Info unduh akun terakhir — untuk banner "Terakhir sinkron" di UI.
class InfoUnduhAkun {
  const InfoUnduhAkun({
    required this.waktu,
    required this.jumlah,
    required this.gagalBeruntun,
  });

  /// Waktu UTC unduh terakhir yang berhasil.
  final DateTime waktu;

  /// Jumlah akun yang ditulis pada unduh terakhir.
  final int jumlah;

  /// Jumlah kegagalan beruntun sejak sukses terakhir (0 = sehat).
  final int gagalBeruntun;
}

/// Hasil unduh akun dari server.
///
/// Dipakai untuk logging, retry, dan tampilan status di layar Pilih Kasir.
class HasilUnduhAkun {
  const HasilUnduhAkun({
    required this.berhasil,
    required this.jumlahServer,
    required this.jumlahDiunduh,
    required this.jumlahDilewati,
    this.pesanGalat,
  });

  /// true jika koneksi ke server berhasil (walau 0 baris diunduh).
  final bool berhasil;

  /// Jumlah baris akun di server (apakah_dihapus = false).
  final int jumlahServer;

  /// Jumlah baris yang benar-benar ditulis ke SQLite.
  final int jumlahDiunduh;

  /// Jumlah baris dilewati (perubahan lokal 'tertunda' / data tidak valid).
  final int jumlahDilewati;

  /// Pesan galat bila [berhasil] false.
  final String? pesanGalat;
}

/// Hasil unduh satu tabel generik (untuk logging).
class HasilUnduhTabel {
  const HasilUnduhTabel({
    required this.tabel,
    required this.jumlahServer,
    required this.jumlahDiunduh,
    required this.jumlahDilewati,
  });

  final String tabel;
  final int jumlahServer;
  final int jumlahDiunduh;
  final int jumlahDilewati;
}

/// Konfigurasi unduh per tabel: kolom waktu untuk last-write-wins dan
/// apakah tabel punya kolom `apakah_dihapus`.
class _KonfigUnduh {
  const _KonfigUnduh({required this.kolomWaktu, required this.punyaHapus});

  final String kolomWaktu;
  final bool punyaHapus;
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

  /// Kunci info unduh akun di SharedPreferences — dipakai layar Pilih Kasir
  /// untuk menampilkan "Terakhir sinkron: ..." agar user tahu datanya fresh.
  static const String kunciAkunUnduhTerakhir = 'wda_akun_unduh_terakhir';
  static const String kunciAkunUnduhJumlah = 'wda_akun_unduh_jumlah';
  static const String kunciAkunUnduhGagalBeruntun =
      'wda_akun_unduh_gagal_beruntun';

  /// Tabel yang ikut UNDUH dari server → SQLite (sinkron dua arah).
  ///
  /// 'akun' ditangani khusus via [unduhAkun] (validasi lebih keras).
  /// 'stok_opname' & 'pesanan_bayar' tidak punya `diperbarui_pada` /
  /// `apakah_dihapus` — hanya ditambah bila id belum ada lokal.
  static const Map<String, _KonfigUnduh> _tabelUnduh = {
    'kategori_menu': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'menu': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'paket_kombo': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'paket_kombo_rincian':
        _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'open_bill': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'shift_kasir': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'pesanan': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'pesanan_rincian':
        _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'pesanan_bayar': _KonfigUnduh(kolomWaktu: 'dibuat_pada', punyaHapus: false),
    'bahan': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'resep': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: false),
    'stok_opname': _KonfigUnduh(kolomWaktu: 'dibuat_pada', punyaHapus: false),
    'kasbon': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'kas_keluar': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
    'pemilik': _KonfigUnduh(kolomWaktu: 'diperbarui_pada', punyaHapus: true),
  };

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
      // Hasilnya di-log + disimpan; gagal = dicoba lagi putaran berikutnya.
      final hasilUnduh = await unduhAkun(client);
      if (!hasilUnduh.berhasil) {
        debugPrint(
            '[Sinkron] unduh akun gagal: ${hasilUnduh.pesanGalat}');
      }

      // Unduh dua arah untuk SEMUA tabel operasional: Supabase dan SQLite
      // harus SAMA. Last-write-wins via kolom waktu; baris lokal 'tertunda'
      // tidak pernah ditimpa.
      for (final entri in _tabelUnduh.entries) {
        final hasil = await _unduhTabel(client, entri.key, entri.value);
        if (hasil.jumlahDiunduh > 0) {
          debugPrint(
              '[Sinkron] ${hasil.tabel}: +${hasil.jumlahDiunduh} dari server');
        }
      }

      return HasilSinkron(berhasil: berhasil, gagal: gagal);
    } catch (_) {
      return const HasilSinkron();
    }
  }

  /// Mengunduh daftar akun dari Supabase ke SQLite lokal.
  ///
  /// PENGAMANAN BERLAPIS (anti akun hilang setelah reinstall):
  /// 1. Validasi kolom kritikal (id, nama, peran; pin_hash wajib untuk kasir)
  ///    — baris tidak valid dilewati dan dihitung, bukan ditulis rusak.
  /// 2. Baris lokal berstatus 'tertunda' (perubahan belum terunggah) TIDAK
  ///    ditimpa — perubahan lokal menang.
  /// 3. Hasil (jumlah server / diunduh / dilewati / galat) di-log via
  ///    debugPrint dan disimpan ke SharedPreferences.
  /// 4. Gagal = catat gagal-beruntun; putaran sinkron berikutnya OTOMATIS
  ///    mencoba lagi (tidak diam-diam gagal selamanya).
  ///
  /// Mengembalikan [HasilUnduhAkun]. Tidak pernah throw.
  Future<HasilUnduhAkun> unduhAkun(SupabaseClient client) async {
    const tag = '[UnduhAkun]';
    try {
      final db = DatabaseLokal.instance;
      final remote = await client
          .from('akun')
          .select()
          .eq('apakah_dihapus', false);

      final daftar = (remote as List).cast<Map<String, dynamic>>();
      debugPrint('$tag server punya ${daftar.length} akun aktif');

      final dbBuka = await db.db;
      var diunduh = 0;
      var dilewati = 0;

      for (final baris in daftar) {
        final peta = Map<String, Object?>.from(baris);

        // Validasi kolom kritikal sebelum ditulis.
        final barisLokal = petakanBarisAkun(peta);
        if (barisLokal == null) {
          dilewati++;
          debugPrint('$tag LEWATI baris tidak valid: id=${peta['id']}');
          continue;
        }
        final id = barisLokal['id'] as String;

        // Jangan timpa perubahan lokal yang belum terunggah.
        final lokal = await dbBuka.query(
          'akun',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (lokal.isNotEmpty &&
            lokal.first['status_sinkron'] == 'tertunda') {
          dilewati++;
          continue;
        }

        await dbBuka.insert(
          'akun',
          barisLokal,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        diunduh++;
      }

      debugPrint(
          '$tag selesai: server=${daftar.length} diunduh=$diunduh '
          'dilewati=$dilewati');

      // Peringatan keras: server punya data tapi tidak ada yang masuk.
      // Ini gejala bug "akun hilang" — jangan dibiarkan diam.
      if (daftar.isNotEmpty && diunduh == 0 && dilewati == daftar.length) {
        debugPrint(
            '$tag PERINGATAN: ${daftar.length} akun di server, '
            'semuanya dilewati! Cek validasi / status tertunda.');
      }

      await _catatUnduhAkun(berhasil: true, jumlah: diunduh);
      return HasilUnduhAkun(
        berhasil: true,
        jumlahServer: daftar.length,
        jumlahDiunduh: diunduh,
        jumlahDilewati: dilewati,
      );
    } catch (e) {
      debugPrint('$tag GAGAL: $e — dicoba lagi putaran berikutnya');
      await _catatUnduhAkun(berhasil: false, jumlah: 0);
      return HasilUnduhAkun(
        berhasil: false,
        jumlahServer: 0,
        jumlahDiunduh: 0,
        jumlahDilewati: 0,
        pesanGalat: e.toString(),
      );
    }
  }

  /// Unduh generik satu tabel dari Supabase → SQLite.
  ///
  /// Strategi konflik LAST-WRITE-WINS:
  /// - Baris lokal `status_sinkron = 'tertunda'` → TIDAK ditimpa.
  /// - Remote lebih baru (kolom waktu) → replace lokal.
  /// - Lokal lebih baru / sama → lewati.
  /// - Tabel tanpa kolom waktu update (pesanan_bayar, stok_opname):
  ///   hanya insert bila id belum ada lokal.
  ///
  /// Boolean Supabase (true/false) dikonversi ke SQLite (1/0) memakai
  /// [_kolomBoolean]. Tidak pernah throw.
  Future<HasilUnduhTabel> _unduhTabel(
    SupabaseClient client,
    String tabel,
    _KonfigUnduh konfig,
  ) async {
    try {
      final query = client.from(tabel).select();
      final remote = konfig.punyaHapus
          ? await query.eq('apakah_dihapus', false)
          : await query;
      final daftar = (remote as List).cast<Map<String, dynamic>>();

      final dbBuka = await DatabaseLokal.instance.db;
      final kolomBool = _kolomBoolean[tabel] ?? const <String>{};
      var diunduh = 0;
      var dilewati = 0;

      for (final baris in daftar) {
        final peta = Map<String, Object?>.from(baris);
        final id = peta['id'] as String?;
        if (id == null || id.isEmpty) {
          dilewati++;
          continue;
        }

        final lokal = await dbBuka.query(
          tabel,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (lokal.isNotEmpty) {
          // Jangan timpa perubahan lokal yang belum terunggah.
          if (lokal.first['status_sinkron'] == 'tertunda') {
            dilewati++;
            continue;
          }
          // Last-write-wins: bandingkan kolom waktu (string ISO8601 UTC —
          // perbandingan leksikografis valid untuk format yang sama).
          if (konfig.kolomWaktu == 'diperbarui_pada') {
            final waktuRemote = peta['diperbarui_pada'] as String? ?? '';
            final waktuLokal =
                lokal.first['diperbarui_pada'] as String? ?? '';
            if (waktuRemote.compareTo(waktuLokal) <= 0) {
              dilewati++;
              continue;
            }
          } else {
            // Tanpa kolom update → jangan timpa yang sudah ada.
            dilewati++;
            continue;
          }
        }

        // Konversi boolean → 1/0, tandai tersinkron.
        final barisLokal = <String, Object?>{};
        for (final entri in peta.entries) {
          final nilai = entri.value;
          if (kolomBool.contains(entri.key) && nilai is bool) {
            barisLokal[entri.key] = nilai ? 1 : 0;
          } else {
            barisLokal[entri.key] = nilai;
          }
        }
        barisLokal['status_sinkron'] = 'tersinkron';

        await dbBuka.insert(
          tabel,
          barisLokal,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        diunduh++;
      }

      return HasilUnduhTabel(
        tabel: tabel,
        jumlahServer: daftar.length,
        jumlahDiunduh: diunduh,
        jumlahDilewati: dilewati,
      );
    } catch (e) {
      debugPrint('[Sinkron] unduh $tabel gagal: $e');
      return HasilUnduhTabel(
          tabel: tabel, jumlahServer: 0, jumlahDiunduh: 0, jumlahDilewati: 0);
    }
  }

  /// Validasi + pemetaan satu baris akun Supabase → baris SQLite.
  ///
  /// Mengembalikan null bila data tidak valid (kolom kritikal kosong).
  /// Dipisah sebagai fungsi murni agar bisa di-unit-test.
  ///
  /// Kolom kritikal:
  /// - id, nama, peran: wajib tidak kosong
  /// - pin_hash: wajib untuk peran 'kasir' (tanpa ini kasir tidak bisa login!)
  /// - aktif: boolean Supabase → 1/0 SQLite
  @visibleForTesting
  static Map<String, Object?>? petakanBarisAkun(
      Map<String, Object?> peta) {
    final id = peta['id'] as String?;
    final nama = peta['nama'] as String?;
    final peran = peta['peran'] as String?;
    if (id == null || id.isEmpty) return null;
    if (nama == null || nama.trim().isEmpty) return null;
    if (peran == null || peran.isEmpty) return null;

    // KRITIKAL: kasir tanpa pin_hash = tidak bisa login = "akun hilang".
    final pinHash = peta['pin_hash'] as String?;
    if (peran == 'kasir' && (pinHash == null || pinHash.isEmpty)) {
      return null;
    }

    return <String, Object?>{
      'id': id,
      'nama': nama,
      'pin_hash': pinHash,
      'peran': peran,
      'aktif': (peta['aktif'] as bool? ?? true) ? 1 : 0,
      'status_sinkron': 'tersinkron',
      'diperbarui_pada': peta['diperbarui_pada'] ??
          peta['diperbaruiPada'] ??
          DateTime.now().toUtc().toIso8601String(),
      'apakah_dihapus': (peta['apakah_dihapus'] as bool? ?? false) ? 1 : 0,
    };
  }

  /// Catat hasil unduh akun ke SharedPreferences.
  ///
  /// Sukses → simpan timestamp + jumlah, reset gagal-beruntun ke 0.
  /// Gagal → naikkan gagal-beruntun (putaran berikutnya tetap mencoba).
  Future<void> _catatUnduhAkun({
    required bool berhasil,
    required int jumlah,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (berhasil) {
        await prefs.setString(kunciAkunUnduhTerakhir,
            DateTime.now().toUtc().toIso8601String());
        await prefs.setInt(kunciAkunUnduhJumlah, jumlah);
        await prefs.setInt(kunciAkunUnduhGagalBeruntun, 0);
      } else {
        final gagal = prefs.getInt(kunciAkunUnduhGagalBeruntun) ?? 0;
        await prefs.setInt(kunciAkunUnduhGagalBeruntun, gagal + 1);
      }
    } catch (_) {
      // Penyimpanan status gagal — unduhnya sendiri tetap jalan.
    }
  }

  /// Baca info unduh akun terakhir untuk ditampilkan di UI.
  /// Mengembalikan null bila belum pernah berhasil mengunduh.
  static Future<InfoUnduhAkun?> bacaInfoUnduhAkun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final waktuIso = prefs.getString(kunciAkunUnduhTerakhir);
      if (waktuIso == null) return null;
      return InfoUnduhAkun(
        waktu: DateTime.parse(waktuIso),
        jumlah: prefs.getInt(kunciAkunUnduhJumlah) ?? 0,
        gagalBeruntun: prefs.getInt(kunciAkunUnduhGagalBeruntun) ?? 0,
      );
    } catch (_) {
      return null;
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

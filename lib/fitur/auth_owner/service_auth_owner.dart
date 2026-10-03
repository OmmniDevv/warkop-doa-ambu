import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/lokal/database_lokal.dart';
import '../../data/model/pemilik.dart';

/// Service keamanan & sesi akun Owner.
///
/// Tanggung jawab:
/// - Masuk + unduh profil ke SQLite lokal ([masuk]).
/// - Hashing Master PIN 6-digit dengan SHA-256 + salt + pepper
///   ([buatHashPin], [verifikasiPinMaster]).
/// - Otorisasi biometrik via `local_auth` ([aktifkanBiometrik]).
///
/// Catatan: pendaftaran akun owner dilakukan langsung di database oleh
/// admin (tidak ada alur registrasi di aplikasi).
///
/// Catatan keamanan: PIN tidak pernah disimpan sebagai teks polos —
/// yang tersimpan hanya hash SHA-256 dari `pepper + idPemilik + pin`.
class ServiceAuthOwner {
  ServiceAuthOwner({
    SupabaseClient? klien,
    DatabaseLokal? basisData,
    LocalAuthentication? authLokal,
  })  : _klien = klien ?? Supabase.instance.client,
        _db = basisData ?? DatabaseLokal.instance,
        _authLokal = authLokal ?? LocalAuthentication();

  final SupabaseClient _klien;
  final DatabaseLokal _db;
  final LocalAuthentication _authLokal;

  /// Pepper aplikasi — lapisan tambahan di atas salt per-pemilik.
  /// Bukan rahasia mutlak, tapi mempersulit serangan rainbow table generik.
  static const _pepper = 'wda::doa-ambu::pin-master';

  // ── Masuk ────────────────────────────────────────────────────

  /// Masuk dengan email + kata sandi, lalu unduh profil ke SQLite lokal.
  ///
  /// Mengembalikan record `(ok, galat)`: `ok` true jika profil berhasil
  /// dimuat ke perangkat; `galat` berisi pesan yang bisa ditampilkan ke
  /// pengguna saat gagal (tidak lagi menelan seluruh error).
  Future<({bool ok, String? galat})> masuk({
    required String email,
    required String kataSandi,
  }) async {
    try {
      final respons = await _klien.auth.signInWithPassword(
        email: email.trim(),
        password: kataSandi,
      );
      final pengguna = respons.user;
      if (pengguna == null) {
        return (ok: false, galat: 'Sesi tidak terbentuk. Coba lagi.');
      }

      final baris = await _klien
          .from('pemilik')
          .select()
          .eq('id', pengguna.id)
          .maybeSingle();

      if (baris == null) {
        // Profil cloud belum ada — buat dari metadata auth.
        final meta = pengguna.userMetadata ?? {};
        await _simpanProfil(
          id: pengguna.id,
          namaPemilik: (meta['nama_pemilik'] as String?) ?? 'Pemilik',
          namaWarkop:
              (meta['nama_warkop'] as String?) ?? 'WARKOP DOA AMBU',
          email: pengguna.email ?? email.trim(),
          nomorKontak: null,
        );
      } else {
        await _db.simpanPemilik(
          Pemilik(
            id: baris['id'] as String,
            namaPemilik: baris['nama_pemilik'] as String,
            namaWarkop: (baris['nama_warkop'] as String?) ?? 'WARKOP DOA AMBU',
            email: baris['email'] as String,
            nomorKontak: baris['nomor_kontak'] as String?,
            hashPinMaster: (baris['hash_pin_master'] as String?) ?? '',
            apakahBiometrikAktif:
                (baris['apakah_biometrik_aktif'] as bool?) ?? false,
            dibuatPada: DateTime.parse(baris['dibuat_pada'] as String),
          ),
        );
      }
      return (ok: true, galat: null);
    } catch (e) {
      return (ok: false, galat: _pesanGalatMasuk(e));
    }
  }

  /// Ubah error teknis saat masuk menjadi pesan Bahasa Indonesia yang
  /// bisa dipahami — tapi tetap tampilkan inti pesannya agar mudah
  /// didiagnosis bila terjadi masalah konfigurasi/jaringan.
  String _pesanGalatMasuk(Object e) {
    final teks = e.toString();
    final rendah = teks.toLowerCase();
    if (rendah.contains('invalid login credentials') ||
        rendah.contains('invalid_credentials')) {
      return 'Email atau kata sandi salah. Periksa lagi.';
    }
    if (rendah.contains('failed host lookup') ||
        rendah.contains('socketexception') ||
        rendah.contains('connection refused') ||
        rendah.contains('network is unreachable') ||
        rendah.contains('connection timed out')) {
      return 'Tidak dapat menghubungi server. Periksa koneksi internet HP.';
    }
    if (rendah.contains('invalid api key') || rendah.contains('api key')) {
      return 'Konfigurasi server aplikasi bermasalah (API key tidak valid).';
    }
    final ringkas = teks.length > 180 ? '${teks.substring(0, 180)}…' : teks;
    return 'Gagal masuk: $ringkas';
  }

  Future<void> _simpanProfil({
    required String id,
    required String namaPemilik,
    required String namaWarkop,
    required String email,
    String? nomorKontak,
  }) async {
    final sekarang = DateTime.now().toUtc();

    // Cerminkan profil ke Supabase (abaikan jika RLS/offline menolak —
    // profil lokal tetap menjadi sumber kebenaran perangkat ini).
    try {
      await _klien.from('pemilik').upsert({
        'id': id,
        'nama_pemilik': namaPemilik,
        'nama_warkop': namaWarkop,
        'email': email,
        'nomor_kontak': nomorKontak,
        'hash_pin_master': '',
        'apakah_biometrik_aktif': false,
        'dibuat_pada': sekarang.toIso8601String(),
        'status_sinkron': 'tersinkron',
      });
    } catch (_) {
      // Sync menyusul via sync engine; lanjutkan offline.
    }

    await _db.simpanPemilik(
      Pemilik(
        id: id,
        namaPemilik: namaPemilik,
        namaWarkop: namaWarkop,
        email: email,
        nomorKontak: nomorKontak,
        hashPinMaster: '',
        dibuatPada: sekarang,
      ),
    );
  }

  // ── Master PIN ───────────────────────────────────────────────────

  /// Buat hash SHA-256 dari PIN: `SHA256(pepper + idPemilik + pin)`.
  ///
  /// Salt = id unik pemilik (UUID dari Supabase) sehingga dua pemilik
  /// dengan PIN sama menghasilkan hash berbeda.
  String buatHashPin({required String idPemilik, required String pin}) {
    final bahan = utf8.encode('$_pepper::$idPemilik::$pin');
    return sha256.convert(bahan).toString();
  }

  /// Simpan Master PIN baru (di-hash) untuk pemilik.
  Future<void> simpanPinMaster({
    required String idPemilik,
    required String pin,
  }) async {
    final hash = buatHashPin(idPemilik: idPemilik, pin: pin);
    await _db.perbaruiPinMaster(idPemilik, hash);
    try {
      await _klien.from('pemilik').update({
        'hash_pin_master': hash,
        'diperbarui_pada': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', idPemilik);
    } catch (_) {
      // Antrekan sinkronisasi menangani sisanya.
    }
  }

  /// Verifikasi PIN master — dipakai untuk otorisasi void & area sensitif.
  Future<bool> verifikasiPinMaster(String pin) async {
    final pemilik = await _db.ambilPemilik();
    if (pemilik == null || pemilik.hashPinMaster.isEmpty) return false;
    final hash = buatHashPin(idPemilik: pemilik.id, pin: pin);
    return _kunciWaktuKonstan(hash, pemilik.hashPinMaster);
  }

  /// Perbandingan string tahan-timing-attack sederhana.
  bool _kunciWaktuKonstan(String a, String b) {
    if (a.length != b.length) return false;
    var beda = 0;
    for (var i = 0; i < a.length; i++) {
      beda |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return beda == 0;
  }

  // ── Biometrik ────────────────────────────────────────────────────

  /// Cek apakah perangkat mendukung biometrik.
  Future<bool> perangkatMendukungBiometrik() async {
    try {
      final dapatDicek = await _authLokal.canCheckBiometrics;
      final perangkatDidukung = await _authLokal.isDeviceSupported();
      return dapatDicek && perangkatDidukung;
    } catch (_) {
      return false;
    }
  }

  /// Minta otentikasi biometrik pertama kali & simpan preferensinya.
  ///
  /// Mengembalikan `true` jika biometrik berhasil diaktifkan.
  Future<bool> aktifkanBiometrik() async {
    try {
      final berhasil = await _authLokal.authenticate(
        localizedReason: 'Aktifkan masuk cepat Warkop Doa Ambu',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!berhasil) return false;
      final pemilik = await _db.ambilPemilik();
      if (pemilik != null) {
        await _db.perbaruiBiometrik(pemilik.id, true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Keluar: hapus sesi Supabase & data lokal perangkat.
  Future<void> keluar() async {
    try {
      await _klien.auth.signOut();
    } catch (_) {}
    await _db.bersihkan();
  }
}

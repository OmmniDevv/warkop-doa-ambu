import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Perangkat printer Bluetooth yang ditemukan saat pemindaian.
class PerangkatPrinter {
  const PerangkatPrinter({required this.id, required this.nama});

  /// Identifier unik perangkat (MAC address / remote id BLE).
  final String id;

  /// Nama tampil perangkat (dari iklan BLE atau nama platform).
  final String nama;
}

/// Error printer berbahasa Indonesia untuk ditampilkan ke pengguna.
///
/// Seluruh kegagalan BLE dibungkus menjadi [PesanPrinter] sehingga UI
/// cukup menangkap tipe ini dan menampilkan [pesan]-nya.
class PesanPrinter implements Exception {
  const PesanPrinter(this.pesan);

  final String pesan;

  @override
  String toString() => 'PesanPrinter: $pesan';
}

/// Kontrak layanan cetak nota ke printer thermal Bluetooth.
abstract class LayananPrinter {
  /// Pindai perangkat sekitar; emit daftar perangkat setiap ada temuan.
  ///
  /// Perangkat yang namanya mengandung 'printer'/'thermal'/'POS'
  /// diprioritaskan; bila tidak ada yang cocok, seluruh perangkat
  /// yang ditemukan tetap ditampilkan.
  Stream<List<PerangkatPrinter>> pindai();

  /// Hubungkan ke [perangkat] hasil [pindai].
  Future<void> hubungkan(PerangkatPrinter perangkat);

  /// Cetak [teks] nota polos lalu potong kertas (ESC/POS: GS V 0).
  Future<void> cetakTeks(String teks);

  /// Putuskan koneksi (aman dipanggil walau belum terhubung).
  Future<void> putuskan();

  /// Status koneksi; UI memakai `StreamBuilder(initialData: false)`.
  Stream<bool> get terhubung;
}

/// Implementasi [LayananPrinter] memakai `flutter_blue_plus` (BLE asli).
///
/// Dipilih implementasi BLE asli (bukan mock) karena seluruh API
/// `flutter_blue_plus` 1.36.x yang dipakai sudah terverifikasi ada:
/// pindai via [FlutterBluePlus.scanResults], hubung via
/// `device.connect()`, tulis via `characteristic.write()`, dan pantau
/// koneksi via `device.connectionState`. Teks dikirim per potongan
/// 180 byte agar muat dalam MTU BLE.
class PrinterBluetooth implements LayananPrinter {
  PrinterBluetooth()
      : _pengendaliTerhubung = StreamController<bool>.broadcast();

  final StreamController<bool> _pengendaliTerhubung;
  StreamSubscription<BluetoothConnectionState>? _langgananKoneksi;
  BluetoothDevice? _perangkat;

  static const _kataKunciPrinter = ['printer', 'thermal', 'pos'];

  @override
  Stream<bool> get terhubung => _pengendaliTerhubung.stream;

  @override
  Stream<List<PerangkatPrinter>> pindai() async* {
    try {
      if (!await FlutterBluePlus.isSupported) {
        throw const PesanPrinter(
          'Bluetooth tidak didukung di perangkat ini.',
        );
      }
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
      );

      final unik = <String, PerangkatPrinter>{};
      await for (final hasil in FlutterBluePlus.scanResults) {
        for (final temuan in hasil) {
          final perangkat = PerangkatPrinter(
            id: temuan.device.remoteId.str,
            nama: _namaPerangkat(temuan),
          );
          unik[perangkat.id] = perangkat;
        }
        yield _saringPrinter(unik.values.toList());
        if (!FlutterBluePlus.isScanningNow) break;
      }
    } on PesanPrinter {
      rethrow;
    } catch (e) {
      throw PesanPrinter('Gagal memindai printer: $e');
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Abaikan — pemindaian memang sudah berhenti.
      }
    }
  }

  @override
  Future<void> hubungkan(PerangkatPrinter perangkat) async {
    try {
      await putuskan();

      final cocok = FlutterBluePlus.lastScanResults.where(
        (r) => r.device.remoteId.str == perangkat.id,
      );
      if (cocok.isEmpty) {
        throw const PesanPrinter(
          'Perangkat tidak ditemukan. Pindai ulang dulu ya.',
        );
      }

      final device = cocok.first.device;
      await device.connect(timeout: const Duration(seconds: 15));
      _perangkat = device;
      _pantauKoneksi(device);
      _kirimStatus(true);
    } on PesanPrinter {
      rethrow;
    } catch (e) {
      throw PesanPrinter('Gagal menghubungkan printer: $e');
    }
  }

  @override
  Future<void> cetakTeks(String teks) async {
    final device = _perangkat;
    if (device == null) {
      throw const PesanPrinter(
        'Belum terhubung ke printer. Hubungkan dulu ya.',
      );
    }
    try {
      final karakteristik = await _cariKarakteristikTulis(device);
      final tanpaRespons = karakteristik.properties.writeWithoutResponse;

      final byte = utf8.encode(teks);
      const ukuranPotongan = 180;
      for (var i = 0; i < byte.length; i += ukuranPotongan) {
        final akhir = i + ukuranPotongan < byte.length
            ? i + ukuranPotongan
            : byte.length;
        await karakteristik.write(
          byte.sublist(i, akhir),
          withoutResponse: tanpaRespons,
        );
      }
      // Potong kertas ESC/POS: GS V 0.
      await karakteristik.write(
        const [0x1D, 0x56, 0x00],
        withoutResponse: tanpaRespons,
      );
    } on PesanPrinter {
      rethrow;
    } catch (e) {
      throw PesanPrinter('Gagal mencetak nota: $e');
    }
  }

  @override
  Future<void> putuskan() async {
    await _langgananKoneksi?.cancel();
    _langgananKoneksi = null;
    final device = _perangkat;
    _perangkat = null;
    try {
      await device?.disconnect();
    } catch (_) {
      // Abaikan — koneksi memang sudah putus.
    }
    _kirimStatus(false);
  }

  /// Bebaskan resource BLE. Panggil saat layar/sheet pemilik ditutup.
  Future<void> buang() async {
    await putuskan();
    await _pengendaliTerhubung.close();
  }

  // ── Internal ─────────────────────────────────────────────────────

  void _kirimStatus(bool tersambung) {
    if (!_pengendaliTerhubung.isClosed) {
      _pengendaliTerhubung.add(tersambung);
    }
  }

  void _pantauKoneksi(BluetoothDevice device) {
    _langgananKoneksi?.cancel();
    _langgananKoneksi = device.connectionState.listen((status) {
      final tersambung = status == BluetoothConnectionState.connected;
      if (!tersambung && identical(_perangkat, device)) {
        _perangkat = null;
      }
      _kirimStatus(tersambung);
    });
  }

  Future<BluetoothCharacteristic> _cariKarakteristikTulis(
    BluetoothDevice device,
  ) async {
    final daftarLayanan = await device.discoverServices();
    for (final layanan in daftarLayanan) {
      for (final karakteristik in layanan.characteristics) {
        if (karakteristik.properties.writeWithoutResponse ||
            karakteristik.properties.write) {
          return karakteristik;
        }
      }
    }
    throw const PesanPrinter('Karakteristik tulis tidak ditemukan.');
  }

  String _namaPerangkat(ScanResult temuan) {
    final iklan = temuan.advertisementData.advName.trim();
    if (iklan.isNotEmpty) return iklan;
    final platform = temuan.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return 'Perangkat ${temuan.device.remoteId.str}';
  }

  List<PerangkatPrinter> _saringPrinter(List<PerangkatPrinter> semua) {
    final cocok = semua.where((p) {
      final nama = p.nama.toLowerCase();
      return _kataKunciPrinter.any(nama.contains);
    }).toList();
    return cocok.isNotEmpty ? cocok : semua;
  }
}

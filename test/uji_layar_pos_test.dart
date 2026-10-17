import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warkop_doa_ambu/app/tema/tema_app.dart';
import 'package:warkop_doa_ambu/bersama/widget/tombol_warkop.dart';
import 'package:warkop_doa_ambu/data/model/akun.dart';
import 'package:warkop_doa_ambu/data/model/kategori_menu.dart';
import 'package:warkop_doa_ambu/data/model/menu.dart';
import 'package:warkop_doa_ambu/data/model/paket_kombo.dart';
import 'package:warkop_doa_ambu/fitur/kasir/penyedia_kasir.dart';
import 'package:warkop_doa_ambu/fitur/pos/penyedia_keranjang.dart';
import 'package:warkop_doa_ambu/fitur/pos/layar_pos.dart';
import 'package:warkop_doa_ambu/fitur/stok_kombo/penyedia_sinkron.dart';

/// Widget test layar kasir POS (pilot redesign).
///
/// Memakai provider fake via ProviderScope overrides — tidak menyentuh
/// database asli. Diuji di 4 lebar layar, 2 tema, 2 skala teks.

final _sekarang = DateTime(2026, 10, 17);

Akun _akunKasirUji() => Akun(
      id: 'akun-uji-1',
      nama: 'Kasir Uji',
      peran: 'kasir',
      diperbaruiPada: _sekarang,
    );

List<KategoriMenu> _kategoriUji() => [
      KategoriMenu(
          id: 'kat-kopi', nama: 'Kopi', urutanTampil: 1, diperbaruiPada: _sekarang),
      KategoriMenu(
          id: 'kat-teh', nama: 'Teh', urutanTampil: 2, diperbaruiPada: _sekarang),
    ];

List<Menu> _menuUji() => [
      Menu(
        id: 'menu-1',
        idKategori: 'kat-kopi',
        nama: 'Kopi Tubruk',
        hargaSatuan: 8000,
        stok: 50,
        stokMinimum: 5,
        fotoUrl: '/tidak/ada/foto.jpg', // ada foto (fallback ke placeholder)
        diperbaruiPada: _sekarang,
      ),
      Menu(
        id: 'menu-2',
        idKategori: 'kat-teh',
        nama: 'Es Teh Manis',
        hargaSatuan: 5000,
        stok: 30,
        stokMinimum: 5,
        diperbaruiPada: _sekarang,
      ),
      Menu(
        id: 'menu-3',
        idKategori: 'kat-kopi',
        nama: 'Kopi Susu Gula Aren',
        hargaSatuan: 12000,
        stok: 2, // menipis (<= stokMinimum)
        stokMinimum: 5,
        diperbaruiPada: _sekarang,
      ),
      Menu(
        id: 'menu-4',
        idKategori: 'kat-teh',
        nama: 'Teh Hangat',
        hargaSatuan: 4000,
        stok: 0, // habis
        stokMinimum: 5,
        diperbaruiPada: _sekarang,
      ),
    ];

List<PaketKombo> _paketUji() => [
      PaketKombo(
        id: 'paket-1',
        nama: 'Paket Nongkrong',
        hargaPaket: 15000,
        diperbaruiPada: _sekarang,
      ),
    ];

/// Notifier uji untuk sesi kasir.
class _SesiKasirUji extends PenampungSesiKasir {
  _SesiKasirUji(this._akun);
  final Akun _akun;
  @override
  Akun? build() => _akun;
}

/// Notifier uji untuk status sinkron.
class _StatusSinkronUji extends NotifikasiStatusSinkron {
  _StatusSinkronUji(this._status);
  final String _status;
  @override
  String build() => _status;
}

Future<void> _pumpPos(
  WidgetTester tester, {
  List<KategoriMenu>? kategori,
  List<Menu>? menu,
  List<PaketKombo>? paket,
  Object? galatMenu,
  bool gelap = false,
  double lebar = 360,
  double skalaTeks = 1.0,
  String statusSinkron = 'Tersinkron',
  int antreSinkron = 0,
}) async {
  tester.view.physicalSize = Size(lebar, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = skalaTeks;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesiKasirProvider.overrideWith(() => _SesiKasirUji(_akunKasirUji())),
        penyediaKategoriPos
            .overrideWith((ref) => Future.value(kategori ?? _kategoriUji())),
        if (galatMenu != null)
          penyediaMenuPos.overrideWith((ref) => Future.error(galatMenu))
        else
          penyediaMenuPos.overrideWith((ref) => Future.value(menu ?? _menuUji())),
        penyediaPaketPos.overrideWith((ref) => Future.value(paket ?? _paketUji())),
        penyediaStatusSinkron.overrideWith(() => _StatusSinkronUji(statusSinkron)),
        penyediaAntreSinkronPos.overrideWith((ref) => Future.value(antreSinkron)),
        penyediaKeranjang.overrideWith(NotifikasiKeranjang.new),
      ],
      child: MaterialApp(
        theme: bangunTema(gelap: false),
        darkTheme: bangunTema(gelap: true),
        themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
        home: const LayarPos(),
      ),
    ),
  );
  // Dua pump: satu untuk future selesai, satu untuk rebuild.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('LayarPos — render dasar', () {
    testWidgets('tampil header, kategori, dan grid menu (360dp terang)',
        (tester) async {
      await _pumpPos(tester);

      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Kasir Uji'), findsOneWidget);
      expect(find.text('Tersinkron'), findsOneWidget);
      // Chip kategori
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Kombo'), findsOneWidget);
      expect(find.text('Kopi'), findsOneWidget);
      expect(find.text('Teh'), findsOneWidget);
      // Menu
      expect(find.text('Kopi Tubruk'), findsOneWidget);
      expect(find.text('Es Teh Manis'), findsOneWidget);
      expect(find.text('Kopi Susu Gula Aren'), findsOneWidget);
      expect(find.text('Teh Hangat'), findsOneWidget);
      // Harga
      expect(find.text('Rp8.000'), findsOneWidget);
      // Badge stok
      expect(find.text('Menipis'), findsOneWidget);
      expect(find.text('Habis'), findsOneWidget);
      // Tidak ada overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('tema gelap tampil benar', (tester) async {
      await _pumpPos(tester, gelap: true);

      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Kopi Tubruk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final lebar in [320.0, 412.0, 768.0]) {
      testWidgets('tidak overflow di lebar ${lebar.toInt()}dp',
          (tester) async {
        await _pumpPos(tester, lebar: lebar);

        expect(find.text('Kopi Tubruk'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tidak overflow di skala teks 1.5', (tester) async {
      await _pumpPos(tester, skalaTeks: 1.5);

      expect(find.text('Kopi Tubruk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LayarPos — states', () {
    testWidgets('loading saat data dimuat', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sesiKasirProvider.overrideWith(() => _SesiKasirUji(_akunKasirUji())),
            // Future yang tidak pernah selesai = loading terus.
            penyediaKategoriPos.overrideWith((ref) => Completer<List<KategoriMenu>>().future),
            penyediaMenuPos.overrideWith((ref) => Completer<List<Menu>>().future),
            penyediaPaketPos.overrideWith((ref) => Completer<List<PaketKombo>>().future),
            penyediaStatusSinkron.overrideWith(() => _StatusSinkronUji('Tersinkron')),
            penyediaAntreSinkronPos.overrideWith((ref) => Future.value(0)),
            penyediaKeranjang.overrideWith(NotifikasiKeranjang.new),
          ],
          child: MaterialApp(
            theme: bangunTema(gelap: false),
            home: const LayarPos(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty saat menu kosong', (tester) async {
      await _pumpPos(tester, menu: []);

      expect(find.text('Belum ada menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error + tombol coba lagi saat gagal muat', (tester) async {
      await _pumpPos(tester, galatMenu: Exception('db rusak'));

      // StatusError menampilkan pesan + tombol
      expect(find.textContaining('Gagal memuat'), findsOneWidget);
      expect(find.widgetWithText(TombolWarkop, 'Coba lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('indikator sinkron antre menampilkan angka', (tester) async {
      await _pumpPos(tester, statusSinkron: 'Menyinkronkan...', antreSinkron: 7);

      expect(find.text('Antre 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('indikator sinkron gagal', (tester) async {
      await _pumpPos(tester, statusSinkron: 'Offline');

      expect(find.text('Gagal sinkron'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LayarPos — keranjang & nota', () {
    testWidgets('ketuk menu memunculkan bilah keranjang dengan total',
        (tester) async {
      await _pumpPos(tester);

      // Bilah keranjang belum ada saat kosong.
      expect(find.textContaining('Keranjang'), findsNothing);

      // Ketuk kartu Kopi Tubruk (Rp8.000).
      await tester.tap(find.text('Kopi Tubruk'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Keranjang'), findsOneWidget);
      expect(find.text('Rp8.000'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bilah keranjang membuka lembar nota + tombol bayar 52dp',
        (tester) async {
      await _pumpPos(tester);

      await tester.tap(find.text('Kopi Tubruk'));
      await tester.pump(const Duration(milliseconds: 200));

      // Buka nota.
      await tester.tap(find.text('Nota'));
      await tester.pump(const Duration(milliseconds: 300));

      // Total menonjol di lembar nota.
      expect(find.text('Rp8.000'), findsWidgets);
      // Tombol bayar ada dan tingginya 52dp (>= 48dp).
      final tombolBayar =
          find.widgetWithText(TombolWarkop, 'Bayar');
      expect(tombolBayar, findsOneWidget);
      final ukuran = tester.getSize(tombolBayar);
      expect(ukuran.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu stok habis tidak bisa diketuk', (tester) async {
      await _pumpPos(tester);

      await tester.tap(find.text('Teh Hangat'));
      await tester.pump(const Duration(milliseconds: 200));

      // Keranjang tetap kosong — bilah tidak muncul.
      expect(find.textContaining('Keranjang'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

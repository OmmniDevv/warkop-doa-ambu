import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// ID unik UUID v4 untuk baris baru (kolom `id` semua tabel).
String idBaru() => _uuid.v4();

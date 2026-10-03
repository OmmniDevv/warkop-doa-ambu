# Skema Database — Warkop Doa Ambu

Seluruh nama memakai **Bahasa Indonesia**. Primary key **UUID v4**.
Setiap tabel (kecuali yang ditandai) memiliki kolom kontrol sinkronisasi:

| Kolom | Tipe | Keterangan |
|---|---|---|
| `status_sinkron` | text | `tertunda` / `tersinkron` / `gagal` |
| `diperbarui_pada` | timestamptz | UTC, default `now()` |
| `apakah_dihapus` | boolean | soft-delete, default `false` |

## Daftar tabel

### `akun`
Akun kasir & owner. Owner login via Supabase Auth (email); kasir via PIN lokal.
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| nama | text | nama tampilan |
| pin_hash | text | SHA-256 + salt (kasir); null untuk owner murni |
| peran | text | `owner` / `kasir` |
| aktif | boolean | default true |

### `kategori_menu`
| Kolom | Tipe |
|---|---|
| id | uuid PK |
| nama | text unique |
| urutan_tampil | integer |
| aktif | boolean |

### `menu`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| id_kategori | uuid FK → kategori_menu | |
| nama | text | |
| harga_satuan | integer | rupiah, tanpa desimal |
| stok | integer | porsi tersedia |
| stok_minimum | integer | ambang badge "stok menipis" |
| tersedia | boolean | |
| foto_url | text | nullable |

### `paket_kombo` / `paket_kombo_rincian`
| paket_kombo | id, nama, harga_paket integer, aktif boolean |
| paket_kombo_rincian | id, id_paket FK, id_menu FK, jumlah integer |

### `pesanan` (nota transaksi)
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| nomor_nota | text unique | format `WDA-YYYYMMDD-XXXX` |
| id_akun | uuid FK → akun | kasir pembuat |
| id_shift | uuid FK → shift_kasir | nullable |
| id_open_bill | uuid FK → open_bill | nullable |
| metode_bayar | text | `tunai` / `non_tunai` |
| status | text | `baru` / `lunas` / `void` |
| total | integer | rupiah |
| bayar | integer | nominal dibayar |
| kembalian | integer | |
| foto_bukti_lokal | text | path lokal HP |
| foto_bukti_remote | text | URL Supabase Storage |
| void_alasan | text | wajib saat void |
| void_disetujui_owner | boolean | default false |

### `pesanan_rincian`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| id_pesanan | uuid FK → pesanan | ON DELETE CASCADE |
| id_menu | uuid FK → menu | nullable (kombo) |
| id_paket | uuid FK → paket_kombo | nullable |
| nama_snapshot | text | nama saat transaksi |
| harga_snapshot | integer | harga saat transaksi |
| jumlah | integer | |
| subtotal | integer | |
| catatan | text | modifier/custom |

### `open_bill`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| label | text | "Meja 3" / nama pelanggan |
| status | text | `buka` / `tutup` |
| id_akun | uuid FK → akun | |

### `shift_kasir`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| id_akun | uuid FK → akun | |
| dibuka_pada | timestamptz | |
| ditutup_pada | timestamptz | nullable |
| saldo_awal | integer | modal laci |
| kas_akhir_sistem | integer | hitung otomatis |
| kas_akhir_fisik | integer | input kasir |
| selisih | integer | fisik − sistem |
| status | text | `buka` / `tutup` |

### `kasbon`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| nama_pelanggan | text | |
| nominal | integer | total hutang |
| sudah_bayar | integer | cicilan masuk |
| jatuh_tempo | date | nullable |
| status | text | `belum_lunas` / `lunas` |
| id_akun | uuid FK → akun | pencatat |

### `kas_keluar`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| id_akun | uuid FK → akun | |
| id_shift | uuid FK → shift_kasir | nullable |
| kategori | text | mis. `es_batu`, `gas`, `lainnya` |
| nominal | integer | |
| catatan | text | |
| terjadi_pada | timestamptz | |

### `log_audit`
Tanpa kolom sinkron (ditulis lokal lalu di-upload; tidak pernah diubah).
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| aksi | text | mis. `void_pesanan`, `tutup_shift`, `ubah_harga` |
| id_akun | uuid FK → akun | pelaku |
| id_referensi | uuid | id data terkait |
| detail | jsonb | sebelum/sesudah |
| alasan | text | wajib untuk aksi sensitif |
| dibuat_pada | timestamptz | |

## Storage

Bucket **`bukti-pembayaran`** (public read, authenticated write) untuk foto
bukti transfer QRIS/non-tunai yang dikompresi (±100–180 KB).

## Indeks

- `pesanan(diperbarui_pada)`, `pesanan(status_sinkron)`, `pesanan(nomor_nota)`
- `pesanan_rincian(id_pesanan)`, `menu(id_kategori)`, `log_audit(dibuat_pada)`
- Semua FK terindeks.

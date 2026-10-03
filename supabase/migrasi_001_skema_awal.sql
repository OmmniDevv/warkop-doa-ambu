-- =============================================================
-- Migrasi awal Warkop Doa Ambu — project qgvuyayoiutqvabjqfan
-- Seluruh nama berbahasa Indonesia. PK UUID v4.
-- Kolom kontrol sinkron: status_sinkron, diperbarui_pada, apakah_dihapus
-- RLS aktif di semua tabel.
-- Model akses: kasir autentikasi via PIN lokal (tanpa Supabase Auth),
--   sehingga tabel operasional diakses memakai anon key yang tertanam
--   di aplikasi (kebijakan: anon + authenticated boleh CRUD).
--   Tabel `pemilik` dikunci ketat: hanya owner terotentikasi yang
--   cocok auth.uid() dengan id barisnya.
--   `log_audit` hanya boleh INSERT (append-only), tanpa UPDATE/DELETE.
-- =============================================================

-- ---------- util: perbarui diperbarui_pada otomatis ----------
create or replace function public.sentuh_diperbarui_pada()
returns trigger
language plpgsql
as $$
begin
  new.diperbarui_pada = now();
  return new;
end;
$$;

-- =============================================================
-- TABEL
-- =============================================================

create table public.akun (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  pin_hash text,
  peran text not null check (peran in ('owner','kasir')),
  aktif boolean not null default true,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.kategori_menu (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  urutan_tampil integer not null default 0,
  aktif boolean not null default true,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.menu (
  id uuid primary key default gen_random_uuid(),
  id_kategori uuid not null references public.kategori_menu(id),
  nama text not null,
  harga_satuan integer not null check (harga_satuan >= 0),
  stok integer not null default 0,
  stok_minimum integer not null default 0,
  tersedia boolean not null default true,
  foto_url text,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.paket_kombo (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  harga_paket integer not null check (harga_paket >= 0),
  aktif boolean not null default true,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.paket_kombo_rincian (
  id uuid primary key default gen_random_uuid(),
  id_paket uuid not null references public.paket_kombo(id) on delete cascade,
  id_menu uuid not null references public.menu(id),
  jumlah integer not null default 1 check (jumlah > 0),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.open_bill (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  status text not null default 'buka' check (status in ('buka','tutup')),
  id_akun uuid not null references public.akun(id),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.shift_kasir (
  id uuid primary key default gen_random_uuid(),
  id_akun uuid not null references public.akun(id),
  dibuka_pada timestamptz not null default now(),
  ditutup_pada timestamptz,
  saldo_awal integer not null default 0,
  kas_akhir_sistem integer not null default 0,
  kas_akhir_fisik integer,
  selisih integer,
  status text not null default 'buka' check (status in ('buka','tutup')),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.pesanan (
  id uuid primary key default gen_random_uuid(),
  nomor_nota text not null unique,
  id_akun uuid not null references public.akun(id),
  id_shift uuid references public.shift_kasir(id),
  id_open_bill uuid references public.open_bill(id),
  metode_bayar text not null check (metode_bayar in ('tunai','non_tunai')),
  status text not null default 'baru'
    check (status in ('baru','lunas','void')),
  total integer not null default 0 check (total >= 0),
  bayar integer not null default 0 check (bayar >= 0),
  kembalian integer not null default 0,
  foto_bukti_lokal text,
  foto_bukti_remote text,
  void_alasan text,
  void_disetujui_owner boolean not null default false,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.pesanan_rincian (
  id uuid primary key default gen_random_uuid(),
  id_pesanan uuid not null references public.pesanan(id) on delete cascade,
  id_menu uuid references public.menu(id),
  id_paket uuid references public.paket_kombo(id),
  nama_snapshot text not null,
  harga_snapshot integer not null check (harga_snapshot >= 0),
  jumlah integer not null default 1 check (jumlah > 0),
  subtotal integer not null check (subtotal >= 0),
  catatan text,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.kasbon (
  id uuid primary key default gen_random_uuid(),
  nama_pelanggan text not null,
  nominal integer not null check (nominal > 0),
  sudah_bayar integer not null default 0 check (sudah_bayar >= 0),
  jatuh_tempo date,
  status text not null default 'belum_lunas'
    check (status in ('belum_lunas','lunas')),
  id_akun uuid not null references public.akun(id),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create table public.kas_keluar (
  id uuid primary key default gen_random_uuid(),
  id_akun uuid not null references public.akun(id),
  id_shift uuid references public.shift_kasir(id),
  kategori text not null,
  nominal integer not null check (nominal > 0),
  catatan text,
  terjadi_pada timestamptz not null default now(),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

-- log_audit: TANPA kolom sinkron (append-only, tidak pernah diubah)
create table public.log_audit (
  id uuid primary key default gen_random_uuid(),
  aksi text not null,
  id_akun uuid references public.akun(id),
  id_referensi uuid,
  detail jsonb,
  alasan text,
  dibuat_pada timestamptz not null default now()
);

-- pemilik: id mengikuti auth.users.id
create table public.pemilik (
  id uuid primary key,
  nama_pemilik text not null,
  nama_warkop text not null default 'WARKOP DOA AMBU',
  email text not null unique,
  nomor_kontak text,
  hash_pin_master text not null,
  apakah_biometrik_aktif boolean not null default false,
  dibuat_pada timestamptz not null default now(),
  status_sinkron text not null default 'tersinkron'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

-- =============================================================
-- INDEKS
-- =============================================================
create index idx_menu_id_kategori on public.menu(id_kategori);
create index idx_pesanan_diperbarui on public.pesanan(diperbarui_pada);
create index idx_pesanan_status_sinkron on public.pesanan(status_sinkron);
create index idx_pesanan_nomor_nota on public.pesanan(nomor_nota);
create index idx_pesanan_rincian_id_pesanan on public.pesanan_rincian(id_pesanan);
create index idx_log_audit_dibuat on public.log_audit(dibuat_pada);
create index idx_paket_rincian_id_paket on public.paket_kombo_rincian(id_paket);
create index idx_shift_id_akun on public.shift_kasir(id_akun);
create index idx_kasbon_id_akun on public.kasbon(id_akun);
create index idx_kas_keluar_id_akun on public.kas_keluar(id_akun);
create index idx_open_bill_id_akun on public.open_bill(id_akun);

-- trigger sentuh diperbarui_pada (eksplisit, idempoten)
drop trigger if exists trg_akun_sentuh on public.akun;
create trigger trg_akun_sentuh
  before update on public.akun
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_kategori_menu_sentuh on public.kategori_menu;
create trigger trg_kategori_menu_sentuh
  before update on public.kategori_menu
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_menu_sentuh on public.menu;
create trigger trg_menu_sentuh
  before update on public.menu
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_paket_kombo_sentuh on public.paket_kombo;
create trigger trg_paket_kombo_sentuh
  before update on public.paket_kombo
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_paket_kombo_rincian_sentuh on public.paket_kombo_rincian;
create trigger trg_paket_kombo_rincian_sentuh
  before update on public.paket_kombo_rincian
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_open_bill_sentuh on public.open_bill;
create trigger trg_open_bill_sentuh
  before update on public.open_bill
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_shift_kasir_sentuh on public.shift_kasir;
create trigger trg_shift_kasir_sentuh
  before update on public.shift_kasir
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_pesanan_sentuh on public.pesanan;
create trigger trg_pesanan_sentuh
  before update on public.pesanan
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_pesanan_rincian_sentuh on public.pesanan_rincian;
create trigger trg_pesanan_rincian_sentuh
  before update on public.pesanan_rincian
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_kasbon_sentuh on public.kasbon;
create trigger trg_kasbon_sentuh
  before update on public.kasbon
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_kas_keluar_sentuh on public.kas_keluar;
create trigger trg_kas_keluar_sentuh
  before update on public.kas_keluar
  for each row execute function public.sentuh_diperbarui_pada();
drop trigger if exists trg_pemilik_sentuh on public.pemilik;
create trigger trg_pemilik_sentuh
  before update on public.pemilik
  for each row execute function public.sentuh_diperbarui_pada();

-- =============================================================
-- RLS
-- =============================================================
alter table public.akun enable row level security;
alter table public.kategori_menu enable row level security;
alter table public.menu enable row level security;
alter table public.paket_kombo enable row level security;
alter table public.paket_kombo_rincian enable row level security;
alter table public.open_bill enable row level security;
alter table public.shift_kasir enable row level security;
alter table public.pesanan enable row level security;
alter table public.pesanan_rincian enable row level security;
alter table public.kasbon enable row level security;
alter table public.kas_keluar enable row level security;
alter table public.log_audit enable row level security;
alter table public.pemilik enable row level security;

-- Kebijakan operasional: aplikasi memakai anon key (kasir login via PIN
-- lokal, tanpa Supabase Auth). Kunci hanya tertanam di aplikasi.
do $$
declare t text;
begin
  foreach t in array array[
    'akun','kategori_menu','menu','paket_kombo','paket_kombo_rincian',
    'open_bill','shift_kasir','pesanan','pesanan_rincian',
    'kasbon','kas_keluar'
  ] loop
    execute format(
      'create policy %I_akses_aplikasi on public.%I for all to anon, authenticated using (true) with check (true)',
      t, t);
  end loop;
end $$;

-- log_audit: append-only (boleh insert, tanpa baca/ubah/hapus via API)
create policy log_audit_tulis on public.log_audit
  for insert to anon, authenticated with check (true);

-- pemilik: hanya owner terotentikasi atas barisnya sendiri
create policy pemilik_milik_sendiri on public.pemilik
  for all to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- =============================================================
-- STORAGE: bucket bukti-pembayaran
-- =============================================================
insert into storage.buckets (id, name, public)
values ('bukti-pembayaran', 'bukti-pembayaran', true)
on conflict (id) do nothing;

create policy bukti_baca_publik on storage.objects
  for select to public
  using (bucket_id = 'bukti-pembayaran');

create policy bukti_tulis_aplikasi on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'bukti-pembayaran');

-- =============================================================
-- SEED: kategori & menu awal
-- =============================================================
insert into public.kategori_menu (nama, urutan_tampil, aktif, status_sinkron)
values
  ('Kopi', 1, true, 'tersinkron'),
  ('Minuman Dingin', 2, true, 'tersinkron'),
  ('Snack', 3, true, 'tersinkron'),
  ('Makanan', 4, true, 'tersinkron')
on conflict (nama) do nothing;

insert into public.menu
  (id_kategori, nama, harga_satuan, stok, stok_minimum, tersedia, status_sinkron)
select k.id, m.nama, m.harga, m.stok, m.stok_min, true, 'tersinkron'
from public.kategori_menu k
join (values
  ('Kopi', 'Kopi Tubruk', 8000, 50, 10),
  ('Kopi', 'Kopi Susu', 12000, 50, 10),
  ('Kopi', 'Kopi Hitam Es', 10000, 50, 10),
  ('Minuman Dingin', 'Es Teh Manis', 5000, 50, 10),
  ('Minuman Dingin', 'Es Jeruk', 7000, 50, 10),
  ('Snack', 'Pisang Goreng', 10000, 30, 5),
  ('Snack', 'Tahu Isi', 8000, 30, 5),
  ('Makanan', 'Indomie Goreng', 12000, 30, 5),
  ('Makanan', 'Nasi Goreng', 15000, 20, 5)
) as m(kat, nama, harga, stok, stok_min) on m.kat = k.nama
on conflict do nothing;

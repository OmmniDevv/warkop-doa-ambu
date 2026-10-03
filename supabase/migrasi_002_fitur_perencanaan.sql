-- =============================================================
-- MIGRASI 002: Fitur perencanaan + foto menu
-- =============================================================
-- 1. Modul bahan + resep (bumbu TIDAK dicatat — hanya bahan utama)
-- 2. Diskon per nota & per item (wajib alasan, tercatat audit)
-- 3. Bayar gabungan (tunai + non-tunai dalam satu nota)
-- 4. Stok opname (cocokkan fisik vs sistem)
-- 5. Bucket storage foto-menu untuk foto item menu
-- =============================================================

-- ── TABEL BAHAN ────────────────────────────────────────────────
create table public.bahan (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  satuan text not null default 'pcs'
    check (satuan in ('pcs','gram','kg','ml','liter','bungkus','ikat')),
  stok numeric not null default 0 check (stok >= 0),
  stok_minimum numeric not null default 0 check (stok_minimum >= 0),
  harga_beli integer not null default 0 check (harga_beli >= 0),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  apakah_dihapus boolean not null default false
);

create index idx_bahan_nama on public.bahan(nama);
create index idx_bahan_menipis on public.bahan(stok, stok_minimum)
  where apakah_dihapus = false;

-- ── TABEL RESEP (menu ↔ bahan + takaran) ───────────────────────
create table public.resep (
  id uuid primary key default gen_random_uuid(),
  id_menu uuid not null references public.menu(id) on delete cascade,
  id_bahan uuid not null references public.bahan(id) on delete restrict,
  takaran numeric not null check (takaran > 0),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  diperbarui_pada timestamptz not null default now(),
  unique (id_menu, id_bahan)
);

create index idx_resep_id_menu on public.resep(id_menu);
create index idx_resep_id_bahan on public.resep(id_bahan);

-- ── DISKON di pesanan (per nota) ───────────────────────────────
alter table public.pesanan
  add column if not exists diskon_nota_nominal integer not null default 0
    check (diskon_nota_nominal >= 0),
  add column if not exists diskon_nota_persen numeric not null default 0
    check (diskon_nota_persen >= 0 and diskon_nota_persen <= 100),
  add column if not exists alasan_diskon text;

-- ── DISKON di pesanan_rincian (per item) ───────────────────────
alter table public.pesanan_rincian
  add column if not exists diskon_nominal integer not null default 0
    check (diskon_nominal >= 0),
  add column if not exists diskon_persen numeric not null default 0
    check (diskon_persen >= 0 and diskon_persen <= 100);

-- ── BAYAR GABUNGAN ─────────────────────────────────────────────
create table public.pesanan_bayar (
  id uuid primary key default gen_random_uuid(),
  id_pesanan uuid not null references public.pesanan(id) on delete cascade,
  metode text not null check (metode in ('tunai','non_tunai')),
  nominal integer not null check (nominal > 0),
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  dibuat_pada timestamptz not null default now()
);

create index idx_pesanan_bayar_id_pesanan on public.pesanan_bayar(id_pesanan);

-- ── STOK OPNAME ────────────────────────────────────────────────
create table public.stok_opname (
  id uuid primary key default gen_random_uuid(),
  tipe_item text not null check (tipe_item in ('menu','bahan')),
  id_item uuid not null,
  nama_snapshot text not null,
  stok_sistem numeric not null,
  stok_fisik numeric not null check (stok_fisik >= 0),
  selisih numeric not null,
  catatan text,
  dibuat_oleh text not null,
  status_sinkron text not null default 'tertunda'
    check (status_sinkron in ('tertunda','tersinkron','gagal')),
  dibuat_pada timestamptz not null default now()
);

create index idx_stok_opname_dibuat_pada on public.stok_opname(dibuat_pada desc);
create index idx_stok_opname_tipe_item on public.stok_opname(tipe_item, id_item);

-- ── STORAGE: bucket foto-menu ──────────────────────────────────
insert into storage.buckets (id, name, public)
values ('foto-menu', 'foto-menu', true)
on conflict (id) do nothing;

create policy foto_menu_baca_publik on storage.objects
  for select to public
  using (bucket_id = 'foto-menu');

create policy foto_menu_tulis_aplikasi on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'foto-menu');

create policy foto_menu_hapus_aplikasi on storage.objects
  for delete to anon, authenticated
  using (bucket_id = 'foto-menu');

-- ── RLS: aktifkan untuk tabel baru (kebijakan longgar seperti tabel lain,
--    hardening menyusul via Edge Function sesuai catatan produksi) ──
alter table public.bahan enable row level security;
alter table public.resep enable row level security;
alter table public.pesanan_bayar enable row level security;
alter table public.stok_opname enable row level security;

create policy bahan_akses_penuh on public.bahan
  for all to public using (true) with check (true);
create policy resep_akses_penuh on public.resep
  for all to public using (true) with check (true);
create policy pesanan_bayar_akses_penuh on public.pesanan_bayar
  for all to public using (true) with check (true);
create policy stok_opname_akses_penuh on public.stok_opname
  for all to public using (true) with check (true);

-- Migrasi 003: relaksasi check constraint metode_bayar di tabel pesanan.
--
-- Aplikasi kini menulis 'gabungan' ke pesanan.metode_bayar bila satu nota
-- dibayar dengan lebih dari satu metode (tunai + non-tunai). Tanpa
-- migrasi ini, baris pesanan 'gabungan' DITOLAK Supabase saat sinkron
-- (check constraint lama) dan ditandai 'gagal' di antrean lokal.
--
-- Jalankan sekali di Supabase SQL editor / via Management API.

alter table public.pesanan
  drop constraint if exists pesanan_metode_bayar_check;

alter table public.pesanan
  add constraint pesanan_metode_bayar_check
  check (metode_bayar in ('tunai', 'non_tunai', 'gabungan'));

-- Floral Bill: Supabase snapshot storage
-- Run this in Supabase SQL Editor after creating the project.
-- This table stores one full JSON snapshot per authenticated user.
-- Row Level Security is mandatory; do not expose the table anonymously.

create table if not exists public.floral_bill_snapshots (
  snapshot_id text primary key default 'default',
  owner_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  constraint floral_bill_snapshot_fixed_id check (snapshot_id = 'default')
);

alter table public.floral_bill_snapshots enable row level security;

revoke all on table public.floral_bill_snapshots from anon;
grant select, insert, update, delete on table public.floral_bill_snapshots to authenticated;

drop policy if exists "Users can read their own Floral Bill snapshot" on public.floral_bill_snapshots;
create policy "Users can read their own Floral Bill snapshot"
  on public.floral_bill_snapshots for select to authenticated
  using (auth.uid() = owner_id);

drop policy if exists "Users can create their own Floral Bill snapshot" on public.floral_bill_snapshots;
create policy "Users can create their own Floral Bill snapshot"
  on public.floral_bill_snapshots for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "Users can update their own Floral Bill snapshot" on public.floral_bill_snapshots;
create policy "Users can update their own Floral Bill snapshot"
  on public.floral_bill_snapshots for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "Users can delete their own Floral Bill snapshot" on public.floral_bill_snapshots;
create policy "Users can delete their own Floral Bill snapshot"
  on public.floral_bill_snapshots for delete to authenticated
  using (auth.uid() = owner_id);

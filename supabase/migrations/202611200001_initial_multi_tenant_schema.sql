-- Billit multi-tenant Supabase foundation
-- Apply this migration to a NEW Supabase project before enabling cloud sync.
-- Local SQLite remains the source of truth until sync is explicitly enabled.

create extension if not exists pgcrypto;

create type public.shop_member_role as enum ('shop_admin', 'worker');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  is_platform_owner boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  business_email text not null default '',
  business_phone text not null default '',
  business_address text not null default '',
  gstin text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shop_memberships (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.shop_member_role not null default 'worker',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, user_id)
);

create index shop_memberships_user_idx on public.shop_memberships(user_id);
create index shop_memberships_shop_idx on public.shop_memberships(shop_id);

-- Security-definer helpers avoid recursive RLS checks on shop_memberships.
create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_platform_owner = true
  );
$$;

create or replace function public.is_shop_member(target_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_owner() or exists (
    select 1 from public.shop_memberships m
    where m.shop_id = target_shop_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create or replace function public.can_manage_shop(target_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_owner() or exists (
    select 1 from public.shop_memberships m
    where m.shop_id = target_shop_id
      and m.user_id = (select auth.uid())
      and m.role = 'shop_admin'
      and m.is_active = true
  );
$$;

create table public.products (
  id text not null,
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  selling_price double precision,
  cost_price double precision,
  stock double precision,
  unit text not null,
  category text not null default 'General',
  sub_category text not null default '',
  active boolean not null default true,
  barcode text,
  hsn_code text not null default '',
  gst_rate double precision,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (shop_id, id)
);
create index products_shop_barcode_idx on public.products(shop_id, barcode);

create table public.sales (
  id text not null,
  shop_id uuid not null references public.shops(id) on delete cascade,
  date timestamptz not null,
  total_amount double precision,
  total_cost double precision,
  profit double precision,
  payment text not null,
  customer_name text not null default '',
  customer_phone text not null default '',
  discount double precision,
  gst_enabled boolean not null default false,
  gst_rate double precision,
  taxable_amount double precision,
  cgst_amount double precision,
  sgst_amount double precision,
  igst_amount double precision,
  customer_gstin text not null default '',
  interstate_sale boolean not null default false,
  gst_inclusive boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (shop_id, id)
);
create index sales_shop_date_idx on public.sales(shop_id, date desc);

create table public.sale_items (
  shop_id uuid not null,
  sale_id text not null,
  position integer not null,
  product_id text not null,
  qty double precision,
  selling_price double precision,
  cost_price double precision,
  subtotal double precision,
  unit_label text not null default 'pcs',
  hsn_code text not null default '',
  gst_rate double precision,
  taxable_amount double precision,
  cgst_amount double precision,
  sgst_amount double precision,
  igst_amount double precision,
  updated_at timestamptz not null default now(),
  primary key (shop_id, sale_id, position),
  foreign key (shop_id, sale_id)
    references public.sales(shop_id, id) on delete cascade
);

create table public.expenses (
  id text not null,
  shop_id uuid not null references public.shops(id) on delete cascade,
  date timestamptz not null,
  category text not null,
  amount double precision,
  description text not null default '',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (shop_id, id)
);
create index expenses_shop_date_idx on public.expenses(shop_id, date desc);

create table public.employees (
  id text not null,
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  type text not null,
  wage double precision,
  attendance integer not null default 0,
  salary_paid boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (shop_id, id)
);

create table public.shop_settings (
  shop_id uuid primary key references public.shops(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_shop_created_idx on public.audit_logs(shop_id, created_at desc);

-- Keep updated_at current on mutable cloud records.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','shops','shop_memberships','products','sales',
    'sale_items','expenses','employees','shop_settings'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end;
$$;

-- RLS is enabled on every table exposed to the client.
alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.shop_memberships enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;
alter table public.employees enable row level security;
alter table public.shop_settings enable row level security;
alter table public.audit_logs enable row level security;

create policy "Profiles visible to self or platform owner"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.is_platform_owner()));

create policy "Users can update own non-privileged profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()) or (select public.is_platform_owner()))
with check (
  (id = (select auth.uid()) and is_platform_owner = false)
  or (select public.is_platform_owner())
);

create policy "Platform owner creates profiles"
on public.profiles for insert to authenticated
with check ((select public.is_platform_owner()) or (id = (select auth.uid()) and is_platform_owner = false));

create policy "Members and platform owner read shops"
on public.shops for select to authenticated
using (public.is_shop_member(id));

create policy "Platform owner creates shops"
on public.shops for insert to authenticated
with check ((select public.is_platform_owner()));

create policy "Shop admins or platform owner update shops"
on public.shops for update to authenticated
using (public.can_manage_shop(id))
with check (public.can_manage_shop(id));

create policy "Platform owner deletes shops"
on public.shops for delete to authenticated
using ((select public.is_platform_owner()));

create policy "Members read memberships"
on public.shop_memberships for select to authenticated
using (
  user_id = (select auth.uid())
  or public.can_manage_shop(shop_id)
);

create policy "Shop admins add workers; platform owner assigns any role"
on public.shop_memberships for insert to authenticated
with check (
  (select public.is_platform_owner())
  or (public.can_manage_shop(shop_id) and role = 'worker')
);

create policy "Shop admins manage workers; platform owner manages all"
on public.shop_memberships for update to authenticated
using (
  (select public.is_platform_owner())
  or (public.can_manage_shop(shop_id) and role = 'worker')
)
with check (
  (select public.is_platform_owner())
  or (public.can_manage_shop(shop_id) and role = 'worker')
);

create policy "Shop admins remove workers; platform owner removes memberships"
on public.shop_memberships for delete to authenticated
using (
  (select public.is_platform_owner())
  or (public.can_manage_shop(shop_id) and role = 'worker')
);

-- Workers can read business data; only shop admins/platform owner can mutate it.
do $$
declare t text;
begin
  foreach t in array array['products','sales','sale_items','expenses','employees'] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.is_shop_member(shop_id))',
      t || '_read_members', t
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.can_manage_shop(shop_id))',
      t || '_insert_admin', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.can_manage_shop(shop_id)) with check (public.can_manage_shop(shop_id))',
      t || '_update_admin', t
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.can_manage_shop(shop_id))',
      t || '_delete_admin', t
    );
  end loop;
end;
$$;

create policy "Members read shop settings"
on public.shop_settings for select to authenticated
using (public.is_shop_member(shop_id));
create policy "Shop admins manage shop settings"
on public.shop_settings for all to authenticated
using (public.can_manage_shop(shop_id))
with check (public.can_manage_shop(shop_id));

create policy "Admins and platform owner read audit logs"
on public.audit_logs for select to authenticated
using (
  (select public.is_platform_owner())
  or (shop_id is not null and public.can_manage_shop(shop_id))
);
create policy "Authenticated members write audit logs for their shop"
on public.audit_logs for insert to authenticated
with check (
  actor_user_id = (select auth.uid())
  and (select public.is_platform_owner() or public.is_shop_member(shop_id))
);

-- Do not grant platform-owner status from client metadata or self-service APIs.
-- Bootstrap the first platform owner manually in the Supabase SQL editor after
-- creating that user's Auth account:
-- update public.profiles set is_platform_owner = true where id = '<AUTH_USER_UUID>';
-- Profile row creation for new Auth users is handled by the trusted backend/admin
-- provisioning workflow, not by a client-supplied role field.

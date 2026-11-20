-- Account bootstrap and granular worker permissions.
-- Apply after 202611200001_initial_multi_tenant_schema.sql.

alter table public.shop_memberships
  add column if not exists permissions jsonb not null default
    '{"billing": true, "inventory": true, "reports": false, "expenses": false, "payroll": false}'::jsonb;

create or replace function public.has_shop_permission(
  target_shop_id uuid,
  permission_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.shop_memberships m
      where m.shop_id = target_shop_id
        and m.user_id = (select auth.uid())
        and m.is_active = true
        and (
          m.role = 'shop_admin'
          or coalesce((m.permissions ->> permission_key)::boolean, false)
        )
    );
$$;

-- Replace broad member-read policies with feature-scoped access.
drop policy if exists products_read_members on public.products;
drop policy if exists sales_read_members on public.sales;
drop policy if exists sale_items_read_members on public.sale_items;
drop policy if exists expenses_read_members on public.expenses;
drop policy if exists employees_read_members on public.employees;

create policy "Inventory permission reads products"
on public.products for select to authenticated
using (public.has_shop_permission(shop_id, 'inventory'));

create policy "Billing permission reads sales"
on public.sales for select to authenticated
using (public.has_shop_permission(shop_id, 'billing'));

create policy "Billing permission reads sale items"
on public.sale_items for select to authenticated
using (public.has_shop_permission(shop_id, 'billing'));

create policy "Billing permission creates sales"
on public.sales for insert to authenticated
with check (public.has_shop_permission(shop_id, 'billing'));

create policy "Billing permission creates sale items"
on public.sale_items for insert to authenticated
with check (public.has_shop_permission(shop_id, 'billing'));

create policy "Expense permission reads expenses"
on public.expenses for select to authenticated
using (public.has_shop_permission(shop_id, 'expenses'));

create policy "Payroll permission reads employees"
on public.employees for select to authenticated
using (public.has_shop_permission(shop_id, 'payroll'));

-- Keep all business-data mutations admin-only except creating sales and sale
-- items under the billing permission. Product stock changes remain server/app
-- controlled in a later transaction/RPC implementation.

-- Supabase Auth user creation creates a non-privileged profile automatically.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, is_platform_owner)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Shop admins can configure a worker's permissions via shop_memberships.
-- Never accept is_platform_owner from user metadata or client input.

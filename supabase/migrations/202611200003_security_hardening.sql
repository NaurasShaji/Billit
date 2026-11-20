-- Security hardening for account provisioning and tenant integrity.
-- Apply after 202611200002_auth_profiles_and_worker_permissions.sql.

-- Membership permissions must be a JSON object with only known boolean flags.
alter table public.shop_memberships
  add constraint shop_memberships_permissions_shape_check
  check (
    jsonb_typeof(permissions) = 'object'
    and permissions - array['billing', 'inventory', 'reports', 'expenses', 'payroll'] = '{}'::jsonb
    and jsonb_typeof(coalesce(permissions -> 'billing', 'true'::jsonb)) = 'boolean'
    and jsonb_typeof(coalesce(permissions -> 'inventory', 'true'::jsonb)) = 'boolean'
    and jsonb_typeof(coalesce(permissions -> 'reports', 'false'::jsonb)) = 'boolean'
    and jsonb_typeof(coalesce(permissions -> 'expenses', 'false'::jsonb)) = 'boolean'
    and jsonb_typeof(coalesce(permissions -> 'payroll', 'false'::jsonb)) = 'boolean'
  );

-- Every line item must reference a product in the same shop.
alter table public.sale_items
  add constraint sale_items_product_same_shop_fk
  foreign key (shop_id, product_id)
  references public.products(shop_id, id);

-- Client-created audit rows are not trustworthy. Critical audit events are
-- written by the trusted Edge Function using the service-role key.
drop policy if exists "Authenticated members write audit logs for their shop"
  on public.audit_logs;

create or replace function public.protect_membership_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or public.is_platform_owner() then
    return new;
  end if;

  if auth.uid() is null
    or new.shop_id is distinct from old.shop_id
    or new.user_id is distinct from old.user_id
    or new.role is distinct from old.role
  then
    raise exception 'Membership identity fields cannot be changed';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_membership_identity
  on public.shop_memberships;
create trigger protect_membership_identity
before update on public.shop_memberships
for each row execute function public.protect_membership_identity();

-- Do not allow a worker to update membership records, even if a future policy
-- is added accidentally. Only shop admins/platform owners may update workers.

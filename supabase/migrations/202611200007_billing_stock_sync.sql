-- Billing-only workers may adjust stock as a consequence of completing a sale,
-- but must not be able to edit product master data.
create policy "Billing permission updates product stock"
on public.products for update to authenticated
using (public.has_shop_permission(shop_id, 'billing'))
with check (public.has_shop_permission(shop_id, 'billing'));

create or replace function public.protect_billing_product_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
    or public.is_platform_owner()
    or public.can_manage_shop(new.shop_id)
    or public.has_shop_permission(new.shop_id, 'inventory')
  then
    return new;
  end if;

  if not public.has_shop_permission(new.shop_id, 'billing') then
    raise exception 'Inventory permission required';
  end if;

  if new.shop_id is distinct from old.shop_id
    or new.id is distinct from old.id
    or new.name is distinct from old.name
    or new.selling_price is distinct from old.selling_price
    or new.cost_price is distinct from old.cost_price
    or new.unit is distinct from old.unit
    or new.category is distinct from old.category
    or new.sub_category is distinct from old.sub_category
    or new.active is distinct from old.active
    or new.barcode is distinct from old.barcode
    or new.hsn_code is distinct from old.hsn_code
    or new.gst_rate is distinct from old.gst_rate
    or new.deleted_at is distinct from old.deleted_at
  then
    raise exception 'Billing permission only allows product stock updates';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_billing_product_fields on public.products;
create trigger protect_billing_product_fields
before update on public.products
for each row execute function public.protect_billing_product_fields();

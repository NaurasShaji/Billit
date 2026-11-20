-- Atomically upsert a sale and replace its line-item snapshot.
-- PostgREST calls this as the authenticated caller (SECURITY INVOKER), so
-- existing sales/sale_items RLS policies remain in force.

create or replace function public.sync_sale_snapshot(
  p_shop_id uuid,
  p_sale jsonb,
  p_items jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_sale_id text;
begin
  if jsonb_typeof(p_sale) is distinct from 'object'
    or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Invalid sale snapshot payload';
  end if;

  v_sale_id := p_sale ->> 'id';
  if v_sale_id is null or length(v_sale_id) = 0 then
    raise exception 'Sale id is required';
  end if;

  insert into public.sales (
    shop_id, id, date, total_amount, total_cost, profit, payment,
    customer_name, customer_phone, discount, gst_enabled, gst_rate,
    taxable_amount, cgst_amount, sgst_amount, igst_amount,
    customer_gstin, interstate_sale, gst_inclusive, deleted_at
  ) values (
    p_shop_id, v_sale_id, (p_sale ->> 'date')::timestamptz,
    nullif(p_sale ->> 'total_amount', '')::double precision,
    nullif(p_sale ->> 'total_cost', '')::double precision,
    nullif(p_sale ->> 'profit', '')::double precision,
    p_sale ->> 'payment',
    coalesce(p_sale ->> 'customer_name', ''),
    coalesce(p_sale ->> 'customer_phone', ''),
    nullif(p_sale ->> 'discount', '')::double precision,
    coalesce((p_sale ->> 'gst_enabled')::boolean, false),
    nullif(p_sale ->> 'gst_rate', '')::double precision,
    nullif(p_sale ->> 'taxable_amount', '')::double precision,
    nullif(p_sale ->> 'cgst_amount', '')::double precision,
    nullif(p_sale ->> 'sgst_amount', '')::double precision,
    nullif(p_sale ->> 'igst_amount', '')::double precision,
    coalesce(p_sale ->> 'customer_gstin', ''),
    coalesce((p_sale ->> 'interstate_sale')::boolean, false),
    coalesce((p_sale ->> 'gst_inclusive')::boolean, false),
    null
  )
  on conflict (shop_id, id) do update set
    date = excluded.date,
    total_amount = excluded.total_amount,
    total_cost = excluded.total_cost,
    profit = excluded.profit,
    payment = excluded.payment,
    customer_name = excluded.customer_name,
    customer_phone = excluded.customer_phone,
    discount = excluded.discount,
    gst_enabled = excluded.gst_enabled,
    gst_rate = excluded.gst_rate,
    taxable_amount = excluded.taxable_amount,
    cgst_amount = excluded.cgst_amount,
    sgst_amount = excluded.sgst_amount,
    igst_amount = excluded.igst_amount,
    customer_gstin = excluded.customer_gstin,
    interstate_sale = excluded.interstate_sale,
    gst_inclusive = excluded.gst_inclusive,
    deleted_at = null;

  delete from public.sale_items
  where shop_id = p_shop_id and sale_id = v_sale_id;

  insert into public.sale_items (
    shop_id, sale_id, position, product_id, qty, selling_price,
    cost_price, subtotal, unit_label, hsn_code, gst_rate,
    taxable_amount, cgst_amount, sgst_amount, igst_amount
  )
  select
    p_shop_id, v_sale_id, item.position, item.product_id, item.qty,
    item.selling_price, item.cost_price, item.subtotal,
    coalesce(item.unit_label, 'pcs'), coalesce(item.hsn_code, ''),
    item.gst_rate, item.taxable_amount, item.cgst_amount,
    item.sgst_amount, item.igst_amount
  from jsonb_to_recordset(p_items) as item(
    position integer,
    product_id text,
    qty double precision,
    selling_price double precision,
    cost_price double precision,
    subtotal double precision,
    unit_label text,
    hsn_code text,
    gst_rate double precision,
    taxable_amount double precision,
    cgst_amount double precision,
    sgst_amount double precision,
    igst_amount double precision
  );
end;
$$;

revoke execute on function public.sync_sale_snapshot(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.sync_sale_snapshot(uuid, jsonb, jsonb) to authenticated, service_role;

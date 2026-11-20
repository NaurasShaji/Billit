-- Compare-and-swap sale snapshots prevent one device from silently
-- replacing a sale changed by another device since its last pull.
drop function if exists public.sync_sale_snapshot(uuid, jsonb, jsonb);

create function public.sync_sale_snapshot(
  p_shop_id uuid,
  p_sale jsonb,
  p_items jsonb,
  p_expected_updated_at timestamptz default null
)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_sale_id text;
  v_current_updated_at timestamptz;
  v_new_updated_at timestamptz;
begin
  if jsonb_typeof(p_sale) is distinct from 'object'
    or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Invalid sale snapshot payload';
  end if;

  v_sale_id := p_sale ->> 'id';
  if v_sale_id is null or length(v_sale_id) = 0 then
    raise exception 'Sale id is required';
  end if;

  select s.updated_at into v_current_updated_at
  from public.sales s
  where s.shop_id = p_shop_id and s.id = v_sale_id
  for update;

  if found then
    if p_expected_updated_at is null
      or v_current_updated_at is distinct from p_expected_updated_at then
      raise exception using errcode = '40001',
        message = 'SYNC_CONFLICT: sale changed in cloud; pull and resolve before retrying';
    end if;

    update public.sales set
      date = (p_sale ->> 'date')::timestamptz,
      total_amount = nullif(p_sale ->> 'total_amount', '')::double precision,
      total_cost = nullif(p_sale ->> 'total_cost', '')::double precision,
      profit = nullif(p_sale ->> 'profit', '')::double precision,
      payment = p_sale ->> 'payment',
      customer_name = coalesce(p_sale ->> 'customer_name', ''),
      customer_phone = coalesce(p_sale ->> 'customer_phone', ''),
      discount = nullif(p_sale ->> 'discount', '')::double precision,
      gst_enabled = coalesce((p_sale ->> 'gst_enabled')::boolean, false),
      gst_rate = nullif(p_sale ->> 'gst_rate', '')::double precision,
      taxable_amount = nullif(p_sale ->> 'taxable_amount', '')::double precision,
      cgst_amount = nullif(p_sale ->> 'cgst_amount', '')::double precision,
      sgst_amount = nullif(p_sale ->> 'sgst_amount', '')::double precision,
      igst_amount = nullif(p_sale ->> 'igst_amount', '')::double precision,
      customer_gstin = coalesce(p_sale ->> 'customer_gstin', ''),
      interstate_sale = coalesce((p_sale ->> 'interstate_sale')::boolean, false),
      gst_inclusive = coalesce((p_sale ->> 'gst_inclusive')::boolean, false),
      deleted_at = null
    where shop_id = p_shop_id and id = v_sale_id
    returning updated_at into v_new_updated_at;
  else
    if p_expected_updated_at is not null then
      raise exception using errcode = '40001',
        message = 'SYNC_CONFLICT: sale no longer exists in cloud';
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
    ) returning updated_at into v_new_updated_at;
  end if;

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

  return v_new_updated_at;
end;
$$;

revoke execute on function public.sync_sale_snapshot(uuid, jsonb, jsonb, timestamptz) from public, anon;
grant execute on function public.sync_sale_snapshot(uuid, jsonb, jsonb, timestamptz) to authenticated, service_role;

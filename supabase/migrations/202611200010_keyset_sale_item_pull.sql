-- Stable keyset pagination for sale line items during cloud pulls.
-- SECURITY INVOKER preserves the caller's RLS visibility.

create or replace function public.sync_sale_items_page(
  p_shop_id uuid,
  p_after_sale_id text default '',
  p_after_position integer default -1,
  p_page_size integer default 500
)
returns setof public.sale_items
language sql
stable
security invoker
set search_path = ''
as $$
  select si.*
  from public.sale_items si
  where si.shop_id = p_shop_id
    and (si.sale_id, si.position) > (p_after_sale_id, p_after_position)
  order by si.sale_id, si.position
  limit greatest(1, least(coalesce(p_page_size, 500), 1000));
$$;

revoke execute on function public.sync_sale_items_page(uuid, text, integer, integer) from public, anon;
grant execute on function public.sync_sale_items_page(uuid, text, integer, integer) to authenticated, service_role;

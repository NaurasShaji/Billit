-- Explicit least-privilege grants for the Supabase Data API.
-- RLS policies remain the actual row-level authorization boundary.

grant usage on schema public to authenticated;
grant usage on type public.shop_member_role to authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.shops,
  public.shop_memberships,
  public.products,
  public.sales,
  public.sale_items,
  public.expenses,
  public.employees,
  public.shop_settings,
  public.audit_logs
to authenticated;

grant execute on function public.is_platform_owner() to authenticated;
grant execute on function public.is_shop_member(uuid) to authenticated;
grant execute on function public.can_manage_shop(uuid) to authenticated;
grant execute on function public.has_shop_permission(uuid, text) to authenticated;

-- No table privileges are granted to anon. Service-role access is managed by
-- Supabase and is used only by the trusted Edge Function.

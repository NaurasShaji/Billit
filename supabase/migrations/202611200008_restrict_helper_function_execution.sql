-- Restrict security-definer authorization helpers to trusted database roles.
-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. These
-- helpers are used by RLS policies and must not be callable by anon clients.

revoke execute on function public.is_platform_owner() from public, anon;
revoke execute on function public.is_shop_member(uuid) from public, anon;
revoke execute on function public.can_manage_shop(uuid) from public, anon;
revoke execute on function public.has_shop_permission(uuid, text) from public, anon;

grant execute on function public.is_platform_owner() to authenticated, service_role;
grant execute on function public.is_shop_member(uuid) to authenticated, service_role;
grant execute on function public.can_manage_shop(uuid) to authenticated, service_role;
grant execute on function public.has_shop_permission(uuid, text) to authenticated, service_role;

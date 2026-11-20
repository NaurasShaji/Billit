-- Return a server-side watermark so every incremental pull uses one
-- consistent upper bound. Rows modified after this instant are picked up by
-- the next sync rather than shifting through the current page set.
create or replace function public.sync_pull_watermark()
returns timestamptz
language sql
volatile
security invoker
set search_path = ''
as $$
  select clock_timestamp();
$$;

revoke execute on function public.sync_pull_watermark() from public, anon;
grant execute on function public.sync_pull_watermark() to authenticated, service_role;

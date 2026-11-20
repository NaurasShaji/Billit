-- Allow workers to synchronize only the business areas explicitly granted
-- to their membership. RLS remains the authorization boundary.
 
create policy "Inventory permission inserts products"
on public.products for insert to authenticated
with check (public.has_shop_permission(shop_id, 'inventory'));
create policy "Inventory permission updates products"
on public.products for update to authenticated
using (public.has_shop_permission(shop_id, 'inventory'))
with check (public.has_shop_permission(shop_id, 'inventory'));
create policy "Inventory permission deletes products"
on public.products for delete to authenticated
using (public.has_shop_permission(shop_id, 'inventory'));

create policy "Expense permission inserts expenses"
on public.expenses for insert to authenticated
with check (public.has_shop_permission(shop_id, 'expenses'));
create policy "Expense permission updates expenses"
on public.expenses for update to authenticated
using (public.has_shop_permission(shop_id, 'expenses'))
with check (public.has_shop_permission(shop_id, 'expenses'));
create policy "Expense permission deletes expenses"
on public.expenses for delete to authenticated
using (public.has_shop_permission(shop_id, 'expenses'));

create policy "Payroll permission inserts employees"
on public.employees for insert to authenticated
with check (public.has_shop_permission(shop_id, 'payroll'));
create policy "Payroll permission updates employees"
on public.employees for update to authenticated
using (public.has_shop_permission(shop_id, 'payroll'))
with check (public.has_shop_permission(shop_id, 'payroll'));

create policy "Billing permission updates sales"
on public.sales for update to authenticated
using (public.has_shop_permission(shop_id, 'billing'))
with check (public.has_shop_permission(shop_id, 'billing'));
create policy "Billing permission deletes sales"
on public.sales for delete to authenticated
using (public.has_shop_permission(shop_id, 'billing'));
create policy "Billing permission updates sale items"
on public.sale_items for update to authenticated
using (public.has_shop_permission(shop_id, 'billing'))
with check (public.has_shop_permission(shop_id, 'billing'));
create policy "Billing permission deletes sale items"
on public.sale_items for delete to authenticated
using (public.has_shop_permission(shop_id, 'billing'));

-- A worker cannot delete employees; payroll permission only allows managing
-- attendance/payroll records through insert/update.

-- Align read policies with independent billing, inventory and reports flags.

drop policy if exists "Inventory permission reads products" on public.products;
create policy "Billing inventory or reports permission reads products"
on public.products for select to authenticated
using (
  public.has_shop_permission(shop_id, 'inventory')
  or public.has_shop_permission(shop_id, 'billing')
  or public.has_shop_permission(shop_id, 'reports')
);

drop policy if exists "Billing permission reads sales" on public.sales;
create policy "Billing or reports permission reads sales"
on public.sales for select to authenticated
using (
  public.has_shop_permission(shop_id, 'billing')
  or public.has_shop_permission(shop_id, 'reports')
);

drop policy if exists "Billing permission reads sale items" on public.sale_items;
create policy "Billing or reports permission reads sale items"
on public.sale_items for select to authenticated
using (
  public.has_shop_permission(shop_id, 'billing')
  or public.has_shop_permission(shop_id, 'reports')
);

drop policy if exists "Expense permission reads expenses" on public.expenses;
create policy "Expense or reports permission reads expenses"
on public.expenses for select to authenticated
using (
  public.has_shop_permission(shop_id, 'expenses')
  or public.has_shop_permission(shop_id, 'reports')
);

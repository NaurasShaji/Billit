import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/boxes.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback onOpenBilling;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenReports;

  const DashboardTab({
    super.key,
    required this.onOpenBilling,
    required this.onOpenProducts,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final settings = Hive.box<dynamic>('app_settings');
    final threshold = (settings.get('low_stock_threshold', defaultValue: 10) as num).toDouble();

    return Scaffold(
      body: ValueListenableBuilder<Box<Sale>>(
        valueListenable: Hive.box<Sale>(Boxes.sales).listenable(),
        builder: (context, salesBox, _) => ValueListenableBuilder<Box<Product>>(
          valueListenable: Hive.box<Product>(Boxes.products).listenable(),
          builder: (context, productsBox, __) => ValueListenableBuilder<Box<Expense>>(
            valueListenable: Hive.box<Expense>(Boxes.expenses).listenable(),
            builder: (context, expensesBox, ___) {
              final allSales = salesBox.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              final todaySales = allSales.where((sale) =>
                  !sale.date.isBefore(start) && sale.date.isBefore(end)).toList();
              final todayRevenue = todaySales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
              final todayProfit = todaySales.fold<double>(0, (sum, sale) => sum + sale.profit);
              final todayExpenses = expensesBox.values.where((expense) =>
                  !expense.date.isBefore(start) && expense.date.isBefore(end))
                  .fold<double>(0, (sum, expense) => sum + expense.amount);
              final activeProducts = productsBox.values.where((product) => product.active).toList();
              final lowStock = activeProducts.where((product) => product.stock <= threshold).toList()
                ..sort((a, b) => a.stock.compareTo(b.stock));
              final lastSevenDays = List.generate(7, (index) {
                final day = DateTime(start.year, start.month, start.day - (6 - index));
                final nextDay = day.add(const Duration(days: 1));
                final revenue = allSales.where((sale) =>
                    !sale.date.isBefore(day) && sale.date.isBefore(nextDay))
                    .fold<double>(0, (sum, sale) => sum + sale.totalAmount);
                return _DayRevenue(day, revenue);
              });
              final maxRevenue = lastSevenDays.fold<double>(
                0, (maximum, day) => day.revenue > maximum ? day.revenue : maximum,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business overview', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(DateFormat('EEEE, d MMMM yyyy').format(now),
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Refresh overview',
                        onPressed: () {},
                        icon: const Icon(Icons.insights_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
                      final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
                      final metrics = <Widget>[
                        _MetricCard(title: "Today's sales", value: currency.format(todayRevenue), subtitle: '${todaySales.length} bills', icon: Icons.point_of_sale_outlined, color: theme.colorScheme.primary),
                        _MetricCard(title: 'Estimated profit', value: currency.format(todayProfit), subtitle: 'Before expenses', icon: Icons.trending_up_rounded, color: Colors.green.shade700),
                        _MetricCard(title: "Today's expenses", value: currency.format(todayExpenses), subtitle: 'Recorded expenses', icon: Icons.account_balance_wallet_outlined, color: Colors.deepOrange.shade600),
                        _MetricCard(title: 'Active products', value: activeProducts.length.toString(), subtitle: '${lowStock.length} low in stock', icon: Icons.inventory_2_outlined, color: Colors.indigo.shade600),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: metrics.map((metric) => SizedBox(width: cardWidth, child: metric)).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 820;
                      final trend = _Panel(
                        title: 'Sales trend',
                        subtitle: 'Revenue over the last 7 days',
                        trailing: TextButton(onPressed: onOpenReports, child: const Text('View reports')),
                        child: SizedBox(
                          height: 190,
                          child: maxRevenue <= 0
                              ? Center(child: Text('Sales activity will appear here.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: lastSevenDays.map((day) {
                                    final ratio = day.revenue / maxRevenue;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (day.revenue > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Text(
                                                  day.revenue >= 10000
                                                      ? '₹${(day.revenue / 1000).toStringAsFixed(0)}k'
                                                      : day.revenue >= 1000
                                                          ? '₹${(day.revenue / 1000).toStringAsFixed(1)}k'
                                                          : '₹${day.revenue.toStringAsFixed(0)}',
                                                  style: theme.textTheme.labelSmall,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            Container(
                                              height: 105 * ratio.clamp(0.04, 1.0),
                                              decoration: BoxDecoration(
                                                color: day.day.year == now.year && day.day.month == now.month && day.day.day == now.day
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.primary.withOpacity(0.35),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(DateFormat('E').format(day.day), style: theme.textTheme.labelSmall),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      );
                      final actions = _Panel(
                        title: 'Quick actions',
                        subtitle: 'Jump to a common task',
                        child: Column(
                          children: [
                            _QuickAction(icon: Icons.add_shopping_cart, title: 'Create a bill', subtitle: 'Start a new checkout', onTap: onOpenBilling),
                            const Divider(height: 1),
                            _QuickAction(icon: Icons.add_box_outlined, title: 'Manage products', subtitle: 'Prices, stock and barcodes', onTap: onOpenProducts),
                            const Divider(height: 1),
                            _QuickAction(icon: Icons.bar_chart_rounded, title: 'Open reports', subtitle: 'Sales and GST summaries', onTap: onOpenReports),
                          ],
                        ),
                      );
                      if (!wide) {
                        return Column(children: [trend, const SizedBox(height: 16), actions]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: trend),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: actions),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _Panel(
                    title: 'Low-stock alerts',
                    subtitle: 'Active products at or below ${threshold.toStringAsFixed(threshold == threshold.roundToDouble() ? 0 : 1)} units',
                    trailing: TextButton(onPressed: onOpenProducts, child: const Text('Inventory')),
                    child: lowStock.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                                const SizedBox(width: 12),
                                const Expanded(child: Text('All active products are above the low-stock threshold.')),
                              ],
                            ),
                          )
                        : Column(
                            children: lowStock.take(6).map((product) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.errorContainer,
                                foregroundColor: theme.colorScheme.onErrorContainer,
                                child: const Icon(Icons.inventory_2_outlined),
                              ),
                              title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(product.category),
                              trailing: Text(
                                '${product.stock.toStringAsFixed(product.stock == product.stock.roundToDouble() ? 0 : 1)} ${product.unit.name}',
                                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                              ),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _Panel(
                    title: 'Recent bills',
                    subtitle: 'Latest saved transactions',
                    trailing: TextButton(onPressed: onOpenReports, child: const Text('All reports')),
                    child: allSales.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('Your saved invoices will appear here.'),
                          )
                        : Column(
                            children: allSales.take(5).map((sale) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                foregroundColor: theme.colorScheme.onPrimaryContainer,
                                child: const Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(sale.customerName.trim().isEmpty ? 'Walk-in customer' : sale.customerName,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${sale.id} · ${DateFormat('d MMM, h:mm a').format(sale.date.toLocal())}'),
                              trailing: Text(currency.format(sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DayRevenue {
  final DateTime day;
  final double revenue;
  const _DayRevenue(this.day, this.revenue);
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                Icon(Icons.arrow_outward, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 5),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _Panel({required this.title, required this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

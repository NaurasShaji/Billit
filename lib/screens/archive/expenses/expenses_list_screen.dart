import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/expense.dart';
import '../../../services/expense_export_service.dart';
import '../../../services/expense_logic.dart';
import 'add_expense_screen.dart';
import '../../../data/database.dart';

enum _Sort { newest, oldest, highest, lowest }

enum _ExportFormat { csv, pdf }

/// Browse expenses by period, see where the money went, and export.
class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final TextEditingController _search = TextEditingController();
  ExpensePeriod _period = ExpensePeriod.thisMonth;
  DateTimeRange? _custom;
  String _query = '';
  String? _category; // display label of the category being filtered
  _Sort _sort = _Sort.newest;
  bool _showAllCategories = false;
  bool _exporting = false;

  static const _palette = <Color>[
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFFE65100),
    Color(0xFF8E24AA),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF6D4C41),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  ({DateTime start, DateTime end})? get _range {
    if (_period == ExpensePeriod.custom && _custom != null) {
      final e = _custom!.end;
      return (
        start: DateTime(_custom!.start.year, _custom!.start.month,
            _custom!.start.day),
        end: DateTime(e.year, e.month, e.day + 1),
      );
    }
    return ExpenseLogic.rangeFor(_period, DateTime.now());
  }

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case ExpensePeriod.today:
        return DateFormat('EEEE, d MMM yyyy').format(now);
      case ExpensePeriod.thisMonth:
        return DateFormat('MMMM yyyy').format(now);
      case ExpensePeriod.lastMonth:
        return DateFormat('MMMM yyyy')
            .format(DateTime(now.year, now.month - 1, 1));
      case ExpensePeriod.thisYear:
        return '${now.year}';
      case ExpensePeriod.all:
        return 'All time';
      case ExpensePeriod.custom:
        final c = _custom;
        if (c == null) return 'Custom range';
        final f = DateFormat('d MMM yyyy');
        return '${f.format(c.start)} - ${f.format(c.end)}';
    }
  }

  String get _fileTag {
    final now = DateTime.now();
    switch (_period) {
      case ExpensePeriod.today:
        return DateFormat('yyyyMMdd').format(now);
      case ExpensePeriod.thisMonth:
        return DateFormat('yyyy-MM').format(now);
      case ExpensePeriod.lastMonth:
        return DateFormat('yyyy-MM')
            .format(DateTime(now.year, now.month - 1, 1));
      case ExpensePeriod.thisYear:
        return '${now.year}';
      case ExpensePeriod.all:
        return 'all';
      case ExpensePeriod.custom:
        final c = _custom;
        if (c == null) return 'custom';
        final f = DateFormat('yyyyMMdd');
        return '${f.format(c.start)}_to_${f.format(c.end)}';
    }
  }

  String _money(double v) {
    final whole = v == v.roundToDouble();
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: whole ? 0 : 2,
    ).format(v);
  }

  Color _colorFor(String label) {
    var h = 0;
    for (final u in label.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    bool has(List<String> words) => words.any(l.contains);
    if (has(['rent', 'lease'])) return Icons.home_work_outlined;
    if (has(['salary', 'wage', 'staff', 'payroll'])) return Icons.badge_outlined;
    if (has(['electric', 'power'])) return Icons.bolt_outlined;
    if (has(['transport', 'fuel', 'petrol', 'diesel', 'delivery', 'travel'])) {
      return Icons.local_shipping_outlined;
    }
    if (has(['tea', 'food', 'snack', 'lunch', 'meal', 'coffee'])) {
      return Icons.restaurant_outlined;
    }
    if (has(['repair', 'maintenance', 'service'])) return Icons.build_outlined;
    if (has(['market', 'advert', 'promo'])) return Icons.campaign_outlined;
    if (has(['stock', 'purchase', 'inventory'])) return Icons.inventory_2_outlined;
    if (has(['tax', 'gst', 'licence', 'license'])) return Icons.receipt_long_outlined;
    if (has(['water', 'internet', 'phone', 'bill'])) return Icons.water_drop_outlined;
    return Icons.payments_outlined;
  }

  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    if (day == d0) return 'Today';
    if (day == DateTime(d0.year, d0.month, d0.day - 1)) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(day);
  }

  ExpenseLine _line(Expense e) => ExpenseLine(
        id: e.id,
        date: e.date,
        category: e.category,
        amount: e.amount,
        description: e.description,
      );

  String get _shopName => Db.settings
      .get('business_name', defaultValue: '')
      .toString()
      .trim();

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------- actions

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom,
    );
    if (picked != null) {
      setState(() {
        _custom = picked;
        _period = ExpensePeriod.custom;
        _category = null;
      });
    }
  }

  Future<void> _confirmDelete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '${_money(expense.amount)} - ${ExpenseLogic.categoryLabel(expense.category)}'
            '${expense.description.isEmpty ? '' : '\n${expense.description}'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await expense.delete();
      _snack('Expense deleted');
    }
  }

  void _showDetails(Expense expense) {
    final theme = Theme.of(context);
    final label = ExpenseLogic.categoryLabel(expense.category);
    final color = _colorFor(label);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(_iconFor(label), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text(_money(expense.amount),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Date',
                  DateFormat('EEEE, d MMM yyyy').format(expense.date)),
              _detailRow(
                  'Note',
                  expense.description.trim().isEmpty
                      ? 'No description'
                      : expense.description.trim()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete expense'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(expense);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> _export(
    _ExportFormat format,
    List<ExpenseLine> lines, {
    required bool share,
  }) async {
    if (lines.isEmpty) {
      _snack('Nothing to export for this view');
      return;
    }
    setState(() => _exporting = true);
    try {
      final isCsv = format == _ExportFormat.csv;
      final name = 'expenses_$_fileTag.${isCsv ? 'csv' : 'pdf'}';
      final List<int> bytes = isCsv
          ? ExpenseExportService.csvBytes(lines)
          : await ExpenseExportService.pdfBytes(
              lines: lines,
              periodLabel: _periodLabel,
              shopName: _shopName,
            );
      if (share) {
        await ExpenseExportService.share(
            name, bytes, isCsv ? 'text/csv' : 'application/pdf');
      } else {
        final saved = await ExpenseExportService.save(name, bytes);
        _snack(saved ? 'Saved $name' : 'Export cancelled');
      }
    } catch (e) {
      _snack('Could not export: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportSheet(List<ExpenseLine> lines) {
    final theme = Theme.of(context);
    Widget option(_ExportFormat f, IconData icon, String title, String sub) {
      return ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                Navigator.pop(context);
                _export(f, lines, share: true);
              },
            ),
            IconButton(
              tooltip: 'Save to device',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () {
                Navigator.pop(context);
                _export(f, lines, share: false);
              },
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Export ${lines.length} ${lines.length == 1 ? 'expense' : 'expenses'}'
                  ' (${_money(ExpenseLogic.total(lines))})\n$_periodLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            option(_ExportFormat.csv, Icons.table_chart_outlined,
                'Spreadsheet (CSV)', 'Opens in Excel or Google Sheets'),
            option(_ExportFormat.pdf, Icons.picture_as_pdf_outlined,
                'PDF report', 'Summary, categories and full list'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntityStore<Expense>>(
      valueListenable: Db.expenses.listenable(),
      builder: (context, box, _) => _buildScaffold(context, box),
    );
  }

  Widget _buildScaffold(BuildContext context, EntityStore<Expense> box) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final range = _range;
    final inPeriod = box.values.where((e) {
      if (range == null) return true;
      return !e.date.isBefore(range.start) && e.date.isBefore(range.end);
    }).toList();
    final periodLines = inPeriod.map(_line).toList();
    final categories = ExpenseLogic.categoryTotals(periodLines);

    // A category filter from a previous period may no longer exist.
    final activeCategory =
        categories.any((c) => c.category == _category) ? _category : null;

    final byId = {for (final e in inPeriod) e.id: e};
    final visible = periodLines.where((l) {
      if (activeCategory != null &&
          ExpenseLogic.categoryLabel(l.category) != activeCategory) {
        return false;
      }
      return ExpenseLogic.matches(l, _query);
    }).toList();

    final filtered = activeCategory != null || _query.trim().isNotEmpty;
    final periodTotal = ExpenseLogic.total(periodLines);
    final visibleTotal = ExpenseLogic.total(visible);

    // Rows: day headers + entries (date sorts) or a flat list (amount sorts).
    final rows = <Object>[]; // DayGroup header marker or ExpenseLine
    if (_sort == _Sort.newest || _sort == _Sort.oldest) {
      var groups = ExpenseLogic.groupByDay(visible);
      if (_sort == _Sort.oldest) groups = groups.reversed.toList();
      for (final g in groups) {
        rows.add(g);
        final entries = [...g.entries]..sort((a, b) => _sort == _Sort.newest
            ? b.date.compareTo(a.date)
            : a.date.compareTo(b.date));
        rows.addAll(entries);
      }
    } else {
      final sorted = [...visible]..sort((a, b) => _sort == _Sort.highest
          ? b.amount.compareTo(a.amount)
          : a.amount.compareTo(b.amount));
      rows.addAll(sorted);
    }

    final top = <Widget>[
      _periodChips(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Text(_periodLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ),
      _summaryCard(
        theme,
        total: filtered ? visibleTotal : periodTotal,
        count: visible.length,
        filtered: filtered,
        periodTotal: periodTotal,
        periodCount: periodLines.length,
      ),
      if (categories.isNotEmpty) _categoryCard(theme, categories, activeCategory),
      _searchRow(theme),
      if (activeCategory != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(activeCategory),
              onDeleted: () => setState(() => _category = null),
            ),
          ),
        ),
    ];

    Widget body;
    if (periodLines.isEmpty) {
      body = ListView(children: [
        ...top.take(2),
        _emptyState(theme, noData: true),
      ]);
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: top.length + (rows.isEmpty ? 1 : rows.length),
        itemBuilder: (context, i) {
          if (i < top.length) return top[i];
          if (rows.isEmpty) return _emptyState(theme, noData: false);
          final row = rows[i - top.length];
          if (row is DayGroup) return _dayHeader(theme, row);
          final line = row as ExpenseLine;
          return _entryTile(theme, line, byId[line.id]);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: visible.isEmpty ? null : () => _showExportSheet(visible),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: body,
    );
  }

  Widget _periodChips() {
    Widget chip(ExpensePeriod p, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _period == p,
            onSelected: (_) {
              if (p == ExpensePeriod.custom) {
                _pickCustomRange();
              } else {
                setState(() {
                  _period = p;
                  _category = null;
                });
              }
            },
          ),
        );
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        children: [
          chip(ExpensePeriod.today, 'Today'),
          chip(ExpensePeriod.thisMonth, 'This month'),
          chip(ExpensePeriod.lastMonth, 'Last month'),
          chip(ExpensePeriod.thisYear, 'This year'),
          chip(ExpensePeriod.all, 'All time'),
          chip(ExpensePeriod.custom, 'Custom'),
        ],
      ),
    );
  }

  Widget _summaryCard(
    ThemeData theme, {
    required double total,
    required int count,
    required bool filtered,
    required double periodTotal,
    required int periodCount,
  }) {
    final scheme = theme.colorScheme;
    final avg = count == 0 ? 0.0 : total / count;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(filtered ? 'Matching expenses' : 'Total spent',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(_money(total),
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 4,
              children: [
                _miniStat(theme, 'Entries', '$count'),
                _miniStat(theme, 'Average', _money(avg)),
                if (filtered)
                  _miniStat(theme, 'Whole period',
                      '${_money(periodTotal)} ($periodCount)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value) {
    final c = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: c.withValues(alpha: 0.75))),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: c)),
      ],
    );
  }

  Widget _categoryCard(
      ThemeData theme, List<CategoryTotal> categories, String? active) {
    final scheme = theme.colorScheme;
    final shown =
        _showAllCategories ? categories : categories.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where the money went',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final c in shown)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(
                    () => _category = active == c.category ? null : c.category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Opacity(
                    opacity: active == null || active == c.category ? 1 : 0.45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium),
                            ),
                            Text(
                                '${_money(c.total)}  \u2022  ${(c.share * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: c.share,
                            minHeight: 7,
                            color: _colorFor(c.category),
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (categories.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllCategories = !_showAllCategories),
                  child: Text(_showAllCategories
                      ? 'Show less'
                      : 'Show all ${categories.length}'),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _searchRow(ThemeData theme) {
    const labels = {
      _Sort.newest: 'Newest first',
      _Sort.oldest: 'Oldest first',
      _Sort.highest: 'Highest amount',
      _Sort.lowest: 'Lowest amount',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search note, category or amount',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final e in labels.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(ThemeData theme, DayGroup g) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(_dayLabel(g.day),
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ),
          Text(_money(g.total),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _entryTile(ThemeData theme, ExpenseLine line, Expense? expense) {
    final scheme = theme.colorScheme;
    final label = ExpenseLogic.categoryLabel(line.category);
    final color = _colorFor(label);
    final hasNote = line.description.trim().isNotEmpty;
    final showDate = _sort == _Sort.highest || _sort == _Sort.lowest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: expense == null ? null : () => _showDetails(expense),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(_iconFor(label), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hasNote ? line.description.trim() : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        hasNote
                            ? '$label${showDate ? ' \u2022 ${DateFormat('d MMM').format(line.date)}' : ''}'
                            : (showDate
                                ? DateFormat('d MMM yyyy').format(line.date)
                                : ' '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_money(line.amount),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, {required bool noData}) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(noData ? Icons.receipt_long_outlined : Icons.search_off,
              size: 60, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
              noData
                  ? 'No expenses in this period'
                  : 'Nothing matches your search',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
              noData
                  ? 'Pick another period above, or tap Add expense.'
                  : 'Try a different word or clear the category filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

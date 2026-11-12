/// Pure helpers for viewing and exporting expenses. No Flutter or Hive imports
/// so they can be unit tested on their own.
library;

/// The few facts about an expense the viewer and exports need.
class ExpenseLine {
  const ExpenseLine({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
  });

  final String id;
  final DateTime date;
  final String category;
  final double amount;
  final String description;
}

class CategoryTotal {
  const CategoryTotal(this.category, this.total, this.count, this.share);

  final String category;
  final double total;
  final int count;

  /// 0..1 share of the overall total.
  final double share;
}

class DayGroup {
  const DayGroup(this.day, this.entries, this.total);

  final DateTime day;
  final List<ExpenseLine> entries;
  final double total;
}

enum ExpensePeriod { today, thisMonth, lastMonth, thisYear, all, custom }

class ExpenseLogic {
  ExpenseLogic._();

  /// Payroll saves salaries as "Salary-Monthly" / "Salary-Daily"; show those
  /// in a friendlier way.
  static String categoryLabel(String category) {
    switch (category) {
      case 'Salary-Monthly':
        return 'Salary (Monthly)';
      case 'Salary-Daily':
        return 'Salary (Daily)';
      default:
        return category.trim().isEmpty ? 'Uncategorised' : category.trim();
    }
  }

  /// Start (inclusive) and end (exclusive) of [period]. Null for
  /// [ExpensePeriod.all] and [ExpensePeriod.custom] (the caller supplies it).
  static ({DateTime start, DateTime end})? rangeFor(
    ExpensePeriod period,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ExpensePeriod.today:
        return (start: today, end: DateTime(now.year, now.month, now.day + 1));
      case ExpensePeriod.thisMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case ExpensePeriod.lastMonth:
        return (
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 1),
        );
      case ExpensePeriod.thisYear:
        return (
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case ExpensePeriod.all:
      case ExpensePeriod.custom:
        return null;
    }
  }

  static double total(Iterable<ExpenseLine> lines) =>
      lines.fold(0.0, (sum, e) => sum + e.amount);

  /// Totals per category, biggest first.
  static List<CategoryTotal> categoryTotals(List<ExpenseLine> lines) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final e in lines) {
      final label = categoryLabel(e.category);
      sums[label] = (sums[label] ?? 0) + e.amount;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final grand = total(lines);
    final out = [
      for (final k in sums.keys)
        CategoryTotal(
          k,
          sums[k]!,
          counts[k]!,
          grand <= 0 ? 0 : sums[k]! / grand,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return out;
  }

  /// Groups entries by calendar day, newest day first.
  static List<DayGroup> groupByDay(List<ExpenseLine> lines) {
    final byDay = <DateTime, List<ExpenseLine>>{};
    for (final e in lines) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      byDay.putIfAbsent(day, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) DayGroup(d, byDay[d]!, total(byDay[d]!))];
  }

  static bool matches(ExpenseLine e, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.description.toLowerCase().contains(q) ||
        categoryLabel(e.category).toLowerCase().contains(q) ||
        e.amount.toStringAsFixed(2).contains(q);
  }

  /// Quotes a CSV cell. Text that a spreadsheet could treat as a formula
  /// (starting with = + - @) gets a leading apostrophe so it stays plain text.
  static String csvCell(Object? value, {bool text = true}) {
    var s = (value ?? '').toString();
    if (text && s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String isoDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// CSV of [lines], oldest first, with a total row at the end.
  static String buildCsv(List<ExpenseLine> lines) {
    final sorted = [...lines]..sort((a, b) => a.date.compareTo(b.date));
    final rows = <String>[
      [
        'Date',
        'Category',
        'Description',
        'Amount',
      ].map((h) => csvCell(h, text: false)).join(','),
      for (final e in sorted)
        [
          csvCell(isoDate(e.date), text: false),
          csvCell(categoryLabel(e.category)),
          csvCell(e.description),
          csvCell(e.amount.toStringAsFixed(2), text: false),
        ].join(','),
      [
        csvCell('', text: false),
        csvCell('', text: false),
        csvCell('Total', text: false),
        csvCell(total(sorted).toStringAsFixed(2), text: false),
      ].join(','),
    ];
    return rows.join('\r\n');
  }
}

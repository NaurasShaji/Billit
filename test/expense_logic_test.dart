import 'package:flutter_test/flutter_test.dart';
import 'package:billit/services/expense_logic.dart';

ExpenseLine _e(String id, DateTime date, String cat, double amt,
        [String desc = '']) =>
    ExpenseLine(
        id: id, date: date, category: cat, amount: amt, description: desc);

void main() {
  group('period ranges', () {
    test('this month and last month handle January', () {
      final now = DateTime(2026, 1, 15);
      final cur = ExpenseLogic.rangeFor(ExpensePeriod.thisMonth, now)!;
      final prev = ExpenseLogic.rangeFor(ExpensePeriod.lastMonth, now)!;
      expect(cur.start, DateTime(2026, 1, 1));
      expect(cur.end, DateTime(2026, 2, 1));
      expect(prev.start, DateTime(2025, 12, 1));
      expect(prev.end, DateTime(2026, 1, 1));
    });

    test('today runs midnight to midnight, also at month end', () {
      final r = ExpenseLogic.rangeFor(
          ExpensePeriod.today, DateTime(2026, 12, 31, 18, 30))!;
      expect(r.start, DateTime(2026, 12, 31));
      expect(r.end, DateTime(2027, 1, 1));
    });

    test('all time and custom have no preset range', () {
      expect(ExpenseLogic.rangeFor(ExpensePeriod.all, DateTime(2026, 5, 1)),
          null);
      expect(ExpenseLogic.rangeFor(ExpensePeriod.custom, DateTime(2026, 5, 1)),
          null);
    });
  });

  group('summaries', () {
    final lines = [
      _e('1', DateTime(2026, 11, 1, 9), 'Rent', 10000),
      _e('2', DateTime(2026, 11, 1, 15), 'Tea', 50),
      _e('3', DateTime(2026, 11, 3), 'Salary-Monthly', 15000),
      _e('4', DateTime(2026, 11, 3), 'Tea', 70),
    ];

    test('category totals are sorted biggest first with shares', () {
      final t = ExpenseLogic.categoryTotals(lines);
      expect(t.map((c) => c.category).toList(),
          ['Salary (Monthly)', 'Rent', 'Tea']);
      expect(t.last.total, 120.0);
      expect(t.last.count, 2);
      expect((t.first.share * 1000).round(), 597); // 15000 / 25120
    });

    test('days are grouped newest first with day totals', () {
      final g = ExpenseLogic.groupByDay(lines);
      expect(g.length, 2);
      expect(g.first.day, DateTime(2026, 11, 3));
      expect(g.first.total, 15070.0);
      expect(g.last.entries.length, 2);
    });

    test('search matches description, category and amount', () {
      final x = _e('9', DateTime(2026, 11, 1), 'Repairs', 499.5, 'Fan motor');
      expect(ExpenseLogic.matches(x, 'motor'), true);
      expect(ExpenseLogic.matches(x, 'repair'), true);
      expect(ExpenseLogic.matches(x, '499'), true);
      expect(ExpenseLogic.matches(x, 'rent'), false);
      expect(ExpenseLogic.matches(x, '  '), true);
    });
  });

  group('csv', () {
    test('has header, rows oldest first, and a total row', () {
      final csv = ExpenseLogic.buildCsv([
        _e('2', DateTime(2026, 11, 3), 'Tea', 70, 'Snacks'),
        _e('1', DateTime(2026, 11, 1), 'Rent', 10000),
      ]);
      final lines = csv.split('\r\n');
      expect(lines.length, 4);
      expect(lines[0], '"Date","Category","Description","Amount"');
      expect(lines[1], '"2026-11-01","Rent","","10000.00"');
      expect(lines[2], '"2026-11-03","Tea","Snacks","70.00"');
      expect(lines[3], '"","","Total","10070.00"');
    });

    test('quotes are escaped and formulas are neutralised', () {
      expect(ExpenseLogic.csvCell('say "hi"'), '"say ""hi"""');
      expect(ExpenseLogic.csvCell('=SUM(A1:A9)'), '"\'=SUM(A1:A9)"');
      expect(ExpenseLogic.csvCell('-5 off'), '"\'-5 off"');
    });
  });
}

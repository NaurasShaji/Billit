import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';
import 'boxes.dart';
import 'loyalty_service.dart';

/// Everything the app knows about one customer, built from saved invoices.
class CustomerSummary {
  CustomerSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.invoices,
    this.loyalty,
  });

  /// `p:<last 10 digits>` for customers with a phone, otherwise `n:<name>`.
  final String id;
  final String name;
  final String phone;

  /// Newest first.
  final List<Sale> invoices;

  /// Null when the loyalty scheme is off or the customer has no phone number.
  final LoyaltyStatus? loyalty;

  bool get hasPhone => LoyaltyLogic.customerKey(phone) != null;
  int get visits => invoices.length;
  double get totalSpent => invoices.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get averageBill => visits == 0 ? 0 : totalSpent / visits;
  DateTime get lastPurchase => invoices.first.date;
  DateTime get firstPurchase => invoices.last.date;
  bool get hasReward => loyalty?.hasReward ?? false;
  String get displayName => name.isNotEmpty ? name : 'Customer $phone';

  String get initial {
    final source = name.isNotEmpty ? name : phone;
    return source.isEmpty
        ? '?'
        : String.fromCharCode(source.runes.first).toUpperCase();
  }

  static final _numericQuery = RegExp(r'^[\d\s+\-]+$');

  /// Matches on name, phone digits (partial is fine) or invoice number.
  bool matches(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (_numericQuery.hasMatch(q)) {
      final digits = q.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty &&
          phone.replaceAll(RegExp(r'\D'), '').contains(digits)) {
        return true;
      }
    }
    return invoices.any((s) => s.id.toLowerCase().contains(q));
  }

  /// Most-bought products across this customer's invoices, best first.
  List<MapEntry<String, double>> topProducts({int limit = 5}) {
    final qty = <String, double>{};
    for (final sale in invoices) {
      for (final item in sale.items) {
        final name = item.productName;
        qty[name] = (qty[name] ?? 0) + item.qty;
      }
    }
    final entries = qty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
}

class CustomerService {
  CustomerService._();

  /// Groups invoices into customers. Customers with a phone number are
  /// identified by it (so "+91 98765 43210" and "9876543210" are one person);
  /// name-only customers are grouped by name; walk-in sales are skipped.
  static List<CustomerSummary> loadAll() {
    final sales = Hive.box<Sale>(Boxes.sales).values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final config = LoyaltyService.config;
    final loyalty = LoyaltyService.statusForAll();

    final groups = <String, List<Sale>>{};
    for (final sale in sales) {
      final phoneKey = LoyaltyLogic.customerKey(sale.customerPhone);
      final name = sale.customerName.trim();
      final String id;
      if (phoneKey != null) {
        id = 'p:$phoneKey';
      } else if (name.isNotEmpty) {
        id = 'n:${name.toLowerCase()}';
      } else {
        continue;
      }
      groups.putIfAbsent(id, () => <Sale>[]).add(sale);
    }

    return groups.entries.map((entry) {
      final list = entry.value; // newest first
      String firstNonEmpty(String Function(Sale) pick) {
        for (final s in list) {
          final v = pick(s).trim();
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      return CustomerSummary(
        id: entry.key,
        name: firstNonEmpty((s) => s.customerName),
        phone: firstNonEmpty((s) => s.customerPhone),
        invoices: list,
        // Customers with a phone but no counted purchases yet still get a card.
        loyalty: config.enabled && entry.key.startsWith('p:')
            ? (loyalty[entry.key.substring(2)] ??
                  LoyaltyStatus(
                    target: config.target,
                    purchases: 0,
                    redeemed: 0,
                  ))
            : null,
      );
    }).toList();
  }
}
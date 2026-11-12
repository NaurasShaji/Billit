/// Pure loyalty-card rules. No Flutter or Hive imports so they can be unit
/// tested on their own; [LoyaltyService] connects them to the app's data.
///
/// How the scheme works:
///  * A customer is identified by phone number (last 10 digits).
///  * Every invoice of at least [LoyaltyConfig.minBill] counts as one purchase.
///  * Every [LoyaltyConfig.target] purchases earns one reward.
///  * The reward (chosen by the owner) is given on a later bill.
///
/// Everything is derived from the saved invoices, so deleting or editing an
/// invoice automatically corrects the customer's progress.
library;

/// What a customer receives when they earn a reward. The owner picks one.
enum LoyaltyRewardType {
  /// Percentage off the bill.
  percent,

  /// Fixed rupee amount off the bill.
  amount,

  /// One or more units of a catalogue product added to the bill for free.
  freeProduct,

  /// Anything else the owner wants to hand over (free gift, free delivery...).
  /// Shown to the cashier as text; the bill itself is unchanged.
  custom,
}

class LoyaltyConfig {
  const LoyaltyConfig({
    this.enabled = false,
    this.target = 5,
    this.rewardType = LoyaltyRewardType.percent,
    this.rewardValue = 10,
    this.productId = '',
    this.productName = '',
    this.productQty = 1,
    this.customText = '',
    this.minBill = 0,
    this.countHistory = false,
    this.startDate,
  });

  final bool enabled;

  /// Purchases needed to earn one reward.
  final int target;
  final LoyaltyRewardType rewardType;

  /// Percent (0-100) or a fixed rupee amount, depending on [rewardType].
  final double rewardValue;

  /// Free-product reward: which product, its name (for display) and quantity.
  final String productId;
  final String productName;
  final double productQty;

  /// Custom reward description, e.g. "Free gift wrap".
  final String customText;

  /// Invoices below this total do not count as a purchase.
  final double minBill;

  /// When false, only invoices on/after [startDate] count.
  final bool countHistory;
  final DateTime? startDate;

  LoyaltyConfig copyWith({
    bool? enabled,
    int? target,
    LoyaltyRewardType? rewardType,
    double? rewardValue,
    String? productId,
    String? productName,
    double? productQty,
    String? customText,
    double? minBill,
    bool? countHistory,
    DateTime? startDate,
  }) => LoyaltyConfig(
    enabled: enabled ?? this.enabled,
    target: target ?? this.target,
    rewardType: rewardType ?? this.rewardType,
    rewardValue: rewardValue ?? this.rewardValue,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    productQty: productQty ?? this.productQty,
    customText: customText ?? this.customText,
    minBill: minBill ?? this.minBill,
    countHistory: countHistory ?? this.countHistory,
    startDate: startDate ?? this.startDate,
  );

  /// True for rewards that reduce the bill (percent / flat amount).
  bool get isDiscount =>
      rewardType == LoyaltyRewardType.percent ||
      rewardType == LoyaltyRewardType.amount;

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Short text such as "10% off", "\u20B950 off", "Free Rose bouquet" or the
  /// owner's own wording for a custom reward.
  String get rewardLabel {
    switch (rewardType) {
      case LoyaltyRewardType.percent:
        return '${_num(rewardValue)}% off';
      case LoyaltyRewardType.amount:
        return '\u20B9${_num(rewardValue)} off';
      case LoyaltyRewardType.freeProduct:
        final name = productName.isEmpty ? 'product' : productName;
        return productQty == 1
            ? 'Free $name'
            : 'Free ${_num(productQty)} \u00D7 $name';
      case LoyaltyRewardType.custom:
        return customText.trim().isEmpty ? 'Loyalty gift' : customText.trim();
    }
  }

  /// Discount (in rupees) this reward gives on a bill with [subtotal].
  /// Never more than the bill itself. Zero for non-discount rewards.
  double discountFor(double subtotal) {
    if (subtotal <= 0 || !isDiscount) return 0;
    final raw = rewardType == LoyaltyRewardType.percent
        ? subtotal * rewardValue / 100
        : rewardValue;
    final capped = raw > subtotal ? subtotal : raw;
    return (capped * 100).roundToDouble() / 100;
  }
}

/// The minimum facts about an invoice that loyalty needs.
class LoyaltyPurchase {
  const LoyaltyPurchase({
    required this.invoiceId,
    required this.phone,
    required this.amount,
    required this.date,
  });

  final String invoiceId;
  final String phone;
  final double amount;
  final DateTime date;
}

class LoyaltyStatus {
  const LoyaltyStatus({
    required this.target,
    required this.purchases,
    required this.redeemed,
  });

  final int target;

  /// Qualifying purchases counted so far.
  final int purchases;

  /// Rewards already used.
  final int redeemed;

  int get earned => target <= 0 ? 0 : purchases ~/ target;

  /// Rewards earned but not yet used.
  int get available {
    final n = earned - redeemed;
    return n < 0 ? 0 : n;
  }

  bool get hasReward => available > 0;

  /// Stamps on the current card (0 .. target-1).
  int get progress => target <= 0 ? 0 : purchases % target;

  /// Purchases still needed to earn the next reward.
  int get toNextReward => target <= 0 ? 0 : target - progress;
}

class LoyaltyLogic {
  LoyaltyLogic._();

  /// Normalises a phone number to the last 10 digits so "+91 98765 43210",
  /// "098765 43210" and "9876543210" are the same customer. Returns null when
  /// there are too few digits to identify a customer.
  static String? customerKey(String phone) {
    final buf = StringBuffer();
    for (final unit in phone.codeUnits) {
      if (unit >= 48 && unit <= 57) buf.writeCharCode(unit);
    }
    final digits = buf.toString();
    if (digits.length < 7) return null;
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static bool counts(LoyaltyPurchase p, LoyaltyConfig c) {
    if (p.amount < c.minBill) return false;
    if (!c.countHistory) {
      final start = c.startDate;
      if (start != null && p.date.isBefore(start)) return false;
    }
    return true;
  }

  /// One pass over all invoices -> loyalty status per customer key.
  /// [redeemedInvoiceIds] are invoices on which a reward was applied.
  static Map<String, LoyaltyStatus> computeAll(
    Iterable<LoyaltyPurchase> purchases,
    LoyaltyConfig config,
    Set<String> redeemedInvoiceIds,
  ) {
    final bought = <String, int>{};
    final used = <String, int>{};
    for (final p in purchases) {
      final key = customerKey(p.phone);
      if (key == null) continue;
      if (counts(p, config)) bought[key] = (bought[key] ?? 0) + 1;
      if (redeemedInvoiceIds.contains(p.invoiceId)) {
        used[key] = (used[key] ?? 0) + 1;
      }
    }
    final keys = {...bought.keys, ...used.keys};
    return {
      for (final k in keys)
        k: LoyaltyStatus(
          target: config.target,
          purchases: bought[k] ?? 0,
          redeemed: used[k] ?? 0,
        ),
    };
  }
}
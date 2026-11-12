import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';
import 'boxes.dart';
import 'loyalty_logic.dart';

export 'loyalty_logic.dart';

/// Connects [LoyaltyLogic] to the saved invoices and app settings.
///
/// Settings live in the `app_settings` box, which the Google Drive backup
/// already saves and restores, so loyalty setup and used rewards are backed up
/// with everything else.
class LoyaltyService {
  LoyaltyService._();

  static const _kEnabled = 'loyalty_enabled';
  static const _kTarget = 'loyalty_target';
  static const _kType = 'loyalty_reward_type';
  static const _kValue = 'loyalty_reward_value';
  static const _kProductId = 'loyalty_product_id';
  static const _kProductName = 'loyalty_product_name';
  static const _kProductQty = 'loyalty_product_qty';
  static const _kCustomText = 'loyalty_custom_text';
  static const _kMinBill = 'loyalty_min_bill';
  static const _kHistory = 'loyalty_count_history';
  static const _kStart = 'loyalty_start';
  static const _kRedemptions = 'loyalty_redemptions';

  static Box<dynamic> get _settings => Hive.box<dynamic>('app_settings');

  // ---------------------------------------------------------------- config

  static LoyaltyRewardType _typeFromString(String v) {
    switch (v) {
      case 'amount':
        return LoyaltyRewardType.amount;
      case 'product':
        return LoyaltyRewardType.freeProduct;
      case 'custom':
        return LoyaltyRewardType.custom;
      default:
        return LoyaltyRewardType.percent;
    }
  }

  static String _typeToString(LoyaltyRewardType t) {
    switch (t) {
      case LoyaltyRewardType.percent:
        return 'percent';
      case LoyaltyRewardType.amount:
        return 'amount';
      case LoyaltyRewardType.freeProduct:
        return 'product';
      case LoyaltyRewardType.custom:
        return 'custom';
    }
  }

  static LoyaltyConfig get config {
    final s = _settings;
    final start =
        DateTime.tryParse(s.get(_kStart, defaultValue: '').toString());
    final productId = s.get(_kProductId, defaultValue: '').toString();
    // Prefer the product's current name; fall back to the name saved with the
    // reward if the product has since been deleted.
    var productName = s.get(_kProductName, defaultValue: '').toString();
    if (productId.isNotEmpty) {
      final product = Hive.box<Product>(Boxes.products).get(productId);
      if (product != null) productName = product.name;
    }
    return LoyaltyConfig(
      enabled: s.get(_kEnabled, defaultValue: false) == true,
      target: (s.get(_kTarget, defaultValue: 5) as num)
          .toInt()
          .clamp(1, 100)
          .toInt(),
      rewardType:
          _typeFromString(s.get(_kType, defaultValue: 'percent').toString()),
      rewardValue: (s.get(_kValue, defaultValue: 10) as num).toDouble(),
      productId: productId,
      productName: productName,
      productQty: (s.get(_kProductQty, defaultValue: 1) as num).toDouble(),
      customText: s.get(_kCustomText, defaultValue: '').toString(),
      minBill: (s.get(_kMinBill, defaultValue: 0) as num).toDouble(),
      countHistory: s.get(_kHistory, defaultValue: false) == true,
      startDate: start,
    );
  }

  static bool get enabled => config.enabled;

  static Future<void> saveConfig(LoyaltyConfig next) async {
    final s = _settings;
    final wasEnabled = s.get(_kEnabled, defaultValue: false) == true;
    await s.put(_kEnabled, next.enabled);
    await s.put(_kTarget, next.target);
    await s.put(_kType, _typeToString(next.rewardType));
    await s.put(_kValue, next.rewardValue);
    await s.put(_kProductId, next.productId);
    await s.put(_kProductName, next.productName);
    await s.put(_kProductQty, next.productQty);
    await s.put(_kCustomText, next.customText.trim());
    await s.put(_kMinBill, next.minBill);
    await s.put(_kHistory, next.countHistory);
    // When the scheme is switched on, only purchases from that moment count
    // (unless the owner chose to credit past purchases too).
    final hasStart = s.get(_kStart, defaultValue: '').toString().isNotEmpty;
    if (next.enabled && (!wasEnabled || !hasStart)) {
      await s.put(_kStart, DateTime.now().toIso8601String());
    }
  }

  // ----------------------------------------------------------- redemptions

  /// invoice id -> description of the reward given on that invoice.
  static Map<String, String> redeemedLabels() {
    final raw = _settings.get(_kRedemptions, defaultValue: '').toString();
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Remembers that [invoiceId] used a loyalty reward, described by [label].
  static Future<void> recordRedemption(String invoiceId, String label) async {
    final map = redeemedLabels();
    map[invoiceId] = label;
    await _settings.put(_kRedemptions, jsonEncode(map));
  }

  /// Removes redemption metadata when its invoice is deleted.
  static Future<void> removeRedemption(String invoiceId) async {
    final map = redeemedLabels();
    if (!map.containsKey(invoiceId)) return;
    map.remove(invoiceId);
    await _settings.put(_kRedemptions, jsonEncode(map));
  }

  // ---------------------------------------------------------------- status

  static Iterable<LoyaltyPurchase> _purchases(Iterable<Sale> sales) =>
      sales.map(
        (s) => LoyaltyPurchase(
          invoiceId: s.id,
          phone: s.customerPhone,
          amount: s.totalAmount,
          date: s.date,
        ),
      );

  /// Loyalty status for every customer with a phone number.
  /// Empty when the scheme is switched off.
  static Map<String, LoyaltyStatus> statusForAll() {
    final c = config;
    if (!c.enabled) return {};
    return LoyaltyLogic.computeAll(
      _purchases(Hive.box<Sale>(Boxes.sales).values),
      c,
      redeemedLabels().keys.toSet(),
    );
  }

  /// Status for one customer, or null when the scheme is off or [phone] is
  /// too short to identify a customer.
  static LoyaltyStatus? statusFor(String phone) {
    final c = config;
    if (!c.enabled) return null;
    final key = LoyaltyLogic.customerKey(phone);
    if (key == null) return null;
    final mine = Hive.box<Sale>(Boxes.sales)
        .values
        .where((s) => LoyaltyLogic.customerKey(s.customerPhone) == key);
    final all = LoyaltyLogic.computeAll(
      _purchases(mine),
      c,
      redeemedLabels().keys.toSet(),
    );
    return all[key] ??
        LoyaltyStatus(target: c.target, purchases: 0, redeemed: 0);
  }

  // -------------------------------------------------------------- messages

  static String get shopName {
    final name =
        _settings.get('business_name', defaultValue: '').toString().trim();
    if (name.isNotEmpty) return name;
    return _settings.get('app_name', defaultValue: 'Billit').toString();
  }

  /// Text for the optional WhatsApp message to the customer.
  static String rewardMessage(
      {required String name, required LoyaltyConfig c}) {
    final who = name.trim().isEmpty ? 'there' : name.trim();
    return 'Hi $who, thank you for being a loyal customer of $shopName! '
        'You have earned a loyalty reward: ${c.rewardLabel}. '
        'Claim it on your next purchase.';
  }
}
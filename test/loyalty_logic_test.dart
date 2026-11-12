import 'package:flutter_test/flutter_test.dart';
import 'package:billit/services/loyalty_logic.dart';

LoyaltyPurchase _p(String id, String phone, {double amount = 100, DateTime? at}) =>
    LoyaltyPurchase(
      invoiceId: id,
      phone: phone,
      amount: amount,
      date: at ?? DateTime(2026, 11, 1),
    );

void main() {
  group('customerKey', () {
    test('matches the same number written differently', () {
      expect(LoyaltyLogic.customerKey('9876543210'), '9876543210');
      expect(LoyaltyLogic.customerKey('+91 98765 43210'), '9876543210');
      expect(LoyaltyLogic.customerKey('098765-43210'), '9876543210');
    });

    test('returns null when too short to identify a customer', () {
      expect(LoyaltyLogic.customerKey(''), null);
      expect(LoyaltyLogic.customerKey('12345'), null);
    });
  });

  group('computeAll', () {
    const cfg = LoyaltyConfig(enabled: true, target: 3, countHistory: true);

    test('counts purchases and earns a reward every `target` purchases', () {
      final purchases = [
        for (var i = 1; i <= 7; i++) _p('INV-$i', '9876543210'),
      ];
      final s = LoyaltyLogic.computeAll(purchases, cfg, {})['9876543210']!;
      expect(s.purchases, 7);
      expect(s.earned, 2);
      expect(s.available, 2);
      expect(s.progress, 1);
      expect(s.toNextReward, 2);
    });

    test('hitting the target exactly unlocks one reward', () {
      final two = [_p('1', '9876543210'), _p('2', '9876543210')];
      final three = [...two, _p('3', '9876543210')];
      expect(LoyaltyLogic.computeAll(two, cfg, {})['9876543210']!.hasReward,
          false);
      expect(LoyaltyLogic.computeAll(three, cfg, {})['9876543210']!.hasReward,
          true);
    });

    test('a redeemed reward is no longer available', () {
      final purchases = [
        for (var i = 1; i <= 4; i++) _p('INV-$i', '9876543210'),
      ];
      final s =
          LoyaltyLogic.computeAll(purchases, cfg, {'INV-4'})['9876543210']!;
      expect(s.earned, 1);
      expect(s.redeemed, 1);
      expect(s.available, 0);
    });

    test('deleting the invoice that used a reward gives the reward back', () {
      final withoutRedeemingInvoice = [
        _p('INV-1', '9876543210'),
        _p('INV-2', '9876543210'),
        _p('INV-3', '9876543210'),
      ];
      // INV-4 (which used the reward) is gone, but still listed as redeemed.
      final s = LoyaltyLogic.computeAll(
          withoutRedeemingInvoice, cfg, {'INV-4'})['9876543210']!;
      expect(s.available, 1);
    });

    test('same customer in different phone formats is one customer', () {
      final purchases = [
        _p('1', '9876543210'),
        _p('2', '+91 9876543210'),
        _p('3', '09876543210'),
      ];
      final all = LoyaltyLogic.computeAll(purchases, cfg, {});
      expect(all.length, 1);
      expect(all['9876543210']!.available, 1);
    });

    test('customers without a usable phone are skipped', () {
      final all = LoyaltyLogic.computeAll([_p('1', ''), _p('2', '123')], cfg, {});
      expect(all.isEmpty, true);
    });

    test('bills under the minimum do not count', () {
      const withMin =
          LoyaltyConfig(enabled: true, target: 2, minBill: 200, countHistory: true);
      final purchases = [
        _p('1', '9876543210', amount: 150),
        _p('2', '9876543210', amount: 250),
        _p('3', '9876543210', amount: 199.99),
        _p('4', '9876543210', amount: 200),
      ];
      final s = LoyaltyLogic.computeAll(purchases, withMin, {})['9876543210']!;
      expect(s.purchases, 2);
      expect(s.available, 1);
    });

    test('history before the start date is ignored unless countHistory', () {
      final start = DateTime(2026, 11, 10);
      final old = _p('1', '9876543210', at: DateTime(2026, 11, 1));
      final fresh = _p('2', '9876543210', at: DateTime(2026, 11, 11));
      final fromNow = LoyaltyConfig(enabled: true, target: 2, startDate: start);
      final withHistory = fromNow.copyWith(countHistory: true);
      expect(
          LoyaltyLogic.computeAll([old, fresh], fromNow, {})['9876543210']!
              .purchases,
          1);
      expect(
          LoyaltyLogic.computeAll([old, fresh], withHistory, {})['9876543210']!
              .purchases,
          2);
    });
  });

  group('reward discount', () {
    test('percent reward', () {
      const c = LoyaltyConfig(rewardType: LoyaltyRewardType.percent, rewardValue: 10);
      expect(c.discountFor(1250), 125.0);
      expect(c.rewardLabel, '10% off');
    });

    test('flat reward is capped at the bill total', () {
      const c = LoyaltyConfig(rewardType: LoyaltyRewardType.amount, rewardValue: 50);
      expect(c.discountFor(500), 50.0);
      expect(c.discountFor(30), 30.0);
      expect(c.discountFor(0), 0.0);
    });

    test('free product reward gives no discount and has a readable label', () {
      const one = LoyaltyConfig(
        rewardType: LoyaltyRewardType.freeProduct,
        productId: 'p1',
        productName: 'Rose bouquet',
      );
      const two = LoyaltyConfig(
        rewardType: LoyaltyRewardType.freeProduct,
        productId: 'p1',
        productName: 'Rose bouquet',
        productQty: 2,
      );
      expect(one.isDiscount, false);
      expect(one.discountFor(500), 0.0);
      expect(one.rewardLabel, 'Free Rose bouquet');
      expect(two.rewardLabel, 'Free 2 \u00D7 Rose bouquet');
    });

    test('custom reward uses the owner\'s wording', () {
      const c = LoyaltyConfig(
        rewardType: LoyaltyRewardType.custom,
        customText: '  Free gift wrap ',
      );
      expect(c.isDiscount, false);
      expect(c.discountFor(500), 0.0);
      expect(c.rewardLabel, 'Free gift wrap');
      expect(const LoyaltyConfig(rewardType: LoyaltyRewardType.custom).rewardLabel,
          'Loyalty gift');
    });

    test('percent reward rounds to paise', () {
      const c = LoyaltyConfig(rewardType: LoyaltyRewardType.percent, rewardValue: 7.5);
      expect(c.discountFor(133.33), 10.0);
    });
  });
}
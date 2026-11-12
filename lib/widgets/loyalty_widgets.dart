import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/loyalty_service.dart';
import '../services/whatsapp_service.dart';

/// Row of stamps (or a progress bar for big targets) showing how far a
/// customer is towards the next reward.
class LoyaltyStamps extends StatelessWidget {
  const LoyaltyStamps({super.key, required this.status, this.size = 22});

  final LoyaltyStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status.target > 12) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: status.target == 0 ? 0 : status.progress / status.target,
          minHeight: 8,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < status.target; i++)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < status.progress
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: i < status.progress
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
            child: i < status.progress
                ? Icon(Icons.check, size: size * 0.6, color: scheme.onPrimary)
                : null,
          ),
      ],
    );
  }
}

String _rewardLine(LoyaltyConfig config, bool applied, int count) {
  final waiting = count > 1 ? ' ($count rewards waiting)' : '';
  switch (config.rewardType) {
    case LoyaltyRewardType.percent:
    case LoyaltyRewardType.amount:
      return '${config.rewardLabel} on this bill$waiting';
    case LoyaltyRewardType.freeProduct:
      return applied
          ? '${config.rewardLabel} added to the bill'
          : '${config.rewardLabel} with this bill$waiting';
    case LoyaltyRewardType.custom:
      return applied
          ? 'Hand over: ${config.rewardLabel}'
          : '${config.rewardLabel}$waiting';
  }
}

/// Shown in the billing screen under the customer fields.
///
/// * No usable phone number -> short hint.
/// * Reward waiting -> highlighted card with Apply / Remove.
/// * Otherwise -> progress towards the next reward.
class LoyaltyBillingBanner extends StatelessWidget {
  const LoyaltyBillingBanner({
    super.key,
    required this.phone,
    required this.canApply,
    required this.applied,
    required this.onApply,
    required this.onRemove,
  });

  final String phone;

  /// False while the cart is empty (nothing to discount yet).
  final bool canApply;

  /// True once the reward has been applied to the current bill.
  final bool applied;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final config = LoyaltyService.config;
    if (!config.enabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = LoyaltyService.statusFor(phone);

    if (status == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Icon(Icons.card_giftcard_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enter the phone number to track loyalty rewards',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    if (status.hasReward) {
      final count = status.available;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.card_giftcard, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    applied ? 'Loyalty reward applied' : 'Loyalty reward available',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rewardLine(config, applied, count),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (applied)
              TextButton(onPressed: onRemove, child: const Text('Remove'))
            else
              FilledButton(
                onPressed: canApply ? onApply : null,
                child: Text(canApply ? 'Apply' : 'Add items'),
              ),
          ],
        ),
      );
    }

    final next = status.toNextReward;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.loyalty_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  next == 1
                      ? 'This bill unlocks ${config.rewardLabel}!'
                      : '${status.progress} of ${status.target} purchases - '
                          '$next more for ${config.rewardLabel}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LoyaltyStamps(status: status, size: 18),
        ],
      ),
    );
  }
}

/// In-app message shown right after a sale when the customer has just earned a
/// reward. Offers to tell the customer on WhatsApp.
Future<void> showLoyaltyMilestoneDialog(
  BuildContext context, {
  required String customerName,
  required String customerPhone,
  required LoyaltyStatus status,
}) {
  final config = LoyaltyService.config;
  final who = customerName.trim().isEmpty ? 'This customer' : customerName.trim();
  final whatsappPhone = WhatsAppService.normalizePhone(customerPhone);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.celebration_outlined, size: 40, color: scheme.primary),
        title: const Text('Loyalty reward unlocked!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$who has completed ${status.purchases} purchases.\n'
              'Reward: ${config.rewardLabel}\n'
              'Apply it on their next bill.',
              textAlign: TextAlign.center,
            ),
            if (status.available > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${status.available} rewards are waiting for this customer.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (whatsappPhone != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Tell on WhatsApp'),
              onPressed: () async {
                await launchUrl(
                  WhatsAppService.chatUri(
                    whatsappPhone,
                    LoyaltyService.rewardMessage(name: customerName, c: config),
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
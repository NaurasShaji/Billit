import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/customer_service.dart';
import '../../services/loyalty_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/loyalty_widgets.dart';
import '../edit_invoice_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final CustomerSummary customer;

  Future<void> _openWhatsApp(BuildContext context) async {
    final digits = WhatsAppService.normalizePhone(customer.phone);
    if (digits == null) return;
    final config = LoyaltyService.config;
    final message = customer.hasReward
        ? LoyaltyService.rewardMessage(name: customer.name, c: config)
        : 'Hi ${customer.name.isEmpty ? 'there' : customer.name}, '
            'thank you for shopping with ${LoyaltyService.shopName}!';
    final ok = await launchUrl(
      WhatsAppService.chatUri(digits, message),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = NumberFormat.simpleCurrency(locale: 'en_IN');
    final moneyShort =
        NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');
    final canWhatsApp = WhatsAppService.normalizePhone(customer.phone) != null;
    final loyalty = customer.loyalty;
    final config = LoyaltyService.config;
    final top = customer.topProducts();
    final usedRewards = LoyaltyService.redeemedLabels();

    Widget stat(String label, String value) => Container(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(customer.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text(
                  customer.initial,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.displayName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone.isNotEmpty
                          ? customer.phone
                          : 'No phone number',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      'Customer since ${dateFmt.format(customer.firstPurchase)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (canWhatsApp)
                IconButton.filledTonal(
                  tooltip: 'Message on WhatsApp',
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () => _openWhatsApp(context),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stat('Visits', '${customer.visits}'),
              stat('Total spent', moneyShort.format(customer.totalSpent)),
              stat('Average bill', moneyShort.format(customer.averageBill)),
              stat('Last visit', dateFmt.format(customer.lastPurchase)),
            ],
          ),
          if (config.enabled) ...[
            const SizedBox(height: 16),
            _buildLoyaltyCard(context, loyalty, config),
          ],
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Frequently bought',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in top)
                  Chip(
                    label: Text(
                        '${p.key} \u00D7 ${p.value == p.value.roundToDouble() ? p.value.toStringAsFixed(0) : p.value.toStringAsFixed(1)}'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text('Invoices (${customer.visits})',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final sale in customer.invoices)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ListTile(
                title: Text(sale.id,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  DateFormat('d MMM yyyy, hh:mm a').format(sale.date) +
                      (usedRewards.containsKey(sale.id)
                          ? '\nReward used: ${usedRewards[sale.id]}'
                          : ''),
                ),
                trailing: Text(
                  money.format(sale.totalAmount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EditInvoiceScreen(sale: sale, isViewOnly: true),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyCard(
      BuildContext context, LoyaltyStatus? status, LoyaltyConfig config) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget shell(Widget child, {Color? color}) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color == null ? scheme.outlineVariant : scheme.primary,
            ),
          ),
          child: child,
        );

    if (status == null) {
      return shell(
        Row(
          children: [
            Icon(Icons.loyalty_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No phone number saved, so loyalty progress is not tracked. '
                'Add the number on the next bill to start a loyalty card.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return shell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.hasReward ? Icons.card_giftcard : Icons.loyalty_outlined,
                color: status.hasReward
                    ? scheme.onPrimaryContainer
                    : scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.hasReward
                      ? (status.available > 1
                          ? '${status.available} rewards ready: ${config.rewardLabel} each'
                          : 'Reward ready: ${config.rewardLabel}')
                      : 'Loyalty card',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: status.hasReward ? scheme.onPrimaryContainer : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LoyaltyStamps(status: status),
          const SizedBox(height: 10),
          Text(
            '${status.progress} of ${status.target} purchases on this card'
            ' \u2022 ${status.toNextReward} more for the next reward'
            '${status.redeemed > 0 ? ' \u2022 ${status.redeemed} used so far' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: status.hasReward
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (status.hasReward) ...[
            const SizedBox(height: 6),
            Text(
              'It is applied from the Billing screen when this phone number is entered.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ],
        ],
      ),
      color: status.hasReward ? scheme.primaryContainer : null,
    );
  }
}
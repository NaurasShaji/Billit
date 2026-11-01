import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/boxes.dart';

class GstExportsScreen extends StatefulWidget {
  const GstExportsScreen({super.key});

  @override
  State<GstExportsScreen> createState() => _GstExportsScreenState();
}

class _GstExportsScreenState extends State<GstExportsScreen> {
  String _csvCell(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Future<void> _shareCsv(String filename, List<List<Object?>> rows) async {
    try {
      final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
      await Share.shareXFiles(
        [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: filename)],
        subject: filename,
        text: 'Floral Bill accounting export',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export CSV: $e')),
      );
    }
  }

  Future<void> _exportGstSalesRegister() async {
    final sales = Hive.box<Sale>(Boxes.sales).values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final rows = <List<Object?>>[
      ['Invoice No', 'Date', 'Customer', 'Phone', 'Customer GSTIN', 'Subtotal', 'Discount', 'Taxable Value', 'CGST', 'SGST', 'IGST', 'Total GST', 'Invoice Total', 'Payment', 'Tax Type', 'HSN/SAC Summary', 'GST Rate Summary'],
      for (final sale in sales)
        [
          sale.id,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(sale.date.toLocal()),
          sale.customerName,
          sale.customerPhone,
          sale.customerGstin,
          sale.items.fold<double>(0, (sum, item) => sum + item.subtotal).toStringAsFixed(2),
          sale.discount.toStringAsFixed(2),
          (sale.gstEnabled ? sale.taxableAmount : (sale.items.fold<double>(0, (sum, item) => sum + item.subtotal) - sale.discount)).toStringAsFixed(2),
          sale.cgstAmount.toStringAsFixed(2),
          sale.sgstAmount.toStringAsFixed(2),
          sale.igstAmount.toStringAsFixed(2),
          (sale.cgstAmount + sale.sgstAmount + sale.igstAmount).toStringAsFixed(2),
          sale.totalAmount.toStringAsFixed(2),
          sale.payment.name.toUpperCase(),
          sale.gstEnabled ? (sale.interstateSale ? 'IGST' : 'CGST+SGST') : 'No GST',
          sale.items.map((item) => item.hsnCode).where((code) => code.isNotEmpty).toSet().join('; '),
          sale.items.map((item) => item.gstRate ?? 0.0).where((rate) => rate > 0).toSet().join('; '),
        ],
    ];
    await _shareCsv('floralbill_gst_sales_register.csv', rows);
  }

  Future<void> _exportGstItemRegister() async {
    final sales = Hive.box<Sale>(Boxes.sales).values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final products = Hive.box<Product>(Boxes.products);
    final rows = <List<Object?>>[
      ['Invoice No', 'Date', 'Customer', 'Customer GSTIN', 'Product', 'HSN/SAC', 'Quantity', 'Unit Rate', 'Taxable Value', 'GST Rate %', 'CGST', 'SGST', 'IGST', 'Line Total'],
      for (final sale in sales)
        for (final item in sale.items)
          [
            sale.id,
            DateFormat('yyyy-MM-dd').format(sale.date.toLocal()),
            sale.customerName,
            sale.customerGstin,
            products.get(item.productId)?.name ?? 'Unknown Product',
            item.hsnCode.isNotEmpty ? item.hsnCode : (products.get(item.productId)?.hsnCode ?? ''),
            item.qty,
            item.sellingPrice.toStringAsFixed(2),
            (sale.gstEnabled ? item.taxableAmount : item.subtotal).toStringAsFixed(2),
            sale.gstEnabled ? (item.gstRate ?? 0.0).toStringAsFixed(2) : '0.00',
            item.cgstAmount.toStringAsFixed(2),
            item.sgstAmount.toStringAsFixed(2),
            item.igstAmount.toStringAsFixed(2),
            ((sale.gstEnabled ? item.taxableAmount : item.subtotal) + item.cgstAmount + item.sgstAmount + item.igstAmount).toStringAsFixed(2),
          ],
    ];
    await _shareCsv('floralbill_gst_item_register.csv', rows);
  }

  Future<void> _exportExpensesRegister() async {
    final expenses = Hive.box<Expense>(Boxes.expenses).values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final rows = <List<Object?>>[
      ['Expense ID', 'Date', 'Category', 'Description', 'Amount'],
      for (final expense in expenses)
        [
          expense.id,
          DateFormat('yyyy-MM-dd').format(expense.date.toLocal()),
          expense.category,
          expense.description,
          expense.amount.toStringAsFixed(2),
        ],
    ];
    await _shareCsv('floralbill_expenses_register.csv', rows);
  }


  Widget _exportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.file_download_outlined),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST & Accounting Exports')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Export registers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate CSV files for GST filing, reconciliation and expense records.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          _exportOption(
            icon: Icons.receipt_long_outlined,
            title: 'GST Sales Register',
            subtitle: 'Invoice-wise taxable values, GST breakup, payment and customer GSTIN.',
            onTap: _exportGstSalesRegister,
          ),
          _exportOption(
            icon: Icons.table_chart_outlined,
            title: 'GST Item Register',
            subtitle: 'Product-wise HSN/SAC, quantities, taxable values and tax amounts.',
            onTap: _exportGstItemRegister,
          ),
          _exportOption(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Expenses Register',
            subtitle: 'Export expense dates, categories, descriptions and amounts.',
            onTap: _exportExpensesRegister,
          ),
        ],
      ),
    );
  }
}

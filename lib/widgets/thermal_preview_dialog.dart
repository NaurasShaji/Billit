import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../services/boxes.dart';

class ThermalPreviewDialog extends StatelessWidget {
  final Sale sale;

  const ThermalPreviewDialog({
    super.key,
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isSmallScreen ? 8 : 16),
      child: Container(
        width: isSmallScreen ? screenSize.width * 0.95 : screenSize.width * 0.9,
        height:
            isSmallScreen ? screenSize.height * 0.85 : screenSize.height * 0.8,
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.print_outlined, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thermal Printer Preview',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, size: isSmallScreen ? 20 : 24),
                ),
              ],
            ),
            const Divider(),

            // Preview Content
            Expanded(
              child: Container(
                width:
                    isSmallScreen ? 180 : 200, // Simulate thermal printer width
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildThermalPreview(isSmallScreen),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 12 : 16),

            // Action Buttons
            isSmallScreen
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.print),
                          label: const Text('Print Now'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.print),
                          label: const Text('Print Now'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalPreview(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Bigger, bold "Royal Garden" heading replacing logo image
        Column(
          children: [
            Text(
              'Royal',
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Garden',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        SizedBox(height: isSmallScreen ? 4 : 6),

        // Business contact info
        Text(
          '+91 9562291843,+91 9446932750',
          style: TextStyle(
            fontSize: isSmallScreen ? 8 : 9,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Four Lane Byepass, Mangattukavala',
          style: TextStyle(
            fontSize: isSmallScreen ? 8 : 9,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Thodupuzha, 685585',
          style: TextStyle(
            fontSize: isSmallScreen ? 8 : 9,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: isSmallScreen ? 6 : 8),

        // Invoice title
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 3 : 4,
              horizontal: isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'INVOICE',
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        // Invoice details
        _buildPreviewRow('ID:', sale.id),
        _buildPreviewRow('Date:',
            DateFormat('dd/MM/yyyy HH:mm').format(sale.date.toLocal())),
        if (sale.customerName.isNotEmpty)
          _buildPreviewRow('Customer:', _truncateText(sale.customerName, 15)),
        if (sale.customerPhone.isNotEmpty)
          _buildPreviewRow('Phone:', sale.customerPhone),
        _buildPreviewRow('Payment:', sale.payment.name.toUpperCase()),

        SizedBox(height: isSmallScreen ? 6 : 8),

        // Items header - adjusted to match thermal printer format
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 2 : 3,
              horizontal: isSmallScreen ? 3 : 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'PRICE',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'QTY',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'AMT',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),

        // Items list
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
          ),
          child: Column(
            children: sale.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemPreview(item, index + 1, isSmallScreen);
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Totals
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildTotalRow(
                  'Subtotal:',
                  sale.items
                      .fold(0.0, (a, b) => a + b.subtotal)
                      .truncate()
                      .toString()),
              if (sale.discount > 0) ...[
                SizedBox(height: isSmallScreen ? 1 : 2),
                _buildTotalRow('Discount:', '-${sale.discount.truncate()}',
                    valueColor: Colors.red),
              ],
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                height: 0.5,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Rs.${sale.totalAmount.truncate()}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Footer
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'THANK YOU!',
            style: TextStyle(
              fontSize: isSmallScreen ? 7 : 8,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'Printed: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now().toLocal())}',
          style: TextStyle(
            fontSize: isSmallScreen ? 5 : 6,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Builder(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 600;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isSmallScreen ? 35 : 40,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 6 : 7,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 6 : 7,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemPreview(SaleItem item, int itemNumber, bool isSmallScreen) {
    final product = Hive.box<Product>(Boxes.products).get(item.productId);
    final productName = '$itemNumber. ${product?.name ?? 'Unknown Product'}';
    final qty = item.qty.toStringAsFixed(product?.unit == UnitType.kg ? 1 : 0);
    final unitLabel =
        item.unitLabel.isNotEmpty ? item.unitLabel : (product?.unit.name ?? '');

    final priceStr = 'Rs.${item.sellingPrice.toStringAsFixed(2)}';
    String qtyStr = '$qty ${unitLabel.isNotEmpty ? unitLabel : ''}'.trim();
    final amtStr = item.subtotal.toStringAsFixed(2);

    // Split product name intelligently at word boundaries (max 13 chars for first line)
    String firstLine = '';
    String secondLine = '';

    if (productName.length <= 13) {
      firstLine = productName;
    } else {
      List<String> words = productName.split(' ');

      // Build first line with as many words as possible (max 13 chars)
      for (String word in words) {
        if ((firstLine + word).length <= 13) {
          firstLine += (firstLine.isEmpty ? '' : ' ') + word;
        } else {
          // Add remaining words to second line
          secondLine += (secondLine.isEmpty ? '' : ' ') + word;
        }
      }

      // If second line is empty, use simple truncation
      if (secondLine.isEmpty) {
        firstLine = productName.substring(0, 13);
        secondLine = productName.substring(13);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: itemNumber.isOdd ? Colors.grey.shade100 : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.3),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 3 : 4,
        horizontal: isSmallScreen ? 3 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show product name with intelligent splitting
          if (secondLine.isEmpty) ...[
            // Short name - show on one line with qty and amount
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Text(
                    firstLine,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 7 : 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    priceStr,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 6 : 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    qtyStr,
                    style: const TextStyle(fontSize: 7),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Rs.$amtStr',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 6 : 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Long name - show name on first line, then qty/amount on second line
            Text(
              firstLine,
              style: TextStyle(
                fontSize: isSmallScreen ? 7 : 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Text(
                    secondLine,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 7 : 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    priceStr,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 6 : 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    qtyStr,
                    style: const TextStyle(fontSize: 7),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Rs.$amtStr',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 6 : 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          'Rs.$value',
          style: TextStyle(
            fontSize: 7,
            color: valueColor ?? Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

// Helper function to show the thermal preview dialog
Future<bool?> showThermalPreviewDialog(BuildContext context, Sale sale) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ThermalPreviewDialog(sale: sale),
  );
}

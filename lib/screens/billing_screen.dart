import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/invoice_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../utils/printer_utils.dart';

class BillingScreen extends StatefulWidget {
  final Sale sale;
  
  const BillingScreen({Key? key, required this.sale}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  bool _isProcessing = false;
  String? _error;
  PrinterType _selectedPrinterType = PrinterType.pdf;

  Future<void> _handlePrint() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (_selectedPrinterType == PrinterType.thermal) {
        // Show printer selection dialog
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => const PrinterSelectionDialog(),
        );

        if (result != true) {
          setState(() => _isProcessing = false);
          return;
        }
      }

      // Generate and print invoice
      await _invoiceService.generateInvoice(
        widget.sale,
        useThermalPrinter: _selectedPrinterType == PrinterType.thermal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedPrinterType == PrinterType.thermal
                  ? 'Invoice printed successfully'
                  : 'PDF generated successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Printer type selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Printer Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<PrinterType>(
                      title: const Text('Thermal Printer (58mm)'),
                      subtitle: const Text('For physical receipts'),
                      value: PrinterType.thermal,
                      groupValue: _selectedPrinterType,
                      onChanged: (value) {
                        setState(() => _selectedPrinterType = value!);
                      },
                    ),
                    RadioListTile<PrinterType>(
                      title: const Text('PDF Document'),
                      subtitle: const Text('For sharing digitally'),
                      value: PrinterType.pdf,
                      groupValue: _selectedPrinterType,
                      onChanged: (value) {
                        setState(() => _selectedPrinterType = value!);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Error message if any
            if (_error != null) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Print button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePrint,
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : Text(
                        _selectedPrinterType == PrinterType.thermal
                            ? 'Print Invoice'
                            : 'Generate PDF'
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

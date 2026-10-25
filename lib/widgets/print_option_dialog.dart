import 'package:flutter/material.dart';
import '../services/thermal_printer_service.dart';
import '../models/models.dart';
import 'thermal_preview_dialog.dart';

enum PrintOption { thermal, pdf }

class PrintOptionDialog extends StatefulWidget {
  final Sale sale;
  
  const PrintOptionDialog({super.key, required this.sale});

  @override
  State<PrintOptionDialog> createState() => _PrintOptionDialogState();
}

class _PrintOptionDialogState extends State<PrintOptionDialog> {
  PrintOption? _selectedOption;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return AlertDialog(
      contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      title: Text(
        'Select Print Option',
        style: TextStyle(
          fontSize: isSmallScreen ? 18 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: isSmallScreen ? screenSize.width * 0.85 : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you want to print the invoice:',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
          
          // EOS/Thermal Printer Option
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _selectedOption == PrintOption.thermal
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                width: _selectedOption == PrintOption.thermal ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() => _selectedOption = PrintOption.thermal),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: isSmallScreen 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<PrintOption>(
                              value: PrintOption.thermal,
                              groupValue: _selectedOption,
                              onChanged: (value) => setState(() => _selectedOption = value),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.print,
                              color: _selectedOption == PrintOption.thermal
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'EOS/Thermal Printer',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedOption == PrintOption.thermal
                                      ? Theme.of(context).primaryColor
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Generate thermal printer format',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final shouldPrint = await showThermalPreviewDialog(context, widget.sale);
                                if (shouldPrint == true) {
                                  Navigator.of(context).pop(PrintOption.thermal);
                                }
                              },
                              child: const Text(
                                'Preview',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Radio<PrintOption>(
                          value: PrintOption.thermal,
                          groupValue: _selectedOption,
                          onChanged: (value) => setState(() => _selectedOption = value),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.print,
                          color: _selectedOption == PrintOption.thermal
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EOS/Thermal Printer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedOption == PrintOption.thermal
                                      ? Theme.of(context).primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Generate thermal printer format',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      final shouldPrint = await showThermalPreviewDialog(context, widget.sale);
                                      if (shouldPrint == true) {
                                        Navigator.of(context).pop(PrintOption.thermal);
                                      }
                                    },
                                    child: const Text(
                                      'Preview',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
            SizedBox(height: isSmallScreen ? 8 : 12),
          
          // PDF Option
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _selectedOption == PrintOption.pdf
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                width: _selectedOption == PrintOption.pdf ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() => _selectedOption = PrintOption.pdf),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    Radio<PrintOption>(
                      value: PrintOption.pdf,
                      groupValue: _selectedOption,
                      onChanged: (value) => setState(() => _selectedOption = value),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Icon(
                      Icons.picture_as_pdf,
                      color: _selectedOption == PrintOption.pdf
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                      size: isSmallScreen ? 24 : 28,
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Document',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedOption == PrintOption.pdf
                                  ? Theme.of(context).primaryColor
                                  : Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          Text(
                            'Generate PDF for sharing or printing',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
      actions: isSmallScreen 
        ? [
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedOption != null
                          ? () => Navigator.of(context).pop(_selectedOption)
                          : null,
                      child: const Text('Print'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ]
        : [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _selectedOption != null
                  ? () => Navigator.of(context).pop(_selectedOption)
                  : null,
              child: const Text('Print'),
            ),
          ],
    );
  }
}

// Helper function to show the dialog
Future<PrintOption?> showPrintOptionDialog(BuildContext context, Sale sale) {
  return showDialog<PrintOption>(
    context: context,
    builder: (context) => PrintOptionDialog(sale: sale),
  );
}

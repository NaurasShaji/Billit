import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final ThermalPrinterService _printerService = ThermalPrinterService();
  List<BluetoothInfo> _devices = [];
  String? _savedMacAddress;
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load saved printer
      _savedMacAddress = await _printerService.getSavedPrinter();

      // Load paired devices
      await _scanDevices();
    } catch (e) {
      print('Error loading printer settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _printerService.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      print('Error scanning devices: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _savePrinter(BluetoothInfo device) async {
    try {
      await _printerService.savePrinter(device.macAdress);
      setState(() {
        _savedMacAddress = device.macAdress;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default printer set to ${device.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving printer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth_disabled,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No paired devices found',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pair your printer in Android Bluetooth settings first',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _scanDevices,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isSelected = device.macAdress == _savedMacAddress;

                    return Card(
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(
                                color: Theme.of(context).primaryColor, width: 2)
                            : BorderSide.none,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          child: Icon(
                            Icons.print,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.macAdress),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Default Printer',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).primaryColor)
                            : ElevatedButton(
                                onPressed: () => _savePrinter(device),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                ),
                                child: const Text('Select'),
                              ),
                        onTap: () => _savePrinter(device),
                      ),
                    );
                  },
                ),
    );
  }
}

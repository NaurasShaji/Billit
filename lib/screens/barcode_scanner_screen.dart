import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Returns the first barcode detected by the device camera.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan barcode'), actions: [
          IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: _controller.toggleTorch),
          IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _controller.switchCamera),
        ]),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
              child: Center(
                  child: Container(
                      width: 280,
                      height: 170,
                      decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.greenAccent, width: 3),
                          borderRadius: BorderRadius.circular(16))))),
          const Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Text('Align the barcode inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)]))),
        ]),
      );
}

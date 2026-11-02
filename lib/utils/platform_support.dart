import 'package:flutter/foundation.dart';

/// Runtime permission prompts are required by Android but not desktop platforms.
bool get needsRuntimeBluetoothPermissions =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Camera-based barcode scanning relies on mobile camera integration.
bool get isCameraScannerSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

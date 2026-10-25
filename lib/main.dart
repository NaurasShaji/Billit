import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart' as pp;

import 'models/models.dart';
import 'services/boxes.dart';
import 'services/auth_service.dart';
import 'services/drive_sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final dir = await pp.getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
  }

  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(UserTypeAdapter());
  Hive.registerAdapter(UnitTypeAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(PaymentMethodAdapter());
  Hive.registerAdapter(SaleItemAdapter());
  Hive.registerAdapter(SaleAdapter());
  Hive.registerAdapter(ExpenseAdapter()); // typeId 8
  Hive.registerAdapter(EmployeeAdapter()); // typeId 9

  await Hive.openBox<User>(Boxes.users);
  await Hive.openBox<Product>(Boxes.products);
  await Hive.openBox<Sale>(Boxes.sales);
  await Hive.openBox<Expense>(Boxes.expenses);
  await Hive.openBox<Employee>(Boxes.employees);
  await Hive.openBox('session');
  final settings = await Hive.openBox<dynamic>('app_settings');
  Future<void> setDefaultSetting(String key, dynamic value) async {
    if (!settings.containsKey(key)) await settings.put(key, value);
  }
  await setDefaultSetting('app_name', 'Floral Bill');
  await setDefaultSetting('app_logo_base64', '');
  await setDefaultSetting('app_theme', 'green');
  await setDefaultSetting('theme_mode', 'system');
  await setDefaultSetting('ui_density', 'comfortable');
  await setDefaultSetting('text_scale', 1.0);
  await setDefaultSetting('corner_radius', 16.0);
  await setDefaultSetting('upi_id', '');
  await setDefaultSetting('upi_payee_name', '');
  await setDefaultSetting('upi_note_prefix', 'Invoice');
  await setDefaultSetting('business_name', 'Royal Garden');
  await setDefaultSetting('business_address', 'FourLane Byepass, Mangattukavala, Thodupuzha, Kerala 685585');
  await setDefaultSetting('business_phone', '9562291843, 9446932750');
  await setDefaultSetting('business_email', '');
  await setDefaultSetting('business_gstin', '');
  await setDefaultSetting('gst_enabled', false);
  await setDefaultSetting('gst_rate', 0.0);
  await setDefaultSetting('gst_price_inclusive', false);
  await setDefaultSetting('invoice_prefix', 'INV');
  await setDefaultSetting('next_invoice_number', 1);
    
  // Initialize services
  final auth = AuthService();
  await auth.ensureSeedUsers();
    
  // Initialize Drive sync service and attempt auto sign-in
  final driveSync = DriveSyncService.instance;
  await driveSync.init();
  await driveSync.tryAutoSignIn();

  runApp(const MyApp());
}

Color _themeSeedColor(String theme) {
  switch (theme) {
    case 'blue': return const Color(0xFF2864C5);
    case 'purple': return const Color(0xFF7651B5);
    case 'amber': return const Color(0xFFB77916);
    case 'teal': return const Color(0xFF168A8A);
    case 'rose': return const Color(0xFFB83280);
    case 'indigo': return const Color(0xFF4F46B8);
    case 'slate': return const Color(0xFF475569);
    case 'coral': return const Color(0xFFD45D45);
    case 'ocean': return const Color(0xFF087EAA);
    case 'green':
    default: return const Color(0xFF25855A);
  }
}

ThemeData _buildAppTheme(Box<dynamic> settings, Brightness brightness) {
  final themeName = settings.get('app_theme', defaultValue: 'green').toString();
  final radius = (settings.get('corner_radius', defaultValue: 16.0) as num).toDouble();
  final compact = settings.get('ui_density', defaultValue: 'comfortable') == 'compact';
  final scheme = ColorScheme.fromSeed(
    seedColor: _themeSeedColor(themeName),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  final base = ThemeData(brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    scaffoldBackgroundColor: dark ? const Color(0xFF111418) : Color.alphaBlend(
      scheme.primary.withOpacity(0.025),
      scheme.surface,
    ),
    textTheme: base.textTheme,
    primaryColor: scheme.primary,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withOpacity(0.14),
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        final selected = states.contains(MaterialState.selected);
        return TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        );
      }),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..restoreSessionIfAny())
      ],
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: Hive.box<dynamic>('app_settings').listenable(),
        builder: (context, settings, _) {
          final modeName = settings.get('theme_mode', defaultValue: 'system').toString();
          final mode = modeName == 'dark'
              ? ThemeMode.dark
              : modeName == 'light'
                  ? ThemeMode.light
                  : ThemeMode.system;
          return MaterialApp(
            title: settings.get('app_name', defaultValue: 'Floral Bill').toString(),
            theme: _buildAppTheme(settings, Brightness.light),
            darkTheme: _buildAppTheme(settings, Brightness.dark),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final scale = (settings.get('text_scale', defaultValue: 1.0) as num)
                  .toDouble()
                  .clamp(0.9, 1.2)
                  .toDouble();
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: AppWrapper(),
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Consumer<AuthService>(
        builder: (_, auth, __) => auth.currentUser == null 
            ? const LoginScreen() 
            : const HomeScreen(),
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.exit_to_app,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Exit App',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to exit the application?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Exit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
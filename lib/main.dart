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
    
  // Initialize services
  final auth = AuthService();
  await auth.ensureSeedUsers();
    
  // Initialize Drive sync service and attempt auto sign-in
  final driveSync = DriveSyncService.instance;
  await driveSync.init();
  await driveSync.tryAutoSignIn();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..restoreSessionIfAny())
      ],
      child: MaterialApp(
        title: 'Floral Billing',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: AppWrapper(),
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
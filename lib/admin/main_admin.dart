import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../config/app_flags.dart';
import '../firebase_options.dart';
import 'screens/admin_panel_screen.dart';

/// Separate admin entry (not linked from the detector app).
///
/// Run when enabled:
///   flutter run -t lib/admin/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vision Trend Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D5EF7)),
      ),
      home: kAdminAppEnabled
          ? const AdminPanelScreen()
          : const _AdminDisabledScreen(),
    );
  }
}

class _AdminDisabledScreen extends StatelessWidget {
  const _AdminDisabledScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              const Text(
                'Admin app is disabled',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Training data is managed in Firebase only.\n'
                'Set kAdminAppEnabled = true in lib/config/app_flags.dart '
                'to open the upload UI.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

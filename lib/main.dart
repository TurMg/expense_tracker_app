import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/services/category_service.dart'; // Import category service
import 'presentation/screens/main_navigation_screen.dart'; // Import main navigation screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize category service dengan data default
  final categoryService = CategoryService();
  await categoryService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Konfigurasi locale untuk mendukung bahasa Indonesia
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
      ],
      locale: const Locale('id', 'ID'),
      // Set main navigation screen sebagai halaman utama
      home: const MainNavigationScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'presentation/screens/add_transaction_screen.dart'; // Import halaman tadi

void main() {
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
      // Kita langsung tembak ke halaman Add Transaction dulu buat testing
      home: const AddTransactionScreen(),
    );
  }
}

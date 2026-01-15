
import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart'; // Bottom navbar global
import 'home_screen.dart'; // Halaman Beranda
import 'statistics_screen.dart'; // Halaman Statistik
import 'history_screen.dart'; // Halaman Riwayat
import 'profile_screen.dart'; // Halaman Profil

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; // Index halaman aktif (0 = Beranda, 1 = Statistik, 2 = Riwayat, 3 = Profil)

  // GlobalKey untuk mengakses state dari setiap screen
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

  // List halaman yang akan ditampilkan
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      const StatisticsScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
  }

  // Fungsi untuk menangani perubahan tab
  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Fungsi untuk menangani tombol tambah transaksi
  void _onAddPressed() {
    // Delegasikan ke screen yang aktif
    _homeScreenKey.currentState?.showAddOptions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: GlobalBottomNavBar(
        currentIndex: _currentIndex,
        onTabChanged: _onTabChanged,
        onAddPressed: _onAddPressed,
      ),
    );
  }
}

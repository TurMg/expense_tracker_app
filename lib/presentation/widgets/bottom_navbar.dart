import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlobalBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabChanged;
  final VoidCallback onAddPressed;

  const GlobalBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.onAddPressed,
  });

  @override
  State<GlobalBottomNavBar> createState() => _GlobalBottomNavBarState();
}

class _GlobalBottomNavBarState extends State<GlobalBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F1F1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, "Beranda", 0),
          _buildNavItem(Icons.bar_chart_rounded, "Statistik", 1),

          // --- TOMBOL TAMBAH (+) DI TENGAH ---
          GestureDetector(
            onTap: widget.onAddPressed,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF5CA6E9),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x445CA6E9),
                        blurRadius: 10,
                        offset: Offset(0, 5))
                  ]),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
          // -----------------------------------

          _buildNavItem(Icons.history_rounded, "Riwayat", 2),
          _buildNavItem(Icons.person_rounded, "Profil", 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onTabChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? const Color(0xFF5CA6E9) : Colors.grey[400]),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isActive ? const Color(0xFF5CA6E9) : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ))
        ],
      ),
    );
  }
}

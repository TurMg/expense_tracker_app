import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- LOGIC: TOMBOL (+) POPUP ---
  void _showAddOptions() {
    // Tampilkan opsi untuk menambah transaksi
    // Implementasi ini bisa disesuaikan dengan kebutuhan
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Fitur ini belum tersedia",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Text("Silakan kembali ke Beranda untuk menambah transaksi",
                  style: GoogleFonts.poppins(fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  // Warna-warna UI (Sesuai Gambar)
  final Color _activeBlue = const Color(0xFF4296F4); // Warna utama biru
  final Color _bgBlueIcon = const Color(0xFF64B5F6); // Background icon User
  final Color _bgGreenIcon =
      const Color(0xFFA5D6A7); // Background icon Kategori
  final Color _bgOrangeIcon =
      const Color(0xFFFF8A65); // Background icon Bantuan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Profil",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        automaticallyImplyLeading:
            true, // Tampilkan tombol back
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),

          // 1. PROFILE HEADER (Avatar + Name)
          Center(
            child: Column(
              children: [
                // Avatar dengan Edit Icon
                Stack(
                  children: [
                    // Lingkaran Avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(
                            0xFFFFCC80), // Warna background avatar (Orange muda)
                      ),
                      // Ganti NetworkImage dengan AssetImage('assets/budi.png') kalau ada file lokal
                      child: ClipOval(
                        child: Image.network(
                          'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg', // Placeholder kartun mirip Budi
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person,
                                  size: 60, color: Colors.white),
                        ),
                      ),
                    ),

                    // Tombol Edit (Pensil Biru)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _activeBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: 3), // Border putih biar misah
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 16),

                // Nama User
                Text(
                  "Budi Setiawan",
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2C37)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 2. MENU OPTIONS
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildMenuOption(
                  icon: Icons.person_outline_rounded,
                  iconBgColor: _bgBlueIcon,
                  title: "User Profil",
                  onTap: () {},
                ),
                _buildMenuDivider(),
                _buildMenuOption(
                  icon: Icons.grid_view_rounded, // Atau category
                  iconBgColor: _bgGreenIcon,
                  title: "Kategori",
                  onTap: () {},
                ),
                _buildMenuDivider(),
                _buildMenuOption(
                  icon: Icons.help_outline_rounded,
                  iconBgColor: _bgOrangeIcon,
                  title: "Pusat Bantuan",
                  onTap: () {},
                ),
                _buildMenuDivider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF1F2C37)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }

  Widget _buildMenuDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF5F6FA));
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: isActive ? _activeBlue : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                color: isActive ? _activeBlue : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
      ],
    );
  }
}

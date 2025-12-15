import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Chart
import 'package:google_fonts/google_fonts.dart'; // Font Poppins
import 'package:intl/intl.dart'; // Formatter
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'; // Scanner
import '../../data/local/database_helper.dart';
import '../../logic/services/ocr_service.dart';
import 'add_transaction_screen.dart'; // Halaman Manual
import 'scan_result_screen.dart'; // Halaman Review Scan (File Baru)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE VARIABLES ---
  double _totalExpense = 0;
  double _totalIncome = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  // Service OCR
  final _ocrService = OcrService();

  // Data Kategori (Sama dengan AddTransactionScreen)
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'Makan',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFF4A285)
    },
    {
      'id': 'Transport',
      'icon': Icons.directions_bus_rounded,
      'color': Color(0xFF81C784)
    },
    {
      'id': 'Belanja',
      'icon': Icons.shopping_bag_rounded,
      'color': Color(0xFF64B5F6)
    },
    {
      'id': 'Tagihan',
      'icon': Icons.receipt_long_rounded,
      'color': Color(0xFFE57373)
    },
  ];

  // Getter Saldo Saat Ini
  double get _currentBalance => _totalIncome - _totalExpense;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- LOGIC: LOAD DATA DARI DB ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAll('transactions');

    double totalExpense = 0;
    double totalIncome = 0;
    // Sort dari yang terbaru
    List<Map<String, dynamic>> sortedData = List.from(data);
    sortedData.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    for (var item in sortedData) {
      if (item['type'] == 'EXPENSE') {
        totalExpense += (item['amount'] as double);
      } else if (item['type'] == 'INCOME') {
        totalIncome += (item['amount'] as double);
      }
    }

    setState(() {
      _transactions = sortedData;
      _totalExpense = totalExpense;
      _totalIncome = totalIncome;
      _isLoading = false;
    });
  }

  // --- LOGIC: SCANNER FLOW ---
  Future<void> _handleScanAndNavigate() async {
    Navigator.pop(context); // Tutup BottomSheet

    try {
      // 1. Buka Scanner HP
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: true,
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();

      if (result.images.isEmpty) return;

      // Show Loading Snack
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sedang membaca struk... 🤖"),
              duration: Duration(seconds: 1)),
        );
      }

      // 2. Proses AI (OCR)
      final receiptData = await _ocrService.scanReceipt(result.images.first);

      // 3. Pindah ke Halaman REVIEW (ScanResultScreen)
      if (mounted) {
        final saveResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              amount: receiptData.amount ?? 0,
              date: receiptData.date ?? DateTime.now(),
              receiptImage: File(result.images.first),
            ),
          ),
        );

        // Kalau user nyimpen data, refresh home
        if (saveResult == true) _loadData();
      }
    } catch (e) {
      print("Error Scan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal scan struk.")),
      );
    }
  }

  // --- FORMATTER ---
  String _formatRp(double amount) {
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  String _formatSmallRp(double amount) {
    if (amount >= 1000000) {
      return "Rp ${(amount / 1000000).toStringAsFixed(1)}jt";
    }
    return _formatRp(amount);
  }

  // --- LOGIC: TOMBOL (+) POPUP ---
  void _showAddOptions() {
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
              Text("Tambah Transaksi",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),

              // OPSI 1: SCAN STRUK (Ke Halaman Review)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue[50], shape: BoxShape.circle),
                  child: const Icon(Icons.document_scanner_rounded,
                      color: Colors.blue),
                ),
                title: Text("Scan Struk",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text("Isi otomatis pakai AI",
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                onTap: _handleScanAndNavigate, // Panggil fungsi scan
              ),

              const SizedBox(height: 10),

              // OPSI 2: INPUT MANUAL (Ke Halaman Input Kosong)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange[50], shape: BoxShape.circle),
                  child:
                      const Icon(Icons.edit_note_rounded, color: Colors.orange),
                ),
                title: Text("Input Manual",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text("Ketik sendiri pengeluaranmu",
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(context);
                  // Buka Halaman Manual (AddTransactionScreen)
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddTransactionScreen()));
                  if (result == true) _loadData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definisi Warna UI
    final blueGradientStart = const Color(0xFF6FABEF);
    final blueGradientEnd = const Color(0xFF5CA6E9);
    final greenSoft = const Color(0xFFE5F7ED);
    final greenText = const Color(0xFF4CAF50);
    final orangeSoft = const Color(0xFFFBECE6);
    final orangeText = const Color(0xFFE57373);
    final bgGrey = const Color(0xFFF8F9FD);

    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // CONTENT UTAMA (Scrollable)
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(
                        bottom: 100), // Space buat BottomNav
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. HEADER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Selamat Pagi,",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text("Halo, Budi",
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20)),
                                      const SizedBox(width: 8),
                                      const Text("👋",
                                          style: TextStyle(fontSize: 20)),
                                    ],
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.black87),
                                  onPressed: () {},
                                ),
                              )
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 2. KARTU SALDO (Gradient)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [blueGradientStart, blueGradientEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                      color: blueGradientEnd.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8))
                                ]),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Saldo Total",
                                        style: GoogleFonts.poppins(
                                            color:
                                                Colors.white.withOpacity(0.9))),
                                    const SizedBox(width: 8),
                                    Icon(Icons.remove_red_eye_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 16)
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(_formatRp(_currentBalance),
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_up_rounded,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text("+12% vs bulan lalu",
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12))
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 3. TOMBOL AKSI (Pemasukan / Pengeluaran)
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  label: "Pemasukan",
                                  icon: Icons.arrow_downward_rounded,
                                  bgColor: greenSoft,
                                  iconColor: greenText,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildActionButton(
                                  label: "Pengeluaran",
                                  icon: Icons.arrow_upward_rounded,
                                  bgColor: orangeSoft,
                                  iconColor: orangeText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 4. CHART RINGKASAN
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Ringkasan",
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Container(
                                      decoration: BoxDecoration(
                                          color: bgGrey,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          _buildTab("Harian", false),
                                          _buildTab(
                                              "Mingguan", true), // Selected
                                          _buildTab("Bulanan", false),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Column(
                                  children: [
                                    // CHART DAN LEGEND DALAM ROW YANG DIKELILINGI CENTER
                                    Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // CHART
                                          SizedBox(
                                            width: 120,
                                            height: 120,
                                            child: PieChart(
                                              PieChartData(
                                                sectionsSpace: 0,
                                                centerSpaceRadius: 45,
                                                startDegreeOffset: -90,
                                                sections: [
                                                  PieChartSectionData(
                                                    color: const Color(
                                                        0xFF81C784), // Hijau Pemasukan
                                                    value: _totalIncome,
                                                    radius: 32,
                                                    showTitle: false,
                                                  ),
                                                  PieChartSectionData(
                                                    color: const Color(
                                                        0xFFFF8A65), // Orange Pengeluaran
                                                    value: _totalExpense == 0
                                                        ? 1
                                                        : _totalExpense, // Minimal 1 biar gak ilang
                                                    radius: 32,
                                                    showTitle: false,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 40),
                                          // LEGEND CHART
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildLegendItem(
                                                  const Color(0xFF81C784),
                                                  "Pemasukan",
                                                  _totalIncome),
                                              const SizedBox(height: 12),
                                              _buildLegendItem(
                                                  const Color(0xFFFF8A65),
                                                  "Pengeluaran",
                                                  _totalExpense),
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 5. TRANSAKSI TERAKHIR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Transaksi Terakhir",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              TextButton(
                                  onPressed: () {},
                                  child: Text("Lihat Semua",
                                      style: GoogleFonts.poppins(
                                          color: const Color(0xFF5CA6E9))))
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTransactionList(),
                        ],
                      ),
                    ),
                  ),

                  // CUSTOM BOTTOM NAVIGATION BAR
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              top: BorderSide(color: Color(0xFFF1F1F1)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildNavItem(Icons.home_rounded, "Beranda", true),
                          _buildNavItem(
                              Icons.bar_chart_rounded, "Statistik", false),

                          // --- TOMBOL TAMBAH (+) DI TENGAH ---
                          GestureDetector(
                            onTap: _showAddOptions, // MUNCULKAN POPUP PILIHAN
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
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                          // -----------------------------------

                          _buildNavItem(Icons.account_balance_wallet_rounded,
                              "Dompet", false),
                          _buildNavItem(Icons.person_rounded, "Profil", false),
                        ],
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildActionButton(
      {required String label,
      required IconData icon,
      required Color bgColor,
      required Color iconColor}) {
    double amount = label == "Pemasukan" ? _totalIncome : _totalExpense;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        color: iconColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(_formatRp(amount),
                    style: GoogleFonts.poppins(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : []),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.black87 : Colors.grey)),
    );
  }

  Widget _buildLegendItem(Color color, String label, double amount) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            Text(_formatRp(amount),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: isActive ? const Color(0xFF5CA6E9) : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                color: isActive ? const Color(0xFF5CA6E9) : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal))
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Text("Belum ada data",
                style: GoogleFonts.poppins(color: Colors.grey))),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _transactions.take(5).length,
      itemBuilder: (context, index) {
        final item = _transactions[index];
        final date = DateTime.parse(item['date']);

        // Cari kategori yang sesuai dari daftar kategori
        final category = _categories.firstWhere(
          (cat) => cat['id'] == item['categoryId'],
          orElse: () => {
            'id': 'Belanja',
            'icon': Icons.shopping_bag_outlined,
            'color': const Color(0xFF64B5F6)
          },
        );

        IconData icon = category['icon'];
        Color bgIcon = (category['color'] as Color).withOpacity(0.1);
        Color colorIcon = category['color'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: bgIcon, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: colorIcon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['categoryId'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                        "${DateFormat('HH:mm').format(date)} • ${DateFormat('d MMM').format(date)}",
                        style: GoogleFonts.poppins(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                "${item['type'] == 'EXPENSE' ? '-' : '+'} ${_formatRp(item['amount'])}",
                style: GoogleFonts.poppins(
                    color: item['type'] == 'EXPENSE'
                        ? const Color(0xFFFF8A65)
                        : const Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              )
            ],
          ),
        );
      },
    );
  }
}

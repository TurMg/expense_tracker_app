import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Chart
import 'package:google_fonts/google_fonts.dart'; // Font Poppins
import 'package:intl/intl.dart'; // Formatter
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'; // Scanner
import '../../data/local/database_helper.dart';
import '../../data/models/category_model.dart'; // Model kategori
import '../../logic/services/ocr_service.dart';
import '../../logic/services/category_service.dart'; // Service kategori dinamis
import 'add_transaction_screen.dart'; // Halaman Manual
import 'history_screen.dart'; // Halaman Riwayat
import 'scan_result_screen.dart'; // Halaman Review Scan (File Baru)
import 'transaction_detail_screen.dart'; // Halaman Detail Transaksi
import '../widgets/bottom_navbar.dart'; // Bottom navbar global

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE VARIABLES ---
  double _totalExpense = 0;
  double _totalIncome = 0;
  double _totalAllExpense =
      0; // Total pengeluaran semua transaksi (tidak terfilter)
  double _totalAllIncome =
      0; // Total pemasukan semua transaksi (tidak terfilter)
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _allTransactions =
      []; // Semua transaksi untuk filter cepat
  List<Category> _categories = []; // Kategori dinamis
  bool _isLoading = true;
  int _currentIndex = 0; // Untuk bottom navbar
  String _activeFilter = "Harian"; // Filter aktif: Harian, Mingguan, Bulanan

  // Service OCR
  final _ocrService = OcrService();
  final _categoryService = CategoryService(); // Service kategori dinamis

  // Getter Saldo Saat Ini
  double get _currentBalance => _totalAllIncome - _totalAllExpense;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- LOGIC: LOAD DATA DARI DB ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load transactions
    final data = await DatabaseHelper.instance.getAll('transactions');
    _allTransactions = data; // Simpan semua data

    // Hitung total semua transaksi (tidak terfilter)
    double totalAllExpense = 0;
    double totalAllIncome = 0;
    for (var item in data) {
      if (item['type'] == 'EXPENSE') {
        totalAllExpense += (item['amount'] as double);
      } else if (item['type'] == 'INCOME') {
        totalAllIncome += (item['amount'] as double);
      }
    }

    // Filter transactions berdasarkan periode aktif
    final filteredData = _filterTransactionsByPeriod(data, _activeFilter);

    double totalExpense = 0;
    double totalIncome = 0;
    // Sort dari yang terbaru
    List<Map<String, dynamic>> sortedData = List.from(filteredData);
    sortedData.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    for (var item in sortedData) {
      if (item['type'] == 'EXPENSE') {
        totalExpense += (item['amount'] as double);
      } else if (item['type'] == 'INCOME') {
        totalIncome += (item['amount'] as double);
      }
    }

    // Load categories
    final categories = await _categoryService.getAllCategories();

    setState(() {
      _transactions = sortedData;
      _totalExpense = totalExpense;
      _totalIncome = totalIncome;
      _totalAllExpense = totalAllExpense;
      _totalAllIncome = totalAllIncome;
      _categories = categories;
      _isLoading = false;
    });
  }

  // --- LOGIC: NAVIGASI BOTTOM NAVBAR ---
  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Navigasi ke screen yang sesuai berdasarkan index
    if (index == 2) {
      // Riwayat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HistoryScreen(),
        ),
      );
      // Kembali ke index 0 setelah navigasi
      Future.delayed(Duration.zero, () {
        setState(() {
          _currentIndex = 0;
        });
      });
    }
    // Tambahkan navigasi untuk tab lain jika diperlukan
  }

  // --- LOGIC: FILTER PERUBAHAN ---
  void _onFilterChanged(String filter) {
    _applyFilter(filter);
  }

  // --- LOGIC: APLIKASI FILTER CEPAT ---
  void _applyFilter(String filter) {
    // Filter dari data yang sudah ada
    final filteredData = _filterTransactionsByPeriod(_allTransactions, filter);

    double totalExpense = 0;
    double totalIncome = 0;
    // Sort dari yang terbaru
    List<Map<String, dynamic>> sortedData = List.from(filteredData);
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
      _activeFilter = filter;
      _transactions = sortedData;
      _totalExpense = totalExpense;
      _totalIncome = totalIncome;
      // Saldo total (_totalAllIncome dan _totalAllExpense) tidak diubah agar tetap menampilkan semua transaksi
    });
  }

  // --- LOGIC: FILTER DATA BERDASARKAN PERIODE ---
  List<Map<String, dynamic>> _filterTransactionsByPeriod(
      List<Map<String, dynamic>> transactions, String period) {
    final now = DateTime.now();
    final filteredTransactions = transactions.where((transaction) {
      final date = DateTime.parse(transaction['date']);

      switch (period) {
        case "Harian":
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case "Mingguan":
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfWeek.add(const Duration(days: 1)));
        case "Bulanan":
          return date.year == now.year && date.month == now.month;
        default:
          return true;
      }
    }).toList();

    return filteredTransactions;
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
    final greenSoft = const Color(0xFFE6F1EB);
    final greenText = const Color(0xFF4CAF50);
    final orangeSoft = const Color(0xFFFBECE6);
    final orangeText = const Color(0xFFE57373);
    final bgGrey = const Color(0xFFF8F9FD);

    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // HEADER (Tidak Scroll)
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Selamat Pagi,",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[600], fontSize: 14)),
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
                            icon: const Icon(Icons.notifications_none_rounded,
                                color: Colors.black87),
                            onPressed: () {},
                          ),
                        )
                      ],
                    ),
                  ),

                  // CONTENT UTAMA (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                    Text("Saldo Saat Ini",
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
                                  icon: Icons.arrow_downward_sharp,
                                  bgColor: greenSoft,
                                  iconColor: greenText,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildActionButton(
                                  label: "Pengeluaran",
                                  icon: Icons.arrow_upward_sharp,
                                  bgColor: orangeSoft,
                                  iconColor: orangeText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

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
                                          _buildTab(
                                              "Harian",
                                              _activeFilter == "Harian",
                                              () => _onFilterChanged("Harian")),
                                          _buildTab(
                                              "Mingguan",
                                              _activeFilter == "Mingguan",
                                              () =>
                                                  _onFilterChanged("Mingguan")),
                                          _buildTab(
                                              "Bulanan",
                                              _activeFilter == "Bulanan",
                                              () =>
                                                  _onFilterChanged("Bulanan")),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 20),
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
                                            child: Stack(
                                              children: [
                                                PieChart(
                                                  PieChartData(
                                                    sectionsSpace: 0,
                                                    centerSpaceRadius: 45,
                                                    startDegreeOffset: -90,
                                                    sections: [
                                                      PieChartSectionData(
                                                        color: const Color(
                                                            0xFF81C784), // Hijau Pemasukan
                                                        value: _totalIncome,
                                                        radius: 16,
                                                        showTitle: false,
                                                      ),
                                                      PieChartSectionData(
                                                        color: const Color(
                                                            0xFFFF8A65), // Orange Pengeluaran
                                                        value: _totalExpense ==
                                                                0
                                                            ? 1
                                                            : _totalExpense, // Minimal 1 biar gak ilang
                                                        radius: 16,
                                                        showTitle: false,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text("Terpakai",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontSize: 10)),
                                                      Text(
                                                          _totalIncome == 0
                                                              ? "0%"
                                                              : "${((_totalExpense / _totalIncome) * 100).toStringAsFixed(0)}%",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16)),
                                                    ],
                                                  ),
                                                ),
                                              ],
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
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 5. TRANSAKSI TERAKHIR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Transaksi Terakhir",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const HistoryScreen(),
                                      ),
                                    );
                                  },
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
                ],
              ),
      ),
      // Tambahkan bottom navbar global
      bottomNavigationBar: GlobalBottomNavBar(
        currentIndex: _currentIndex,
        onTabChanged: _onTabChanged,
        onAddPressed: _showAddOptions,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  color: iconColor, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
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
        final categoryId = item['categoryId'];

        // Cari kategori berdasarkan ID
        final category = _categories.firstWhere(
          (cat) => cat.id == categoryId,
          orElse: () => Category(
            id: categoryId,
            name: categoryId,
            type: item['type'],
            icon: Icons.category_rounded,
            color: Colors.grey,
          ),
        );

        // Hitung warna background icon (lebih terang dari warna kategori)
        final bgIcon = category.color.withOpacity(0.2);

        return GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              builder: (context) => TransactionDetailScreen(
                transaction: item,
              ),
            );

            if (result == true) {
              _loadData(); // Refresh data jika transaksi dihapus atau diedit
            }
          },
          child: Container(
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
                  child: Icon(category.icon, color: category.color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name,
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
          ),
        );
      },
    );
  }
}

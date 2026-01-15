import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/category_model.dart'; // Model kategori
import '../../logic/services/ocr_service.dart';
import '../../logic/services/category_service.dart'; // Service kategori
import '../widgets/bottom_navbar.dart'; // Bottom navbar global
import 'home_screen.dart'; // Untuk navigasi ke beranda
import 'statistics_screen.dart'; // Halaman Statistik
import 'add_transaction_screen.dart'; // Halaman Manual
import 'scan_result_screen.dart'; // Halaman Review Scan
import 'profile_screen.dart'; // Halaman Profil

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // State Data
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Category> _categories = []; // Kategori dinamis
  double _totalExpenseMonth = 0;
  double _totalIncomeMonth = 0;
  bool _isLoading = true;
  int _currentIndex = 2; // Untuk bottom navbar (index 2 = Riwayat)

  // Service
  final _ocrService = OcrService();
  final _categoryService = CategoryService(); // Service kategori dinamis

  // State Filter
  String _searchQuery = '';
  String _filterType = 'Semua'; // Opsi: Semua, Pemasukan, Pengeluaran

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- LOGIC LOAD DATA ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load transactions
    final data = await DatabaseHelper.instance.getAll('transactions');

    // Load categories
    final categories = await _categoryService.getAllCategories();

    setState(() {
      _allTransactions = data;
      _categories = categories;
      _isLoading = false;
    });

    _applyFilter(); // Terapkan filter awal (akan menghitung total)
  }

  // --- LOGIC FILTERING (Search + Kategori) ---
  void _applyFilter() {
    List<Map<String, dynamic>> temp = _allTransactions;

    // 1. Filter Tipe (Semua / Pemasukan / Pengeluaran)
    if (_filterType == 'Pemasukan') {
      temp = temp.where((item) => item['type'] == 'INCOME').toList();
    } else if (_filterType == 'Pengeluaran') {
      temp = temp.where((item) => item['type'] == 'EXPENSE').toList();
    } else if (_filterType == 'Semua') {
      // Untuk 'Semua', tampilkan semua transaksi termasuk yang type-nya null
      temp = temp
          .where((item) =>
              item['type'] == 'INCOME' ||
              item['type'] == 'EXPENSE' ||
              item['type'] == null)
          .toList();
    }

    // 2. Filter Search (Merchant / Kategori / Note)
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((item) {
        final query = _searchQuery.toLowerCase();
        final cat = (item['categoryId'] ?? '').toLowerCase();
        final note = (item['note'] ?? '').toLowerCase();
        return cat.contains(query) || note.contains(query);
      }).toList();
    }

    // 3. Sorting (Terbaru ke Terlama)
    temp.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    // Hitung Total Pengeluaran dan Pemasukan Bulan Ini (Buat Card Biru)
    double totalExp = 0;
    double totalInc = 0;
    final now = DateTime.now();

    // Hitung total bulan ini berdasarkan filter yang aktif
    for (var item in _allTransactions) {
      DateTime date = DateTime.parse(item['date']);
      // Cek bulan & tahun sama
      if (date.month == now.month && date.year == now.year) {
        // Sesuaikan dengan filter yang aktif
        if (_filterType == 'Pemasukan') {
          if (item['type'] == 'INCOME') {
            totalInc += (item['amount'] as double);
          }
        } else if (_filterType == 'Pengeluaran') {
          if (item['type'] == 'EXPENSE' || item['type'] == null) {
            totalExp += (item['amount'] as double);
          }
        } else if (_filterType == 'Semua') {
          if (item['type'] == 'EXPENSE' || item['type'] == null) {
            totalExp += (item['amount'] as double);
          } else if (item['type'] == 'INCOME') {
            totalInc += (item['amount'] as double);
          }
        }
      }
    }

    setState(() {
      _filteredTransactions = temp;
      _totalExpenseMonth = totalExp;
      _totalIncomeMonth = totalInc;
    });
  }

  // --- FORMATTER ---
  String _formatRp(double amount) {
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today)
      return "HARI INI, ${DateFormat('d MMM', 'id_ID').format(date).toUpperCase()}";
    if (checkDate == yesterday)
      return "KEMARIN, ${DateFormat('d MMM', 'id_ID').format(date).toUpperCase()}";

    return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date).toUpperCase();
  }

  // --- LOGIC: NAVIGASI BOTTOM NAVBAR ---
  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Navigasi ke screen yang sesuai berdasarkan index
    if (index == 0) {
      // Beranda
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
    if (index == 1) {
      // Statistik
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const StatisticsScreen(),
        ),
      );
    }
    if (index == 3) {
      // Profil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Riwayat Transaksi",
            style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. SEARCH BAR & FILTER
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilter();
                        },
                        decoration: InputDecoration(
                          hintText: "Cari transaksi (e.g. Kopi, Gaji)",
                          hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[400], fontSize: 14),
                          prefixIcon:
                              Icon(Icons.search, color: Colors.grey[400]),
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter Chips
                      Row(
                        children: [
                          _buildFilterChip("Semua", null),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                              "Pemasukan", Icons.arrow_downward_rounded),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                              "Pengeluaran", Icons.arrow_upward_rounded),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. CONTENT LIST
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // BLUE CARD SUMMARY
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6FABEF), Color(0xFF5CA6E9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF5CA6E9)
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _filterType == 'Pemasukan'
                                      ? "TOTAL PEMASUKAN BULAN INI"
                                      : "TOTAL PENGELUARAN BULAN INI",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Text(
                                  _formatRp(_filterType == 'Pemasukan'
                                      ? _totalIncomeMonth
                                      : _totalExpenseMonth),
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _filterType == 'Pemasukan'
                                            ? Icons.trending_up_rounded
                                            : Icons.trending_down_rounded,
                                        color: Colors.white,
                                        size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                        _filterType == 'Pemasukan'
                                            ? "Naik 12% dari bulan lalu"
                                            : "Hemat 12% dari bulan lalu",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white, fontSize: 12))
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // TRANSACTION LIST (GROUPED)
                        _buildGroupedTransactionList(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
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
                onTap: _handleScanAndNavigate,
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

        // Kalau user nyimpen data, refresh history
        if (saveResult == true) _loadData();
      }
    } catch (e) {
      print("Error Scan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal scan struk.")),
      );
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFilterChip(String label, IconData? icon) {
    bool isActive = _filterType == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = label;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (label == "Pemasukan"
                  ? const Color(0xFF4CAF50) // Hijau untuk Pemasukan
                  : label == "Pengeluaran"
                      ? const Color(0xFFFF8A65) // Orange untuk Pengeluaran
                      : const Color(0xFF1F2C37)) // Hitam untuk Semua
              : Colors.white, // Putih untuk tidak aktif
          borderRadius: BorderRadius.circular(24),
          border: isActive ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isActive
                      ? Colors.white // Tetap putih saat aktif untuk kontras
                      : (label == "Pemasukan"
                          ? const Color(0xFFA2D1B0)
                          : const Color(0xFFF4A285))),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: GoogleFonts.poppins(
                    color: isActive ? Colors.white : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(
            child: Text("Tidak ada transaksi",
                style: GoogleFonts.poppins(color: Colors.grey))),
      );
    }

    // Logic Grouping Manual
    List<Widget> groupedList = [];
    String lastDate = '';

    for (var item in _filteredTransactions) {
      DateTime date = DateTime.parse(item['date']);
      String header = _formatDateHeader(date);

      // Hitung Total Harian (Opsional, di gambar ada "-Rp 134.000" di header)
      // Disini saya skip angka total harian biar kode gak terlalu kompleks, fokus ke UI listnya dulu.

      if (header != lastDate) {
        groupedList.add(Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(header,
                  style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              // Text("-Rp 134.000", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)), // Placeholder total harian
            ],
          ),
        ));
        lastDate = header;
      }

      groupedList.add(_buildTransactionCard(item));
    }

    return Column(children: groupedList);
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    bool isIncome = item['type'] == 'INCOME';
    double amount = item['amount'];
    final categoryId = item['categoryId'];
    String note = item['note'] ?? '';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (note.isNotEmpty)
                  Text(note,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[500], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            "${isIncome ? '+' : '-'} ${_formatRp(amount)}",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isIncome
                    ? const Color(0xFF4CAF50)
                    : const Color(
                        0xFFFF8A65) // Hijau atau Orange (sesuai home_screen)
                ),
          )
        ],
      ),
    );
  }
}

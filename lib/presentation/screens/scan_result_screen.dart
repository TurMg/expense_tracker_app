import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../../data/local/database_helper.dart';
import '../../logic/services/ocr_service.dart';

class ScanResultScreen extends StatefulWidget {
  final double amount;
  final DateTime date;
  final File receiptImage;

  const ScanResultScreen({
    super.key,
    required this.amount,
    required this.date,
    required this.receiptImage,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late File _currentImage;
  
  bool _isExpense = true; // Default Pengeluaran
  String _selectedCategory = 'Makan';
  final _ocrService = OcrService();

  // Data Kategori
  final List<Map<String, dynamic>> _categories = [
    {'id': 'Makan', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFFF4A285)},
    {'id': 'Transport', 'icon': Icons.directions_bus_rounded, 'color': const Color(0xFF81C784)},
    {'id': 'Belanja', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFF64B5F6)},
    {'id': 'Tagihan', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFFE57373)},
  ];

  // --- DEFINISI WARNA ---
  final Color _greenBorder = const Color(0xFF4CAF50);  
  final Color _orangeActive = const Color(0xFFF4A285); 
  final Color _greyBg = const Color(0xFFF5F6FA);
  
  // Warna Tombol Simpan (Hijau Add Transaction)
  final Color _greenBtnColor = const Color.fromARGB(255, 11, 177, 100); 
  
  // Warna Tombol Pemasukan (Request Baru)
  final Color _greenIncomeActive = const Color(0xFF4CAF50); 

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.amount.toStringAsFixed(0));
    _noteController = TextEditingController();
    _selectedDate = widget.date;
    _currentImage = widget.receiptImage;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- LOGIC SIMPAN (UPDATED: Handle Type) ---
  Future<void> _saveTransaction() async {
    try {
      final transaction = {
        'id': const Uuid().v4(),
        'amount': double.parse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'categoryId': _selectedCategory,
        'date': _selectedDate.toIso8601String(),
        'note': _noteController.text.isEmpty ? "Scan Struk" : _noteController.text,
        'receiptPath': _currentImage.path,
        // TAMBAHAN PENTING: Penanda Tipe Transaksi
        'type': _isExpense ? 'EXPENSE' : 'INCOME',
      };

      print('Menyimpan transaksi scan: $transaction');
      final result = await DatabaseHelper.instance.insert('transactions', transaction);
      print('Transaksi scan berhasil disimpan dengan ID: $result');
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error menyimpan transaksi scan: $e');
    }
  }

  // --- LOGIC RESCAN ---
  Future<void> _performRescan() async {
    Navigator.pop(context); 

    try {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: true,
      );
      
      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();
      
      if (result.images.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Memperbarui data... 🤖"), duration: Duration(seconds: 1)),
      );

      final newPath = result.images.first;
      final ocrResult = await _ocrService.scanReceipt(newPath);

      setState(() {
        _currentImage = File(newPath);
        if (ocrResult.amount != null) {
          _amountController.text = ocrResult.amount!.toStringAsFixed(0);
        }
        if (ocrResult.date != null) {
          _selectedDate = ocrResult.date!;
        }
      });

    } catch (e) {
      print("Error Rescan: $e");
    }
  }

  void _showRescanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scan Ulang?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Gambar dan data yang sekarang akan diganti.", style: GoogleFonts.poppins()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _performRescan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: Text("Ya, Buka Kamera", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(String value) {
    if (value.isEmpty) return "0";
    double num = double.tryParse(value.replaceAll('.', '')) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(num);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER & THUMBNAIL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Review Transaksi", 
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Pastikan data sesuai dengan struk", 
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {}, 
                        child: Container(
                          width: 48, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black,
                            image: DecorationImage(
                              image: FileImage(_currentImage),
                              fit: BoxFit.cover
                            )
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 2. TOTAL BAYAR
                  Text("TOTAL BAYAR", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _greenBorder.withOpacity(0.3), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: _greenBorder.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        Text("Rp", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (val) {
                              String formatted = _formatNumber(val);
                              if (formatted != val) {
                                _amountController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                              }
                            },
                          ),
                        ),
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24)
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. TAB SWITCHER (WARNA SUDAH DIPERBAIKI)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _greyBg,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildTabButton("Pengeluaran", true)),
                        Expanded(child: _buildTabButton("Pemasukan", false)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. KATEGORI GRID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Kategori", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Lihat Semua", style: GoogleFonts.poppins(color: Colors.blue[400], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _categories.map((cat) => _buildCategoryItem(cat)).toList(),
                  ),

                  const SizedBox(height: 30),

                  // 5. TANGGAL
                  Align(alignment: Alignment.centerLeft, child: Text("Tanggal", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, initialDate: _selectedDate,
                        firstDate: DateTime(2020), lastDate: DateTime.now()
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400])
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. CATATAN
                  Align(alignment: Alignment.centerLeft, child: Text("Catatan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.sort_rounded, color: Colors.grey),
                        hintText: "Tulis deskripsi transaksi...",
                        border: InputBorder.none
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // 7. BOTTOM ACTION BAR
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF5F5F5)))
            ),
            child: Row(
              children: [
                // TOMBOL SCAN ULANG
                GestureDetector(
                  onTap: _showRescanDialog,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.black54),
                  ),
                ),
                const SizedBox(width: 16),
                
                // TOMBOL SIMPAN (WARNA HIJAU ADD TRANSACTION)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _greenBtnColor, // WARNA HIJAU SAMA DENGAN MANUAL
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text("Simpan Transaksi", 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---

  // UPDATED: Logic Warna Tab
  Widget _buildTabButton(String label, bool isExp) {
    // Cek apakah tab ini sedang aktif
    bool isActive = _isExpense == isExp;
    
    // Tentukan warna aktif: Orange untuk Pengeluaran, Hijau #a2d1b0 untuk Pemasukan
    Color activeColor = isExp ? _orangeActive : _greenIncomeActive;

    return GestureDetector(
      onTap: () => setState(() => _isExpense = isExp),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
            fontSize: 14
          )),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> cat) {
    bool isSelected = _selectedCategory == cat['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat['id']),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? cat['color'] : cat['color'].withOpacity(0.1), 
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(cat['icon'], color: isSelected ? Colors.white : cat['color'], size: 24),
          ),
          const SizedBox(height: 8),
          Text(cat['id'], style: GoogleFonts.poppins(
            fontSize: 12, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black87 : Colors.grey
          ))
        ],
      ),
    );
  }
}
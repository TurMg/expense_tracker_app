import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database_helper.dart';
import '../../logic/services/category_service.dart';

class AddTransactionScreen extends StatefulWidget {
  // Parameter Opsional (Diisi kalau hasil Scan, Kosong kalau Manual)
  final double? initialAmount;
  final DateTime? initialDate;
  final File? initialImage;

  const AddTransactionScreen(
      {super.key, this.initialAmount, this.initialDate, this.initialImage});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Controller
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = ''; // Akan diisi dengan kategori dinamis
  bool _isExpense = true; // Toggle Pengeluaran/Pemasukan
  bool _isAmountFilled = false; // Untuk track apakah amount sudah diisi

  // Warna dari desain
  final Color _orangeColor =
      const Color(0xFFF4A285); // Warna Peach/Orange Tombol
  final Color _greenBtnColor =
      const Color(0xFF98D1B6); // Warna Hijau Tombol Simpan
  final Color _textAmountColor = const Color(0xFFF4A285);

  final Color _greenIncomeActive = const Color(0xFF4CAF50); 

  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _incomeCategories = [];
  final CategoryService _categoryService = CategoryService();
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    // Isi data kalau ada (dari hasil scan)
    _amountController = TextEditingController(
        text: widget.initialAmount != null
            ? widget.initialAmount!.toStringAsFixed(0)
            : '');
    // Set initial state untuk amount filled
    _isAmountFilled = widget.initialAmount != null && widget.initialAmount! > 0;
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    _noteController = TextEditingController();
    _loadCategories();
  }

  // Load kategori dari database
  Future<void> _loadCategories() async {
    try {
      final expenseCats = await _categoryService.getCategoriesByType('EXPENSE');
      final incomeCats = await _categoryService.getCategoriesByType('INCOME');

      setState(() {
        _expenseCategories = expenseCats
            .map((cat) => {
                  'id': cat.id,
                  'name': cat.name,
                  'icon': cat.icon,
                  'color': cat.color,
                })
            .toList();

        _incomeCategories = incomeCats
            .map((cat) => {
                  'id': cat.id,
                  'name': cat.name,
                  'icon': cat.icon,
                  'color': cat.color,
                })
            .toList();

        _isLoadingCategories = false;

        // Set default category jika selected category kosong atau tidak ada di list
        final currentCategories =
            _isExpense ? _expenseCategories : _incomeCategories;
        if (_selectedCategory.isEmpty ||
            !currentCategories.any((cat) => cat['id'] == _selectedCategory)) {
          if (currentCategories.isNotEmpty) {
            _selectedCategory = currentCategories.first['id'];
          }
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      print('Amount tidak boleh kosong');
      return;
    }

    try {
      final transaction = {
        'id': const Uuid().v4(),
        'amount': double.parse(
            _amountController.text.replaceAll('.', '')), // Hapus titik format
        'categoryId': _selectedCategory,
        'date': _selectedDate.toIso8601String(),
        'note': _noteController.text,
        'receiptPath':
            widget.initialImage?.path, // Simpan path gambar kalau ada
        'type': _isExpense ? 'EXPENSE' : 'INCOME', // Tentukan tipe transaksi
      };

      print('Menyimpan transaksi: $transaction');
      final result =
          await DatabaseHelper.instance.insert('transactions', transaction);
      print('Transaksi berhasil disimpan dengan ID: $result');

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error menyimpan transaksi: $e');
    }
  }

  // Format ribuan saat ngetik (Simple formatter)
  String _formatNumber(String s) {
    if (s.isEmpty) return '';
    s = s.replaceAll('.', ''); // Hapus titik lama
    if (int.tryParse(s) == null) return '';
    final number = int.parse(s);
    return NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0)
        .format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Tambah Transaksi",
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // 1. TOGGLE (Pengeluaran / Pemasukan)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                            child:
                                _buildToggleButton("Pengeluaran", _isExpense)),
                        Expanded(
                            child:
                                _buildToggleButton("Pemasukan", !_isExpense)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. INPUT JUMLAH (GEDE BANGET)
                  const Text("Jumlah", style: TextStyle(color: Colors.grey)),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _textAmountColor),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Rp 0",
                      hintStyle:
                          TextStyle(color: _textAmountColor.withOpacity(0.5)),
                      prefixText:
                          _amountController.text.isNotEmpty ? "Rp " : null,
                      prefixStyle: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _textAmountColor),
                    ),
                    onChanged: (val) {
                      // Logic format ribuan sederhana
                      String formatted = _formatNumber(val);
                      if (formatted != val) {
                        _amountController.value = TextEditingValue(
                          text: formatted,
                          selection:
                              TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                      // Update state untuk warna tombol
                      setState(() {
                        _isAmountFilled =
                            formatted.isNotEmpty && formatted != '0';
                      });
                    },
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // 3. KATEGORI GRID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Kategori",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Lihat Semua",
                          style:
                              TextStyle(color: Colors.blue[400], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isLoadingCategories
                      ? const CircularProgressIndicator()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: (_isExpense
                                  ? _expenseCategories
                                  : _incomeCategories)
                              .map((cat) => _buildCategoryItem(cat))
                              .toList(),
                        ),

                  const SizedBox(height: 30),

                  // 4. TANGGAL
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Tanggal",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (picked != null)
                        setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey[400])
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. CATATAN
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Catatan",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                          icon: Icon(Icons.sort_rounded, color: Colors.grey),
                          hintText: "Tulis deskripsi transaksi...",
                          border: InputBorder.none),
                    ),
                  ),

                  // Kalau ada gambar hasil scan, tampilin kecil
                  if (widget.initialImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.image, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text("Gambar struk terlampir",
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12))
                        ],
                      ),
                    ),

                  const SizedBox(height: 100), // Space bawah
                ],
              ),
            ),
          ),

          // 6. TOMBOL SIMPAN (Sticky Bottom)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _isAmountFilled
                        ? const Color.fromARGB(
                            255, 11, 177, 100) // Warna cerah saat amount diisi
                        : _greenBtnColor, // Warna default saat amount kosong
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Simpan Transaksi",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildToggleButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = label == "Pengeluaran";
          // Reset kategori ke default berdasarkan jenis transaksi
          final categories =
              _isExpense ? _expenseCategories : _incomeCategories;
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first['id'];
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? (label == "Pengeluaran" ? _orangeColor : _greenIncomeActive)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold)),
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
              color: isSelected
                  ? cat['color']
                  : (cat['color'] as Color)
                      .withOpacity(0.1), // Selected jadi solid, unselected soft
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(cat['icon'] as IconData,
                color: isSelected ? Colors.white : cat['color']),
          ),
          const SizedBox(height: 8),
          Text(cat['name'],
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
        ],
      ),
    );
  }
}

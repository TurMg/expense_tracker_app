import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Buat generate ID unik
import '../../logic/services/ocr_service.dart';
import '../../data/local/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // --- CONTROLLERS & STATE ---
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _ocrService = OcrService();

  File? _receiptImage;
  bool _isScanning = false;
  DateTime _selectedDate = DateTime.now();

  // Nanti ini diambil dari Database, sementara hardcode dulu sesuai seed data
  String _selectedCategory = 'Makan';
  final List<String> _categories = ['Makan', 'Transport', 'Belanja', 'Gaji'];

  // --- LOGIC: AMBIL GAMBAR & SCAN ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _receiptImage = File(pickedFile.path);
        _isScanning = true; // Mulai loading
      });

      // PANGGIL SERVICE OCR DI SINI
      final detectedAmount = await _ocrService.scanReceipt(pickedFile.path);

      if (mounted) {
        setState(() {
          _isScanning = false; // Stop loading
          if (detectedAmount != null) {
            // Kalau nemu angka, langsung tempel ke kolom Amount
            _amountController.text = detectedAmount.toStringAsFixed(0);

            // UX: Kasih notif sukses
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Dapet bro! Totalnya Rp ${detectedAmount.toStringAsFixed(0)}"),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // UX: Kasih notif gagal
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Waduh, gak nemu totalnya. Isi manual ya bro."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    } catch (e) {
      setState(() => _isScanning = false);
      print("Error ambil gambar: $e");
    }
  }

  // --- LOGIC: SIMPAN KE DB ---
  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi dulu nominalnya bro!")),
      );
      return;
    }

    // Siapin data
    final transaction = {
      'id': const Uuid().v4(), // Generate ID unik
      'amount': double.parse(_amountController.text),
      'categoryId': _selectedCategory, // Nanti ini pake ID kategori beneran
      'date': _selectedDate.toIso8601String(),
      'note': _noteController.text,
      'receiptPath': _receiptImage?.path, // Simpan path gambarnya aja
    };

    // Panggil Database Helper
    await DatabaseHelper.instance.insert('transactions', transaction);

    if (mounted) {
      Navigator.pop(context, true); // Balik ke halaman Home & refresh
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ocrService.dispose(); // PENTING: Matikan mata OCR
    super.dispose();
  }

  // --- UI VIEW ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Catat Transaksi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. AREA FOTO STRUK
            GestureDetector(
              onTap: () => _showPickerOptions(context),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                  image: _receiptImage != null
                      ? DecorationImage(
                          image: FileImage(_receiptImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _isScanning
                    ? const Center(
                        child: CircularProgressIndicator()) // Loading pas scan
                    : _receiptImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 50, color: Colors.grey),
                              Text("Tap buat Scan Struk",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 20),

            // 2. FORM INPUT
            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Total Belanja (Rp)",
                border: OutlineInputBorder(),
                prefixText: "Rp ",
                suffixIcon: Icon(Icons.attach_money),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(
                labelText: "Kategori",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Note Field
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: "Catatan (Opsional)",
                border: OutlineInputBorder(),
                icon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 16),

            // Date Picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  "Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),

            const SizedBox(height: 30),

            // 3. TOMBOL SIMPAN
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("SIMPAN TRANSAKSI",
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  // Modal Bawah buat pilih Kamera/Galeri
  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Ambil dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Foto Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

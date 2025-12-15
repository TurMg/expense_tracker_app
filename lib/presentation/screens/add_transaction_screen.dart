import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../logic/services/ocr_service.dart';
import '../../data/local/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _ocrService = OcrService();

  File? _receiptImage;
  bool _isScanning = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Makan';
  final List<String> _categories = ['Makan', 'Transport', 'Belanja', 'Gaji'];

  // --- LOGIC UTAMA: SCANNER ---
  Future<void> _scanReceipt() async {
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

      final scannedPath = result.images.first;

      setState(() {
        _receiptImage = File(scannedPath);
        _isScanning = true;
      });

      // Proses OCR
      final ocrResult = await _ocrService.scanReceipt(scannedPath);

      if (mounted) {
        setState(() {
          _isScanning = false;

          // LANGSUNG ISI TOTAL
          bool dataFound = false;
          if (ocrResult.amount != null) {
            _amountController.text = ocrResult.amount!.toStringAsFixed(0);
            dataFound = true;
          }

          // ISI TANGGAL
          if (ocrResult.date != null) {
            _selectedDate = ocrResult.date!;
          }

          if (dataFound) {
            String msg =
                "Scan sukses! Rp ${ocrResult.amount?.toStringAsFixed(0) ?? '-'}";
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Total tidak ditemukan. Pastikan foto jelas."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    } catch (e) {
      setState(() => _isScanning = false);
      print("Error Scan: $e");
    }
  }

  // --- LOGIC SIMPAN (Sama) ---
  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi dulu nominalnya bro!")),
      );
      return;
    }

    final transaction = {
      'id': const Uuid().v4(),
      'amount': double.parse(_amountController.text),
      'categoryId': _selectedCategory,
      'date': _selectedDate.toIso8601String(),
      'note': _noteController.text,
      'receiptPath': _receiptImage?.path,
    };

    await DatabaseHelper.instance.insert('transactions', transaction);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Catat Transaksi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _scanReceipt,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                  image: _receiptImage != null
                      ? DecorationImage(
                          image: FileImage(_receiptImage!), fit: BoxFit.contain)
                      : null,
                ),
                child: _isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : _receiptImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.document_scanner_rounded,
                                  size: 50, color: Colors.blue),
                              Text("Tap buat Scan Otomatis",
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                            ],
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 20),
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
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(
                  labelText: "Kategori", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                  labelText: "Catatan (Opsional)",
                  border: OutlineInputBorder(),
                  icon: Icon(Icons.note)),
            ),
            const SizedBox(height: 16),
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
}

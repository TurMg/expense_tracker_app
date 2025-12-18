import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/category_model.dart';
import '../../logic/services/category_service.dart';
import 'add_transaction_screen.dart'; // Import buat fitur Edit

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final ScrollController? scrollController;

  const TransactionDetailScreen(
      {super.key, required this.transaction, this.scrollController});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _categoryService = CategoryService();
  Category? _category;
  bool _isLoading = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _loadCategory();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategory() async {
    final categories = await _categoryService.getAllCategories();
    final categoryId = widget.transaction['categoryId'];

    setState(() {
      _category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => Category(
          id: categoryId,
          name: categoryId,
          type: widget.transaction['type'],
          icon: Icons.category_rounded,
          color: Colors.grey,
        ),
      );
      _isLoading = false;
    });
  }

  // --- LOGIC DELETE ---
  Future<void> _deleteTransaction(BuildContext context) async {
    // Tampilkan Dialog Konfirmasi dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Hapus Transaksi?",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Data ini akan hilang permanen lho.",
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text("Batal", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Hapus", style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Hapus dari DB
      await DatabaseHelper.instance.query(
          'DELETE FROM transactions WHERE id = ?', [widget.transaction['id']]);
      if (context.mounted) {
        Navigator.pop(context, true); // Balik ke Home & Refresh
      }
    }
  }

  // --- LOGIC EDIT ---
  Future<void> _editTransaction(BuildContext context) async {
    // Navigasi ke AddTransactionScreen dengan membawa data transaksi yang ada
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          existingTransaction: widget.transaction,
        ),
      ),
    );

    // Jika berhasil edit, refresh data dan tutup detail screen
    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  // --- FORMATTER ---
  String _formatRp(double amount) {
    return NumberFormat.currency(
            locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Extract Data
    double amount = widget.transaction['amount'] as double;
    String dateStr = widget.transaction['date'];
    String note = widget.transaction['note'] ?? '-';
    bool isExpense = (widget.transaction['type'] == 'EXPENSE' ||
        widget.transaction['type'] == null);

    // Style Variables
    final Color primaryColor =
        isExpense ? const Color(0xFFF4A285) : const Color(0xFFA2D1B0);
    final String labelType = isExpense ? "Pengeluaran" : "Pemasukan";
    final IconData iconType =
        isExpense ? Icons.trending_down_rounded : Icons.trending_up_rounded;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. HEADER (Drag Handle & Close)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // Drag Handle Look
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 20),
                        // Title Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(
                                width: 24), // Spacer biar title tengah
                            Text("Detail Transaksi",
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        )
                      ],
                    ),
                  ),

                  // 2. MAIN CONTENT (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Amount
                          Text(_formatRp(amount),
                              style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2C37))),
                          const SizedBox(height: 16),

                          // Badge Type
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconType,
                                    size: 16,
                                    color: primaryColor), // Icon panah kecil
                                const SizedBox(width: 8),
                                Text(labelType,
                                    style: GoogleFonts.poppins(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                          const Divider(color: Color(0xFFF5F6FA), thickness: 2),
                          const SizedBox(height: 20),

                          // --- ITEM LIST ---

                          // 1. KATEGORI
                          _buildDetailItem(
                              title: "KATEGORI",
                              value: _category?.name ?? 'Tidak ada kategori',
                              icon: _category?.icon ?? Icons.category_rounded,
                              bgColor: _category?.color?.withOpacity(0.15) ?? const Color(0xFFFFF3E0),
                              iconColor: _category?.color ?? const Color(0xFFF57C00),
                              hasArrow: true),

                          // 2. WAKTU
                          _buildDetailItem(
                            title: "WAKTU",
                            value: _formatDate(dateStr),
                            icon: Icons.calendar_today_rounded,
                            bgColor: const Color(0xFFE3F2FD), // Biru muda
                            iconColor: const Color(0xFF2196F3),
                          ),

                          // 3. SUMBER DANA (Hardcode dulu sesuai gambar, atau ambil dr DB kalau ada)
                          _buildDetailItem(
                            title: "SUMBER DANA",
                            value: "Tunai / Cash",
                            icon: Icons.account_balance_wallet_rounded,
                            bgColor: const Color(0xFFE8F5E9), // Hijau muda
                            iconColor: const Color(0xFF4CAF50),
                          ),

                          // 4. CATATAN
                          _buildDetailItem(
                              title: "CATATAN",
                              value: note,
                              icon: Icons.description_rounded,
                              bgColor: const Color(0xFFF3E5F5), // Ungu muda
                              iconColor: const Color(0xFFAB47BC),
                              isMultiLine: true),
                        ],
                      ),
                    ),
                  ),

                  // 3. BOTTOM BUTTONS
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Tombol Edit
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _editTransaction(context),
                            icon: const Icon(Icons.edit,
                                size: 18, color: Colors.white),
                            label: Text("Edit Transaksi",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                    0xFF2196F3), // Biru sesuai gambar
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tombol Hapus
                        TextButton.icon(
                          onPressed: () => _deleteTransaction(context),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE57373), size: 18),
                          label: Text("Hapus Transaksi",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFE57373),
                                  fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildDetailItem({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    bool hasArrow = false,
    bool isMultiLine = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F1F1)), // Border halus
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Row(
        crossAxisAlignment:
            isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF90A4AE),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2C37)),
                  maxLines: isMultiLine ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasArrow)
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400])
        ],
      ),
    );
  }
}

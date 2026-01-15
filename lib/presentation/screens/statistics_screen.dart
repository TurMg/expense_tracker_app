import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isExpense = true; // Tab Pengeluaran Aktif
  int _selectedPeriodIndex =
      0; // 0: Harian, 1: Mingguan, 2: Bulanan, 3: Tahunan

  // Warna UI (Sesuai Gambar)
  final Color _activeBlue = const Color(0xFF4296F4);
  final Color _inactiveGrey = const Color(0xFFF1F1F1);
  final Color _textBlack = const Color(0xFF1F2C37);
  final Color _textGrey = const Color(0xFF9E9E9E);
  final Color _redBadgeBg = const Color(0xFFFEECEB);
  final Color _redBadgeText = const Color(0xFFE57373);

  // Data Dummy Kategori
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Makanan & Minuman',
      'count': '12 Transaksi',
      'amount': 'Rp 2.080.000',
      'pct': 0.4, // 40%
      'color': const Color(0xFFFF8A65), // Orange
      'icon': Icons.restaurant_menu_rounded,
      'bgIcon': const Color(0xFFFFF3E0),
    },
    {
      'name': 'Transportasi',
      'count': '8 Transaksi',
      'amount': 'Rp 1.560.000',
      'pct': 0.3, // 30%
      'color': const Color(0xFF64B5F6), // Blue
      'icon': Icons.directions_car_filled_rounded,
      'bgIcon': const Color(0xFFE3F2FD),
    },
    {
      'name': 'Belanja Bulanan',
      'count': '5 Transaksi',
      'amount': 'Rp 1.560.000',
      'pct': 0.3, // 30%
      'color': const Color(0xFFA5D6A7), // Green
      'icon': Icons.shopping_bag_rounded,
      'bgIcon': const Color(0xFFE8F5E9),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Statistik Keuangan",
            style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {},
              icon:
                  const Icon(Icons.calendar_today_rounded, color: Colors.black))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TAB SWITCHER (Pemasukan / Pengeluaran)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!)),
              child: Row(
                children: [
                  Expanded(child: _buildMainTab("Pemasukan", false)),
                  Expanded(child: _buildMainTab("Pengeluaran", true)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. PERIOD FILTER 
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodChip("Harian", 0),
                const SizedBox(width: 4),
                _buildPeriodChip("Mingguan", 1),
                const SizedBox(width: 4),
                _buildPeriodChip("Bulanan", 2),
                const SizedBox(width: 4),
                _buildPeriodChip("Tahunan", 3),
              ],
            ),

            const SizedBox(height: 24),

            // 3. CHART CARD AREA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[100]!),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tren Pengeluaran",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16)),

                  const SizedBox(height: 20),

                  // --- LINE CHART ---
                  AspectRatio(
                    aspectRatio: 1.7,
                    child: LineChart(
                      _mainData(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TOTAL SUMMARY DI BAWAH CHART
                  Text("Total Pengeluaran Minggu Ini",
                      style:
                          GoogleFonts.poppins(color: _textGrey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text("Rp 5.200.000",
                      style: GoogleFonts.poppins(
                          color: _textBlack,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _redBadgeBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text("📈 +12% dari minggu lalu",
                        style: GoogleFonts.poppins(
                            color: _redBadgeText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 4. KATEGORI PENGELUARAN TITLE
            Text("Kategori Pengeluaran",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),

            // 5. LIST KATEGORI
            ..._categories.map((cat) => _buildCategoryItem(cat)).toList(),

            const SizedBox(height: 30),
          ],
        ),
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

              // OPSI 1: SCAN STRUK
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
                onTap: () {
                  Navigator.pop(context); // Tutup BottomSheet
                  // TODO: Implement scan functionality
                },
              ),

              const SizedBox(height: 10),

              // OPSI 2: INPUT MANUAL
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
                onTap: () {
                  Navigator.pop(context); // Tutup BottomSheet
                  // TODO: Navigate to manual input screen
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- CHART CONFIGURATION ---
  LineChartData _mainData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1000,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey[100], strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: 6,
      // FORCE TOOLTIP MUNCUL DI INDEX 4 (JUMAT)
      showingTooltipIndicators: [
        ShowingTooltipIndicators([
          LineBarSpot(
            LineChartBarData(spots: []),
            0,
            LineChartBarData(spots: []).spots.isEmpty
                ? const FlSpot(4, 4.8)
                : const FlSpot(4, 4.8),
          ),
        ])
      ],
      lineTouchData: LineTouchData(
        enabled: false,
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
          return spotIndexes.map((spotIndex) {
            return TouchedSpotIndicatorData(
              FlLine(color: Colors.transparent),
              FlDotData(
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: _activeBlue,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  );
                },
              ),
            );
          }).toList();
        },
        touchTooltipData: LineTouchTooltipData(
          // --- PERBAIKAN DI SINI ---
          // Menggunakan getTooltipColor (Function) bukan tooltipBgColor (Color)
          getTooltipColor: (touchedSpot) => const Color(0xFF1F2C37),

          tooltipRoundedRadius: 8,
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tooltipMargin: 16,
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              return LineTooltipItem(
                'Rp 1.2jt',
                GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 2.0), // Sen
            FlSpot(1, 2.8), // Sel
            FlSpot(2, 2.2), // Rab
            FlSpot(3, 3.5), // Kam
            FlSpot(4, 4.8), // Jum (Puncak)
            FlSpot(5, 3.0), // Sab
            FlSpot(6, 3.8), // Min
          ],
          isCurved: true,
          color: _activeBlue.withOpacity(0.5),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                _activeBlue.withOpacity(0.2),
                _activeBlue.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    TextStyle style = GoogleFonts.poppins(
        color: Colors.grey[400], fontWeight: FontWeight.w500, fontSize: 12);

    // Highlight Jumat
    if (value.toInt() == 4) {
      style = GoogleFonts.poppins(
          color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12);
    }

    Widget text;
    switch (value.toInt()) {
      case 0:
        text = Text('Sen', style: style);
        break;
      case 1:
        text = Text('Sel', style: style);
        break;
      case 2:
        text = Text('Rab', style: style);
        break;
      case 3:
        text = Text('Kam', style: style);
        break;
      case 4:
        text = Text('Jum', style: style);
        break;
      case 5:
        text = Text('Sab', style: style);
        break;
      case 6:
        text = Text('Min', style: style);
        break;
      default:
        text = const Text('');
    }

    return SideTitleWidget(axisSide: meta.axisSide, child: text);
  }

  // --- WIDGET HELPER ---

  Widget _buildMainTab(String label, bool isExp) {
    bool isActive = _isExpense == isExp;
    return GestureDetector(
      onTap: () => setState(() => _isExpense = isExp),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? (isExp ? const Color(0xFFF4A285) : const Color(0xFF4CAF50))
              : Colors.transparent, // Active jadi Oranye untuk Pengeluaran, Hijau untuk Pemasukan
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : Colors.grey, // Text putih kalau active
                  fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int index) {
    bool isActive = _selectedPeriodIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriodIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? _activeBlue : Colors.transparent, // Biru vs Transparan
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: isActive ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item['bgIcon'],
              shape: BoxShape.circle,
            ),
            child: Icon(item['icon'], color: item['color'], size: 24),
          ),
          const SizedBox(width: 16),

          // Data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(item['count'],
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(item['amount'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 14)),

                        // Progress Bar Kecil di Kanan
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: item['pct'],
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      item['color']),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text("${(item['pct'] * 100).toInt()}%",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey, fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
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

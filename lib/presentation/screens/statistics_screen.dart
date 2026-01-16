import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isExpense = true; // Tab Pengeluaran Aktif
  int _selectedPeriodIndex =
      0; // 0: Harian, 1: Mingguan (gunakan logika bulanan), 2: Bulanan (gunakan logika tahunan)

  List<Map<String, dynamic>> _realCategories = [];
  List<FlSpot> _chartSpots = [];
  List<DateTime> _chartDates = [];
  List<String> _monthLabels = [];
  double _totalAmount = 0.0;
  int _numWeeks = 4; // default
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatisticsData();
  }

  // Warna UI (Sesuai Gambar)
  final Color _activeBlue = const Color(0xFF4296F4);
  final Color _inactiveGrey = const Color(0xFFF1F1F1);
  final Color _textBlack = const Color(0xFF1F2C37);
  final Color _textGrey = const Color(0xFF9E9E9E);
  final Color _redBadgeBg = const Color(0xFFFEECEB);
  final Color _redBadgeText = const Color(0xFFE57373);

  Future<void> _loadStatisticsData() async {
    setState(() => _isLoading = true);

    String type = _isExpense ? 'EXPENSE' : 'INCOME';
    DateTime now = DateTime.now();

    // Tentukan periode
    DateTime startDate;
    DateTime endDate = now;
    if (_selectedPeriodIndex == 0) {
      // Harian: 7 hari terakhir
      startDate = now.subtract(const Duration(days: 6));
    } else if (_selectedPeriodIndex == 1) {
      // Mingguan: bulan ini
      startDate = DateTime(now.year, now.month, 1);
    } else {
      // Bulanan: 12 bulan terakhir
      startDate = DateTime(now.year - 1, now.month + 1, 1);
    }

    // Ambil transaksi dalam periode
    List<Map<String, dynamic>> transactions =
        await DatabaseHelper.instance.query(
      "SELECT * FROM transactions WHERE type = ? AND date >= ? AND date <= ?",
      [type, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // Hitung total amount
    if (_selectedPeriodIndex == 0) {
      // Untuk harian, total hari ini saja
      DateTime today = DateTime(now.year, now.month, now.day);
      _totalAmount = transactions.where((t) {
        DateTime tDate = DateTime.parse(t['date']);
        return tDate.year == today.year &&
            tDate.month == today.month &&
            tDate.day == today.day;
      }).fold(0.0, (sum, t) => sum + (t['amount'] as double));
    } else {
      _totalAmount =
          transactions.fold(0.0, (sum, t) => sum + (t['amount'] as double));
    }

    // Untuk chart: hitung berdasarkan periode
    if (_selectedPeriodIndex == 0) {
      // Harian: 7 hari terakhir
      _chartSpots = [];
      _chartDates = [];
      for (int i = 0; i < 7; i++) {
        DateTime date = startDate.add(Duration(days: i));
        _chartDates.add(date);
        double dayTotal = transactions.where((t) {
          DateTime tDate = DateTime.parse(t['date']);
          return tDate.year == date.year &&
              tDate.month == date.month &&
              tDate.day == date.day;
        }).fold(0.0, (sum, t) => sum + (t['amount'] as double));
        _chartSpots
            .add(FlSpot(i.toDouble(), dayTotal / 100000)); // Scale untuk chart
      }
    } else if (_selectedPeriodIndex == 1) {
      // Mingguan: bagi bulan ini menjadi beberapa minggu sesuai jumlah hari
      _chartSpots = [];
      DateTime monthStart = startDate;
      int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      _numWeeks = (daysInMonth / 7).ceil();
      int weekLength = (daysInMonth / _numWeeks).ceil();
      for (int i = 0; i < _numWeeks; i++) {
        DateTime weekStart = monthStart.add(Duration(days: i * weekLength));
        DateTime weekEnd = (i == _numWeeks - 1) ? endDate : weekStart.add(Duration(days: weekLength - 1));
        double weekTotal = transactions.where((t) {
          DateTime tDate = DateTime.parse(t['date']);
          return tDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              tDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).fold(0.0, (sum, t) => sum + (t['amount'] as double));
        _chartSpots.add(FlSpot(i.toDouble(), weekTotal / 100000));
      }
    } else {
      // Bulanan: 12 bulan terakhir
      _chartSpots = [];
      _monthLabels = [];
      for (int i = 11; i >= 0; i--) {
        DateTime month = DateTime(now.year, now.month - i, 1);
        String monthLabel = DateFormat('MMM', 'id_ID').format(month);
        _monthLabels.add(monthLabel);
        double monthTotal = transactions.where((t) {
          DateTime tDate = DateTime.parse(t['date']);
          return tDate.year == month.year && tDate.month == month.month;
        }).fold(0.0, (sum, t) => sum + (t['amount'] as double));
        _chartSpots.add(FlSpot((11 - i).toDouble(), monthTotal / 100000));
      }
    }

    // Ambil kategori dengan statistik
    await _loadCategoriesWithStats(transactions);

    setState(() => _isLoading = false);
  }

  Future<void> _loadCategoriesWithStats(
      List<Map<String, dynamic>> transactions) async {
    // Group by categoryId
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var t in transactions) {
      String catId = t['categoryId'];
      if (!grouped.containsKey(catId)) grouped[catId] = [];
      grouped[catId]!.add(t);
    }

    // Ambil detail kategori
    List<Map<String, dynamic>> categories = await DatabaseHelper.instance.query(
        "SELECT * FROM categories WHERE type = ?",
        [_isExpense ? 'EXPENSE' : 'INCOME']);

    _realCategories = [];
    for (var cat in categories) {
      String catId = cat['id'];
      if (grouped.containsKey(catId)) {
        var trans = grouped[catId]!;
        double total =
            trans.fold(0.0, (sum, t) => sum + (t['amount'] as double));
        _realCategories.add({
          'name': cat['name'],
          'count': '${trans.length} Transaksi',
          'amount':
              'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(total)}',
          'pct': trans.length /
              transactions.length, // Percentage berdasarkan jumlah transaksi
          'color': Color(cat['colorCode']),
          'icon': IconData(cat['iconCode'], fontFamily: 'MaterialIcons'),
          'bgIcon': Color(cat['colorCode']).withOpacity(0.1),
        });
      }
    }

    // Sort by total descending
    _realCategories.sort((a, b) => double.parse(b['pct'].toString())
        .compareTo(double.parse(a['pct'].toString())));
  }

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
                  Text(
                      _selectedPeriodIndex == 0
                          ? "Total Pengeluaran Hari Ini"
                          : _selectedPeriodIndex == 1
                              ? "Total Pengeluaran Bulan Ini"
                              : "Total Pengeluaran Tahun Ini",
                      style:
                          GoogleFonts.poppins(color: _textGrey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                      "Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_totalAmount)}",
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
            ...(_realCategories.isNotEmpty ? _realCategories : _categories)
                .map((cat) => _buildCategoryItem(cat))
                .toList(),

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
      maxX: _selectedPeriodIndex == 0
          ? 6
          : _selectedPeriodIndex == 1
              ? _numWeeks - 1
              : 11,
      minY: 0,
      maxY: _chartSpots.isNotEmpty
          ? (_chartSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity)
          : 6,
      lineTouchData: LineTouchData(
        enabled: true,
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
              double actualAmount = barSpot.y * 100000;
              return LineTooltipItem(
                'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(actualAmount)}',
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
          spots: _chartSpots.isNotEmpty
              ? _chartSpots
              : const [
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
          dotData: const FlDotData(show: true),
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

    Widget text;
    if (_selectedPeriodIndex == 0) {
      // Harian: nama hari sesuai tanggal
      if (value.toInt() < _chartDates.length) {
        DateTime date = _chartDates[value.toInt()];
        String dayName;
        switch (date.weekday) {
          case DateTime.monday:
            dayName = 'Sen';
            break;
          case DateTime.tuesday:
            dayName = 'Sel';
            break;
          case DateTime.wednesday:
            dayName = 'Rab';
            break;
          case DateTime.thursday:
            dayName = 'Kam';
            break;
          case DateTime.friday:
            dayName = 'Jum';
            break;
          case DateTime.saturday:
            dayName = 'Sab';
            break;
          case DateTime.sunday:
            dayName = 'Min';
            break;
          default:
            dayName = '';
        }
        // Highlight hari terkini (hari ini)
        DateTime now = DateTime.now();
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          style = GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12);
        }
        text = Text(dayName, style: style);
      } else {
        text = const Text('');
      }
    } else if (_selectedPeriodIndex == 1) {
      // Mingguan: Minggu-1, Minggu-2, Minggu-3, Minggu-4, Minggu-5
      DateTime now = DateTime.now();
      int daysIntoMonth = now.day - 1;
      int currentWeekIndex = (daysIntoMonth / 7).floor();
      TextStyle finalStyle = style;
      if (value.toInt() == currentWeekIndex) {
        finalStyle = GoogleFonts.poppins(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12);
      }
      switch (value.toInt()) {
        case 0:
          text = Text('Minggu-1', style: finalStyle);
          break;
        case 1:
          text = Text('Minggu-2', style: finalStyle);
          break;
        case 2:
          text = Text('Minggu-3', style: finalStyle);
          break;
        case 3:
          text = Text('Minggu-4', style: finalStyle);
          break;
        case 4:
          text = Text('Minggu-5', style: finalStyle);
          break;
        default:
          text = const Text('');
      }
    } else {
      // Bulanan: label bulan sesuai data
      if (value.toInt() < _monthLabels.length) {
        TextStyle finalStyle = style;
        if (value.toInt() == 11) {
          finalStyle = GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12);
        }
        text = Text(_monthLabels[value.toInt()], style: finalStyle);
      } else {
        text = const Text('');
      }
    }

    return SideTitleWidget(axisSide: meta.axisSide, child: text);
  }

  // --- WIDGET HELPER ---

  Widget _buildMainTab(String label, bool isExp) {
    bool isActive = _isExpense == isExp;
    return GestureDetector(
      onTap: () {
        if (_isExpense != isExp) {
          setState(() => _isExpense = isExp);
          _loadStatisticsData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? (isExp ? const Color(0xFFF4A285) : const Color(0xFF4CAF50))
              : Colors
                  .transparent, // Active jadi Oranye untuk Pengeluaran, Hijau untuk Pemasukan
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
      onTap: () {
        if (_selectedPeriodIndex != index) {
          setState(() => _selectedPeriodIndex = index);
          _loadStatisticsData();
        }
      },
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

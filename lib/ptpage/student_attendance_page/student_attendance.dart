import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

class StudentAttendancePage extends StatefulWidget {
  final Users student;

  const StudentAttendancePage({super.key, required this.student});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage>
    with SingleTickerProviderStateMixin {
  late Future<List<Attendance>> _attendanceFuture;
  List<Attendance> _allAttendances = [];
  List<Attendance> _filteredAttendances = [];

  int _totalClasses = 0;
  int _attended = 0;
  int _missed = 0;

  String _selectedFilter = "Son 30 Gün";
  final List<String> _filterOptions = [
    "Haftalık",
    "Son 30 Gün",
    "Aylık",
    "Yıllık",
    "Tümü",
  ];

  late TabController _tabController;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _attendanceFuture = _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 🔥 STATUS DEĞERİNİ DOĞRU PARSE ET (TÜM DURUMLARI KAPSAR)
  // =========================================================================

  /// Bu fonksiyon, status değeri ne olursa olsun doğru şekilde parse eder
  /// "TRUE", "true", "True", "1", "YES", true, 1 hepsi için true döner
  bool _isPresent(Attendance att) {
    final status = att.status;
    if (status == null) return false;

    // String ise (en yaygın durum)
    if (status is String) {
      final upper = status.toUpperCase().trim();
      return upper == "TRUE" ||
          upper == "1" ||
          upper == "YES" ||
          upper == "EVET";
    }
  }

  String _formatDateTurkish(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getShortMonthName(int month) {
    const months = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];
    return months[month - 1];
  }

  Future<List<Attendance>> _fetchData() async {
    try {
      final repo = AppRepository();
      if (!repo.isLoaded) await repo.loadCriticalData();

      final allAttendances = repo.allAttendances;
      print("📊 Toplam yoklama: ${allAttendances.length}");

      final data = allAttendances
          .where((a) => a.student_id == widget.student.app)
          .toList();

      print(
        "📊 Öğrenci ${widget.student.first_name} için ${data.length} yoklama",
      );
      for (var att in data) {
        print(
          "   Tarih: ${att.attendance_date}, Status: ${att.status}, Tip: ${att.status.runtimeType}",
        );
      }

      data.sort((a, b) => b.attendance_date.compareTo(a.attendance_date));
      return data;
    } catch (e) {
      throw Exception("Veriler yüklenirken hata oluştu: $e");
    }
  }

  void _applyFilter(List<Attendance> data) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilter) {
      case "Haftalık":
        startDate = now.subtract(const Duration(days: 7));
        break;
      case "Son 30 Gün":
        startDate = now.subtract(const Duration(days: 30));
        break;
      case "Aylık":
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case "Yıllık":
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(2000);
    }

    List<Attendance> filtered;
    if (_selectedFilter == "Tümü") {
      filtered = data;
    } else {
      filtered = data.where((a) {
        final date = DateTime.parse(a.attendance_date);
        return date.isAfter(startDate);
      }).toList();
    }

    int attendedCount = 0;
    int missedCount = 0;

    // 🔥 _isPresent fonksiyonu ile doğru kontrol
    for (var att in filtered) {
      if (_isPresent(att)) {
        attendedCount++;
      } else {
        missedCount++;
      }
    }

    _allAttendances = data;
    _filteredAttendances = filtered;
    _totalClasses = filtered.length;
    _attended = attendedCount;
    _missed = missedCount;

    print(
      "📊 Filtre sonucu: Toplam=$_totalClasses, Katıldı=$_attended, Kaçırdı=$_missed",
    );
  }

  void _changeFilter(String newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      _applyFilter(_allAttendances);
    });
  }

  Map<String, Map<String, int>> _getMonthlyStats() {
    Map<String, Map<String, int>> monthly = {};
    for (var att in _filteredAttendances) {
      if (att.attendance_date.length >= 7) {
        String monthKey = att.attendance_date.substring(0, 7);
        if (!monthly.containsKey(monthKey)) {
          monthly[monthKey] = {"attended": 0, "missed": 0};
        }
        if (_isPresent(att)) {
          monthly[monthKey]!["attended"] = monthly[monthKey]!["attended"]! + 1;
        } else {
          monthly[monthKey]!["missed"] = monthly[monthKey]!["missed"]! + 1;
        }
      }
    }
    return monthly;
  }

  Map<String, Map<String, int>> _getWeeklyStats() {
    Map<String, Map<String, int>> weekly = {};
    for (var att in _filteredAttendances) {
      try {
        final date = DateTime.parse(att.attendance_date);
        final weekKey = DateFormat('yyyy-WW').format(date);
        if (!weekly.containsKey(weekKey)) {
          weekly[weekKey] = {"attended": 0, "missed": 0};
        }
        if (_isPresent(att)) {
          weekly[weekKey]!["attended"] = weekly[weekKey]!["attended"]! + 1;
        } else {
          weekly[weekKey]!["missed"] = weekly[weekKey]!["missed"]! + 1;
        }
      } catch (e) {
        print("Tarih parse hatası: $e");
      }
    }
    return weekly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Yoklama Raporum",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _changeFilter,
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == _selectedFilter
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: filter == _selectedFilter
                          ? Colors.indigo
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: FutureBuilder<List<Attendance>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error);
          }

          final data = snapshot.data ?? [];

          if (!_isDataLoaded || data != _allAttendances) {
            _applyFilter(data);
            _isDataLoaded = true;
          }

          if (data.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedFilter,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_totalClasses} kayıt",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildSummaryCard(),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.indigo.shade50,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: "Grafik", icon: Icon(Icons.bar_chart)),
                    Tab(text: "Liste", icon: Icon(Icons.list_alt)),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildChartView(), _buildListView()],
                ),
              ),
              const VersionFooter(),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.indigo),
          const SizedBox(height: 16),
          Text(
            "Yoklama verileri yükleniyor...",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            "Veriler yüklenirken hata oluştu",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _attendanceFuture = _fetchData();
                _isDataLoaded = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar Dene"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double rate = _totalClasses == 0 ? 0 : (_attended / _totalClasses) * 100;
    Color rateColor = rate >= 80
        ? Colors.green
        : (rate >= 50 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Toplam",
                "$_totalClasses",
                Icons.calendar_today,
                Colors.white,
              ),
              _buildStatItem(
                "Katıldı",
                "$_attended",
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Kaçırdı",
                "$_missed",
                Icons.cancel,
                Colors.red.shade300,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        "Katılım Oranı",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "%${rate.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: rateColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildChartView() {
    final monthlyStats = _getMonthlyStats();
    final weeklyStats = _getWeeklyStats();

    if (_selectedFilter == "Haftalık" && weeklyStats.isNotEmpty) {
      return _buildWeeklyChart(weeklyStats);
    } else if (monthlyStats.isNotEmpty) {
      return _buildMonthlyChart(monthlyStats);
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Bu dönemde yoklama verisi yok",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildWeeklyChart(Map<String, Map<String, int>> weeklyStats) {
    var sortedKeys = weeklyStats.keys.toList()..sort();
    double maxBarHeight = 120.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph, color: Colors.indigo, size: 22),
                SizedBox(width: 8),
                Text(
                  "Haftalık Katılım Grafiği",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final week = sortedKeys[index];
                  final att = weeklyStats[week]!["attended"]!;
                  final mis = weeklyStats[week]!["missed"]!;
                  final total = att + mis;
                  double attHeight = total == 0
                      ? 0
                      : (att / total) * maxBarHeight;
                  final weekNum = week.split('-')[1];
                  final year = week.split('-')[0];

                  return Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 30,
                              height: maxBarHeight,
                              decoration: BoxDecoration(
                                color: Colors.red.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              width: 30,
                              height: attHeight,
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$year Hafta $weekNum",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "$att/$total",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green.shade400, "Katıldı"),
                const SizedBox(width: 20),
                _buildLegendItem(Colors.red.shade200, "Kaçırdı"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(Map<String, Map<String, int>> monthlyStats) {
    var sortedKeys = monthlyStats.keys.toList()..sort();
    double maxBarHeight = 120.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.indigo, size: 22),
                SizedBox(width: 8),
                Text(
                  "Aylık Katılım Grafiği",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final month = sortedKeys[index];
                  final att = monthlyStats[month]!["attended"]!;
                  final mis = monthlyStats[month]!["missed"]!;
                  final total = att + mis;
                  double attHeight = total == 0
                      ? 0
                      : (att / total) * maxBarHeight;
                  final monthNum = int.parse(month.split('-')[1]);
                  final monthName = _getShortMonthName(monthNum);
                  final year = month.split('-')[0];

                  return Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 35,
                              height: maxBarHeight,
                              decoration: BoxDecoration(
                                color: Colors.red.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              width: 35,
                              height: attHeight,
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          monthName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          year,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "$att/$total",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green.shade400, "Katıldı"),
                const SizedBox(width: 20),
                _buildLegendItem(Colors.red.shade200, "Kaçırdı"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _attendanceFuture = _fetchData();
          _isDataLoaded = false;
        });
        await _attendanceFuture;
      },
      child: _filteredAttendances.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Bu dönemde yoklama kaydı yok",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredAttendances.length,
              itemBuilder: (context, index) {
                final att = _filteredAttendances[index];
                final isPresent = _isPresent(att); // 🔥 _isPresent kullanılıyor
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: isPresent
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isPresent ? Icons.check_circle : Icons.cancel,
                        color: isPresent ? Colors.green : Colors.red,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      _formatDateTurkish(att.attendance_date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: att.note.isNotEmpty
                        ? Text(att.note, style: const TextStyle(fontSize: 12))
                        : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPresent ? "Katıldı" : "Yok",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz yoklama kaydın bulunmuyor",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Yoklamalar alındıkça burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

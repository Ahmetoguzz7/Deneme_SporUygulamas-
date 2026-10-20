/*
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class DailyPaymentTracker extends StatefulWidget {
  const DailyPaymentTracker({super.key});

  @override
  State<DailyPaymentTracker> createState() => _DailyPaymentTrackerState();
}

class _DailyPaymentTrackerState extends State<DailyPaymentTracker> {
  final AppRepository _repo = AppRepository();

  // 🔥 MOD: false = Tek Gün, true = Tarih Aralığı
  bool _isRangeMode = false;

  // Tek Gün modu için
  DateTime _selectedDate = DateTime.now();

  // Tarih Aralığı modu için
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  List<Payment> _filteredPayments = [];
  double _totalAmount = 0;
  bool _isLoading = true;
  String? _error;

  bool _isGroupView = false;
  String? _selectedGroupId;
  List<Group> _allGroups = [];

  Map<String, GroupReportData> _groupReports = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      _allGroups = List.from(_repo.allGroups);
      _filterPayments();
      _calculateGroupReports();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // 🔥 FİLTRELEME
  void _filterPayments() {
    List<Payment> payments;

    if (_isRangeMode) {
      // 🔥 TARİH ARALIĞI MODU
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      payments = _repo.allPayments.where((p) {
        if (p.status != "paid") return false;
        try {
          final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
          return paidDate.isAfter(start.subtract(const Duration(days: 1))) &&
              paidDate.isBefore(end.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    } else {
      // 🔥 TEK GÜN MODU
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      payments = _repo.allPayments.where((p) {
        if (p.status != "paid") return false;
        final paidDate = p.paid_date.split('T')[0];
        return paidDate == formattedDate;
      }).toList();
    }

    payments.sort((a, b) => b.paid_date.compareTo(a.paid_date));

    final total = payments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );

    setState(() {
      _filteredPayments = payments;
      _totalAmount = total;
      _isLoading = false;
    });
  }

  Future<void> _calculateGroupReports() async {
    final reports = <String, GroupReportData>{};

    DateTime start, end;
    if (_isRangeMode) {
      start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    } else {
      start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      end = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
      );
    }

    for (var group in _allGroups) {
      final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
      final studentIds = relations.map((r) => r.student_id).toSet();

      double targetTotal = 0;
      final studentsInGroup = <Users>[];

      for (var studentId in studentIds) {
        final student = _repo.getUserById(studentId);
        if (student != null && student.role.toLowerCase() == "student") {
          studentsInGroup.add(student);
          targetTotal += double.tryParse(student.amount) ?? 0;
        }
      }

      double collectedInRange = 0;
      final paymentsInRange = <Payment>[];

      for (var payment in _repo.allPayments) {
        if (payment.status != "paid") continue;
        if (!studentIds.contains(payment.student_id)) continue;

        try {
          final paidDate = DateTime.parse(payment.paid_date.split('T')[0]);
          if (paidDate.isAfter(start.subtract(const Duration(days: 1))) &&
              paidDate.isBefore(end.add(const Duration(days: 1)))) {
            collectedInRange += double.tryParse(payment.amount) ?? 0;
            paymentsInRange.add(payment);
          }
        } catch (e) {}
      }

      reports[group.groups_id] = GroupReportData(
        groupName: group.name,
        targetTotal: targetTotal,
        collectedToday: collectedInRange,
        studentCount: studentsInGroup.length,
        paymentsToday: paymentsInRange,
        students: studentsInGroup,
      );
    }

    setState(() {
      _groupReports = reports;
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(lastDate) ? lastDate : _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      errorFormatText: 'Geçersiz tarih formatı',
      errorInvalidText: 'Geçersiz tarih',
      fieldHintText: 'Gün/Ay/Yıl',
      fieldLabelText: 'Tarih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _filterPayments();
      _calculateGroupReports();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime initialStart;
    DateTime initialEnd;

    if (_selectedDateRange != null) {
      initialStart = _selectedDateRange!.start;
      initialEnd = _selectedDateRange!.end;
    } else {
      initialStart = DateTime(now.year, now.month, 1);
      initialEnd = DateTime(now.year, now.month + 1, 0);
    }

    if (initialEnd.isAfter(lastDate)) {
      initialEnd = lastDate;
    }
    if (initialStart.isAfter(lastDate)) {
      initialStart = lastDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Tarih Aralığı Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      saveText: 'Kaydet',
      errorFormatText: 'Geçersiz tarih formatı',
      errorInvalidText: 'Geçersiz tarih',

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateRange = picked;
      });
      _filterPayments();
      _calculateGroupReports();
    }
  }

  // 🔥 Seçili tarih aralığını tut
  DateTimeRange? _selectedDateRange;

  void _showReportDialog() {
    String baslik;
    if (_isRangeMode && _selectedDateRange != null) {
      final startAy = _getMonthNameTurkish(_selectedDateRange!.start.month);
      final endAy = _getMonthNameTurkish(_selectedDateRange!.end.month);
      if (_selectedDateRange!.start.year == _selectedDateRange!.end.year &&
          _selectedDateRange!.start.month == _selectedDateRange!.end.month) {
        baslik = "$startAy ${_selectedDateRange!.start.year}";
      } else {
        baslik =
            "$startAy ${_selectedDateRange!.start.year} - $endAy ${_selectedDateRange!.end.year}";
      }
    } else if (!_isRangeMode) {
      baslik = _getFormattedDate();
    } else {
      baslik = "Tüm Zamanlar";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "📊 Grup Tahsilat Raporu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                baslik,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 24),

              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Hedef",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.targetTotal).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.teal.shade200,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Tahsilat",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.collectedToday).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.teal.shade200,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Eksik",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + (r.targetTotal - r.collectedToday)).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _allGroups.length,
                  itemBuilder: (context, index) {
                    final group = _allGroups[index];
                    final report = _groupReports[group.groups_id];
                    if (report == null) return const SizedBox.shrink();

                    final collectionRate = report.targetTotal > 0
                        ? (report.collectedToday / report.targetTotal) * 100
                        : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: collectionRate >= 100
                              ? Colors.green.shade200
                              : collectionRate >= 70
                              ? Colors.orange.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.group,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "${report.studentCount} öğrenci",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: collectionRate >= 100
                                      ? Colors.green.shade100
                                      : collectionRate >= 70
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${collectionRate.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: collectionRate >= 100
                                        ? Colors.green
                                        : collectionRate >= 70
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _reportTile(
                                  "Hedef",
                                  "${report.targetTotal.toStringAsFixed(0)} TL",
                                  Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: _reportTile(
                                  "Tahsilat",
                                  "${report.collectedToday.toStringAsFixed(0)} TL",
                                  Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _reportTile(
                                  "Eksik",
                                  "${(report.targetTotal - report.collectedToday).toStringAsFixed(0)} TL",
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: collectionRate / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: collectionRate >= 100
                                  ? Colors.green
                                  : collectionRate >= 70
                                  ? Colors.orange
                                  : Colors.red,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthNameTurkish(int month) {
    const months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    return months[month - 1];
  }

  Widget _reportTile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(_selectedDate);
  }

  String _getFormattedDateRange() {
    if (_selectedDateRange == null) return "Tarih seçilmedi";
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return "${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}";
  }

  int _calculateDayCount() {
    if (_selectedDateRange == null) return 0;
    return _selectedDateRange!.end
            .difference(_selectedDateRange!.start)
            .inDays +
        1;
  }

  String _getStudentName(String studentId) {
    final student = _repo.getUserById(studentId);
    if (student == null) return "Bilinmeyen";
    return "${student.first_name} ${student.last_name}";
  }

  String _getGroupName(String groupId) {
    final group = _repo.getGroupById(groupId);
    return group?.name ?? "Grup Yok";
  }

  void _showPaymentDetail(Payment payment) {
    final studentName = _getStudentName(payment.student_id);
    final groupName = _getGroupName(payment.groups_id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.teal, size: 28),
                SizedBox(width: 10),
                Text(
                  "Ödeme Detayı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.person, "Öğrenci", studentName),
            const Divider(),
            _detailRow(Icons.group, "Grup", groupName),
            const Divider(),
            _detailRow(Icons.attach_money, "Tutar", "${payment.amount} TL"),
            const Divider(),
            _detailRow(Icons.payment, "Yöntem", payment.payment_method),
            const Divider(),
            _detailRow(
              Icons.calendar_today,
              "Tarih",
              _formatDate(payment.paid_date),
            ),
            const Divider(),
            if (payment.note.isNotEmpty)
              _detailRow(Icons.note, "Not", payment.note),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  List<Payment> _getFilteredPayments() {
    if (_isGroupView && _selectedGroupId != null) {
      final group = _repo.getGroupById(_selectedGroupId!);
      if (group != null) {
        final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
        final studentIds = relations.map((r) => r.student_id).toSet();
        return _filteredPayments
            .where((p) => studentIds.contains(p.student_id))
            .toList();
      }
    }
    return _filteredPayments;
  }

  double _getFilteredTotal() {
    return _getFilteredPayments().fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _getFilteredPayments();
    final filteredTotal = _getFilteredTotal();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Ödeme Takibi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // 🔥 MOD DEĞİŞTİRME BUTONU
          IconButton(
            icon: Icon(
              _isRangeMode ? Icons.calendar_today : Icons.calendar_view_day,
              color: Colors.teal,
            ),
            onPressed: () {
              setState(() {
                _isRangeMode = !_isRangeMode;
                if (!_isRangeMode) {
                  _selectedDateRange = null;
                }
                _filterPayments();
                _calculateGroupReports();
              });
            },
            tooltip: _isRangeMode
                ? "Tek Gün Moduna Geç"
                : "Tarih Aralığı Moduna Geç",
          ),
          // 🔥 TARİH SEÇİM BUTONU
          IconButton(
            icon: Icon(
              _isRangeMode ? Icons.date_range : Icons.calendar_today,
              color: Colors.teal,
            ),
            onPressed: _isRangeMode ? _selectDateRange : _selectDate,
            tooltip: _isRangeMode ? "Tarih Aralığı Seç" : "Tarih Seç",
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.teal),
            onPressed: _showReportDialog,
            tooltip: "Raporlar",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("Ödemeler yükleniyor..."),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: $_error"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 📅 TARİH SEÇİCİ KARTI
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isRangeMode
                                            ? Icons.date_range
                                            : Icons.calendar_today,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isRangeMode
                                            ? "📅 Tarih Aralığı"
                                            : "📆 Tek Gün",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isRangeMode)
                                    GestureDetector(
                                      onTap: _selectDateRange,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.circle,
                                              color: Colors.green,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getFormattedDateRange(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: _selectDate,
                                      child: Text(
                                        _getFormattedDate(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // 🔥 TARİH SEÇİM BUTONU
                              GestureDetector(
                                onTap: _isRangeMode
                                    ? _selectDateRange
                                    : _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isRangeMode
                                            ? Icons.date_range
                                            : Icons.calendar_today,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isRangeMode
                                            ? "Aralık Seç"
                                            : "Tarih Seç",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Toplam Tahsilat",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_isRangeMode &&
                                      _selectedDateRange != null)
                                    Text(
                                      "${_calculateDayCount()} gün",
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${filteredTotal.toStringAsFixed(0)} TL",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${filteredPayments.length} ödeme",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔥 GRUP FİLTRELEME
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Grup Bazlı Görünüm",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Switch(
                                value: _isGroupView,
                                onChanged: (value) {
                                  setState(() {
                                    _isGroupView = value;
                                    if (!value) _selectedGroupId = null;
                                  });
                                },
                                activeColor: Colors.teal,
                              ),
                            ],
                          ),
                          if (_isGroupView)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                hint: const Text("Grup Seçiniz"),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.group),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Tüm Gruplar"),
                                  ),
                                  ..._allGroups.map((group) {
                                    return DropdownMenuItem(
                                      value: group.groups_id,
                                      child: Text(group.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGroupId = value;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ÖDEME LİSTESİ
                    if (filteredPayments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isGroupView && _selectedGroupId != null
                                  ? "Bu gruba ait ödeme kaydı bulunamadı"
                                  : _isRangeMode
                                  ? "Bu tarih aralığında ödeme kaydı bulunamadı"
                                  : "Bu güne ait ödeme kaydı bulunamadı",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isGroupView && _selectedGroupId != null
                                        ? "Gruba Ait Ödemeler (${filteredPayments.length})"
                                        : "Ödeme Yapanlar (${filteredPayments.length})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredPayments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 16),
                              itemBuilder: (context, index) {
                                final payment = filteredPayments[index];
                                final studentName = _getStudentName(
                                  payment.student_id,
                                );

                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.teal,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    studentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${payment.payment_method} • ${_formatDate(payment.paid_date)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (_isGroupView &&
                                          _selectedGroupId != null)
                                        Text(
                                          _getGroupName(payment.groups_id),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${double.tryParse(payment.amount)?.toStringAsFixed(0) ?? payment.amount} TL",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  onTap: () => _showPaymentDetail(payment),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                    const VersionFooter(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
    );
  }
}

// 🔥 RAPOR VERİ MODELİ
class GroupReportData {
  final String groupName;
  final double targetTotal;
  final double collectedToday;
  final int studentCount;
  final List<Payment> paymentsToday;
  final List<Users> students;

  GroupReportData({
    required this.groupName,
    required this.targetTotal,
    required this.collectedToday,
    required this.studentCount,
    required this.paymentsToday,
    required this.students,
  });
}
*/
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class DailyPaymentTracker extends StatefulWidget {
  const DailyPaymentTracker({super.key});

  @override
  State<DailyPaymentTracker> createState() => _DailyPaymentTrackerState();
}

class _DailyPaymentTrackerState extends State<DailyPaymentTracker> {
  final AppRepository _repo = AppRepository();

  // 🔥 MOD: false = Tek Gün, true = Tarih Aralığı
  bool _isRangeMode = false;

  // Tek Gün modu için
  DateTime _selectedDate = DateTime.now();

  // Tarih Aralığı modu için
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  List<Payment> _filteredPayments = [];
  double _totalAmount = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  StreamSubscription? _dataUpdateSubscription; // 🔥 Canlı Dinleyici

  bool _isGroupView = false;
  String? _selectedGroupId;
  List<Group> _allGroups = [];

  Map<String, GroupReportData> _groupReports = {};

  @override
  void initState() {
    super.initState();

    // 🔥 1. Arka planda veri güncellendiğinde ekranı otomatik yenilemek için dinle
    _dataUpdateSubscription = _repo.onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromMemory();
      }
    });

    // 🔥 2. Sayfa açılışında akıllı veri yükleme (RAM'de varsa anında aç)
    _initSmartData();
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel(); // Bellek sızıntısını önle
    super.dispose();
  }

  // 🔥 Akıllı Veri Yükleme Yöntemi
  Future<void> _initSmartData() async {
    if (_repo.allPayments.isEmpty || !_repo.isLoaded) {
      if (mounted) setState(() => _isLoading = true);
      await _repo.loadAllData();
    }
    _loadDataFromMemory();
  }

  void _loadDataFromMemory() {
    if (!mounted) return;
    try {
      _allGroups = List.from(_repo.allGroups);
      _filterPayments();
      _calculateGroupReports();

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadData({bool force = false}) async {
    setState(() {
      if (force) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      if (force) {
        await _repo.loadAllData(forceRefresh: true);
      } else if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }
      _loadDataFromMemory();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // 🔥 FİLTRELEME
  void _filterPayments() {
    List<Payment> payments;

    if (_isRangeMode) {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      payments = _repo.allPayments.where((p) {
        if (p.status != "paid") return false;
        try {
          final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
          return paidDate.isAfter(start.subtract(const Duration(days: 1))) &&
              paidDate.isBefore(end.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    } else {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      payments = _repo.allPayments.where((p) {
        if (p.status != "paid") return false;
        final paidDate = p.paid_date.split('T')[0];
        return paidDate == formattedDate;
      }).toList();
    }

    payments.sort((a, b) => b.paid_date.compareTo(a.paid_date));

    final total = payments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );

    _filteredPayments = payments;
    _totalAmount = total;
  }

  Future<void> _calculateGroupReports() async {
    final reports = <String, GroupReportData>{};

    DateTime start, end;
    if (_isRangeMode) {
      start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    } else {
      start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      end = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
      );
    }

    for (var group in _allGroups) {
      final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
      final studentIds = relations.map((r) => r.student_id).toSet();

      double targetTotal = 0;
      final studentsInGroup = <Users>[];

      for (var studentId in studentIds) {
        final student = _repo.getUserById(studentId);
        if (student != null && student.role.toLowerCase() == "student") {
          studentsInGroup.add(student);
          targetTotal += double.tryParse(student.amount) ?? 0;
        }
      }

      double collectedInRange = 0;
      final paymentsInRange = <Payment>[];

      for (var payment in _repo.allPayments) {
        if (payment.status != "paid") continue;
        if (!studentIds.contains(payment.student_id)) continue;

        try {
          final paidDate = DateTime.parse(payment.paid_date.split('T')[0]);
          if (paidDate.isAfter(start.subtract(const Duration(days: 1))) &&
              paidDate.isBefore(end.add(const Duration(days: 1)))) {
            collectedInRange += double.tryParse(payment.amount) ?? 0;
            paymentsInRange.add(payment);
          }
        } catch (e) {}
      }

      reports[group.groups_id] = GroupReportData(
        groupName: group.name,
        targetTotal: targetTotal,
        collectedToday: collectedInRange,
        studentCount: studentsInGroup.length,
        paymentsToday: paymentsInRange,
        students: studentsInGroup,
      );
    }

    if (mounted) {
      setState(() {
        _groupReports = reports;
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(lastDate) ? lastDate : _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _filterPayments();
      _calculateGroupReports();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime initialStart;
    DateTime initialEnd;

    if (_selectedDateRange != null) {
      initialStart = _selectedDateRange!.start;
      initialEnd = _selectedDateRange!.end;
    } else {
      initialStart = DateTime(now.year, now.month, 1);
      initialEnd = DateTime(now.year, now.month + 1, 0);
    }

    if (initialEnd.isAfter(lastDate)) initialEnd = lastDate;
    if (initialStart.isAfter(lastDate)) initialStart = lastDate;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Tarih Aralığı Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      saveText: 'Kaydet',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateRange = picked;
      });
      _filterPayments();
      _calculateGroupReports();
    }
  }

  void _showReportDialog() {
    String baslik;
    if (_isRangeMode && _selectedDateRange != null) {
      final startAy = _getMonthNameTurkish(_selectedDateRange!.start.month);
      final endAy = _getMonthNameTurkish(_selectedDateRange!.end.month);
      if (_selectedDateRange!.start.year == _selectedDateRange!.end.year &&
          _selectedDateRange!.start.month == _selectedDateRange!.end.month) {
        baslik = "$startAy ${_selectedDateRange!.start.year}";
      } else {
        baslik =
            "$startAy ${_selectedDateRange!.start.year} - $endAy ${_selectedDateRange!.end.year}";
      }
    } else if (!_isRangeMode) {
      baslik = _getFormattedDate();
    } else {
      baslik = "Tüm Zamanlar";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Grup Tahsilat Raporu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                baslik,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 24),

              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade50, Colors.teal.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Hedef",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.targetTotal).toStringAsFixed(0)} ₺",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 35,
                      color: Colors.teal.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Tahsilat",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.collectedToday).toStringAsFixed(0)} ₺",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 35,
                      color: Colors.teal.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Eksik",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + (r.targetTotal - r.collectedToday)).toStringAsFixed(0)} ₺",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _allGroups.length,
                  itemBuilder: (context, index) {
                    final group = _allGroups[index];
                    final report = _groupReports[group.groups_id];
                    if (report == null) return const SizedBox.shrink();

                    final collectionRate = report.targetTotal > 0
                        ? (report.collectedToday / report.targetTotal) * 100
                        : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: collectionRate >= 100
                              ? Colors.green.shade200
                              : collectionRate >= 70
                              ? Colors.orange.shade200
                              : Colors.red.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.group_rounded,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      "${report.studentCount} öğrenci",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: collectionRate >= 100
                                      ? Colors.green.shade100
                                      : collectionRate >= 70
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${collectionRate.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: collectionRate >= 100
                                        ? Colors.green.shade700
                                        : collectionRate >= 70
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _reportTile(
                                  "Hedef",
                                  "${report.targetTotal.toStringAsFixed(0)} ₺",
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _reportTile(
                                  "Tahsilat",
                                  "${report.collectedToday.toStringAsFixed(0)} ₺",
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _reportTile(
                                  "Eksik",
                                  "${(report.targetTotal - report.collectedToday).toStringAsFixed(0)} ₺",
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (collectionRate / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade100,
                              color: collectionRate >= 100
                                  ? Colors.green
                                  : collectionRate >= 70
                                  ? Colors.orange
                                  : Colors.red,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthNameTurkish(int month) {
    const months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    return months[month - 1];
  }

  Widget _reportTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(_selectedDate);
  }

  String _getFormattedDateRange() {
    if (_selectedDateRange == null) return "Tarih seçilmedi";
    final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
    return "${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}";
  }

  int _calculateDayCount() {
    if (_selectedDateRange == null) return 0;
    return _selectedDateRange!.end
            .difference(_selectedDateRange!.start)
            .inDays +
        1;
  }

  String _getStudentName(String studentId) {
    final student = _repo.getUserById(studentId);
    if (student == null) return "Bilinmeyen";
    return "${student.first_name} ${student.last_name}";
  }

  String _getGroupName(String groupId) {
    final group = _repo.getGroupById(groupId);
    return group?.name ?? "Grup Yok";
  }

  void _showPaymentDetail(Payment payment) {
    final studentName = _getStudentName(payment.student_id);
    final groupName = _getGroupName(payment.groups_id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.teal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Ödeme Detayı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.person_outline, "Öğrenci", studentName),
            const Divider(height: 16),
            _detailRow(Icons.group_outlined, "Grup", groupName),
            const Divider(height: 16),
            _detailRow(
              Icons.payments_outlined,
              "Tutar",
              "${payment.amount} ₺",
              isBold: true,
            ),
            const Divider(height: 16),
            _detailRow(
              Icons.payment_rounded,
              "Yöntem",
              payment.payment_method.isNotEmpty
                  ? payment.payment_method
                  : "Nakit / Diğer",
            ),
            const Divider(height: 16),
            _detailRow(
              Icons.calendar_today_rounded,
              "Tarih",
              _formatDate(payment.paid_date),
            ),
            if (payment.note.isNotEmpty) ...[
              const Divider(height: 16),
              _detailRow(Icons.sticky_note_2_outlined, "Not", payment.note),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Kapat",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal.shade700),
        const SizedBox(width: 12),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: const Color(0xFF1E293B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  List<Payment> _getFilteredPayments() {
    if (_isGroupView && _selectedGroupId != null) {
      final group = _repo.getGroupById(_selectedGroupId!);
      if (group != null) {
        final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
        final studentIds = relations.map((r) => r.student_id).toSet();
        return _filteredPayments
            .where((p) => studentIds.contains(p.student_id))
            .toList();
      }
    }
    return _filteredPayments;
  }

  double _getFilteredTotal() {
    return _getFilteredPayments().fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _getFilteredPayments();
    final filteredTotal = _getFilteredTotal();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Günlük Ödeme Takibi",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(
              _isRangeMode ? Icons.calendar_today : Icons.date_range,
              color: Colors.teal,
            ),
            onPressed: () {
              setState(() {
                _isRangeMode = !_isRangeMode;
                if (!_isRangeMode) {
                  _selectedDateRange = null;
                }
                _filterPayments();
                _calculateGroupReports();
              });
            },
            tooltip: _isRangeMode
                ? "Tek Gün Moduna Geç"
                : "Tarih Aralığı Moduna Geç",
          ),
          IconButton(
            icon: Icon(
              _isRangeMode ? Icons.edit_calendar : Icons.event,
              color: Colors.teal,
            ),
            onPressed: _isRangeMode ? _selectDateRange : _selectDate,
            tooltip: _isRangeMode ? "Tarih Aralığı Seç" : "Tarih Seç",
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.teal),
            onPressed: _showReportDialog,
            tooltip: "Raporlar",
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.teal,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
            onPressed: () => _loadData(force: true),
            tooltip: "Yenile",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("Ödemeler yükleniyor..."),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: $_error"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadData(force: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadData(force: true),
              color: Colors.teal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 📅 TARİH SEÇİCİ KARTI
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isRangeMode
                                            ? Icons.date_range
                                            : Icons.calendar_today,
                                        color: Colors.tealAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isRangeMode
                                            ? "Tarih Aralığı"
                                            : "Seçilen Gün",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (_isRangeMode)
                                    GestureDetector(
                                      onTap: _selectDateRange,
                                      child: Text(
                                        _getFormattedDateRange(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: _selectDate,
                                      child: Text(
                                        _getFormattedDate(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _isRangeMode
                                    ? _selectDateRange
                                    : _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.edit_calendar_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isRangeMode
                                            ? "Aralık Değiştir"
                                            : "Gün Değiştir",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Toplam Tahsilat",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_isRangeMode &&
                                      _selectedDateRange != null)
                                    Text(
                                      "${_calculateDayCount()} gün aralığı",
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${filteredTotal.toStringAsFixed(0)} ₺",
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "${filteredPayments.length} işlem",
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔥 GRUP FİLTRELEME
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Grup Bazlı Görünüm",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _isGroupView,
                                onChanged: (value) {
                                  setState(() {
                                    _isGroupView = value;
                                    if (!value) _selectedGroupId = null;
                                  });
                                },
                                activeColor: Colors.teal,
                              ),
                            ],
                          ),
                          if (_isGroupView)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                isExpanded: true,
                                hint: const Text("Grup Seçiniz"),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.group_rounded,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Tüm Gruplar"),
                                  ),
                                  ..._allGroups.map((group) {
                                    return DropdownMenuItem(
                                      value: group.groups_id,
                                      child: Text(group.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGroupId = value;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ÖDEME LİSTESİ
                    if (filteredPayments.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _isGroupView && _selectedGroupId != null
                                    ? "Bu gruba ait ödeme kaydı bulunamadı"
                                    : _isRangeMode
                                    ? "Bu tarih aralığında ödeme kaydı bulunamadı"
                                    : "Bu güne ait ödeme kaydı bulunamadı",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.payments_rounded,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isGroupView && _selectedGroupId != null
                                        ? "Gruba Ait Ödemeler (${filteredPayments.length})"
                                        : "Ödeme Yapanlar (${filteredPayments.length})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredPayments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 16),
                              itemBuilder: (context, index) {
                                final payment = filteredPayments[index];
                                final studentName = _getStudentName(
                                  payment.student_id,
                                );

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.teal,
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    studentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${payment.payment_method.isNotEmpty ? payment.payment_method : 'Nakit'} • ${_formatDate(payment.paid_date)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (_isGroupView &&
                                            _selectedGroupId != null)
                                          Text(
                                            _getGroupName(payment.groups_id),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.teal.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${double.tryParse(payment.amount)?.toStringAsFixed(0) ?? payment.amount} ₺",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  onTap: () => _showPaymentDetail(payment),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                    const VersionFooter(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
    );
  }
}

// 🔥 RAPOR VERİ MODELİ
class GroupReportData {
  final String groupName;
  final double targetTotal;
  final double collectedToday;
  final int studentCount;
  final List<Payment> paymentsToday;
  final List<Users> students;

  GroupReportData({
    required this.groupName,
    required this.targetTotal,
    required this.collectedToday,
    required this.studentCount,
    required this.paymentsToday,
    required this.students,
  });
}

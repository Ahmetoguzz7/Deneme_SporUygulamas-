import 'dart:async';

import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/core/student_group_resolver.dart';
import 'package:EVOM_SPOR/core/student_fee_resolver.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentReminderScreen extends StatefulWidget {
  const PaymentReminderScreen({Key? key}) : super(key: key);

  @override
  _PaymentReminderScreenState createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  List<Users> firstHalfStudents = [];
  List<Users> secondHalfStudents = [];

  List<Users> filteredFirstHalfStudents = [];
  List<Users> filteredSecondHalfStudents = [];

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String _selectedGroupFilter = "Tümü";
  List<String> _groupFilterOptions = ["Tümü"];

  bool isLoading = true;
  DateTime _selectedDate = DateTime.now();

  final Map<String, List<Payment>> _paymentsByStudent = {};

  // 🔥 StudentSearchScreen ile birebir aynı grup çözümleyici (öğrenci -> grup listesi)
  Map<String, List<String>> _studentGroups = {};

  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
    _searchController.addListener(_onSearchChanged);

    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        _processData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _repoSubscription?.cancel();
    _studentGroups = {};
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showSnack("Telefon numarası bulunamadı!", _danger);
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnack("Arama yapılamıyor!", _danger);
    }
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    _processData();
    if (mounted) setState(() => isLoading = false);
  }

  void _processData() {
    // 🔥 Her işlemde güncel RAM verisinden yeniden kur (bayat cache kalmaz)
    _studentGroups = StudentGroupResolver.buildMap();
    _buildPaymentCaches();
    _buildGroupFilterOptions();
    _filterStudentsAsync();
  }

  /// 🔥 StudentSearchScreen ile birebir aynı: StudentGroupResolver kullanır
  String _getStudentGroupNameFast(String studentId) {
    return StudentGroupResolver.label(_studentGroups, studentId);
  }

  void _buildPaymentCaches() {
    _paymentsByStudent.clear();
    for (var p in _repo.allPayments) {
      if (p.status.toLowerCase() == 'paid' ||
          p.status.toUpperCase() == 'TRUE') {
        (_paymentsByStudent[p.student_id] ??= []).add(p);
      }
    }
  }

  void _buildGroupFilterOptions() {
    final groupNames = _repo.allGroups
        .map((g) => g.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    // Seçili grup listede yoksa (geçici boş okuma vb.) ekle: dropdown
    // "exactly one item" hatasıyla patlamasın ve filtre kaybolmasın.
    if (_selectedGroupFilter != "Tümü" &&
        !groupNames.contains(_selectedGroupFilter)) {
      groupNames.add(_selectedGroupFilter);
    }
    groupNames.sort();
    _groupFilterOptions = ["Tümü", ...groupNames];
  }

  Timer? _debounceTimer;

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  void _applyFilter() {
    bool matchesFilter(Users s) {
      final name = "${s.first_name} ${s.last_name}".toLowerCase();
      final group = _getStudentGroupNameFast(s.app);

      if (_selectedGroupFilter != "Tümü" &&
          !StudentGroupResolver.isInGroup(
            _studentGroups,
            s.app,
            _selectedGroupFilter,
          )) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        return name.contains(_searchQuery) ||
            group.toLowerCase().contains(_searchQuery);
      }

      return true;
    }

    filteredFirstHalfStudents = firstHalfStudents.where(matchesFilter).toList();
    filteredSecondHalfStudents = secondHalfStudents
        .where(matchesFilter)
        .toList();
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

  String _getMonthShort(int month) {
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

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Ay Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month);
        _searchQuery = "";
        _searchController.clear();
        _selectedGroupFilter = "Tümü";
      });
      _processData();
    }
  }

  void _filterStudentsAsync() {
    final first = <Users>[];
    final second = <Users>[];

    final students = _repo.getStudentsOnly();

    for (var student in students) {
      if (student.is_active.toString().trim().toUpperCase() != "TRUE") continue;

      final status = _getPaymentStatusForMonth(student.app, _selectedDate);
      if (status != "unpaid") continue;

      final date = _parseDateString(student.created_at);
      if (date == null) continue;

      if (date.day <= 14) {
        first.add(student);
      } else {
        second.add(student);
      }
    }

    first.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );
    second.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );

    firstHalfStudents = first;
    secondHalfStudents = second;
    _applyFilter();
  }

  String _getPaymentStatusForMonth(String studentId, DateTime month) {
    final fee = _getStudentMonthlyFeeForMonth(studentId, month);
    final paid = _getStudentTotalPaidForMonth(studentId, month);
    if (fee == 0) return "unknown";
    if (paid >= fee) return "paid";
    if (paid > 0) return "partial";
    return "unpaid";
  }

  double _getStudentTotalPaidForMonth(String studentId, DateTime month) {
    double total = 0;
    final payments = _paymentsByStudent[studentId] ?? [];
    for (var payment in payments) {
      try {
        String dateStr = payment.due_date;
        if (dateStr.isEmpty) dateStr = payment.paid_date;
        if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
        final parts = dateStr.split('-');
        if (parts.length >= 2) {
          final y = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          if (y == month.year && m == month.month) {
            total += double.tryParse(payment.amount) ?? 0;
          }
        }
      } catch (_) {}
    }
    return total;
  }

  /// 🔥 Aya göre ücret: zam/düzeltme geçmişi dikkate alınır (eski aylar değişmez)
  double _getStudentMonthlyFeeForMonth(String studentId, DateTime month) {
    return StudentFeeResolver.forStudentMonth(
      _repo,
      studentId,
      month.year,
      month.month,
    );
  }

  double _getCachedFee(String studentId) {
    return _getStudentMonthlyFeeForMonth(studentId, _selectedDate);
  }

  DateTime? _parseDateString(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr);
      if (dateStr.contains('-') && dateStr.length >= 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2].substring(0, 2));
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendReminder(Users student) async {
    final fee = _getCachedFee(student.app);
    final monthName = _getMonthNameTurkish(_selectedDate.month);
    final year = _selectedDate.year;

    final message =
        "Sayın ${student.first_name} ${student.last_name}, $monthName $year ayına ait ${fee.toStringAsFixed(0)} TL ödemeniz alınmamıştır.";

    final success = await GoogleSheetService.addNotification({
      "notifications_id":
          "NTF-${DateTime.now().millisecondsSinceEpoch}-${student.app}",
      "sender_id": "Admin",
      "recipient_id": student.app,
      "groups_id": "",
      "title": "💰 Ödeme Hatırlatma",
      "message": message,
      "type": "payment_reminder",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    });

    _showSnack(
      success ? "✅ Hatırlatma gönderildi" : "❌ Gönderim başarısız!",
      success ? _success : _danger,
    );
  }

  Future<void> _sendReminderToAll(
    List<Users> students,
    String groupLabel,
  ) async {
    if (students.isEmpty) {
      _showSnack("Gönderilecek öğrenci yok!", _warning);
      return;
    }

    int sent = 0;
    final monthName = _getMonthNameTurkish(_selectedDate.month);
    final year = _selectedDate.year;

    for (var s in students) {
      final fee = _getCachedFee(s.app);
      final message =
          "Sayın ${s.first_name} ${s.last_name}, $monthName $year ayına ait ${fee.toStringAsFixed(0)} TL ödemeniz alınmamıştır.";

      final success = await GoogleSheetService.addNotification({
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${s.app}",
        "sender_id": "Admin",
        "recipient_id": s.app,
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatma",
        "message": message,
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      });
      if (success) sent++;
    }

    _showSnack("✅ $sent öğrenciye hatırlatma gönderildi", _success);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parsed = _parseDateString(dateStr);
    return parsed != null
        ? DateFormat('dd/MM/yyyy', 'tr_TR').format(parsed)
        : "—";
  }

  Widget _buildStudentCard(Users s) {
    final fee = _getCachedFee(s.app);
    final groupName = _getStudentGroupNameFast(s.app);
    final regDate = _parseDateString(s.created_at);
    final dayLabel = regDate != null
        ? (regDate.day <= 14 ? "1-14" : "15-31")
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    color: _danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${s.first_name} ${s.last_name}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$groupName • Kayıt: ${_formatDate(s.created_at)}",
                    style: const TextStyle(color: _textSecondary, fontSize: 10),
                  ),
                  if (s.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _makePhoneCall(s.phone),
                      child: Text(
                        s.phone,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${fee.toStringAsFixed(0)} ₺",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _danger,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _sendReminder(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Hatırlat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Users> students, String title, Color titleColor) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Text(
            "Bu grupta ödemeyen öğrenci yok! 🎉",
            style: TextStyle(
              color: _success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _sendReminderToAll(students, title),
              child: const Text(
                "Tümüne Gönder",
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (_, i) => _buildStudentCard(students[i]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _getMonthShort(_selectedDate.month);
    final year = _selectedDate.year;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: const Text("Ödeme Hatırlatma", style: TextStyle(fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _selectMonth,
            icon: const Icon(Icons.calendar_month, size: 16),
            label: Text("$monthName $year"),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "İsim veya grup ara...",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedGroupFilter,
                        items: _groupFilterOptions.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedGroupFilter = val;
                              _applyFilter();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: _accent,
                  tabs: [
                    Tab(text: "1-14 Gün (${filteredFirstHalfStudents.length})"),
                    Tab(
                      text: "15-31 Gün (${filteredSecondHalfStudents.length})",
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildList(
                            filteredFirstHalfStudents,
                            "1-14 Kayıt Grubu",
                            _accent,
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildList(
                            filteredSecondHalfStudents,
                            "15-31 Kayıt Grubu",
                            _warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const VersionFooter(),
              ],
            ),
    );
  }
}

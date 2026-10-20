/*
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class StudentSearchScreen extends StatefulWidget {
  final Users? currentUser;
  const StudentSearchScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  List<Users> _allStudents = [];
  List<Users> filteredStudents = [];
  Timer? _searchDebounce;
  bool isLoading = true;

  String selectedGroupFilter = "Tümü";
  String selectedMonthFilter = "";
  String selectedPaymentFilter = "Tümü";

  List<String> groupNames = ["Tümü"];
  List<String> monthOptions = [];
  String searchQuery = "";

  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;
  int _freeCount = 0;

  // Performans için Önbellek (Cache) Map'leri
  final Map<String, String> _groupNameCache = {};
  final Map<String, double> _feeCache = {};
  final Map<String, double> _paidCache = {};
  final Map<String, String> _statusCache = {};

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF97316);
  static const Color _red = Color(0xFFEF4444);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _prepareFilters();
    _initializeData();

    // 🔥 SESSİZ GÜNCELLEME: AppRepository'deki veriler arkada ne zaman güncellense
    // bu dinleyici arayüzü kilitlemeden sessizce listeyi yeniler.
    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        print(
          "⚡ Arama Sayfası: Arka planda veri güncellendi, liste çaktırmadan yenileniyor...",
        );
        _clearPerformanceCaches();
        _applyFiltersAndCalculate();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _repoSubscription?.cancel();
    _clearPerformanceCaches();
    super.dispose();
  }

  void _clearPerformanceCaches() {
    _groupNameCache.clear();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
  }

  void _prepareFilters() {
    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      monthOptions.add(
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
      );
    }
    selectedMonthFilter = monthOptions[6]; // Mevcut ay
  }

  /// 🚀 İlk Kurulumda RAM'deki Verileri Çek
  void _initializeData() {
    if (mounted) {
      setState(() => isLoading = true);
    }

    _allStudents = _repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' &&
              u.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();
    groupNames = ["Tümü", ..._repo.allGroups.map((g) => g.name).toSet()];

    _applyFiltersAndCalculate();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // 🔥 JET HIZINDA FİLTRELEME VE CACHE HESAPLAMA (DONMA YAPMAZ)
  // =========================================================================
  void _applyFiltersAndCalculate() {
    if (!mounted) return;

    int paid = 0, partial = 0, unpaid = 0, free = 0;
    final List<Users> filtered = [];
    final lowerQuery = searchQuery.trim().toLowerCase();

    for (final student in _allStudents) {
      // 1. İsim, Telefon ve E-posta Filtresi
      if (lowerQuery.isNotEmpty) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        if (!fullName.contains(lowerQuery) &&
            !student.email.toLowerCase().contains(lowerQuery) &&
            !student.phone.contains(lowerQuery)) {
          continue;
        }
      }

      // 2. Hızlı Grup Filtresi
      if (selectedGroupFilter != "Tümü") {
        final groupName = _getStudentGroupNameFast(student.app);
        if (groupName != selectedGroupFilter) continue;
      }

      // 3. Ödeme Durumu Çekimi (Hafızadan veya Hesaplamadan)
      final status = _getPaymentStatusFast(student.app, selectedMonthFilter);
      if (status == "registered_after") continue;

      // İstatistik Sayılarını ödeme filtresinden bağımsız hesapla
      switch (status) {
        case "paid":
          paid++;
          break;
        case "partial":
          partial++;
          break;
        case "unpaid":
          unpaid++;
          break;
        case "free":
          free++;
          break;
      }

      // 4. Ödeme Tipi Filtresi
      if (selectedPaymentFilter != "Tümü") {
        if (selectedPaymentFilter == "Ödeyen" && status != "paid") continue;
        if (selectedPaymentFilter == "Ödemeyen" && status != "unpaid") continue;
        if (selectedPaymentFilter == "Kısmi Ödeyen" && status != "partial")
          continue;
        if (selectedPaymentFilter == "Ücretsiz" && status != "free") continue;
      }

      filtered.add(student);
    }

    // Tek bir setState ile ekrana yansıt (Arayüz hatası vermez)
    setState(() {
      filteredStudents = filtered;
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
      _freeCount = free;
    });
  }

  // =========================================================================
  // ⚡ PERFORMANS İÇİN OKUMA YARDIMCILARI (RAM'DEN ÇEKER)
  // =========================================================================

  String _getStudentGroupNameFast(String studentId) {
    return _groupNameCache.putIfAbsent(studentId, () {
      final relations = _repo.getGroupStudentsByStudentId(studentId);
      final active = relations.where(
        (r) => r.is_active.toUpperCase() == "TRUE",
      );
      if (active.isEmpty) return "Grup Yok";
      return _repo.getGroupById(active.first.groups_id)?.name ?? "Grup Yok";
    });
  }

  double _getStudentMonthlyFeeFast(String studentId) {
    return _feeCache.putIfAbsent(studentId, () {
      final student = _repo.getUserById(studentId);
      return double.tryParse(student?.amount ?? "0") ?? 0.0;
    });
  }

  double _getStudentTotalPaidFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _paidCache.putIfAbsent(cacheKey, () {
      final parts = monthYear.split('-');
      if (parts.length != 2) return 0.0;
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      final student = _repo.getUserById(studentId);
      if (student == null) return 0.0;

      // Kayıt tarihi kontrolü
      final regYear = _getRegistrationYear(student);
      final regMonth = _getRegistrationMonth(student);
      if (yr < regYear || (yr == regYear && mo < regMonth)) return 0.0;

      double total = 0.0;
      final payments = _repo.getPaymentsByStudentId(studentId);
      for (var p in payments) {
        final st = p.status.toString().toUpperCase();
        if (st != "PAID" && st != "TRUE") continue;
        try {
          final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
          if (paidDate.year == yr && paidDate.month == mo) {
            total += double.tryParse(p.amount) ?? 0.0;
          }
        } catch (_) {}
      }
      return total;
    });
  }

  String _getPaymentStatusFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _statusCache.putIfAbsent(cacheKey, () {
      final student = _repo.getUserById(studentId);
      if (student == null) return "unknown";

      final parts = monthYear.split('-');
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      final regYear = _getRegistrationYear(student);
      final regMonth = _getRegistrationMonth(student);

      // 🔥 Kayıt ayından TAM BİR ÖNCEKİ ay her zaman ÜCRETSİZ sayılır
      // (örn: 1 Temmuz kayıt -> Haziran ücretsiz)
      final freeYear = regMonth == 1 ? regYear - 1 : regYear;
      final freeMonth = regMonth == 1 ? 12 : regMonth - 1;
      if (yr == freeYear && mo == freeMonth) {
        return "free";
      }

      if (yr < regYear || (yr == regYear && mo < regMonth)) {
        return "registered_after";
      }

      final fee = _getStudentMonthlyFeeFast(studentId);
      final paid = _getStudentTotalPaidFast(studentId, monthYear);

      if (fee == 0) return "unknown";
      if (paid >= fee) return "paid";
      if (paid > 0) return "partial";
      return "unpaid";
    });
  }

  int _getRegistrationYear(Users student) {
    if (student.created_at.isEmpty) return DateTime.now().year;
    try {
      return DateTime.parse(student.created_at).year;
    } catch (_) {
      return DateTime.now().year;
    }
  }

  int _getRegistrationMonth(Users student) {
    if (student.created_at.isEmpty) return 1;
    try {
      return DateTime.parse(student.created_at).month;
    } catch (_) {
      return 1;
    }
  }

  // =========================================================================
  // ⚡ TETİKLEYİCİLER (DEBOUNCE KORUMALI)
  // =========================================================================
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Kullanıcı klavyede duraksadığı an filtreleme yapar, arayüzü kasmaz
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      searchQuery = value;
      _applyFiltersAndCalculate();
    });
  }

  void _onGroupFilterChanged(String? value) {
    setState(() => selectedGroupFilter = value ?? "Tümü");
    _applyFiltersAndCalculate();
  }

  void _onMonthFilterChanged(String? value) {
    setState(() => selectedMonthFilter = value ?? monthOptions[6]);
    _applyFiltersAndCalculate();
  }

  void _onPaymentFilterChanged(String filterValue) {
    setState(() {
      selectedPaymentFilter = selectedPaymentFilter == filterValue
          ? "Tümü"
          : filterValue;
    });
    _applyFiltersAndCalculate();
  }

  /// 🔄 Manuel Zoraki Yenileme (Aşağı Kaydırınca veya Yenile Butonuyla)
  void _refreshData() async {
    setState(() => isLoading = true);
    _clearPerformanceCaches();
    await _repo.refreshAllData();
    _initializeData();
  }

  // =========================================================================
  // 🖼️ ARAYÜZ YARDIMCILARI
  // =========================================================================
  String _getMonthName(int m) => [
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
  ][m - 1];

  String _formatDate(String d) {
    if (d.isEmpty) return "—";
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d.split('T')[0]));
    } catch (_) {
      return d;
    }
  }

  Color _statusColor(String s) => s == "paid"
      ? _green
      : s == "partial"
      ? _orange
      : s == "free"
      ? _accent
      : _red;
  String _statusLabel(String s) => s == "paid"
      ? "Ödedi"
      : s == "partial"
      ? "Kısmi"
      : s == "free"
      ? "Ücretsiz"
      : "Ödemedi";
  IconData _statusIcon(String s) => s == "paid"
      ? Icons.check_circle_rounded
      : s == "partial"
      ? Icons.timelapse_rounded
      : s == "free"
      ? Icons.card_giftcard_rounded
      : Icons.cancel_rounded;

  @override
  Widget build(BuildContext context) {
    final parts = selectedMonthFilter.split('-');
    final monthName = parts.length == 2
        ? _getMonthName(int.parse(parts[1]))
        : "";
    final year = parts.isNotEmpty ? parts[0] : "";
    final total = _paidCount + _partialCount + _unpaidCount + _freeCount;
    final paidPct = total > 0 ? _paidCount / total : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Öğrenci Ödeme Sayfası",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary,
              ),
            ),
            Text(
              "$monthName $year · $total Öğrenci",
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async => _refreshData(),
              color: _accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Üst İstatistik Kartı
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$monthName $year",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Ödeme Durumu Özeti",
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 65,
                                    height: 65,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: paidPct >= 0.7
                                            ? _green
                                            : paidPct >= 0.4
                                            ? _orange
                                            : _red,
                                        width: 3.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${(paidPct * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          color: paidPct >= 0.7
                                              ? _green
                                              : paidPct >= 0.4
                                              ? _orange
                                              : _red,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: paidPct,
                                  backgroundColor: _border,
                                  valueColor: AlwaysStoppedAnimation(_green),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _statCard(
                                    "Ödeyen",
                                    _paidCount,
                                    _green,
                                    Icons.check_circle_rounded,
                                    "Ödeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Kısmi",
                                    _partialCount,
                                    _orange,
                                    Icons.timelapse_rounded,
                                    "Kısmi Ödeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Ödemeyen",
                                    _unpaidCount,
                                    _red,
                                    Icons.cancel_rounded,
                                    "Ödemeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Ücretsiz",
                                    _freeCount,
                                    _accent,
                                    Icons.card_giftcard_rounded,
                                    "Ücretsiz",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Filtreleme Paneli
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        "Öğrenci adı, e-posta veya tel ara...",
                                    hintStyle: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 13,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _textSecondary,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedGroupFilter,
                                      items: groupNames,
                                      icon: Icons.group_rounded,
                                      onChanged: _onGroupFilterChanged,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedMonthFilter,
                                      items: monthOptions,
                                      icon: Icons.calendar_month_rounded,
                                      displayMap: (m) {
                                        final p = m.split('-');
                                        return "${_getMonthName(int.parse(p[1]))} ${p[0]}";
                                      },
                                      onChanged: _onMonthFilterChanged,
                                    ),
                                  ),
                                ],
                              ),
                              const VersionFooter(),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Liste Bölümü
                  filteredStudents.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              "Öğrenci bulunamadı",
                              style: TextStyle(color: _textSecondary),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = filteredStudents[i];
                              final status = _getPaymentStatusFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final color = _statusColor(status);
                              final fee = _getStudentMonthlyFeeFast(s.app);
                              final paid = _getStudentTotalPaidFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final pct = fee > 0
                                  ? (paid / fee).clamp(0.0, 1.0)
                                  : 0.0;
                              final group = _getStudentGroupNameFast(s.app);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PaymentScreen(student: s),
                                      ),
                                    );
                                    if (result == true) {
                                      _clearPerformanceCaches();
                                      _applyFiltersAndCalculate();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              child: Text(
                                                s.first_name.isNotEmpty
                                                    ? s.first_name[0]
                                                          .toUpperCase()
                                                    : "?",
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${s.first_name} ${s.last_name}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    group,
                                                    style: const TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _statusLabel(status),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        status == "free"
                                            ? Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _accent.withOpacity(
                                                    0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .card_giftcard_rounded,
                                                      size: 16,
                                                      color: _accent,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "Bu ay ücretsiz (deneme ayı)",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: _accent,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _surfaceLight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          "Aidat: ${fee.toStringAsFixed(0)} ₺  |  Ödenen: ${paid.toStringAsFixed(0)} ₺",
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                _textSecondary,
                                                          ),
                                                        ),
                                                        Text(
                                                          "%${(pct * 100).toStringAsFixed(0)}",
                                                          style: TextStyle(
                                                            color: color,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value: pct,
                                                        backgroundColor:
                                                            _border,
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                              color,
                                                            ),
                                                        minHeight: 5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filteredStudents.length),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color color,
    IconData icon,
    String filterValue,
  ) {
    final sel = selectedPaymentFilter == filterValue;
    return Expanded(
      child: InkWell(
        onTap: () => _onPaymentFilterChanged(filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : _border, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: TextStyle(
                  color: sel ? color : _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? color : _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                displayMap != null ? displayMap(item) : item,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
*/
/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class StudentSearchScreen extends StatefulWidget {
  final Users? currentUser;
  const StudentSearchScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  List<Users> _allStudents = [];
  List<Users> filteredStudents = [];
  Timer? _searchDebounce;
  bool isLoading = true;

  String selectedGroupFilter = "Tümü";
  String selectedMonthFilter = "";
  String selectedPaymentFilter = "Tümü";

  List<String> groupNames = ["Tümü"];
  List<String> monthOptions = [];
  String searchQuery = "";

  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;

  // Performans için Önbellek (Cache) Map'leri
  final Map<String, String> _groupNameCache = {};
  final Map<String, double> _feeCache = {};
  final Map<String, double> _paidCache = {};
  final Map<String, String> _statusCache = {};

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF97316);
  static const Color _red = Color(0xFFEF4444);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _prepareFilters();
    _initializeData();

    // 🔥 SESSİZ GÜNCELLEME: AppRepository'deki veriler arkada ne zaman güncellense
    // bu dinleyici arayüzü kilitlemeden sessizce listeyi yeniler.
    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        print(
          "⚡ Arama Sayfası: Arka planda veri güncellendi, liste çaktırmadan yenileniyor...",
        );
        _clearPerformanceCaches();
        _applyFiltersAndCalculate();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _repoSubscription?.cancel();
    _clearPerformanceCaches();
    super.dispose();
  }

  void _clearPerformanceCaches() {
    _groupNameCache.clear();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
  }

  void _prepareFilters() {
    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      monthOptions.add(
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
      );
    }
    selectedMonthFilter = monthOptions[6]; // Mevcut ay
  }

  /// 🚀 İlk Kurulumda RAM'deki Verileri Çek
  void _initializeData() {
    if (mounted) {
      setState(() => isLoading = true);
    }

    _allStudents = _repo.allUsers
        .where((u) => u.role.toLowerCase() == 'student')
        .toList();
    groupNames = ["Tümü", ..._repo.allGroups.map((g) => g.name).toSet()];

    _applyFiltersAndCalculate();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // 🔥 JET HIZINDA FİLTRELEME VE CACHE HESAPLAMA (DONMA YAPMAZ)
  // =========================================================================
  void _applyFiltersAndCalculate() {
    if (!mounted) return;

    int paid = 0, partial = 0, unpaid = 0;
    final List<Users> filtered = [];
    final lowerQuery = searchQuery.trim().toLowerCase();

    for (final student in _allStudents) {
      // 1. İsim, Telefon ve E-posta Filtresi
      if (lowerQuery.isNotEmpty) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        if (!fullName.contains(lowerQuery) &&
            !student.email.toLowerCase().contains(lowerQuery) &&
            !student.phone.contains(lowerQuery)) {
          continue;
        }
      }

      // 2. Hızlı Grup Filtresi
      if (selectedGroupFilter != "Tümü") {
        final groupName = _getStudentGroupNameFast(student.app);
        if (groupName != selectedGroupFilter) continue;
      }

      // 3. Ödeme Durumu Çekimi (Hafızadan veya Hesaplamadan)
      final status = _getPaymentStatusFast(student.app, selectedMonthFilter);
      if (status == "registered_after") continue;

      // İstatistik Sayılarını ödeme filtresinden bağımsız hesapla
      switch (status) {
        case "paid":
          paid++;
          break;
        case "partial":
          partial++;
          break;
        case "unpaid":
          unpaid++;
          break;
      }

      // 4. Ödeme Tipi Filtresi
      if (selectedPaymentFilter != "Tümü") {
        if (selectedPaymentFilter == "Ödeyenler" && status != "paid") continue;
        if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
          continue;
        if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
          continue;
      }

      filtered.add(student);
    }

    // Tek bir setState ile ekrana yansıt (Arayüz hatası vermez)
    setState(() {
      filteredStudents = filtered;
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
    });
  }

  // =========================================================================
  // ⚡ PERFORMANS İÇİN OKUMA YARDIMCILARI (RAM'DEN ÇEKER)
  // =========================================================================

  String _getStudentGroupNameFast(String studentId) {
    return _groupNameCache.putIfAbsent(studentId, () {
      final relations = _repo.getGroupStudentsByStudentId(studentId);
      final active = relations.where(
        (r) => r.is_active.toUpperCase() == "TRUE",
      );
      if (active.isEmpty) return "Grup Yok";
      return _repo.getGroupById(active.first.groups_id)?.name ?? "Grup Yok";
    });
  }

  double _getStudentMonthlyFeeFast(String studentId) {
    return _feeCache.putIfAbsent(studentId, () {
      final student = _repo.getUserById(studentId);
      return double.tryParse(student?.amount ?? "0") ?? 0.0;
    });
  }

  double _getStudentTotalPaidFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _paidCache.putIfAbsent(cacheKey, () {
      final parts = monthYear.split('-');
      if (parts.length != 2) return 0.0;
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      final student = _repo.getUserById(studentId);
      if (student == null) return 0.0;

      // Kayıt tarihi kontrolü
      final regYear = _getRegistrationYear(student);
      final regMonth = _getRegistrationMonth(student);
      if (yr < regYear || (yr == regYear && mo < regMonth)) return 0.0;

      double total = 0.0;
      final payments = _repo.getPaymentsByStudentId(studentId);
      for (var p in payments) {
        final st = p.status.toString().toUpperCase();
        if (st != "PAID" && st != "TRUE") continue;
        try {
          final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
          if (paidDate.year == yr && paidDate.month == mo) {
            total += double.tryParse(p.amount) ?? 0.0;
          }
        } catch (_) {}
      }
      return total;
    });
  }

  String _getPaymentStatusFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _statusCache.putIfAbsent(cacheKey, () {
      final student = _repo.getUserById(studentId);
      if (student == null) return "unknown";

      final parts = monthYear.split('-');
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      if (yr < _getRegistrationYear(student) ||
          (yr == _getRegistrationYear(student) &&
              mo < _getRegistrationMonth(student))) {
        return "registered_after";
      }

      final fee = _getStudentMonthlyFeeFast(studentId);
      final paid = _getStudentTotalPaidFast(studentId, monthYear);

      if (fee == 0) return "unknown";
      if (paid >= fee) return "paid";
      if (paid > 0) return "partial";
      return "unpaid";
    });
  }

  int _getRegistrationYear(Users student) {
    if (student.created_at.isEmpty) return DateTime.now().year;
    try {
      return DateTime.parse(student.created_at).year;
    } catch (_) {
      return DateTime.now().year;
    }
  }

  int _getRegistrationMonth(Users student) {
    if (student.created_at.isEmpty) return 1;
    try {
      return DateTime.parse(student.created_at).month;
    } catch (_) {
      return 1;
    }
  }

  // =========================================================================
  // ⚡ TETİKLEYİCİLER (DEBOUNCE KORUMALI)
  // =========================================================================
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Kullanıcı klavyede duraksadığı an filtreleme yapar, arayüzü kasmaz
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      searchQuery = value;
      _applyFiltersAndCalculate();
    });
  }

  void _onGroupFilterChanged(String? value) {
    setState(() => selectedGroupFilter = value ?? "Tümü");
    _applyFiltersAndCalculate();
  }

  void _onMonthFilterChanged(String? value) {
    setState(() => selectedMonthFilter = value ?? monthOptions[6]);
    _applyFiltersAndCalculate();
  }

  void _onPaymentFilterChanged(String filterValue) {
    setState(() {
      selectedPaymentFilter = selectedPaymentFilter == filterValue
          ? "Tümü"
          : filterValue;
    });
    _applyFiltersAndCalculate();
  }

  /// 🔄 Manuel Zoraki Yenileme (Aşağı Kaydırınca veya Yenile Butonuyla)
  void _refreshData() async {
    setState(() => isLoading = true);
    _clearPerformanceCaches();
    await _repo.refreshAllData();
    _initializeData();
  }

  // =========================================================================
  // 🖼️ ARAYÜZ YARDIMCILARI
  // =========================================================================
  String _getMonthName(int m) => [
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
  ][m - 1];

  String _formatDate(String d) {
    if (d.isEmpty) return "—";
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d.split('T')[0]));
    } catch (_) {
      return d;
    }
  }

  Color _statusColor(String s) => s == "paid"
      ? _green
      : s == "partial"
      ? _orange
      : _red;
  String _statusLabel(String s) => s == "paid"
      ? "Ödedi"
      : s == "partial"
      ? "Kısmi"
      : "Ödemedi";
  IconData _statusIcon(String s) => s == "paid"
      ? Icons.check_circle_rounded
      : s == "partial"
      ? Icons.timelapse_rounded
      : Icons.cancel_rounded;

  @override
  Widget build(BuildContext context) {
    final parts = selectedMonthFilter.split('-');
    final monthName = parts.length == 2
        ? _getMonthName(int.parse(parts[1]))
        : "";
    final year = parts.isNotEmpty ? parts[0] : "";
    final total = _paidCount + _partialCount + _unpaidCount;
    final paidPct = total > 0 ? _paidCount / total : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Öğrenci Ödeme Sayfası",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary,
              ),
            ),
            Text(
              "$monthName $year · $total Öğrenci",
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async => _refreshData(),
              color: _accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Üst İstatistik Kartı
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$monthName $year",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Ödeme Durumu Özeti",
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 65,
                                    height: 65,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: paidPct >= 0.7
                                            ? _green
                                            : paidPct >= 0.4
                                            ? _orange
                                            : _red,
                                        width: 3.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${(paidPct * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          color: paidPct >= 0.7
                                              ? _green
                                              : paidPct >= 0.4
                                              ? _orange
                                              : _red,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: paidPct,
                                  backgroundColor: _border,
                                  valueColor: AlwaysStoppedAnimation(_green),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _statCard(
                                    "Ödeyenler",
                                    _paidCount,
                                    _green,
                                    Icons.check_circle_rounded,
                                    "Ödeyenler",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Kısmi",
                                    _partialCount,
                                    _orange,
                                    Icons.timelapse_rounded,
                                    "Kısmi Ödeyenler",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Ödemeyenler",
                                    _unpaidCount,
                                    _red,
                                    Icons.cancel_rounded,
                                    "Ödemeyenler",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Filtreleme Paneli
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        "Öğrenci adı, e-posta veya tel ara...",
                                    hintStyle: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 13,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _textSecondary,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedGroupFilter,
                                      items: groupNames,
                                      icon: Icons.group_rounded,
                                      onChanged: _onGroupFilterChanged,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedMonthFilter,
                                      items: monthOptions,
                                      icon: Icons.calendar_month_rounded,
                                      displayMap: (m) {
                                        final p = m.split('-');
                                        return "${_getMonthName(int.parse(p[1]))} ${p[0]}";
                                      },
                                      onChanged: _onMonthFilterChanged,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Liste Bölümü
                  filteredStudents.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              "Öğrenci bulunamadı",
                              style: TextStyle(color: _textSecondary),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = filteredStudents[i];
                              final status = _getPaymentStatusFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final color = _statusColor(status);
                              final fee = _getStudentMonthlyFeeFast(s.app);
                              final paid = _getStudentTotalPaidFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final pct = fee > 0
                                  ? (paid / fee).clamp(0.0, 1.0)
                                  : 0.0;
                              final group = _getStudentGroupNameFast(s.app);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PaymentScreen(student: s),
                                      ),
                                    );
                                    if (result == true) {
                                      _clearPerformanceCaches();
                                      _applyFiltersAndCalculate();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              child: Text(
                                                s.first_name.isNotEmpty
                                                    ? s.first_name[0]
                                                          .toUpperCase()
                                                    : "?",
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${s.first_name} ${s.last_name}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    group,
                                                    style: const TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _statusLabel(status),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _surfaceLight,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Aidat: ${fee.toStringAsFixed(0)} ₺  |  Ödenen: ${paid.toStringAsFixed(0)} ₺",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _textSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    "%${(pct * 100).toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: pct,
                                                  backgroundColor: _border,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                        color,
                                                      ),
                                                  minHeight: 5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filteredStudents.length),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color color,
    IconData icon,
    String filterValue,
  ) {
    final sel = selectedPaymentFilter == filterValue;
    return Expanded(
      child: InkWell(
        onTap: () => _onPaymentFilterChanged(filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : _border, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: TextStyle(
                  color: sel ? color : _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? color : _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                displayMap != null ? displayMap(item) : item,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
*/
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/core/student_group_resolver.dart';
import 'package:EVOM_SPOR/core/student_fee_resolver.dart';
import 'package:EVOM_SPOR/widgets/data_error_state.dart';

class StudentSearchScreen extends StatefulWidget {
  final Users? currentUser;
  const StudentSearchScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  List<Users> _allStudents = [];
  List<Users> filteredStudents = [];
  Timer? _searchDebounce;
  bool isLoading = true;
  bool _hasError = false;

  String selectedGroupFilter = "Tümü";
  String selectedMonthFilter = "";
  String selectedPaymentFilter = "Tümü";

  List<String> groupNames = ["Tümü"];
  List<String> monthOptions = [];
  String searchQuery = "";

  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;
  int _freeCount = 0;

  // Performans için Önbellek (Cache) Map'leri
  // 🔥 Grup eşleşmesi artık Grup Yönetimi sayfasıyla AYNI kaynaktan geliyor
  Map<String, List<String>> _studentGroups = {};
  final Map<String, double> _feeCache = {};
  final Map<String, double> _paidCache = {};
  final Map<String, String> _statusCache = {};

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF97316);
  static const Color _red = Color(0xFFEF4444);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _prepareFilters();
    _initializeData();

    // 🔥 SESSİZ GÜNCELLEME: AppRepository'deki veriler arkada ne zaman güncellense
    // bu dinleyici arayüzü kilitlemeden sessizce listeyi yeniler.
    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        print(
          "⚡ Arama Sayfası: Arka planda veri güncellendi, liste çaktırmadan yenileniyor...",
        );
        _clearPerformanceCaches();
        _applyFiltersAndCalculate();
      }
    });
    _loadLocalDataDirectly();
  }

  void _loadLocalDataDirectly() {
    // 0ms gecikme ile RAM'den listeleri çek
    _allStudents = _repo.getStudentsOnly(); //
    //_allGroups = _repo.allGroups; //[cite: 11]

    // Arayüzü anında çiz
    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _repoSubscription?.cancel();
    _clearPerformanceCaches();
    super.dispose();
  }

  void _clearPerformanceCaches() {
    _studentGroups = {};
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
  }

  void _prepareFilters() {
    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      monthOptions.add(
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
      );
    }
    selectedMonthFilter = monthOptions[6]; // Mevcut ay
  }

  /// 🚀 İlk Kurulumda RAM'deki Verileri Çek
  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _hasError = false;
      });
    }

    // 🔥 Repo henüz yüklenmediyse burada da yükleyip hatayı yakala
    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    if (_repo.hasError && _repo.allUsers.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    _allStudents = _repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' &&
              u.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();
    groupNames = ["Tümü", ..._repo.allGroups.map((g) => g.name).toSet()];

    _applyFiltersAndCalculate();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // 🔥 JET HIZINDA FİLTRELEME VE CACHE HESAPLAMA (DONMA YAPMAZ)
  // =========================================================================
  void _applyFiltersAndCalculate() {
    if (!mounted) return;

    // 🔥 Her filtrelemede güncel RAM verisinden yeniden kur (bayat cache kalmaz)
    _studentGroups = StudentGroupResolver.buildMap();

    int paid = 0, partial = 0, unpaid = 0, free = 0;
    final List<Users> filtered = [];
    final lowerQuery = searchQuery.trim().toLowerCase();

    for (final student in _allStudents) {
      // 1. İsim, Telefon ve E-posta Filtresi
      if (lowerQuery.isNotEmpty) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        if (!fullName.contains(lowerQuery) &&
            !student.email.toLowerCase().contains(lowerQuery) &&
            !student.phone.contains(lowerQuery)) {
          continue;
        }
      }

      // 2. Hızlı Grup Filtresi
      if (selectedGroupFilter != "Tümü") {
        if (!StudentGroupResolver.isInGroup(
          _studentGroups,
          student.app,
          selectedGroupFilter,
        )) {
          continue;
        }
      }

      // 3. Ödeme Durumu Çekimi (Hafızadan veya Hesaplamadan)
      final status = _getPaymentStatusFast(student.app, selectedMonthFilter);
      if (status == "registered_after") continue;

      // İstatistik Sayılarını ödeme filtresinden bağımsız hesapla
      switch (status) {
        case "paid":
          paid++;
          break;
        case "partial":
          partial++;
          break;
        case "unpaid":
          unpaid++;
          break;
        case "free":
          free++;
          break;
      }

      // 4. Ödeme Tipi Filtresi
      if (selectedPaymentFilter != "Tümü") {
        if (selectedPaymentFilter == "Ödeyen" && status != "paid") continue;
        if (selectedPaymentFilter == "Ödemeyen" && status != "unpaid") continue;
        if (selectedPaymentFilter == "Kısmi Ödeyen" && status != "partial")
          continue;
        if (selectedPaymentFilter == "Ücretsiz" && status != "free") continue;
      }

      filtered.add(student);
    }

    // Tek bir setState ile ekrana yansıt (Arayüz hatası vermez)
    setState(() {
      filteredStudents = filtered;
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
      _freeCount = free;
    });
  }

  // =========================================================================
  // ⚡ PERFORMANS İÇİN OKUMA YARDIMCILARI (RAM'DEN ÇEKER)
  // =========================================================================

  String _getStudentGroupNameFast(String studentId) {
    return StudentGroupResolver.label(_studentGroups, studentId);
  }

  /// 🔥 Aya göre ücret (zam/düzeltme geçmişi dikkate alınır, eski aylar değişmez)
  double _getStudentMonthlyFeeFast(String studentId, String monthYear) {
    return _feeCache.putIfAbsent("${studentId}_$monthYear", () {
      final parts = monthYear.split('-');
      if (parts.length != 2) return 0.0;
      return StudentFeeResolver.forStudentMonth(
        _repo,
        studentId,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    });
  }

  double _getStudentTotalPaidFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _paidCache.putIfAbsent(cacheKey, () {
      final parts = monthYear.split('-');
      if (parts.length != 2) return 0.0;
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      final student = _repo.getUserById(studentId);
      if (student == null) return 0.0;

      // Kayıt tarihi kontrolü
      final regYear = _getRegistrationYear(student);
      final regMonth = _getRegistrationMonth(student);
      if (yr < regYear || (yr == regYear && mo < regMonth)) return 0.0;

      double total = 0.0;
      final payments = _repo.getPaymentsByStudentId(studentId);
      for (var p in payments) {
        final st = p.status.toString().toUpperCase();
        if (st != "PAID" && st != "TRUE") continue;
        try {
          final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
          if (paidDate.year == yr && paidDate.month == mo) {
            total += double.tryParse(p.amount) ?? 0.0;
          }
        } catch (_) {}
      }
      return total;
    });
  }

  String _getPaymentStatusFast(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    return _statusCache.putIfAbsent(cacheKey, () {
      final student = _repo.getUserById(studentId);
      if (student == null) return "unknown";

      final parts = monthYear.split('-');
      final yr = int.parse(parts[0]);
      final mo = int.parse(parts[1]);

      final regYear = _getRegistrationYear(student);
      final regMonth = _getRegistrationMonth(student);

      // 🔥 Kayıt ayından TAM BİR ÖNCEKİ ay her zaman ÜCRETSİZ sayılır
      // (örn: 1 Temmuz kayıt -> Haziran ücretsiz)
      final freeYear = regMonth == 1 ? regYear - 1 : regYear;
      final freeMonth = regMonth == 1 ? 12 : regMonth - 1;
      if (yr == freeYear && mo == freeMonth) {
        return "free";
      }

      if (yr < regYear || (yr == regYear && mo < regMonth)) {
        return "registered_after";
      }

      final fee = _getStudentMonthlyFeeFast(studentId, monthYear);
      final paid = _getStudentTotalPaidFast(studentId, monthYear);

      if (fee == 0) return "unknown";
      if (paid >= fee) return "paid";
      if (paid > 0) return "partial";
      return "unpaid";
    });
  }

  int _getRegistrationYear(Users student) {
    if (student.created_at.isEmpty) return DateTime.now().year;
    try {
      return DateTime.parse(student.created_at).year;
    } catch (_) {
      return DateTime.now().year;
    }
  }

  int _getRegistrationMonth(Users student) {
    if (student.created_at.isEmpty) return 1;
    try {
      return DateTime.parse(student.created_at).month;
    } catch (_) {
      return 1;
    }
  }

  // =========================================================================
  // ⚡ TETİKLEYİCİLER (DEBOUNCE KORUMALI)
  // =========================================================================
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Kullanıcı klavyede duraksadığı an filtreleme yapar, arayüzü kasmaz
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      searchQuery = value;
      _applyFiltersAndCalculate();
    });
  }

  void _onGroupFilterChanged(String? value) {
    setState(() => selectedGroupFilter = value ?? "Tümü");
    _applyFiltersAndCalculate();
  }

  void _onMonthFilterChanged(String? value) {
    setState(() => selectedMonthFilter = value ?? monthOptions[6]);
    _applyFiltersAndCalculate();
  }

  void _onPaymentFilterChanged(String filterValue) {
    setState(() {
      selectedPaymentFilter = selectedPaymentFilter == filterValue
          ? "Tümü"
          : filterValue;
    });
    _applyFiltersAndCalculate();
  }

  /// 🔄 Manuel Zoraki Yenileme (Aşağı Kaydırınca veya Yenile Butonuyla)
  void _refreshData() async {
    setState(() => isLoading = true);
    _clearPerformanceCaches();
    await _repo.refreshAllData();
    _initializeData();
  }

  // =========================================================================
  // 🖼️ ARAYÜZ YARDIMCILARI
  // =========================================================================
  String _getMonthName(int m) => [
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
  ][m - 1];

  String _formatDate(String d) {
    if (d.isEmpty) return "—";
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d.split('T')[0]));
    } catch (_) {
      return d;
    }
  }

  Color _statusColor(String s) => s == "paid"
      ? _green
      : s == "partial"
      ? _orange
      : s == "free"
      ? _accent
      : _red;
  String _statusLabel(String s) => s == "paid"
      ? "Ödedi"
      : s == "partial"
      ? "Kısmi"
      : s == "free"
      ? "Ücretsiz"
      : "Ödemedi";
  IconData _statusIcon(String s) => s == "paid"
      ? Icons.check_circle_rounded
      : s == "partial"
      ? Icons.timelapse_rounded
      : s == "free"
      ? Icons.card_giftcard_rounded
      : Icons.cancel_rounded;

  @override
  Widget build(BuildContext context) {
    final parts = selectedMonthFilter.split('-');
    final monthName = parts.length == 2
        ? _getMonthName(int.parse(parts[1]))
        : "";
    final year = parts.isNotEmpty ? parts[0] : "";
    final total = _paidCount + _partialCount + _unpaidCount + _freeCount;
    final paidPct = total > 0 ? _paidCount / total : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Öğrenci Ödeme Sayfası",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary,
              ),
            ),
            Text(
              "$monthName $year · $total Öğrenci",
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _hasError
          ? DataErrorState(
              message: _repo.lastErrorMessage,
              accentColor: _accent,
              onRetry: _initializeData,
            )
          : RefreshIndicator(
              onRefresh: () async => _refreshData(),
              color: _accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Üst İstatistik Kartı
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$monthName $year",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Ödeme Durumu Özeti",
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 65,
                                    height: 65,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: paidPct >= 0.7
                                            ? _green
                                            : paidPct >= 0.4
                                            ? _orange
                                            : _red,
                                        width: 3.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${(paidPct * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          color: paidPct >= 0.7
                                              ? _green
                                              : paidPct >= 0.4
                                              ? _orange
                                              : _red,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: paidPct,
                                  backgroundColor: _border,
                                  valueColor: AlwaysStoppedAnimation(_green),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _statCard(
                                    "Ödeyen",
                                    _paidCount,
                                    _green,
                                    Icons.check_circle_rounded,
                                    "Ödeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Kısmi",
                                    _partialCount,
                                    _orange,
                                    Icons.timelapse_rounded,
                                    "Kısmi Ödeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Ödemeyen",
                                    _unpaidCount,
                                    _red,
                                    Icons.cancel_rounded,
                                    "Ödemeyen",
                                  ),
                                  const SizedBox(width: 8),
                                  _statCard(
                                    "Ücretsiz",
                                    _freeCount,
                                    _accent,
                                    Icons.card_giftcard_rounded,
                                    "Ücretsiz",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Filtreleme Paneli
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        "Öğrenci adı, e-posta veya tel ara...",
                                    hintStyle: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 13,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _textSecondary,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedGroupFilter,
                                      items: groupNames,
                                      icon: Icons.group_rounded,
                                      onChanged: _onGroupFilterChanged,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedMonthFilter,
                                      items: monthOptions,
                                      icon: Icons.calendar_month_rounded,
                                      displayMap: (m) {
                                        final p = m.split('-');
                                        return "${_getMonthName(int.parse(p[1]))} ${p[0]}";
                                      },
                                      onChanged: _onMonthFilterChanged,
                                    ),
                                  ),
                                ],
                              ),
                              const VersionFooter(),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Liste Bölümü
                  filteredStudents.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              "Öğrenci bulunamadı",
                              style: TextStyle(color: _textSecondary),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = filteredStudents[i];
                              final status = _getPaymentStatusFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final color = _statusColor(status);
                              final fee = _getStudentMonthlyFeeFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final paid = _getStudentTotalPaidFast(
                                s.app,
                                selectedMonthFilter,
                              );
                              final pct = fee > 0
                                  ? (paid / fee).clamp(0.0, 1.0)
                                  : 0.0;
                              final group = _getStudentGroupNameFast(s.app);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PaymentScreen(student: s),
                                      ),
                                    );
                                    if (result == true) {
                                      _clearPerformanceCaches();
                                      _applyFiltersAndCalculate();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              child: Text(
                                                s.first_name.isNotEmpty
                                                    ? s.first_name[0]
                                                          .toUpperCase()
                                                    : "?",
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${s.first_name} ${s.last_name}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    group,
                                                    style: const TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _statusLabel(status),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        status == "free"
                                            ? Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _accent.withOpacity(
                                                    0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .card_giftcard_rounded,
                                                      size: 16,
                                                      color: _accent,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "Bu ay ücretsiz (deneme ayı)",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: _accent,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _surfaceLight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          "Aidat: ${fee.toStringAsFixed(0)} ₺  |  Ödenen: ${paid.toStringAsFixed(0)} ₺",
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                _textSecondary,
                                                          ),
                                                        ),
                                                        Text(
                                                          "%${(pct * 100).toStringAsFixed(0)}",
                                                          style: TextStyle(
                                                            color: color,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value: pct,
                                                        backgroundColor:
                                                            _border,
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                              color,
                                                            ),
                                                        minHeight: 5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filteredStudents.length),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color color,
    IconData icon,
    String filterValue,
  ) {
    final sel = selectedPaymentFilter == filterValue;
    return Expanded(
      child: InkWell(
        onTap: () => _onPaymentFilterChanged(filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : _border, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: TextStyle(
                  color: sel ? color : _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? color : _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                displayMap != null ? displayMap(item) : item,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

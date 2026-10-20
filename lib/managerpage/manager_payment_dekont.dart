import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:EVOM_SPOR/managerpage/manager_offline/offline_payment_service.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/core/student_fee_resolver.dart';
import 'package:uuid/uuid.dart';

class PaymentScreen extends StatefulWidget {
  final Users student;
  const PaymentScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final AppRepository _repo = AppRepository();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String selectedMethod = "Nakit";
  DateTime selectedPaymentDate = DateTime.now();
  bool isProcessing = false;

  Future<Map<String, dynamic>>? _allDataFuture;
  int _selectedYear = DateTime.now().year;
  late int _previousYear;
  late int _currentYear;

  DateTime? _selectedMissingMonth;

  // 🔥 Çoklu ay seçimi (ileriye dönük toplu ödeme)
  bool _multiSelectMode = false;
  final Set<DateTime> _selectedMultiMonths = {};

  bool _historicalDebtExpanded = false;
  final Set<String> _deletingIds = {}; // çift silmeyi önler

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  List<Map<String, dynamic>> _feeUpdateHistory = [];
  Map<String, double> _feeOverrides = {};

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  // TEMA
  static const Color _bg = Color(0xFFF4F6FA);
  static const Color _surface = Colors.white;
  static const Color _teal = Color(0xFF0D9488);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _blueAccent = Color(0xFF2563EB);
  static const Color _green = Color(0xFF22C55E);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textSub = Color(0xFF94A3B8);
  static const Color _borderLight = Color(0xFFE2E8F0);

  bool _isMounted = false;
  late final OfflinePaymentService _offlinePaymentService;

  /// 🔥 Ekran kapansa bile yaşar (static). studentId -> yeni aylık ücret.
  /// Sunucuya henüz ulaşmamış ücret güncellemelerini tutar.
  static final Map<String, double> _pendingFeeSync = {};
  static const String _pendingFeePrefsKey = 'pending_fee_amount_sync';

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _currentYear = DateTime.now().year;
    _previousYear = _currentYear - 1;
    _selectedYear = _currentYear;
    _allDataFuture = Future.value({
      'monthlyFee': 0.0,
      'currentYear': _currentYear,
      'previousYear': _previousYear,
    });
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlinePaymentService = OfflinePaymentService();
    await _offlinePaymentService.init();
    unawaited(_flushPendingFeeSync());
    if (_isMounted) {
      setState(() {
        _allDataFuture = _loadAllDataParallel();
      });
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // =========================================================================
  // TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

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

  String _formatDateTurkish(DateTime? date) {
    if (date == null) return "Belirsiz";
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateFromString(String dateStr) {
    final date = _parseDateString(dateStr);
    return _formatDateTurkish(date);
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

  String _formatDisplayDateTurkish(DateTime date) {
    return _formatDateTurkish(date);
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR
  // =========================================================================
  int _getCurrentYear() => DateTime.now().year;
  int _getCurrentMonth() => DateTime.now().month;

  int _getStudentRegistrationYear() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.year;
    return _currentYear;
  }

  int _getStudentRegistrationMonth() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.month;
    return 1;
  }

  /// 🔥 Kayıt ayından TAM BİR ÖNCEKİ ay her zaman ÜCRETSİZ sayılır.
  bool _isFreeMonth(int year, int month) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    final freeYear = registrationMonth == 1
        ? registrationYear - 1
        : registrationYear;
    final freeMonth = registrationMonth == 1 ? 12 : registrationMonth - 1;
    return year == freeYear && month == freeMonth;
  }

  int? _getYearFromDueDate(String d) {
    if (d.isEmpty) return null;
    if (d.contains('-') && d.length >= 10)
      return int.tryParse(d.substring(0, 4));
    final m = RegExp(r'\d{4}').firstMatch(d);
    return m != null ? int.parse(m.group(0)!) : null;
  }

  int? _getMonthFromDueDate(String d) {
    if (d.isEmpty) return null;
    if (d.contains('-') && d.length >= 10)
      return int.tryParse(d.substring(5, 7));
    for (int i = 1; i <= 12; i++) {
      if (d.contains(_getMonthNameTurkish(i))) return i;
    }
    return null;
  }

  // =========================================================================
  // ÜCRET HESAPLAMA
  // =========================================================================
  double _getStudentMonthlyFeeForMonth(int year, int month) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    if (year < registrationYear ||
        (year == registrationYear && month < registrationMonth)) {
      return 0;
    }
    return StudentFeeResolver.feeForMonth(
      baseFee: monthlyFee,
      updates: _feeUpdateHistory,
      overrides: _feeOverrides,
      year: year,
      month: month,
    );
  }

  double _getExpectedAnnualForYear(int year) {
    double total = 0;
    for (var month in _getMonthsOfYear(year)) {
      total += _getStudentMonthlyFeeForMonth(year, month.month);
    }
    return total;
  }

  // =========================================================================
  // HESAPLAMALAR
  // =========================================================================
  List<Payment> _getPaymentsForYear(int year) => paymentHistory
      .where(
        (p) => _getYearFromDueDate(p.due_date) == year && p.status == "paid",
      )
      .toList();

  List<DateTime> _getMonthsOfYear(int year) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    List<DateTime> months = [];
    for (int m = 1; m <= 12; m++) {
      final md = DateTime(year, m, 1);
      if (year == registrationYear &&
          m < registrationMonth &&
          !_isFreeMonth(year, m)) {
        continue;
      }
      if (year >= registrationYear) {
        months.add(md);
      }
    }
    return months;
  }

  double _getPaidAmountForExactMonth(int year, int month) {
    double total = 0;
    for (var p in _getPaymentsForYear(year)) {
      if (_getYearFromDueDate(p.due_date) == year &&
          _getMonthFromDueDate(p.due_date) == month) {
        total += double.tryParse(p.amount) ?? 0;
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getMissingPaymentsForYear(int year) {
    final now = DateTime.now();
    final currentMonth = _getCurrentMonth();
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    List<Map<String, dynamic>> result = [];
    for (var month in _getMonthsOfYear(year)) {
      if (year == registrationYear && month.month < registrationMonth) continue;
      final monthlyFeeForThisMonth = _getStudentMonthlyFeeForMonth(
        year,
        month.month,
      );
      if (monthlyFeeForThisMonth == 0) continue;
      final paid = _getPaidAmountForExactMonth(year, month.month);
      final remaining = monthlyFeeForThisMonth - paid;
      if (remaining <= 0.01) continue;
      bool isMonthOver = false;
      bool isFutureMonth = false;
      if (year < _currentYear) {
        isMonthOver = true;
      } else if (year == _currentYear) {
        if (month.month < currentMonth) {
          isMonthOver = true;
        } else if (month.month == currentMonth) {
          isMonthOver = now.isAfter(DateTime(year, month.month + 1, 0));
        } else {
          isFutureMonth = true;
        }
      } else {
        isFutureMonth = true;
      }
      result.add({
        'date': month,
        'required': monthlyFeeForThisMonth,
        'paid': paid,
        'remaining': remaining,
        'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
        'isMonthOver': isMonthOver,
        'isCurrentMonth': (year == _currentYear && month.month == currentMonth),
        'isFutureMonth': isFutureMonth,
      });
    }
    result.sort((a, b) {
      if (a['isMonthOver'] && !b['isMonthOver']) return -1;
      if (!a['isMonthOver'] && b['isMonthOver']) return 1;
      return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
    });
    return result;
  }

  double _getTotalReceivedForYear(int year) => _getPaymentsForYear(
    year,
  ).fold(0, (s, p) => s + (double.tryParse(p.amount) ?? 0));

  List<Map<String, dynamic>> _getAllHistoricalDebts() {
    final List<Map<String, dynamic>> result = [];
    final registrationYear = _getStudentRegistrationYear();
    final startYear = registrationYear;
    final endYear = _currentYear - 1;
    for (int year = startYear; year <= endYear; year++) {
      final missing = _getMissingPaymentsForYear(year);
      if (missing.isEmpty) continue;
      final totalDebt = missing.fold<double>(
        0,
        (s, m) => s + (m['remaining'] as double),
      );
      result.add({'year': year, 'months': missing, 'totalDebt': totalDebt});
    }
    return result;
  }

  DateTime? _getEarliestUnpaidMonth() {
    final registrationYear = _getStudentRegistrationYear();
    DateTime? earliest;
    for (int year = registrationYear; year <= _currentYear; year++) {
      final missing = _getMissingPaymentsForYear(
        year,
      ).where((m) => m['isFutureMonth'] != true).toList();
      if (missing.isEmpty) continue;
      missing.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );
      final candidate = missing.first['date'] as DateTime;
      if (earliest == null || candidate.isBefore(earliest)) {
        earliest = candidate;
      }
      break;
    }
    return earliest;
  }

  bool _isMonthLockedBySequence(DateTime date) {
    final earliest = _getEarliestUnpaidMonth();
    if (earliest == null) return false;
    final earliestKey = earliest.year * 12 + earliest.month;
    final dateKey = date.year * 12 + date.month;
    return dateKey > earliestKey;
  }

  List<Map<String, dynamic>> _getMonthlyPaymentStatusForYear(int year) {
    final now = DateTime.now();
    final currentMonth = _getCurrentMonth();
    return _getMonthsOfYear(year)
        .map((month) {
          if (_isFreeMonth(year, month.month)) {
            return {
              'date': month,
              'required': 0.0,
              'paid': 0.0,
              'remaining': 0.0,
              'isFullyPaid': true,
              'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
              'status': "free",
            };
          }
          final monthlyFeeForThisMonth = _getStudentMonthlyFeeForMonth(
            year,
            month.month,
          );
          if (monthlyFeeForThisMonth == 0) return null;
          final paid = _getPaidAmountForExactMonth(year, month.month);
          final remaining = monthlyFeeForThisMonth - paid;
          final isPaid = remaining <= 0.01;
          String status;
          if (isPaid) {
            status = "paid";
          } else {
            bool over = false;
            if (year < _currentYear)
              over = true;
            else if (month.month < currentMonth)
              over = true;
            else if (month.month == currentMonth)
              over = now.isAfter(DateTime(year, month.month + 1, 0));
            status = over ? "overdue" : "current";
          }
          return {
            'date': month,
            'required': monthlyFeeForThisMonth,
            'paid': paid,
            'remaining': remaining > 0 ? remaining : 0,
            'isFullyPaid': isPaid,
            'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
            'status': status,
          };
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // =========================================================================
  // 🔥 LOKAL VERİ YÜKLEME (OFFLINE-FIRST)
  // =========================================================================
  Future<Map<String, dynamic>> _loadAllDataParallel() async {
    if (!_isMounted) return {};

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;
      final localPayments = _repo.allPayments;

      final current = allUsers.firstWhere(
        (u) => u.app == widget.student.app,
        orElse: () => widget.student,
      );
      monthlyFee = double.tryParse(current.amount) ?? 0;
      // Sunucuya henüz yansımamış yeni ücret varsa eski değerle ezme
      // (Kayıt, sunucu onayı gelince _syncFeeUpdateInBackground'ta silinir.)
      final pendingFee = _pendingFeeSync[widget.student.app];
      if (pendingFee != null) monthlyFee = pendingFee;

      final studentGroupRelations = _repo.getGroupStudentsByStudentId(
        widget.student.app,
      );
      final activeGroupIds = studentGroupRelations
          .where((r) => r.is_active.toString().toUpperCase() == "TRUE")
          .map((r) => r.groups_id)
          .toSet();

      studentGroups = allGroups
          .where((g) => activeGroupIds.contains(g.groups_id))
          .toList();

      if (studentGroups.isNotEmpty) {
        selectedGroupId = studentGroups.first.groups_id;
        selectedGroupName = studentGroups.map((g) => g.name).join(', ');
      } else {
        selectedGroupId = "";
        selectedGroupName = "Grup Yok";
      }

      paymentHistory =
          localPayments
              .where(
                (p) => p.student_id == widget.student.app && p.status == "paid",
              )
              .toList()
            ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

      final studentPayments = localPayments
          .where((p) => p.student_id == widget.student.app)
          .toList();
      final serverHistory = StudentFeeResolver.parseUpdates(studentPayments);
      final serverOverrides = StudentFeeResolver.parseOverrides(
        studentPayments,
      );

      final localHistory = await _readLocalFeeHistory();
      final mergedHistory = <String, Map<String, dynamic>>{};
      for (final u in serverHistory) {
        final d = u['date'] as DateTime;
        mergedHistory["${d.year}-${d.month}"] = u;
      }
      for (final u in localHistory) {
        final d = u['date'] as DateTime;
        final k = "${d.year}-${d.month}";
        final existing = mergedHistory[k];
        final localTs = (u['ts'] as int?) ?? 0;
        final serverTs = (existing?['ts'] as int?) ?? 0;
        if (existing == null || localTs > serverTs) mergedHistory[k] = u;
      }
      _feeUpdateHistory
        ..clear()
        ..addAll(
          mergedHistory.values.toList()..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          ),
        );

      _feeOverrides
        ..clear()
        ..addAll(serverOverrides);
      final localOverrides = await _readLocalOverrides();
      localOverrides.forEach((k, v) {
        if (!_feeOverrides.containsKey(k)) _feeOverrides[k] = v;
      });

      return {
        'monthlyFee': monthlyFee,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      return {
        'monthlyFee': 0.0,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    }
  }

  // =========================================================================
  // ÜCRET GÜNCELLEME (GEÇMİŞ ve GELECEK)
  // =========================================================================

  Future<void> _showFeeUpdateOptions() async {
    if (!_isMounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Ücret Güncelleme Türü"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.trending_up, color: _teal),
              title: const Text("Geleceğe Yönelik"),
              subtitle: const Text(
                "Seçilen aydan itibaren tüm aylar etkilenir",
              ),
              onTap: () => Navigator.pop(context, "future"),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: _orange),
              title: const Text("Geçmişe Yönelik"),
              subtitle: const Text("Sadece seçilen ayın ücretini değiştirir"),
              onTap: () => Navigator.pop(context, "past"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
        ],
      ),
    );
    if (!_isMounted) return;

    if (result == "future") {
      _updateMonthlyFee();
    } else if (result == "past") {
      _bulkOverridePastMonths();
    }
  }

  String get _feeHistKey => 'fee_hist_${widget.student.app}';
  String get _feeOvrKey => 'fee_ovr_${widget.student.app}';

  Future<List<Map<String, dynamic>>> _readLocalFeeHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_feeHistKey);
      if (raw == null || raw.isEmpty) return [];
      final list = <Map<String, dynamic>>[];
      for (final e in jsonDecode(raw) as List) {
        final d = DateTime.tryParse(e['date'].toString());
        if (d == null) continue;
        list.add({
          'date': DateTime(d.year, d.month, 1),
          'fee': (e['fee'] as num).toDouble(),
          'oldFee': (e['oldFee'] as num).toDouble(),
          'ts': (e['ts'] as num?)?.toInt() ?? 0,
        });
      }
      list.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );
      return list;
    } catch (e) {
      print("Lokal ücret geçmişi okunamadı: $e");
      return [];
    }
  }

  Future<void> _writeLocalFeeHistory(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _feeHistKey,
        jsonEncode(
          list
              .map(
                (u) => {
                  'date': DateFormat(
                    'yyyy-MM-dd',
                  ).format(u['date'] as DateTime),
                  'fee': u['fee'],
                  'oldFee': u['oldFee'],
                  'ts': u['ts'] ?? 0,
                },
              )
              .toList(),
        ),
      );
    } catch (e) {
      print("Lokal ücret geçmişi yazılamadı: $e");
    }
  }

  Future<Map<String, double>> _readLocalOverrides() async {
    final result = <String, double>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_feeOvrKey);
      if (raw == null || raw.isEmpty) return result;
      (jsonDecode(raw) as Map).forEach((k, v) {
        result[k.toString()] = (v as num).toDouble();
      });
    } catch (e) {
      print("Lokal ücret düzeltmeleri okunamadı: $e");
    }
    return result;
  }

  Future<void> _writeLocalOverrides(Map<String, double> added) async {
    try {
      final current = await _readLocalOverrides();
      current.addAll(added);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_feeOvrKey, jsonEncode(current));
    } catch (e) {
      print("Lokal ücret düzeltmeleri yazılamadı: $e");
    }
  }

  // =========================================================================
  // 🔥 ÜCRET GÜNCELLEME SENKRONU (geç yansıma düzeltmesi)
  // =========================================================================

  /// Yeni ücreti SQLite + RAM'e anında yazar (RAM-only değişiklik, bir sonraki
  /// _loadFromDisk'te eski değerle ezilirdi). Diğer ekranlar anında görür.
  Future<void> _applyFeeToRepoUser(double newFee) async {
    _pendingFeeSync[widget.student.app] = newFee;
    await _repo.setUserAmountLocal(widget.student.app, newFee);
  }

  Future<bool> _retry(
    Future<dynamic> Function() action, {
    int attempts = 3,
  }) async {
    for (int i = 0; i < attempts; i++) {
      try {
        final r = await action();
        if (r is bool && r == false) throw Exception('false döndü');
        return true;
      } catch (e) {
        print("Sync denemesi ${i + 1}/$attempts başarısız: $e");
        if (i < attempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
    return false;
  }

  /// ❗ Eski hata: updateUserAmount, savePayment bitince VE ekran hâlâ açıksa
  /// çalışıyordu. Artık ikisi paralel, ekrandan bağımsız ve tekrar denemeli.
  Future<void> _syncFeeUpdateInBackground({
    required Payment feeUpdatePayment,
    required String studentId,
    required double newFee,
  }) async {
    // Ödeme sisteminin okuduğu asıl değer: kullanıcının amount'u
    final amountFuture = _retry(
      () => GoogleSheetService.updateUserAmount(studentId, newFee),
    );
    // fee_update kaydı (geçmiş için) — bağımsız, birbirini beklemez
    final paymentFuture = _offlinePaymentService
        .savePayment(feeUpdatePayment)
        .catchError((e) {
          print("fee_update kaydı hatası: $e");
          return false;
        });

    final amountOk = await amountFuture;
    if (amountOk) {
      _pendingFeeSync.remove(studentId);
      // Bu arada bir tazeleme eski Sheet değerini yerele yazdıysa düzelt
      await _repo.setUserAmountLocal(studentId, newFee);
      await _removePendingFeeFromPrefs(studentId);
      GoogleSheetService.invalidateCache('users');
    } else {
      // Çevrimdışı vb.: kalıcı kuyruğa yaz, sonraki açılışta tekrar dene
      await _savePendingFeeToPrefs(studentId, newFee);
    }

    await paymentFuture;
    GoogleSheetService.invalidateCache('payments');
  }

  Future<void> _savePendingFeeToPrefs(String studentId, double fee) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      final raw = prefs.getString(_pendingFeePrefsKey);
      if (raw != null && raw.isNotEmpty) map.addAll(jsonDecode(raw) as Map);
      map[studentId] = fee;
      await prefs.setString(_pendingFeePrefsKey, jsonEncode(map));
    } catch (e) {
      print("Bekleyen ücret yazılamadı: $e");
    }
  }

  Future<void> _removePendingFeeFromPrefs(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingFeePrefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map.remove(studentId);
      await prefs.setString(_pendingFeePrefsKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Ekran açılırken, daha önce sunucuya gidememiş ücretleri tekrar dener.
  Future<void> _flushPendingFeeSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingFeePrefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final e in map.entries.toList()) {
        final fee = (e.value as num).toDouble();
        final ok = await _retry(
          () => GoogleSheetService.updateUserAmount(e.key, fee),
          attempts: 2,
        );
        if (ok) {
          _pendingFeeSync.remove(e.key);
          await _removePendingFeeFromPrefs(e.key);
          GoogleSheetService.invalidateCache('users');
        } else {
          _pendingFeeSync[e.key] = fee;
        }
      }
    } catch (e) {
      print("Bekleyen ücret flush hatası: $e");
    }
  }

  Future<void> _updateMonthlyFee() async {
    if (!_isMounted) return;

    final oldFee = monthlyFee;
    final ctrl = TextEditingController(text: monthlyFee.toStringAsFixed(0));
    final oldCtrl = TextEditingController(text: monthlyFee.toStringAsFixed(0));
    bool isSubmitting = false;
    DateTime effectiveMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: _teal),
                SizedBox(width: 8),
                Text('Gelecek Aylar İçin\nÜcret Güncelle'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Aylık Ücret (TL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: oldCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Önceki Ücret (seçilen aydan öncesi için)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.history),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    "Geçerli olacağı ay: ${_getMonthNameTurkish(effectiveMonth.month)} ${effectiveMonth.year}",
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: effectiveMonth,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(
                              () => effectiveMonth = DateTime(
                                picked.year,
                                picked.month,
                                1,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  minimumSize: const Size(100, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newFee = double.tryParse(ctrl.text) ?? 0;
                        final oldFeeInput =
                            double.tryParse(oldCtrl.text) ?? monthlyFee;
                        if (newFee > 0 && newFee != oldFeeInput) {
                          setDialogState(() => isSubmitting = true);

                          final oldMonthlyFee = oldFeeInput;
                          final feeUpdatePayment = Payment(
                            payments_id: "fee_${const Uuid().v4()}",
                            student_id: widget.student.app,
                            groups_id: selectedGroupId ?? "",
                            recorded_by: "Admin",
                            amount: "0",
                            due_date:
                                "${effectiveMonth.year}-${effectiveMonth.month.toString().padLeft(2, '0')}-01",
                            paid_date: DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now()),
                            status: "fee_update",
                            payment_method: "Sistem",
                            note:
                                "FEE_UPDATE: ${newFee.toStringAsFixed(0)} (Eski: ${oldMonthlyFee.toStringAsFixed(0)} TL)",
                          );

                          // 🔥 Önce RAM ve Lokal'e anında işle, UI'ı bloklama
                          _repo.allPayments.add(feeUpdatePayment);
                          paymentHistory.insert(0, feeUpdatePayment);
                          monthlyFee = newFee;
                          await _applyFeeToRepoUser(newFee);

                          final localList = await _readLocalFeeHistory();
                          localList.removeWhere((u) {
                            final d = u['date'] as DateTime;
                            return d.year == effectiveMonth.year &&
                                d.month == effectiveMonth.month;
                          });
                          localList.add({
                            'date': effectiveMonth,
                            'fee': newFee,
                            'oldFee': oldMonthlyFee,
                            'ts': DateTime.now().millisecondsSinceEpoch,
                          });
                          await _writeLocalFeeHistory(localList);

                          if (mounted) Navigator.pop(context);
                          if (_isMounted) {
                            setState(() {
                              _allDataFuture = _loadAllDataParallel();
                            });
                            _showSnackBar(
                              '✅ Aylık ücret güncellendi: ${newFee.toStringAsFixed(0)} TL',
                            );
                          }

                          // 🔥 Arka plan senkronu: ekran kapansa bile devam eder
                          unawaited(
                            _syncFeeUpdateInBackground(
                              feeUpdatePayment: feeUpdatePayment,
                              studentId: widget.student.app,
                              newFee: newFee,
                            ),
                          );
                        } else if (newFee == oldFeeInput) {
                          if (mounted) Navigator.pop(context);
                        } else if (_isMounted) {
                          _showSnackBar(
                            '❌ Geçerli bir tutar girin!',
                            isError: true,
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _bulkOverridePastMonths() async {
    if (!_isMounted) return;

    int selectedYear = _currentYear;
    List<int> selectedMonths = [];
    double newFee = 0;
    String generatedCode = "";
    String enteredCode = "";
    bool stepTwo = false;
    bool isSubmitting = false;

    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    Set<String> availableMonthsSet = {};
    for (int y = registrationYear; y <= _currentYear; y++) {
      int startMonth = (y == registrationYear) ? registrationMonth : 1;
      int endMonth = (y == _currentYear) ? _getCurrentMonth() : 12;
      for (int m = startMonth; m <= endMonth; m++) {
        availableMonthsSet.add("$y-$m");
      }
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.history_edu, color: _teal),
                SizedBox(width: 8),
                Text('Geçmiş Aylar İçin\nToplu Ücret Düzeltme'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: List.generate(_currentYear - registrationYear + 1, (
                      i,
                    ) {
                      int year = registrationYear + i;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: stepTwo
                        ? null
                        : (val) {
                            if (val != null)
                              setDialogState(() => selectedYear = val);
                          },
                    decoration: InputDecoration(
                      labelText: "Yıl",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderLight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            "Değiştirmek İstediğiniz Ayı Seçin",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(12, (index) {
                              int month = index + 1;
                              final key = "$selectedYear-$month";
                              if (!availableMonthsSet.contains(key)) {
                                return const SizedBox.shrink();
                              }
                              bool isSelected = selectedMonths.contains(month);
                              return FilterChip(
                                label: Text(_getMonthNameTurkish(month)),
                                selected: isSelected,
                                onSelected: stepTwo
                                    ? null
                                    : (selected) {
                                        setDialogState(() {
                                          if (selected) {
                                            selectedMonths.add(month);
                                          } else {
                                            selectedMonths.remove(month);
                                          }
                                        });
                                      },
                                backgroundColor: _bg,
                                selectedColor: _teal.withOpacity(0.2),
                                checkmarkColor: _teal,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    enabled: !stepTwo,
                    onChanged: (val) => newFee = double.tryParse(val) ?? 0,
                    decoration: InputDecoration(
                      labelText: "Yeni Ücret (TL)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!stepTwo)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (newFee <= 0) {
                          _showSnackBar(
                            "Lütfen geçerli bir ücret girin!",
                            isError: true,
                          );
                          return;
                        }
                        if (selectedMonths.isEmpty) {
                          _showSnackBar(
                            "Lütfen en az bir ay seçin!",
                            isError: true,
                          );
                          return;
                        }
                        generatedCode =
                            (100000 +
                                    DateTime.now().millisecondsSinceEpoch %
                                        900000)
                                .toString();
                        setDialogState(() => stepTwo = true);
                      },
                      icon: const Icon(Icons.security),
                      label: const Text("Kod Oluştur"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (stepTwo) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Doğrulama Kodu:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            generatedCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => enteredCode = val,
                      decoration: InputDecoration(
                        labelText: "Kodu Girin",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              if (stepTwo)
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (enteredCode != generatedCode) {
                            _showSnackBar("❌ Kod hatalı!", isError: true);
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final List<Payment> newOverridePayments = [];
                          final Map<String, double> addedOverrides = {};

                          for (int month in selectedMonths) {
                            final dueDate =
                                "$selectedYear-${month.toString().padLeft(2, '0')}-01";
                            final today = DateTime.now();
                            final paidDate =
                                "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
                            final yearMonth = dueDate.substring(0, 7);

                            final overridePayment = Payment(
                              payments_id: "",
                              student_id: widget.student.app,
                              groups_id: selectedGroupId ?? "",
                              recorded_by: "Admin",
                              amount: newFee.toStringAsFixed(0),
                              due_date: dueDate,
                              paid_date: paidDate,
                              status: "fee_override",
                              payment_method: "Sistem",
                              note:
                                  "OVERRIDE: $generatedCode (Toplu güncelleme)",
                            );

                            _repo.allPayments.add(overridePayment);
                            paymentHistory.insert(0, overridePayment);
                            newOverridePayments.add(overridePayment);
                            _feeOverrides[yearMonth] = newFee;
                            addedOverrides[yearMonth] = newFee;
                          }

                          await _writeLocalOverrides(addedOverrides);

                          if (mounted) Navigator.pop(context);
                          if (_isMounted) {
                            setState(() {
                              _allDataFuture = _loadAllDataParallel();
                            });
                            _showSnackBar(
                              "✅ ${selectedMonths.length} ayın ücreti düzeltildi!",
                            );
                          }

                          // 🔥 Arka planda güvenli senkronizasyon
                          unawaited(
                            _offlinePaymentService
                                .savePaymentsBatch(newOverridePayments)
                                .then((success) async {
                                  if (success && _isMounted) {
                                    try {
                                      GoogleSheetService.invalidateCache(
                                        'payments',
                                      );
                                    } catch (e) {
                                      print("Arka plan sync hatası: $e");
                                    }
                                  }
                                }),
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: _green),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Onayla ve Kaydet"),
                ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 🔥 ÖDEME İŞLEMLERİ (ANINDA TEPKİ - OFFLINE FIRST)
  // =========================================================================

  Future<void> _selectPaymentDateForMissingMonth(
    DateTime missingMonth, {
    bool isMonthOver = false,
  }) async {
    if (!_isMounted) return;

    final firstDay = DateTime(missingMonth.year, missingMonth.month, 1);
    final lastDay = DateTime(missingMonth.year, missingMonth.month + 1, 0);

    DateTime initialDate;
    if (isMonthOver) {
      initialDate = DateTime(missingMonth.year, missingMonth.month, 15);
      if (initialDate.day != 15) initialDate = lastDay;
    } else {
      initialDate = selectedPaymentDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDay,
      lastDate: lastDay,
      helpText:
          'Ödeme Tarihi Seç (${_getMonthNameTurkish(missingMonth.month)} ${missingMonth.year})',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );

    if (picked != null && _isMounted) {
      setState(() {
        selectedPaymentDate = picked;
        _selectedMissingMonth = missingMonth;
      });
    }
  }

  Future<void> _processPaymentForMissingMonth(
    DateTime missingMonth,
    double requiredAmount,
  ) async {
    if (amountController.text.isEmpty) {
      _showSnackBar("Lütfen tutar girin!", isError: true);
      return;
    }

    final String currentGroupId = selectedGroupId ?? "";
    final tutar = double.tryParse(amountController.text) ?? 0;
    if (tutar > requiredAmount) {
      _showSnackBar(
        "Maksimum ${requiredAmount.toStringAsFixed(0)} TL girebilirsiniz!",
        isError: true,
      );
      return;
    }

    if (!_isMounted) return;
    setState(() => isProcessing = true);

    final payMonth =
        "${missingMonth.year}-${missingMonth.month.toString().padLeft(2, '0')}-01";
    final payDate =
        "${selectedPaymentDate.year}-${selectedPaymentDate.month.toString().padLeft(2, '0')}-${selectedPaymentDate.day.toString().padLeft(2, '0')}";

    final newPayment = Payment(
      payments_id: const Uuid().v4(),
      student_id: widget.student.app,
      groups_id: currentGroupId,
      recorded_by: "Admin",
      amount: amountController.text,
      due_date: payMonth,
      paid_date: payDate,
      status: "paid",
      payment_method: selectedMethod,
      note: noteController.text.trim(),
    );

    // 🔥 RAM ve Yerel listeye anında ekle (Sıfır gecikme)
    _repo.allPayments.add(newPayment);
    paymentHistory.insert(0, newPayment);

    if (_isMounted) {
      setState(() {
        _selectedMissingMonth = null;
        amountController.clear();
        noteController.clear();
        isProcessing = false;
      });
    }

    final monthName =
        _getMonthNameTurkish(missingMonth.month) + " ${missingMonth.year}";
    _showSnackBar("✅ $monthName ödemesi kaydedildi!");

    // 🔥 Ağ isteğini arka plana at (Asla kullanıcıyı bekletmez)
    unawaited(
      _offlinePaymentService.savePayment(newPayment).then((success) {
        if (success && _isMounted) {
          GoogleSheetService.invalidateCache('payments');
        }
      }),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!_isMounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPaymentDetailPopup(Payment p) {
    if (!_isMounted) return;

    final month = _getMonthFromDueDate(p.due_date);
    final year = _getYearFromDueDate(p.due_date);
    final monthName = (month != null && year != null)
        ? _getMonthNameTurkish(month) + " $year"
        : "—";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.receipt_long, color: _teal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Ödeme Detayı",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              monthName,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _textSub),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _popupRow(
                    Icons.attach_money,
                    "Tutar",
                    "${double.tryParse(p.amount)?.toStringAsFixed(0) ?? p.amount} TL",
                    _green,
                  ),
                  _popupRow(
                    Icons.calendar_today,
                    "Ödeme Tarihi",
                    _formatDateFromString(p.paid_date),
                    _teal,
                  ),
                  _popupRow(Icons.date_range, "Ay", monthName, _teal),
                  _popupRow(
                    p.payment_method == "Nakit"
                        ? Icons.money
                        : p.payment_method == "Kredi Kartı"
                        ? Icons.credit_card
                        : Icons.account_balance,
                    "Yöntem",
                    p.payment_method,
                    _orange,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditPaymentDialog(p);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text("Düzenle"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _teal,
                            side: BorderSide(color: _teal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeletePayment(p),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text("Sil"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(color: _red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
        },
      ),
    );
  }

  void _showEditPaymentDialog(Payment payment) async {
    if (!_isMounted) return;

    final amountCtrl = TextEditingController(text: payment.amount);
    final noteCtrl = TextEditingController(text: payment.note);
    String selectedMethodEdit = payment.payment_method;
    DateTime selectedDateEdit =
        _parseDateString(payment.paid_date) ?? DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: _teal),
                SizedBox(width: 8),
                Text("Ödemeyi Düzenle", style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Tutar (TL)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMethodEdit,
                    items: paymentMethods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedMethodEdit = v!),
                    decoration: const InputDecoration(
                      labelText: "Ödeme Yöntemi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newAmount = amountCtrl.text.trim();
                        final newNote = noteCtrl.text.trim();
                        final newMethod = selectedMethodEdit;
                        final newDate = _formatDateForDB(selectedDateEdit);

                        if (newAmount.isEmpty ||
                            double.tryParse(newAmount) == null) {
                          _showSnackBar(
                            "❌ Geçerli bir tutar girin!",
                            isError: true,
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        final idx = paymentHistory.indexWhere(
                          (p) => p.payments_id == payment.payments_id,
                        );
                        final repoIdx = _repo.allPayments.indexWhere(
                          (p) => p.payments_id == payment.payments_id,
                        );

                        final updatedPayment = Payment(
                          payments_id: payment.payments_id,
                          student_id: payment.student_id,
                          groups_id: selectedGroupId ?? payment.groups_id,
                          recorded_by: payment.recorded_by,
                          amount: newAmount,
                          due_date: payment.due_date,
                          paid_date: newDate,
                          status: payment.status,
                          payment_method: newMethod,
                          note: newNote,
                        );

                        if (_isMounted) {
                          setState(() {
                            if (idx >= 0) paymentHistory[idx] = updatedPayment;
                            if (repoIdx >= 0)
                              _repo.allPayments[repoIdx] = updatedPayment;
                          });
                          if (mounted) Navigator.pop(context);
                          _showSnackBar("✅ Ödeme güncellendi!");
                        }

                        unawaited(
                          GoogleSheetService.updatePayment(
                            payment.payments_id,
                            {
                              "amount": newAmount,
                              "payment_method": newMethod,
                              "paid_date": newDate,
                              "note": newNote,
                            },
                          ).then((success) {
                            if (success)
                              GoogleSheetService.invalidateCache('payments');
                          }),
                        );
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _teal),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Kaydet"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeletePayment(Payment payment) async {
    if (!_isMounted) return;
    if (_deletingIds.contains(payment.payments_id)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ödemeyi Sil", style: TextStyle(color: _red)),
        content: Text(
          "${_formatDateFromString(payment.paid_date)} tarihli ${payment.amount} TL ödeme silinecek.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true || !_isMounted) return;

    _deletingIds.add(payment.payments_id);

    if (_isMounted) {
      setState(() {
        paymentHistory.removeWhere((p) => p.payments_id == payment.payments_id);
        _repo.allPayments.removeWhere(
          (p) => p.payments_id == payment.payments_id,
        );
      });
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar("✅ Ödeme silindi!");
    }

    unawaited(
      GoogleSheetService.deletePayment(payment.payments_id).then((success) {
        if (success) GoogleSheetService.invalidateCache('payments');
        _deletingIds.remove(payment.payments_id);
      }),
    );
  }

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Widget _popupRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: _textSub)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall() async {
    final phone = widget.student.phone;
    if (phone.isEmpty) {
      _showSnackBar("Telefon numarası mevcut değil", isError: true);
      return;
    }
    final Uri telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      _showSnackBar("Arama yapılamadı", isError: true);
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Ödeme İşlemleri",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: _teal),
            tooltip: "Ücret Güncelle",
            onPressed: _showFeeUpdateOptions,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _allDataFuture,
        builder: (context, snapshot) {
          if (_allDataFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final totalReceived = _getTotalReceivedForYear(_selectedYear);
          final expectedAnnual = _getExpectedAnnualForYear(_selectedYear);
          final missingPayments = _getMissingPaymentsForYear(_selectedYear);
          final monthlyStatus = _getMonthlyPaymentStatusForYear(_selectedYear);
          final historicalDebts = _getAllHistoricalDebts();
          final registrationYear = _getStudentRegistrationYear();

          double collectionRate = expectedAnnual > 0
              ? (totalReceived / expectedAnnual * 100).clamp(0.0, 100.0)
              : 0;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: _surface,
                child: Row(
                  children: [
                    _buildYearButton(_previousYear),
                    const SizedBox(width: 12),
                    _buildYearButton(_currentYear),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStudentCard(),
                      const SizedBox(height: 16),
                      _buildYearlyStatsCard(
                        _selectedYear,
                        totalReceived,
                        expectedAnnual,
                        collectionRate,
                      ),
                      const SizedBox(height: 16),
                      if (historicalDebts.isNotEmpty)
                        _buildHistoricalDebtPanel(
                          historicalDebts,
                          registrationYear,
                        ),
                      const SizedBox(height: 16),
                      if (monthlyStatus.isNotEmpty)
                        _buildMonthlyPaymentStatusCard(
                          monthlyStatus,
                          _selectedYear,
                        ),
                      const SizedBox(height: 16),
                      if (missingPayments.isNotEmpty)
                        _buildMissingPaymentsCard(missingPayments),
                      const SizedBox(height: 16),
                      _buildPaymentFormCard(),
                      const SizedBox(height: 16),
                      _buildPaymentHistoryCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
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

  Widget _buildYearButton(int year) {
    final isSel = _selectedYear == year;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isMounted) {
            setState(() {
              _selectedYear = year;
              _selectedMissingMonth = null;
              amountController.clear();
              noteController.clear();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? _teal : _bg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSel ? Colors.transparent : _borderLight,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : _textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard() {
    final registrationYear = _getStudentRegistrationYear();
    final registrationDate = _parseDateString(widget.student.created_at);
    final registrationText = registrationDate != null
        ? "Kayıt: ${_formatDateTurkish(registrationDate)}"
        : "Kayıt: $registrationYear";
    final phoneNumber = widget.student.phone.isNotEmpty
        ? widget.student.phone
        : "Telefon yok";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: widget.student.profile_photo_url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.student.profile_photo_url,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.student.first_name} ${widget.student.last_name}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.email,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      registrationText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.group, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.call, size: 16, color: _teal),
                      onPressed: _makePhoneCall,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    width: 55,
    height: 55,
    color: _teal,
    child: Center(
      child: Text(
        widget.student.first_name.isNotEmpty
            ? widget.student.first_name[0].toUpperCase()
            : "?",
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );

  Widget _buildYearlyStatsCard(
    int year,
    double totalReceived,
    double expectedAnnual,
    double collectionRate,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _statCol("$year", "YILI"),
          _divider(),
          _statCol("${totalReceived.toStringAsFixed(0)} TL", "TAHSİLAT"),
          _divider(),
          _statCol("${expectedAnnual.toStringAsFixed(0)} TL", "BEKLENEN"),
          _divider(),
          _statCol("${collectionRate.toStringAsFixed(0)}%", "ORAN"),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label) => Expanded(
    child: Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  Widget _buildMonthlyPaymentStatusCard(
    List<Map<String, dynamic>> monthlyStatus,
    int year,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: _teal),
              const SizedBox(width: 8),
              Text(
                "$year Yılı Aylık Ödeme Durumu",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: monthlyStatus.length,
            itemBuilder: (_, i) {
              final item = monthlyStatus[i];
              final isPaid = item['isFullyPaid'];
              final status = item['status'];
              final isFree = status == "free";
              final requiredFee = item['required'] as double;

              Color bgColor = isFree
                  ? Colors.blue.shade50
                  : isPaid
                  ? Colors.green.shade50
                  : status == "current"
                  ? Colors.orange.shade50
                  : Colors.red.shade50;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['monthName'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFree
                          ? "Ücretsiz"
                          : "${(item['paid'] as double).toStringAsFixed(0)}/${requiredFee.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMissingPaymentsCard(List<Map<String, dynamic>> missingPayments) {
    if (_selectedMissingMonth != null) {
      final sel = missingPayments.firstWhere(
        (m) =>
            (m['date'] as DateTime).year == _selectedMissingMonth!.year &&
            (m['date'] as DateTime).month == _selectedMissingMonth!.month,
        orElse: () => {},
      );
      if (sel.isNotEmpty) return _buildPaymentFormForMissingMonth(sel);
    }

    if (_multiSelectMode) return _buildMultiSelectCard(missingPayments);

    final overdue = missingPayments
        .where((m) => m['isMonthOver'] == true)
        .toList();
    final current = missingPayments
        .where((m) => m['isCurrentMonth'] == true && m['isMonthOver'] == false)
        .toList();
    final future = missingPayments
        .where((m) => m['isFutureMonth'] == true)
        .toList();
    final totalDebt = missingPayments
        .where((m) => m['isFutureMonth'] != true)
        .fold<double>(0, (s, m) => s + (m['remaining'] as double));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _red, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Ödenmemiş Aylar",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "${totalDebt.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              if (!_isMounted) return;
              setState(() {
                _multiSelectMode = true;
                _selectedMultiMonths.clear();
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_check_rounded,
                    size: 18,
                    color: _teal,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Birden Fazla Ay Seçip Toplu Öde",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _teal,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: _teal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (overdue.isNotEmpty) ...[
            Text(
              "📅 Geçmiş Aylar:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: overdue
                  .map(
                    (m) => _buildPaymentButton(
                      m['date'] as DateTime,
                      m['remaining'],
                      m['monthName'],
                      _red,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],
          if (current.isNotEmpty) ...[
            Text(
              "📌 Bu Ay:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: current
                  .map(
                    (m) => _buildPaymentButton(
                      m['date'] as DateTime,
                      m['remaining'],
                      m['monthName'],
                      _orange,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiSelectCard(List<Map<String, dynamic>> missingPayments) {
    final selectable =
        missingPayments.where((m) => (m['remaining'] as double) > 0.01).toList()
          ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

    bool isLockedForSelection(DateTime date) {
      final dateKey = date.year * 12 + date.month;
      for (final m in selectable) {
        final mDate = m['date'] as DateTime;
        final mKey = mDate.year * 12 + mDate.month;
        if (mKey >= dateKey) continue;
        if (!_selectedMultiMonths.contains(mDate)) return true;
      }
      return false;
    }

    final selectedItems = selectable
        .where((m) => _selectedMultiMonths.contains(m['date'] as DateTime))
        .toList();
    final totalSelected = selectedItems.fold<double>(
      0,
      (s, m) => s + (m['remaining'] as double),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.playlist_add_check_rounded, color: _teal, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Toplu Ay Seçimi",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _teal,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (!_isMounted) return;
                  setState(() {
                    _multiSelectMode = false;
                    _selectedMultiMonths.clear();
                  });
                },
                icon: const Icon(Icons.close, size: 20, color: _textSub),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selectable.map((m) {
              final date = m['date'] as DateTime;
              final isSelected = _selectedMultiMonths.contains(date);
              final isLocked = !isSelected && isLockedForSelection(date);
              return GestureDetector(
                onTap: () {
                  if (!_isMounted) return;
                  if (isLocked) {
                    _showSnackBar(
                      "⚠️ Önce önceki aylar seçilmelidir!",
                      isError: true,
                    );
                    return;
                  }
                  setState(() {
                    if (isSelected) {
                      final dateKey = date.year * 12 + date.month;
                      _selectedMultiMonths.removeWhere((d) {
                        return (d.year * 12 + d.month) >= dateKey;
                      });
                    } else {
                      _selectedMultiMonths.add(date);
                    }
                  });
                },
                child: Opacity(
                  opacity: isLocked ? 0.55 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _teal : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: _teal),
                    ),
                    child: Text(
                      "${m['monthName']} (${(m['remaining'] as double).toStringAsFixed(0)} TL)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedMultiMonths.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  amountController.text = totalSelected.toStringAsFixed(0);
                  _processMultiMonthPayment(selectedItems);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Seçili Ayların Ödemesini Al (${totalSelected.toStringAsFixed(0)} TL)",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _processMultiMonthPayment(
    List<Map<String, dynamic>> selectedItems,
  ) async {
    final totalTutar = double.tryParse(amountController.text) ?? 0;
    if (totalTutar <= 0) {
      _showSnackBar("Geçerli bir tutar girin!", isError: true);
      return;
    }

    if (!_isMounted) return;
    setState(() => isProcessing = true);

    final payDateStr = _formatDateForDB(DateTime.now());
    final perMonthShare = totalTutar / selectedItems.length;
    final newPayments = <Payment>[];

    for (final m in selectedItems) {
      final date = m['date'] as DateTime;
      final maxForMonth = m['remaining'] as double;
      final amountForMonth = perMonthShare > maxForMonth
          ? maxForMonth
          : perMonthShare;
      final payMonth =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-01";

      newPayments.add(
        Payment(
          payments_id: const Uuid().v4(),
          student_id: widget.student.app,
          groups_id: selectedGroupId ?? "",
          recorded_by: "Admin",
          amount: amountForMonth.toStringAsFixed(0),
          due_date: payMonth,
          paid_date: payDateStr,
          status: "paid",
          payment_method: selectedMethod,
          note: noteController.text.trim(),
        ),
      );
    }

    for (final p in newPayments) {
      _repo.allPayments.add(p);
      paymentHistory.insert(0, p);
    }

    if (_isMounted) {
      setState(() {
        _multiSelectMode = false;
        _selectedMultiMonths.clear();
        amountController.clear();
        noteController.clear();
        isProcessing = false;
      });
    }

    _showSnackBar("✅ ${newPayments.length} ay için ödeme kaydedildi!");

    unawaited(
      _offlinePaymentService.savePaymentsBatch(newPayments).then((success) {
        if (success && _isMounted) {
          GoogleSheetService.invalidateCache('payments');
        }
      }),
    );
  }

  Widget _buildPaymentButton(
    DateTime date,
    double remaining,
    String monthName,
    Color color,
  ) {
    final isLocked = _isMonthLockedBySequence(date);
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showSnackBar("⚠️ Önce önceki aylar ödenmelidir!", isError: true);
          return;
        }
        setState(() {
          _selectedMissingMonth = date;
          amountController.text = remaining.toStringAsFixed(0);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(
          "$monthName (${remaining.toStringAsFixed(0)} TL)",
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentFormForMissingMonth(Map<String, dynamic> missingMonth) {
    final date = missingMonth['date'] as DateTime;
    final remaining = missingMonth['remaining'] as double;
    final monthName = missingMonth['monthName'] as String;

    if (amountController.text.isEmpty) {
      amountController.text = remaining.toStringAsFixed(0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _teal, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "$monthName Ödemesi",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _selectedMissingMonth = null),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Tutar (TL)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () => _processPaymentForMissingMonth(date, remaining),
              style: ElevatedButton.styleFrom(backgroundColor: _teal),
              child: const Text(
                "Ödemeyi Tamamla",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFormCard() => const SizedBox.shrink();

  Widget _buildPaymentHistoryCard() {
    final payments = _getPaymentsForYear(_selectedYear);
    if (payments.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: _teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  "$_selectedYear Ödeme Geçmişi",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length > 5 ? 5 : payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = payments[i];
              return ListTile(
                onTap: () => _showPaymentDetailPopup(p),
                title: Text("${p.amount} TL - ${p.payment_method}"),
                subtitle: Text(_formatDateFromString(p.paid_date)),
                trailing: const Icon(Icons.chevron_right, size: 18),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalDebtPanel(
    List<Map<String, dynamic>> debts,
    int registrationYear,
  ) {
    return const SizedBox.shrink();
  }
}

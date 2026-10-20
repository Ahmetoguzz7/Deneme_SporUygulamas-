import 'dart:async';
import 'dart:math' as math;

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/ExpensesPage.dart';
import 'package:EVOM_SPOR/managerpage/StudentCollectionPage.dart';
import 'package:EVOM_SPOR/managerpage/antremanprogram.dart';
import 'package:EVOM_SPOR/managerpage/daily_payment.dart';
import 'package:EVOM_SPOR/managerpage/payment_history.dart';
import 'package:EVOM_SPOR/managerpage/student_P&A.dart';
import 'package:EVOM_SPOR/managerpage/student_tarihli_attandance.dart';
import 'package:EVOM_SPOR/managerpage/unassigned_assistants.dart';
import 'package:EVOM_SPOR/managerpage/version_tracking.dart';
import 'package:EVOM_SPOR/versionfooter.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/loginpage/login.dart';
import 'package:EVOM_SPOR/managerpage/manager_group.dart';
import 'package:EVOM_SPOR/managerpage/manager_notifications.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_attandance.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_search.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';

import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _T {
  static const canvas = Color(0xFFF6F7F9);
  static const surface = Colors.white;
  static const border = Color(0xFFEBEEF2);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const brand = Color(0xFFF97316);
  static const brand2 = Color(0xFFEF4444);
  static const headerA = Color(0xFF1E293B);
  static const headerB = Color(0xFF0F172A);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const r = 18.0;
  static BoxDecoration panel() => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: border),
  );
}

class AdminDashboard extends StatefulWidget {
  final String currentUserRole;
  final Users? currentUser;
  const AdminDashboard({
    Key? key,
    required this.currentUserRole,
    this.currentUser,
  }) : super(key: key);
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _dashboardData;
  final AppRepository _repo = AppRepository();
  List<Users> _allUsers = [];
  bool _isProcessing = false;
  DateTime _lastUpdated = DateTime.now();
  int _motivationIndex = 0;
  int _todayTab = 0;
  StreamSubscription<bool>? _logSubscription;
  StreamSubscription<bool>? _dataUpdateSub;
  StreamSubscription<String>? _syncErrorSub;
  Timer? _clockTimer;

  Map<String, dynamic>? _lastGoodData;

  static const List<String> _motivationQuotes = [
    "Bugün dünden bir adım öteye.",
    "Disiplin, motivasyonun bittiği yerde başlar.",
    "Zor gelen, seni büyüten şeydir.",
    "Yorgunluk geçicidir, vazgeçmek kalıcıdır.",
    "Bir tekrar daha. Fark orada.",
    "Ter bugün akar, sonuç yarın konuşur.",
    "Hazır hissetmeni bekleme; başla, hazır olursun.",
    "Yavaş git ama durma.",
    "Emek sessizdir; sonuç yüksek sesle konuşur.",
    "Odak, yeteneği yener.",
    "Güç, kaslarda değil; kalkma sayında.",
    "Her büyük sezon, tek bir antrenmanla başladı.",
    "Bahane mi sonuç mu? İkisi aynı anda olmaz.",
    "Şampiyonlar salon boşken çalışır.",
  ];

  @override
  void initState() {
    super.initState();
    _dashboardData = _loadAllDataWithRepo();
    _isProcessing = _repo.isProcessing;
    final doy = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    _motivationIndex = doy % _motivationQuotes.length;

    _logSubscription = _repo.onOperationLogsUpdated.listen((_) {
      if (!mounted) return;
      setState(() => _isProcessing = _repo.isProcessing);
    });

    _dataUpdateSub = _repo.onDataUpdated.listen((_) {
      if (!mounted) return;
      setState(() {
        _lastUpdated = DateTime.now();
        _dashboardData = _loadAllDataWithRepo();
      });
    });

    _syncErrorSub = _repo.onSyncError.listen((errorMsg) {
      if (!mounted) return;
      _showSyncErrorDialog(errorMsg);
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _repo.startAutoSync();
  }

  void _showSyncErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("İşlem Gerçekleştirilemedi", style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          "Yapılan son işlem sunucuya kaydedilemedi.\n\nHata detayı: $errorMsg\n\nLütfen internet bağlantınızı kontrol edip tekrar deneyin.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat", style: TextStyle(color: _T.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _repo.syncNow();
            },
            child: const Text(
              "Tekrar Dene",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _dataUpdateSub?.cancel();
    _syncErrorSub?.cancel();
    _clockTimer?.cancel();
    _repo.stopAutoSync();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadAllDataWithRepo() async {
    try {
      if (!_repo.isLoaded || _repo.allUsers.isEmpty) {
        await _repo.loadAllData();
      }

      _allUsers = _repo.allUsers;
      final students = _allUsers
          .where((u) => u.role.toLowerCase() == "student")
          .toList();
      final totalCoaches = _repo.allCoaches.length;
      final totalStudents = students.length;
      final activeStudents = students.where((u) => _truthy(u.is_active)).length;
      final totalGroups = _repo.allGroups.length;

      // 🛡️ Güvenlik Filtresi: API'den anlık boş/sıfır veri dönerse eski sağlıklı veriyi koru
      if (totalStudents == 0 &&
          totalGroups == 0 &&
          totalCoaches == 0 &&
          _lastGoodData != null) {
        return _lastGoodData!;
      }

      final prefs = await SharedPreferences.getInstance();
      String? resetDateStr = prefs.getString('income_reset_date');
      final now = DateTime.now();
      final currentMonth =
          "${now.year}-${now.month.toString().padLeft(2, '0')}";
      final lastMonthDate = DateTime(now.year, now.month - 1, 1);
      final lastMonth =
          "${lastMonthDate.year}-${lastMonthDate.month.toString().padLeft(2, '0')}";

      double monthlyIncome = 0, lastMonthIncome = 0, totalIncome = 0;
      double currentPeriodIncome = 0;

      for (var p in _repo.allPayments) {
        final status = p.status.toString().toLowerCase().trim();
        if (status == "paid" || status == "true" || status == "1") {
          final amount = double.tryParse(p.amount) ?? 0;
          totalIncome += amount;
          try {
            String dateStr = p.paid_date.isNotEmpty ? p.paid_date : p.due_date;
            if (dateStr.isEmpty) continue;
            if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
            if (dateStr.contains(' ')) dateStr = dateStr.split(' ')[0];
            if (dateStr.split('-').length == 2) dateStr = "$dateStr-01";
            final paymentDate = DateTime.parse(dateStr);
            final paymentMonth =
                "${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}";
            if (paymentMonth == currentMonth) monthlyIncome += amount;
            if (paymentMonth == lastMonth) lastMonthIncome += amount;
          } catch (e) {
            if (p.due_date.startsWith(currentMonth)) monthlyIncome += amount;
          }
        }
      }

      if (resetDateStr == null || resetDateStr.isEmpty) {
        currentPeriodIncome = monthlyIncome;
      } else {
        final resetDate = DateTime.parse(resetDateStr);
        for (var p in _repo.allPayments) {
          final status = p.status.toString().toLowerCase().trim();
          if (status != "paid" && status != "true" && status != "1") continue;
          try {
            String dateStr = p.paid_date.isNotEmpty ? p.paid_date : p.due_date;
            if (dateStr.isEmpty) continue;
            if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
            if (dateStr.contains(' ')) dateStr = dateStr.split(' ')[0];
            if (dateStr.split('-').length == 2) dateStr = "$dateStr-01";
            final paymentDate = DateTime.parse(dateStr);
            if (paymentDate.isAfter(resetDate) ||
                (paymentDate.year == resetDate.year &&
                    paymentDate.month == resetDate.month &&
                    paymentDate.day == resetDate.day)) {
              currentPeriodIncome += double.tryParse(p.amount) ?? 0;
            }
          } catch (e) {
            continue;
          }
        }
      }

      double? incomeTrend;
      if (lastMonthIncome > 0) {
        incomeTrend =
            ((monthlyIncome - lastMonthIncome) / lastMonthIncome) * 100;
      }

      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final recent = _repo.allNotifications.where((n) {
        try {
          final recipient = n.recipient_id.toLowerCase();
          if (recipient != 'all' && recipient != 'tümü') return false;
          final date = DateTime.parse(n.sent_at);
          return date.isAfter(sevenDaysAgo);
        } catch (e) {
          return false;
        }
      }).toList();
      recent.sort((a, b) => b.sent_at.compareTo(a.sent_at));

      final birthdays = <Users>[];
      final newRegistrations = <Users>[];

      for (var user in _allUsers) {
        if (user.role.toLowerCase() == "student") {
          if (user.b_date.isNotEmpty) {
            try {
              final birthDate = DateTime.parse(user.b_date);
              final today = DateTime(now.year, now.month, now.day);
              final thisYearBirthday = DateTime(
                now.year,
                birthDate.month,
                birthDate.day,
              );
              if (thisYearBirthday.isAfter(today) ||
                  thisYearBirthday.isAtSameMomentAs(today)) {
                final daysLeft = thisYearBirthday.difference(today).inDays;
                if (daysLeft <= 7) birthdays.add(user);
              }
            } catch (_) {}
          }

          if (user.created_at.isNotEmpty) {
            try {
              final regDate = DateTime.parse(user.created_at);
              if (regDate.year == now.year && regDate.month == now.month) {
                newRegistrations.add(user);
              }
            } catch (_) {}
          }
        }
      }
      birthdays.sort(
        (a, b) => _getDaysUntilBirthday(
          a.b_date,
        ).compareTo(_getDaysUntilBirthday(b.b_date)),
      );
      newRegistrations.sort((a, b) => b.created_at.compareTo(a.created_at));

      final computedData = {
        'totalStudents': totalStudents,
        'activeStudents': activeStudents,
        'totalCoaches': totalCoaches,
        'totalGroups': totalGroups,
        'monthlyIncome': monthlyIncome,
        'totalIncome': totalIncome,
        'currentPeriodIncome': currentPeriodIncome,
        'incomeTrend': incomeTrend,
        'resetDate': resetDateStr,
        'recentNotifications': recent,
        'upcomingBirthdays': birthdays,
        'newRegistrations': newRegistrations,
      };

      _lastGoodData = computedData;
      return computedData;
    } catch (e, stackTrace) {
      debugPrint("Veri yükleme hatası: $e\n$stackTrace");
      if (_lastGoodData != null) return _lastGoodData!;

      return {
        'totalStudents': 0,
        'activeStudents': 0,
        'totalCoaches': 0,
        'totalGroups': 0,
        'monthlyIncome': 0.0,
        'totalIncome': 0.0,
        'currentPeriodIncome': 0.0,
        'incomeTrend': null,
        'resetDate': null,
        'recentNotifications': <Notifications>[],
        'upcomingBirthdays': <Users>[],
        'newRegistrations': <Users>[],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              _repo.allUsers.isEmpty) {
            return _buildSportLoadingScreen();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return _buildErrorScreen(snapshot.error);
          }

          final data = snapshot.data ?? {};
          final totalStudents = data['totalStudents'] ?? 0;
          final activeStudents = data['activeStudents'] ?? 0;
          final totalCoaches = data['totalCoaches'] ?? 0;
          final totalGroups = data['totalGroups'] ?? 0;
          final monthlyIncome = (data['monthlyIncome'] ?? 0.0) as double;
          final incomeTrend = data['incomeTrend'] as double?;
          final recentNotifications =
              (data['recentNotifications'] ?? <Notifications>[])
                  as List<Notifications>;
          final upcomingBirthdays =
              (data['upcomingBirthdays'] ?? <Users>[]) as List<Users>;
          final newRegistrations =
              (data['newRegistrations'] ?? <Users>[]) as List<Users>;

          return RefreshIndicator(
            color: _T.brand,
            onRefresh: () async {
              await _repo.refreshAllData();
              if (!mounted) return;
              setState(() {
                _lastUpdated = DateTime.now();
                _dashboardData = _loadAllDataWithRepo();
              });
              await _dashboardData;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(monthlyIncome, incomeTrend),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      children: [
                        _buildMiniStats(
                          activeStudents,
                          totalStudents,
                          totalCoaches,
                          totalGroups,
                        ),
                        const SizedBox(height: 14),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildTodayCard(
                          recentNotifications,
                          upcomingBirthdays,
                          newRegistrations,
                        ),
                        const SizedBox(height: 24),
                        _sectionEyebrow("KEŞFET"),
                        _buildMotivationCard(),
                        const SizedBox(height: 12),
                        _buildMusicStrip(),
                        const SizedBox(height: 12),
                        const SportsNewsCard(),
                        const SizedBox(height: 24),
                        _sectionEyebrow("YÖNETİM"),
                        _buildMenuSections(),
                        const SizedBox(height: 4),
                        _buildSyncBar(),
                        const SizedBox(height: 14),
                        const VersionFooter(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionEyebrow(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _T.muted,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double monthlyIncome, double? trend) {
    final name = (widget.currentUser?.first_name.isNotEmpty ?? false)
        ? widget.currentUser!.first_name
        : "Yönetici";
    final dateStr = DateFormat('d MMMM EEEE', 'tr_TR').format(DateTime.now());
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.headerA, _T.headerB],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Merhaba, $name 👋",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _headerIconButton(Icons.logout_rounded, _handleLogout),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_T.brand, _T.brand2],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Bu ayki gelir",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showTotalIncomeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Detay",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AnimatedMoney(value: monthlyIncome),
                    const SizedBox(width: 10),
                    if (trend != null) _buildTrendChip(trend),
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onLongPress: _showResetIncomeDialog,
                  child: Text(
                    "Sıfırlamak için uzun basın",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChip(double trend) {
    final up = trend >= 0;
    final color = up ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 3),
          Text(
            "%${trend.abs().toStringAsFixed(0)}",
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildMiniStats(
    int activeStudents,
    int totalStudents,
    int coaches,
    int groups,
  ) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            icon: Icons.people_alt_rounded,
            color: _T.info,
            value: activeStudents,
            label: "Aktif Öğrenci",
            sub: totalStudents > 0 ? "/ $totalStudents" : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            icon: Icons.sports_rounded,
            color: _T.brand,
            value: coaches,
            label: "Antrenör",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            icon: Icons.groups_2_rounded,
            color: _T.success,
            value: groups,
            label: "Grup",
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required int value,
    required String label,
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _T.panel(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _AnimatedInt(
                value: value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _T.ink,
                ),
              ),
              if (sub != null)
                Text(
                  " $sub",
                  style: TextStyle(
                    fontSize: 11,
                    color: _T.muted.withOpacity(0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: _T.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.fact_check_rounded, "Yoklama", _T.brand, "attendance"),
      (Icons.point_of_sale_rounded, "Ödeme Al", _T.success, "student_search"),
      (Icons.campaign_rounded, "Duyuru", _T.info, "notification"),
      (
        Icons.notifications_active_rounded,
        "Hatırlat",
        _T.danger,
        "payment_reminder",
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: _T.panel(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _navigateToRoute(a.$4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: a.$3.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(a.$1, color: a.$3, size: 23),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      a.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _T.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMotivationCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          int next = _motivationIndex;
          while (next == _motivationIndex && _motivationQuotes.length > 1) {
            next = math.Random().nextInt(_motivationQuotes.length);
          }
          _motivationIndex = next;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_T.brand, _T.brand2],
          ),
          borderRadius: BorderRadius.circular(_T.r),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "GÜNÜN SÖZÜ",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _motivationQuotes[_motivationIndex],
                      key: ValueKey(_motivationIndex),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.refresh_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(
    List<Notifications> notifications,
    List<Users> birthdays,
    List<Users> newRegistrations,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _T.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _segTab(
                "Duyurular",
                0,
                Icons.campaign_rounded,
                notifications.length,
              ),
              const SizedBox(width: 4),
              _segTab("Doğum G.", 1, Icons.cake_rounded, birthdays.length),
              const SizedBox(width: 4),
              _segTab(
                "Yeni Kayıt",
                2,
                Icons.person_add_alt_1_rounded,
                newRegistrations.length,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 210,
            child: _todayTab == 0
                ? (notifications.isEmpty
                      ? _emptyState(
                          Icons.notifications_off_outlined,
                          "Son 7 günde duyuru yok",
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: notifications
                              .map((n) => _announcementRow(n))
                              .toList(),
                        ))
                : _todayTab == 1
                ? (birthdays.isEmpty
                      ? _emptyState(
                          Icons.cake_outlined,
                          "Yakında doğum günü yok",
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: birthdays
                              .map((s) => _birthdayRow(s))
                              .toList(),
                        ))
                : (newRegistrations.isEmpty
                      ? _emptyState(
                          Icons.person_outline_rounded,
                          "Bu ay yeni kayıt bulunmuyor",
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: newRegistrations
                              .map((s) => _newRegistrationRow(s))
                              .toList(),
                        )),
          ),
        ],
      ),
    );
  }

  Widget _segTab(String label, int index, IconData icon, int count) {
    final active = _todayTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _todayTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? _T.ink.withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? _T.ink : _T.muted.withOpacity(0.8),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? _T.ink : _T.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active ? _T.brand : _T.muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$count",
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _newRegistrationRow(Users student) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentScreen(student: student)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _T.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _T.success,
              child: Text(
                _initial(student.first_name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${student.first_name} ${student.last_name}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: _T.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Kayıt: ${_formatDateStr(student.created_at)}",
                    style: const TextStyle(fontSize: 10.5, color: _T.success),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _T.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "İşlem Yap",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateStr(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _announcementRow(Notifications notif) {
    final urgent = notif.type == "urgent";
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: urgent ? _T.danger : _T.info,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: _T.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  notif.message,
                  style: const TextStyle(fontSize: 11, color: _T.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _T.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Acil",
                style: TextStyle(
                  fontSize: 9,
                  color: _T.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _birthdayRow(Users student) {
    final daysLeft = _getDaysUntilBirthday(student.b_date);
    final soon = daysLeft <= 1;
    final accent = soon ? const Color(0xFFDB2777) : _T.brand;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent,
            child: Text(
              _initial(student.first_name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: _T.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getDayText(daysLeft),
                  style: TextStyle(fontSize: 10.5, color: accent),
                ),
              ],
            ),
          ),
          Icon(Icons.celebration_rounded, size: 18, color: accent),
        ],
      ),
    );
  }

  Widget _buildMusicStrip() {
    const playlists = [
      (
        "Antrenman",
        "Spotify",
        "https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP",
        Color(0xFF1DB954),
      ),
      (
        "Kardiyo",
        "YouTube",
        "https://www.youtube.com/results?search_query=workout+music",
        Color(0xFFEF4444),
      ),
      (
        "Odak",
        "Spotify",
        "https://open.spotify.com/playlist/37i9dQZF1DWZeKCadgRdKQ",
        Color(0xFF2563EB),
      ),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = playlists[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              try {
                await launchUrl(
                  Uri.parse(p.$3),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: _T.panel(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.$4.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: p.$4,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.$1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _T.ink,
                        ),
                      ),
                      Text(
                        p.$2,
                        style: const TextStyle(fontSize: 10, color: _T.muted),
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

  Widget _buildMenuSections() {
    final sections = <String, List<Map<String, dynamic>>>{
      "Öğrenci": [
        _m("Ödeme", Icons.point_of_sale, _T.success, "student_search"),
        _m("Kayıt", Icons.person_add, _T.info, "register"),
        _m("Yoklama", Icons.fact_check, _T.brand, "attendance"),
        _m("Aktif/Pasif", Icons.person_off, Colors.blueGrey, "pasifaktif"),
        _m(
          "Devamsızlık",
          Icons.warning_amber,
          Colors.deepOrange,
          "attendance_detail",
        ),
        _m(
          "Öğrenci Dataları",
          Icons.data_array_rounded,
          Colors.deepOrange,
          "student_data",
        ),
      ],
      "Finans": [
        _m("Tahsilat", Icons.bar_chart, Colors.indigo, "daily_payment"),
        _m(
          "Hatırlat",
          Icons.notifications_active,
          _T.danger,
          "payment_reminder",
        ),
        _m(
          "Giderler",
          Icons.call_missed_outgoing_sharp,
          _T.danger,
          "expense_management",
        ),
      ],
      "Grup & Program": [
        _m("Program", Icons.calendar_month, _T.brand, "training_schedule"),
        _m("Gruplar", Icons.groups, _T.info, "group"),
        _m("Antrenör", Icons.badge, Colors.teal, "antrenor&yardimci"),
      ],
      "Sistem": [
        _m("Duyuru", Icons.campaign, Colors.purple, "notification"),
        _m(
          "Güncelleme",
          Icons.system_update,
          Colors.amber,
          "GüncellemeKontrol",
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _T.ink,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.86,
              children: entry.value.map((menu) => _menuCard(menu)).toList(),
            ),
            const SizedBox(height: 18),
          ],
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _m(
    String title,
    IconData icon,
    Color color,
    String route,
  ) => {"title": title, "icon": icon, "color": color, "route": route};

  Widget _menuCard(Map<String, dynamic> menu) {
    final color = menu["color"] as Color;
    return InkWell(
      onTap: () => _navigateToRoute(menu["route"]),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: _T.panel(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(menu["icon"], size: 23, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              menu["title"],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                color: _T.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBar() {
    final busy = _isProcessing;
    final color = busy ? _T.brand : _T.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(Icons.cloud_done_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            busy
                ? "Senkronize ediliyor…"
                : "Güncel · ${_relativeTime(_lastUpdated)}",
            style: TextStyle(
              fontSize: 11,
              color: _T.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 28, color: _T.muted.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(color: _T.muted.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToRoute(String route) async {
    switch (route) {
      case "student_search":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StudentSearchScreen(currentUser: widget.currentUser),
          ),
        );
        break;
      case "register":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdvancedSignUpPage()),
        );
        break;
      case "antrenor&yardimci":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssistantManagementPage()),
        );
        break;
      case "GüncellemeKontrol":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VersionTrackingScreen()),
        );
        break;
      case "attendance":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TakeAttendanceScreen(
              currentUser:
                  widget.currentUser ??
                  Users(
                    app: "",
                    branches_id: "",
                    first_name: "",
                    last_name: "",
                    email: "",
                    phone: "",
                    password_hash: "",
                    role: "",
                    profile_photo_url: "",
                    amount: "",
                    b_date: "",
                    created_at: "",
                    last_login: "",
                    is_active: "",
                  ),
            ),
          ),
        );
        break;
      case "notification":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NotificationsScreen(currentUser: widget.currentUser),
          ),
        );
        break;
      case "payment_reminder":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentReminderScreen()),
        );
        break;
      case "training_schedule":
        final repo = AppRepository();
        if (!repo.isLoaded) {
          await repo.loadAllData();
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklyTrainingScreen(
              groups: repo.allGroups,
              relations: repo.allGroupStudents,
              students: repo.allUsers,
              coaches: repo.allCoaches,
              onScheduleUpdated: (groupId, newSchedule) async {
                await GoogleSheetService.updateGroupSchedule(
                  groupId,
                  newSchedule,
                );
                await repo.refreshTable('groups', 'groups');
              },
            ),
          ),
        );
        break;
      case "group":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupManagementScreen()),
        );
        break;
      case "attendance_detail":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentAttendanceDetailScreen(),
          ),
        );
        break;
      case "daily_payment":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyPaymentTracker()),
        );
        break;
      case "pasifaktif":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentActivationScreen()),
        );
        break;
      case "expense_management":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpensesPage()),
        );
        break;
      case "student_data":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentCollectionPage()),
        );
        break;
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
      (route) => false,
    );
  }

  void _showTotalIncomeDialog() {
    _dashboardData
        .then((data) {
          if (!mounted) return;
          final monthlyIncome = data['monthlyIncome'] ?? 0.0;
          final currentPeriodIncome = data['currentPeriodIncome'] ?? 0.0;
          final resetDate = data['resetDate'];
          final now = DateTime.now();
          final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(now);
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.history, color: _T.info),
                    SizedBox(width: 8),
                    Text("Gelir Detayı"),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _incomeBox(
                      "$monthName Geliri",
                      "${(monthlyIncome as double).toStringAsFixed(0)}₺",
                      _T.info,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _T.brand.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _T.brand.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            resetDate != null
                                ? "Sıfırlama Sonrası:"
                                : "$monthName:",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "${(currentPeriodIncome as double).toStringAsFixed(0)}₺",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _T.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: _T.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resetDate != null
                                ? "Sıfırlama: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.parse(resetDate))}"
                                : "Henüz sıfırlama yapılmadı",
                            style: const TextStyle(
                              fontSize: 13,
                              color: _T.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Kapat",
                      style: TextStyle(color: _T.muted),
                    ),
                  ),
                ],
              );
            },
          );
        })
        .catchError((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Veri yüklenirken hata: $error"),
              backgroundColor: _T.danger,
            ),
          );
        });
  }

  Widget _incomeBox(
    String label,
    String value,
    Color color, {
    bool big = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetIncomeDialog() {
    final TextEditingController codeController = TextEditingController();
    final String randomSecureCode = (math.Random().nextInt(9000) + 1000)
        .toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _T.danger),
              SizedBox(width: 8),
              Text("Geliri Sıfırla"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Aylık gelir tablosunu bugünden itibaren sıfırlamak istediğinize emin misiniz?\n\nBu işlemden sonra sadece bugünden sonraki ödemeler hesaba katılacaktır.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _T.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Onay Kodu: ",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      randomSecureCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _T.danger,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Yukarıdaki Kodu Girin",
                  hintText: "Doğrulama kodunu yazın",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: _T.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (codeController.text == randomSecureCode) {
                  final prefs = await SharedPreferences.getInstance();
                  final todayStr = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.now());
                  await prefs.setString('income_reset_date', todayStr);
                  if (!mounted) return;
                  Navigator.pop(context);
                  setState(() {
                    _dashboardData = _loadAllDataWithRepo();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Gelir sayacı $todayStr tarihi itibariyle sıfırlandı!",
                      ),
                      backgroundColor: _T.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Hatalı onay kodu girdiniz! Lütfen tekrar deneyin.",
                      ),
                      backgroundColor: _T.danger,
                    ),
                  );
                }
              },
              child: const Text(
                "Onayla ve Sıfırla",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSportLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.headerA, _T.headerB],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_T.brand, _T.brand2],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _T.brand.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_gymnastics_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              "EVOM SPOR",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(strokeWidth: 3, color: _T.brand),
            ),
            const SizedBox(height: 20),
            Text(
              "Veriler hazırlanıyor…",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.headerA, _T.headerB],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 72, color: _T.brand),
              const SizedBox(height: 16),
              const Text(
                "Bağlantı sorunu",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Veriler yüklenemedi. İnternetini kontrol edip tekrar dene.",
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () => setState(() {
                  _dashboardData = _loadAllDataWithRepo();
                }),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  "Tekrar dene",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _truthy(String s) {
    final v = s.toLowerCase().trim();
    return v == "true" || v == "1" || v == "evet" || v == "aktif" || v == "yes";
  }

  String _initial(String name) =>
      name.trim().isEmpty ? "?" : name.trim()[0].toUpperCase();

  int _getDaysUntilBirthday(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final thisYearBirthday = DateTime(
        now.year,
        birthDate.month,
        birthDate.day,
      );
      return thisYearBirthday
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
    } catch (e) {
      return 999;
    }
  }

  String _getDayText(int days) {
    if (days <= 0) return "Bugün! 🎂";
    if (days == 1) return "Yarın 🎉";
    return "$days gün sonra";
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return "az önce";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} sa önce";
    return DateFormat('dd.MM HH:mm').format(t);
  }
}

class _AnimatedInt extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _AnimatedInt({required this.value, required this.style});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(v.round().toString(), style: style),
    );
  }
}

class _AnimatedMoney extends StatelessWidget {
  final double value;
  const _AnimatedMoney({required this.value});
  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        "₺${_fmt(v)}",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _NewsItem {
  final String title;
  final String link;
  _NewsItem(this.title, this.link);
}

class SportsNewsCard extends StatefulWidget {
  const SportsNewsCard({super.key, this.maxItems = 4});
  final int maxItems;
  @override
  State<SportsNewsCard> createState() => _SportsNewsCardState();
}

class _SportsNewsCardState extends State<SportsNewsCard> {
  static const List<String> _feeds = [
    "https://www.hurriyet.com.tr/rss/spor",
    "https://www.sabah.com.tr/rss/spor.xml",
    "https://www.trthaber.com/spor_articles.rss",
    "https://www.aa.com.tr/tr/rss/default?cat=spor",
  ];

  List<_NewsItem> _items = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    for (final feed in _feeds) {
      try {
        final resp = await http
            .get(Uri.parse(feed))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) continue;
        final items = _parseRss(resp.body).take(widget.maxItems).toList();
        if (items.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _items = items;
            _loading = false;
            _error = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = true;
    });
  }

  List<_NewsItem> _parseRss(String xml) {
    final items = <_NewsItem>[];
    final itemRe = RegExp(r'<item[\s\S]*?</item>', caseSensitive: false);
    for (final m in itemRe.allMatches(xml)) {
      final block = m.group(0)!;
      final title = _tag(block, 'title');
      var link = _tag(block, 'link');
      if (link.isEmpty) link = _tag(block, 'guid');
      if (title.isNotEmpty) items.add(_NewsItem(title, link));
    }
    return items;
  }

  String _tag(String block, String tag) {
    final re = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false);
    var v = re.firstMatch(block)?.group(1) ?? '';
    v = v.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim();
    v = v
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"');
    return v;
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _T.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.newspaper_rounded, color: _T.info, size: 17),
              const SizedBox(width: 8),
              const Text(
                "Spor Gündemi",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _T.ink,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _load,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh_rounded, size: 17, color: _T.muted),
                ),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  "Haberler şu an yüklenemedi.",
                  style: TextStyle(
                    color: _T.muted.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ..._items.map(
              (n) => InkWell(
                onTap: () => _open(n.link),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _T.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          n.title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _T.ink,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 13,
                        color: _T.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/*
import 'dart:async';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/ptpage/studetnweeklyprogram.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/parent/parent_student_attandence.dart';
import 'package:EVOM_SPOR/parent/veli_payment_page.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VeliAnaSayfa extends StatefulWidget {
  final Users veli;
  const VeliAnaSayfa({super.key, required this.veli});

  @override
  State<VeliAnaSayfa> createState() => _VeliAnaSayfaState();
}

class _VeliAnaSayfaState extends State<VeliAnaSayfa> {
  bool _isLoading = true;
  List<Users> cocuklar = [];
  int _seciliCocukIndex = 0;

  // 📢 BİLDİRİMLER İÇİN DEĞİŞKENLER
  List<Notifications> _recentNotifications = [];
  int _unreadNotificationCount = 0;
  bool _notificationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVeliData();
  }

  // 🚀 OFFLINE-FIRST VERİ YÜKLEME
  Future<void> _loadVeliData() async {
    final repo = AppRepository();

    if (!repo.isLoaded) {
      await repo.loadAllData();
    }

    if (repo.allParentStudents.isEmpty) {
      try {
        final parentStudents = await GoogleSheetService.getParentStudents();
        repo.allParentStudents = parentStudents;
        print(
          "✅ parent_student verileri API'den çekildi: ${parentStudents.length}",
        );
      } catch (e) {
        print("⚠️ parent_student API hatası: $e");
      }
    }

    _processVeliData();

    unawaited(() async {
      try {
        await repo.refreshAllData();
        if (mounted) {
          setState(() {
            _processVeliData();
            _notificationsLoaded = true;
          });
        }
      } catch (e) {
        print("⚠️ Arka plan yenileme hatası: $e");
      }
    }());
  }

  void _processVeliData() {
    final repo = AppRepository();

    final parentRelations = repo.allParentStudents
        .where((ps) => ps.parent_id == widget.veli.app)
        .toList();

    final studentIds = parentRelations.map((ps) => ps.student_id).toSet();

    cocuklar = repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' && studentIds.contains(u.app),
        )
        .toList();

    print("🔍 Bulunan çocuk sayısı: ${cocuklar.length}");

    if (_seciliCocukIndex >= cocuklar.length) _seciliCocukIndex = 0;

    _isLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await AppRepository().refreshAllData();
    await _loadVeliData();
  }

  void _openNotificationsPage(BuildContext context) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(currentUser: widget.veli),
      ),
    );
  }

  // =========================================================================
  // 🔥 AİDAT VERİLERİNİ ÇEK (DÜZELTİLDİ)
  // =========================================================================

  Future<Map<String, dynamic>> _getPaymentData() async {
    final repo = AppRepository();
    if (!repo.isLoaded) await repo.loadAllData();
    return {
      'payments': repo.allPayments,
      'groups': repo.allGroups,
      'groupStudents': repo.allGroupStudents,
    };
  }

  // =========================================================================
  // 🔥 BİLDİRİM YARDIMCI FONKSİYONLARI
  // =========================================================================

  IconData _getIconForNotif(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet;
      case 'urgent':
        return Icons.priority_high;
      case 'announcement':
        return Icons.emoji_events;
      case 'attendance_alert':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColorForNotif(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatRelativeDateTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 30) {
        return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
      }
      if (diff.inDays > 0) {
        return diff.inDays == 1 ? "Dün" : "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} saat önce";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} dakika önce";
      }
      return "Az önce";
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildNotificationCardForHome(Notifications notif) {
    bool isUrgent = notif.type?.toLowerCase() == "urgent";
    bool isUnread = notif.is_read?.toLowerCase() != "true";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isUrgent
            ? Border.all(color: Colors.red.shade200, width: 1)
            : (isUnread
                  ? Border.all(color: Colors.blue.shade200, width: 1)
                  : null),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red
                  : (isUnread ? Colors.blue : Colors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColorForNotif(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForNotif(notif.type),
              color: _getIconColorForNotif(notif.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 12,
                          color: isUrgent
                              ? Colors.red.shade800
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Acil",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    if (isUnread && !isUrgent)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDateTurkish(notif.sent_at),
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    if (_recentNotifications.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                "Son 7 Günün Duyuruları",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$_unreadNotificationCount",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openNotificationsPage(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Tüm duyuruları gör",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 10,
                  color: Colors.blue.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 BUILD
  // =========================================================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text("Bilgileriniz yükleniyor..."),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: Center(
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
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Bağlı Sporcu Bulunamadı",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              "Lütfen veli hesabınıza bağlı sporcu ekleyin.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 ÇOCUK KARTI
  // =========================================================================

  Widget _buildCocukCard(Users cocuk, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey, Colors.grey],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.orange.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                cocuk.first_name.isNotEmpty
                    ? cocuk.first_name[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${cocuk.first_name} ${cocuk.last_name}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "ID: ${cocuk.app}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.orange, size: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 MENÜ KARTI
  // =========================================================================

  Widget _buildMenuCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 ANA BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (cocuklar.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: Colors.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Çocuk Seçim Kaydırıcısı (Carousel)
              // 🎯 SADECE ÖĞRENCİ SAYISI KADAR KAYDIRMA
              CarouselSlider.builder(
                itemCount: cocuklar.length, // Sadece öğrenci sayısı kadar
                options: CarouselOptions(
                  height: 130,
                  viewportFraction: 0.85,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: false, // 🔥 SÜREKLİ KAYMAYI ENGELLE
                  initialPage: _seciliCocukIndex,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _seciliCocukIndex = index;
                    });
                  },
                ),
                itemBuilder: (context, index, realIndex) {
                  final cocuk = cocuklar[index];
                  return _buildCocukCard(cocuk, index == _seciliCocukIndex);
                },
              ),
              const SizedBox(height: 24),

              // 3. Hızlı Menü Grid Yapısı
              const Text(
                "Hızlı Menü",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildMenuCard(
                    "Yoklama Geçmişi",
                    Icons.fact_check_outlined,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentAttendancePage(
                          student: cocuklar[_seciliCocukIndex],
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    "Aidat / Ödemeler",
                    Icons.credit_card,
                    Colors.orange,
                    () {
                      final seciliCocuk = cocuklar[_seciliCocukIndex];
                      // 🎯 VERİLERİ DOĞRU ŞEKİLDE GÖNDER
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FutureBuilder(
                            future: _getPaymentData(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Scaffold(
                                  body: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Scaffold(
                                  body: Center(
                                    child: Text(
                                      "Veri yüklenemedi",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                              final data = snapshot.data!;
                              return AidatPage(
                                user: seciliCocuk,
                                tumOdemeler: data['payments'] ?? [],
                                tumGruplar: data['groups'] ?? [],
                                tumGroupStudents: data['groupStudents'] ?? [],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    "Haftalık Program",
                    Icons.calendar_view_week,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentWeeklyProgram(
                          student: cocuklar[_seciliCocukIndex],
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    "Duyurular & Mesajlar",
                    Icons.mark_chat_unread_outlined,
                    Colors.redAccent,
                    () => _openNotificationsPage(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Son Duyurular Bölümü
              if (_notificationsLoaded && _recentNotifications.isNotEmpty) ...[
                _buildNotificationsSection(),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
*/

import 'dart:async';

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/ptpage/studetnweeklyprogram.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/parent/parent_student_attandence.dart';
import 'package:EVOM_SPOR/parent/veli_payment_page.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 GLOBAL CACHE SINIFI - VERİLERİ TEK BİR YERDE TUTAR
class VeliCache {
  static final VeliCache _instance = VeliCache._internal();
  factory VeliCache() => _instance;
  VeliCache._internal();

  bool _isLoaded = false;
  List<Users> _cocuklar = [];
  List<Notifications> _recentNotifications = [];
  int _unreadNotificationCount = 0;
  Map<String, Map<String, dynamic>> _studentStats = {};
  DateTime? _lastLoadTime;

  bool get isLoaded => _isLoaded;
  List<Users> get cocuklar => _cocuklar;
  List<Notifications> get recentNotifications => _recentNotifications;
  int get unreadNotificationCount => _unreadNotificationCount;

  // 🔥 Öğrenci istatistiklerini cache'ten al
  Map<String, dynamic> getStudentStats(String studentId) {
    return _studentStats[studentId] ?? {'attended': 0, 'total': 0, 'rate': 0.0};
  }

  // 🔥 Cache'i temizle (çıkış yaparken)
  void clear() {
    _isLoaded = false;
    _cocuklar = [];
    _recentNotifications = [];
    _unreadNotificationCount = 0;
    _studentStats = {};
    _lastLoadTime = null;
  }

  // 🔥 Verileri yükle (sadece ilk kez veya zorunlu yenilemede)
  Future<void> loadData(Users veli, {bool forceRefresh = false}) async {
    // Eğer veriler yüklüyse ve 30 dakikadan az geçmişse tekrar yükleme
    if (_isLoaded && !forceRefresh) {
      final now = DateTime.now();
      if (_lastLoadTime != null &&
          now.difference(_lastLoadTime!).inMinutes < 30) {
        print(
          "✅ Cache'den veriler kullanılıyor (${_lastLoadTime!.difference(now).inMinutes} dakika önce)",
        );
        return;
      }
    }

    print("🔄 Veriler yeniden yükleniyor...");
    final repo = AppRepository();

    if (!repo.isLoaded) {
      await repo.loadAllData();
    }

    if (repo.allParentStudents.isEmpty) {
      try {
        final parentStudents = await GoogleSheetService.getParentStudents();
        repo.allParentStudents = parentStudents;
      } catch (e) {
        print("⚠️ parent_student API hatası: $e");
      }
    }

    // Veliye bağlı öğrencileri bul
    final parentRelations = repo.allParentStudents
        .where((ps) => ps.parent_id == veli.app)
        .toList();

    final studentIds = parentRelations.map((ps) => ps.student_id).toSet();

    _cocuklar = repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' && studentIds.contains(u.app),
        )
        .toList();

    // Her öğrenci için istatistikleri cache'le
    for (var cocuk in _cocuklar) {
      final yoklamalar = repo.getAttendancesByStudentId(cocuk.app);
      int attended = yoklamalar.where((a) => a.status == "TRUE").length;
      int total = yoklamalar.length;
      double rate = total == 0 ? 0 : (attended / total) * 100;
      _studentStats[cocuk.app] = {
        'attended': attended,
        'total': total,
        'rate': rate,
      };
    }

    // Son 7 günün bildirimlerini cache'le
    final myId = veli.app.toString();
    final allNotifs = repo.getNotificationsByRecipient(myId);
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    _recentNotifications =
        allNotifs.where((n) {
            try {
              final date = DateTime.parse(n.sent_at);
              return date.isAfter(sevenDaysAgo);
            } catch (_) {
              return false;
            }
          }).toList()
          ..sort((a, b) => b.sent_at.compareTo(a.sent_at))
          ..take(5).toList(); // En son 5 bildirimi al

    _unreadNotificationCount = allNotifs
        .where((n) => n.is_read.toLowerCase() != "true")
        .length;

    _isLoaded = true;
    _lastLoadTime = DateTime.now();

    print(
      "✅ Cache yüklendi: ${_cocuklar.length} öğrenci, ${_recentNotifications.length} bildirim",
    );
  }

  // 🔥 Cache'deki verileri güncelle (arka planda)
  Future<void> refresh(Users veli) async {
    await loadData(veli, forceRefresh: true);
  }
}

// =========================================================================
// 🔥 VELİ ANA SAYFA - CACHE KULLANAN VERSİYON
// =========================================================================

class VeliAnaSayfa extends StatefulWidget {
  final Users veli;
  const VeliAnaSayfa({super.key, required this.veli});

  @override
  State<VeliAnaSayfa> createState() => _VeliAnaSayfaState();
}

class _VeliAnaSayfaState extends State<VeliAnaSayfa> {
  bool _isLoading = true;
  int _seciliCocukIndex = 0;

  // 🔥 Cache'den okunan veriler
  List<Users> _cocuklar = [];
  List<Notifications> _recentNotifications = [];
  int _unreadNotificationCount = 0;

  final VeliCache _cache = VeliCache();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 🚀 VERİ YÜKLEME (ÖNCE CACHE'E BAK)
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    // Önce cache'ten oku
    await _cache.loadData(widget.veli);

    // Cache'ten verileri al
    _cocuklar = _cache.cocuklar;
    _recentNotifications = _cache.recentNotifications;
    _unreadNotificationCount = _cache.unreadNotificationCount;

    setState(() => _isLoading = false);

    // Arka planda yenile (UI'ı kilitlemeden)
    unawaited(_backgroundRefresh());
  }

  // 🔄 ARKA PLANDA SESSİZ YENİLEME
  Future<void> _backgroundRefresh() async {
    try {
      await _cache.refresh(widget.veli);
      if (mounted) {
        setState(() {
          _cocuklar = _cache.cocuklar;
          _recentNotifications = _cache.recentNotifications;
          _unreadNotificationCount = _cache.unreadNotificationCount;
          if (_seciliCocukIndex >= _cocuklar.length) _seciliCocukIndex = 0;
        });
      }
    } catch (e) {
      print("⚠️ Arka plan yenileme hatası: $e");
    }
  }

  // 🔄 MANUEL YENİLEME (ÇEKME ile)
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _cache.refresh(widget.veli);
    setState(() {
      _cocuklar = _cache.cocuklar;
      _recentNotifications = _cache.recentNotifications;
      _unreadNotificationCount = _cache.unreadNotificationCount;
      if (_seciliCocukIndex >= _cocuklar.length) _seciliCocukIndex = 0;
      _isLoading = false;
    });
  }

  void _openNotificationsPage(BuildContext context) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(currentUser: widget.veli),
      ),
    );
  }

  // =========================================================================
  // 🔥 AİDAT VERİLERİNİ ÇEK (Cache kullanarak)
  // =========================================================================

  Future<Map<String, dynamic>> _getPaymentData() async {
    final repo = AppRepository();
    if (!repo.isLoaded) await repo.loadAllData();
    return {
      'payments': repo.allPayments,
      'groups': repo.allGroups,
      'groupStudents': repo.allGroupStudents,
    };
  }

  // =========================================================================
  // 🔥 BİLDİRİM YARDIMCI FONKSİYONLARI (Cache'den okuyor)
  // =========================================================================

  IconData _getIconForNotif(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet;
      case 'urgent':
        return Icons.priority_high;
      case 'announcement':
        return Icons.emoji_events;
      case 'attendance_alert':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColorForNotif(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatRelativeDateTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 30) {
        return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
      }
      if (diff.inDays > 0) {
        return diff.inDays == 1 ? "Dün" : "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} saat önce";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} dakika önce";
      }
      return "Az önce";
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildNotificationCardForHome(Notifications notif) {
    bool isUrgent = notif.type?.toLowerCase() == "urgent";
    bool isUnread = notif.is_read?.toLowerCase() != "true";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isUrgent
            ? Border.all(color: Colors.red.shade200, width: 1)
            : (isUnread
                  ? Border.all(color: Colors.blue.shade200, width: 1)
                  : null),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red
                  : (isUnread ? Colors.blue : Colors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColorForNotif(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForNotif(notif.type),
              color: _getIconColorForNotif(notif.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 12,
                          color: isUrgent
                              ? Colors.red.shade800
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Acil",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    if (isUnread && !isUrgent)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDateTurkish(notif.sent_at),
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    if (_recentNotifications.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                "Son Bildirimler",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$_unreadNotificationCount",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openNotificationsPage(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Tüm duyuruları gör",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 10,
                  color: Colors.blue.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 BUILD
  // =========================================================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              _cache.clear(); // 🔥 Çıkışta cache'i temizle
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('saved_email');
              await prefs.remove('saved_password');
              await prefs.setBool('remember_me', false);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
                (route) => false,
              );
            },
          ),
        ],

        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text("Bilgileriniz yükleniyor..."),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              _cache.clear();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('saved_email');
              await prefs.remove('saved_password');
              await prefs.setBool('remember_me', false);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
                (route) => false,
              );
            },
          ),
        ],
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
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
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Bağlı Sporcu Bulunamadı",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              "Lütfen veli hesabınıza bağlı sporcu ekleyin.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 ÇOCUK KARTI
  // =========================================================================

  Widget _buildCocukCard(Users cocuk, bool isSelected) {
    // 🔥 Cache'den istatistikleri al
    final stats = _cache.getStudentStats(cocuk.app);

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey, Colors.grey],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.orange.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                cocuk.first_name.isNotEmpty
                    ? cocuk.first_name[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${cocuk.first_name} ${cocuk.last_name}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "%${(stats['rate'] ?? 0).toStringAsFixed(1)}",
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${stats['attended'] ?? 0}/${stats['total'] ?? 0}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.orange, size: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 MENÜ KARTI
  // =========================================================================

  Widget _buildMenuCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 ANA BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_cocuklar.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              _cache.clear();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('saved_email');
              await prefs.remove('saved_password');
              await prefs.setBool('remember_me', false);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
                (route) => false,
              );
            },
          ),
        ],
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: Colors.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Çocuk Seçim Kaydırıcısı (Carousel)
              CarouselSlider.builder(
                itemCount: _cocuklar.length,
                options: CarouselOptions(
                  height: 130,
                  viewportFraction: 0.85,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: false,
                  initialPage: _seciliCocukIndex,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _seciliCocukIndex = index;
                    });
                  },
                ),
                itemBuilder: (context, index, realIndex) {
                  final cocuk = _cocuklar[index];
                  return _buildCocukCard(cocuk, index == _seciliCocukIndex);
                },
              ),
              const SizedBox(height: 24),

              // 3. Hızlı Menü Grid Yapısı
              const Text(
                "Hızlı Menü",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildMenuCard(
                    "Yoklama Geçmişi",
                    Icons.fact_check_outlined,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentAttendancePage(
                          student: _cocuklar[_seciliCocukIndex],
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    "Aidat / Ödemeler",
                    Icons.credit_card,
                    Colors.orange,
                    () {
                      final seciliCocuk = _cocuklar[_seciliCocukIndex];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FutureBuilder(
                            future: _getPaymentData(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Scaffold(
                                  body: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Scaffold(
                                  body: Center(
                                    child: Text(
                                      "Veri yüklenemedi",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                              final data = snapshot.data!;
                              return AidatPage(
                                user: seciliCocuk,
                                tumOdemeler: data['payments'] ?? [],
                                tumGruplar: data['groups'] ?? [],
                                tumGroupStudents: data['groupStudents'] ?? [],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    "Haftalık Program",
                    Icons.calendar_view_week,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentWeeklyProgram(
                          student: _cocuklar[_seciliCocukIndex],
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    "Duyurular & Mesajlar",
                    Icons.mark_chat_unread_outlined,
                    Colors.redAccent,
                    () => _openNotificationsPage(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Son Duyurular Bölümü
              if (_recentNotifications.isNotEmpty) ...[
                _buildNotificationsSection(),
                const SizedBox(height: 20),
              ],
              const VersionFooter(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

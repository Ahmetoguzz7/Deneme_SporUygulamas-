import 'dart:async';

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/ptpage/studetnweeklyprogram.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_info.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserInterface extends StatefulWidget {
  final Users user;

  const UserInterface({super.key, required this.user});

  @override
  State<UserInterface> createState() => _UserInterfaceState();
}

class _UserInterfaceState extends State<UserInterface> {
  final AppRepository _repo = AppRepository();

  bool _isLoading = true;
  String? _error;
  String _loadingMessage = "Veriler hazırlanıyor...";

  bool _isParent = false;
  List<Users> _bagliCocuklar = [];
  Users? _bagliVeli;
  Coach? _currentCoach;
  List<Payment> _allPayments = [];
  List<Group> _allGroups = [];
  List<GroupStudent> _allRelations = [];
  List<Group> _todaysGroups = [];
  String _todayName = "";

  // BİLDİRİMLER İÇİN DEĞİŞKENLER
  List<Notifications> _recentNotifications = [];
  int _unreadNotificationCount = 0;
  bool _notificationsLoaded = false;

  List<ParentStudent> _parentStudents = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromRepository();
  }

  // 🚀 HIZLANDIRILMIŞ: Repository'den direkt veri çek
  Future<void> _loadDataFromRepository() async {
    try {
      // 1. ADIM: Eğer RAM yüklenmemişse, HIZLICA Hive önbellekten yükle
      if (!_repo.isLoaded) {
        setState(() {
          _loadingMessage = "Veriler önbellekten anında hazırlanıyor...";
        });
        await _repo.loadCriticalData();
      }

      // 2. ADIM: EKRANI HİÇ BEKLETMEDEN ELDEKİ VERİLERLE ANINDA ÇİZELİM
      _processLocalRepositoryData();

      // 3. ADIM: İNTERNETTEN GELECEK BÜYÜK VERİYİ ARKA PLANA ATALIM (UI ENGELLENMEZ!)
      unawaited(() async {
        try {
          // İnternete doğrudan giden bu ağır isteği arka planda sessizce yapıyoruz kanka
          final remoteParentStudents =
              await GoogleSheetService.getParentStudents().timeout(
                const Duration(seconds: 10),
              );
          _parentStudents = remoteParentStudents;

          if (mounted) {
            setState(() {
              _processLocalRepositoryData();
            });
          }
        } catch (e) {
          print(
            "⚠️ Arka plan parent-student çekme hatası (Önemli değil, lokal veri kullanılıyor): $e",
          );
        }
      }());
    } catch (e) {
      print("❌ Öğrenci sayfası kritik yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Verileri RAM'den ayıklayıp değişkenlere basan yardımcı fonksiyon kanka
  // Verileri RAM'den ayıklayıp değişkenlere basan yardımcı fonksiyon kanka
  void _processLocalRepositoryData() {
    final isParent =
        widget.user.role.toLowerCase() == 'parent' ||
        widget.user.role.toLowerCase() == 'veli';

    Users? bagliVeli;
    List<Users> bagliCocuklar = [];
    Coach? currentCoach;

    if (isParent) {
      bagliCocuklar = _repo.getChildrenByParentId(
        widget.user.app,
        _parentStudents,
      );
      currentCoach = null;
    } else {
      currentCoach = _repo.getCoachByStudentId(widget.user.app);
      bagliVeli = _repo.getParentByStudentId(widget.user.app, _parentStudents);
    }

    final myGroups = _repo.getGroupsByStudentId(widget.user.app);
    _todayName = _getTodayName();

    // 🔥 DÜZELTİLDİ: Bugünün gruplarını yeni parse fonksiyonuna göre hassas filtreliyoruz kanka
    _todaysGroups = myGroups.where((group) {
      final parsedDays = _parseScheduleDaysAndTimes(group.schedule);
      return parsedDays.any(
        (element) =>
            element['day'].toString().toLowerCase() == _todayName.toLowerCase(),
      );
    }).toList();

    _todaysGroups.sort((a, b) {
      final aTime = _getGroupStartTime(a, _todayName);
      final bTime = _getGroupStartTime(b, _todayName);
      return _timeToMinutes(aTime).compareTo(_timeToMinutes(bTime));
    });

    // Bildirimleri hazırla (Son 7 gün)
    final allFilteredNotifications = _getFilteredNotificationsForStudent();
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final filteredByDate = allFilteredNotifications.where((notif) {
      if (notif.sent_at.isEmpty || notif.sent_at == 'null') return false;
      DateTime? notifDate = DateTime.tryParse(notif.sent_at);
      if (notifDate == null) return false;
      return notifDate.isAfter(sevenDaysAgo);
    }).toList();

    _recentNotifications = filteredByDate.take(3).toList();
    _unreadNotificationCount = filteredByDate
        .where((n) => n.is_read?.toLowerCase() != "true")
        .length;
    _notificationsLoaded = true;

    _isParent = isParent;
    _bagliCocuklar = bagliCocuklar;
    _bagliVeli = bagliVeli;
    _currentCoach = currentCoach;
    _allPayments = _repo.allPayments;
    _allGroups = _repo.allGroups;
    _allRelations = _repo.allGroupStudents;
    _isLoading = false; // ⚡ EKRAN KİLİDİ AÇILDI!
  }

  // FİLTRELENMİŞ BİLDİRİMLER (ÖĞRENCİ İÇİN)
  List<Notifications> _getFilteredNotificationsForStudent() {
    final kullaniciId = widget.user.app.toString().trim().toLowerCase();
    final kullaniciRole = widget.user.role.toLowerCase();

    final myGroups = _repo.getGroupsByStudentId(widget.user.app);
    final myGroupIds = myGroups.map((g) => g.groups_id).toSet();

    final myCoach = _repo.getCoachByStudentId(widget.user.app);
    final myCoachUserId =
        myCoach?.user_id.toString().trim().toLowerCase() ?? '';

    final isStudent = kullaniciRole == 'student' || kullaniciRole == 'öğrenci';

    final filtered = _repo.allNotifications.where((d) {
      final recipientId = d.recipient_id?.toString().trim().toLowerCase() ?? '';
      final senderId = d.sender_id?.toString().trim().toLowerCase() ?? '';
      final groupId = d.groups_id?.toString().trim() ?? '';

      if (senderId == kullaniciId) return false;
      if (recipientId == 'all' || recipientId == 'tümü') return true;
      if (recipientId == kullaniciId) return true;
      if (isStudent && groupId.isNotEmpty && myGroupIds.contains(groupId))
        return true;
      if (isStudent && myCoachUserId.isNotEmpty && senderId == myCoachUserId)
        return true;

      return false;
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.sent_at ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.sent_at ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  // ANA SAYFADA GÖSTERİLECEK BİLDİRİM KARTI (KÜÇÜLTÜLMÜŞ)
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

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _repo.refreshAllData();
    await _loadDataFromRepository();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.user,
          currentCoach: _currentCoach,
        ),
      ),
    );
  }

  // ============================================================
  // 🎨 UI BİLEŞENLERİ
  // ============================================================

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/sports.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              " EVOM SPOR",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Bağlantı Hatası",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? "Bilinmeyen hata",
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _refreshData,
              child: const Text(
                "Tekrar Dene",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, double size, Users user) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade200,
            child: Center(
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultAvatar(user, size),
        ),
      );
    } else {
      return _buildDefaultAvatar(user, size);
    }
  }

  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";

    return Container(
      width: size,
      height: size,
      color: Colors.indigo.shade100,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildParentHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildProfileImage(
                    widget.user.profile_photo_url,
                    90,
                    widget.user,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hoş Geldin,",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${widget.user.first_name} ${widget.user.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            "Veli Hesabı",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatCard(
                    _bagliCocuklar.length,
                    "ÇOCUK",
                    Icons.family_restroom,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 📅 YARDIMCI METODLAR (GELİŞMİŞ PARSE ENTEGRASYONU)
  // ============================================================

  String _getTodayName() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  // 🔥 YENİ: Her iki metoda da can suyu veren ortak parse motoru kanka
  List<Map<String, dynamic>> _parseScheduleDaysAndTimes(String schedule) {
    final List<Map<String, dynamic>> result = [];
    if (schedule.isEmpty) return result;

    const List<String> weekDays = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];

    String normalize(String input) {
      return input
          .trim()
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ç', 'c')
          .replaceAll('ş', 's')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ö', 'o');
    }

    final timeRegex = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
    final blockRegex = RegExp(
      r'([a-zA-ZçÇğĞıİöÖşŞüÜ\s-]+)(?::|,)\s*(\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    final matches = blockRegex.allMatches(schedule);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final daysPart = match.group(1)!;
        final timePart = match.group(2)!;

        final timeMatch = timeRegex.firstMatch(timePart);
        if (timeMatch == null) continue;
        final start = timeMatch.group(1)!;
        final end = timeMatch.group(2)!;

        final rawDays = daysPart.split(RegExp(r'[-.]'));

        for (var rawDay in rawDays) {
          final normalizedRaw = normalize(rawDay);
          if (normalizedRaw.isEmpty) continue;

          for (int i = 0; i < weekDays.length; i++) {
            if (normalize(weekDays[i]) == normalizedRaw) {
              result.add({'day': weekDays[i], 'start': start, 'end': end});
              break;
            }
          }
        }
      }
    } else {
      // Fallback düz tekil kontrol
      for (int i = 0; i < weekDays.length; i++) {
        final pattern = RegExp(
          '${weekDays[i]}:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})',
          caseSensitive: false,
        );
        final match = pattern.firstMatch(schedule);
        if (match != null) {
          result.add({
            'day': weekDays[i],
            'start': match.group(1)!,
            'end': match.group(2)!,
          });
        }
      }
    }
    return result;
  }

  // 🔥 TAM GÜVENLİ HALE GETİRİLMİŞ SAAT GETİRME METODU
  String _getGroupScheduleForDay(Group group, String dayName) {
    final parsed = _parseScheduleDaysAndTimes(group.schedule);

    // Arama yaparken iki tarafı da Türkçe karakterlerden arındırıp küçük harfe çekiyoruz kanka
    String clean(String input) => input
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o');

    final match = parsed.firstWhere(
      (element) => clean(element['day'].toString()) == clean(dayName),
      orElse: () => <String, dynamic>{}, // Güvenli boş map tanımı
    );

    // containsKey kontrolü isNotEmpty'den çok daha güvenlidir
    if (match.containsKey('start') && match['start'] != null) {
      return "${match['start']} - ${match['end']}";
    }
    return "Saat belirtilmemiş";
  }

  // 🔥 TAM GÜVENLİ HALE GETİRİLMİŞ BAŞLANGIÇ SAATİ METODU
  String _getGroupStartTime(Group group, String dayName) {
    final parsed = _parseScheduleDaysAndTimes(group.schedule);

    String clean(String input) => input
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o');

    final match = parsed.firstWhere(
      (element) => clean(element['day'].toString()) == clean(dayName),
      orElse: () => <String, dynamic>{},
    );

    if (match.containsKey('start') && match['start'] != null) {
      return match['start'];
    }
    return "23:59";
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }

  /*
  Widget _buildStudentHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildProfileImage(
                    widget.user.profile_photo_url,
                    90,
                    widget.user,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hoş Geldin,",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${widget.user.first_name} ${widget.user.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            "Öğrenci",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_bagliVeli != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_bagliVeli!.first_name} ${_bagliVeli!.last_name} (Veli)",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  */
  Widget _buildStudentHeader() {
    // 🧠 RAM'den bağlı hoca, branş ve şube bilgilerini salisesinde çekiyoruz kanka
    final myGroups = _repo.getGroupsByStudentId(widget.user.app);

    String coachName = "Atanmamış";
    String branchName = "Belirtilmemiş";
    String sportName = "Belirtilmemiş";

    if (myGroups.isNotEmpty) {
      final mainGroup = myGroups.first;

      // Hoca adı
      final coach = _repo.getCoachById(mainGroup.coach_id);
      final coachUser = coach != null ? _repo.getUserById(coach.user_id) : null;
      if (coachUser != null) {
        coachName = "${coachUser.first_name} ${coachUser.last_name}".trim();
      }

      // Şube/Lokasyon adı
      final branch = _repo.getBranchById(mainGroup.branches_id);
      if (branch != null) branchName = branch.name;

      // Spor Branşı adı
      final sport = _repo.getSportById(mainGroup.sports_id);
      if (sport != null) sportName = sport.name;
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Kısım: Fotoğraf ve İsim Bilgisi
              Row(
                children: [
                  _buildProfileImage(
                    widget.user.profile_photo_url,
                    85,
                    widget.user,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 El sallama emojili Hoş Geldin kısmı yukarıya alındı kanka
                        const Text(
                          "👋 Hoş Geldin,",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "${widget.user.first_name} ${widget.user.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            "Öğrenci Hesabı",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1, thickness: 1),
              const SizedBox(height: 12),

              // 🔥 Bağlı Olduğu Hoca, Branş ve Lokasyon Bilgileri (Yatay Çipler)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildHeaderInfoChip(
                      Icons.person,
                      "Hoca",
                      coachName,
                      Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderInfoChip(
                      Icons.sports_basketball,
                      "Branş",
                      sportName,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderInfoChip(
                      Icons.location_on,
                      "Şube",
                      branchName,
                      Colors.redAccent,
                    ),
                  ],
                ),
              ),

              // Eğer Veli bağlıysa alt tarafta küçük bilgi satırı kalmaya devam eder
              if (_bagliVeli != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        size: 12,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Veli: ${_bagliVeli!.first_name} ${_bagliVeli!.last_name}",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Çiplerin tasarımını pürüzsüz basmak için yardımcı alt widget kanka
  Widget _buildHeaderInfoChip(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(int value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTrainingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
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
          const Row(
            children: [
              Icon(Icons.sports, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                "🏃 Bugünkü Antrenman Programım",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_todaysGroups.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "$_todayName günü antrenman programınız bulunmamaktadır.\nİyi dinlenmeler! 🏋️",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._todaysGroups.map((group) {
              final scheduleToday = _getGroupScheduleForDay(group, _todayName);
              final coach = _repo.getCoachById(group.coach_id);
              final coachName = coach != null
                  ? _repo.getUserById(coach.user_id)?.first_name ?? "Antrenör"
                  : "Antrenör";

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.group,
                        size: 22,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Antrenör: $coachName",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
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
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        scheduleToday,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // BİLDİRİMLER BÖLÜMÜ (FİLTRE BUTONSUZ - SADECE SON 7 GÜN)
  Widget _buildNotificationsSection() {
    if (_recentNotifications.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildMenuGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hızlı İşlemler",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildMenuCard(
              "Ders Yoklama",
              Icons.check_circle_outline,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAttendancePage(student: widget.user),
                ),
              ),
            ),
            _buildMenuCard(
              "Aylık Aidat",
              Icons.payments_outlined,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AidatPage(
                    user: widget.user,
                    tumOdemeler: _allPayments,
                    tumGruplar: _allGroups,
                    tumGroupStudents: _allRelations,
                  ),
                ),
              ),
            ),
            _buildMenuCard(
              "Duyurular",
              Icons.campaign_outlined,
              Colors.blue,
              () => _openNotificationsPage(context),
            ),
            _buildMenuCard(
              "Kişisel Bilgiler",
              Icons.badge_outlined,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KisiselBilgilerPage(user: widget.user),
                ),
              ),
            ),
            _buildMenuCard(
              "Haftalık Program",
              Icons.calendar_month,
              Colors.teal,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentWeeklyProgram(student: widget.user),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? _buildLoadingScreen()
          : _error != null
          ? _buildErrorScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: _isParent ? 220 : 240,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    title: const SizedBox.shrink(),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        onPressed: _logout,
                      ),
                    ],

                    flexibleSpace: FlexibleSpaceBar(
                      background: _isParent
                          ? _buildParentHeader()
                          : _buildStudentHeader(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (!_isParent) _buildTodayTrainingCard(),
                          if (_notificationsLoaded &&
                              _recentNotifications.isNotEmpty)
                            _buildNotificationsSection(),
                          _buildMenuGrid(),
                          const SizedBox(height: 30),
                          const VersionFooter(),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // 📅 YARDIMCI METODLAR
  // ============================================================
}

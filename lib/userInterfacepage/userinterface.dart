/*
import 'dart:async';

import 'package:EVOM_SPOR/userInterfacepage/ptantrenmanprogram.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendance.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
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

Widget _ptEyebrow(String text) => Padding(
  padding: const EdgeInsets.only(left: 4, bottom: 12),
  child: Align(
    alignment: Alignment.centerLeft,
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

class PersonalTrainer extends StatefulWidget {
  final Users users;
  final Sports sport;
  final Coach coachData;
  final bool isAssistant;

  const PersonalTrainer({
    super.key,
    required this.users,
    required this.sport,
    required this.coachData,
    this.isAssistant = false,
  });

  @override
  State<PersonalTrainer> createState() => _PersonalTrainerState();
}

class _PersonalTrainerState extends State<PersonalTrainer> {
  final AppRepository _repo = AppRepository();

  // Veriler için state değişkenleri
  List<Group> _myGroups = [];
  List<Users> _myStudents = [];
  List<Payment> _myPayments = [];
  List<Notifications> _recentNotifications = [];
  int _allNotificationsCount = 0;
  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  String? _error;
  List<Group> _todaysGroups = [];

  // Öğrenci sayıları için cache
  Map<String, int> _studentCountByGroup = {};

  // Bağlı olduğu hocalar
  List<Map<String, dynamic>> _supervisors = [];

  // 🔥 EKLENDİ: Repo'da veri güncellendiğinde ekranı otomatik yenilemek için
  StreamSubscription<bool>? _dataUpdateSub;

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatRelativeDateTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 30) {
        final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
        return formatter.format(date);
      }
      if (diff.inDays > 0) {
        if (diff.inDays == 1) return "Dün";
        return "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} saat önce";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} dakika önce";
      }
      return "Az önce";
    } catch (e) {
      return "Şimdi";
    }
  }

  String _formatDateLongTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadDataFromRepository());

    // 🔥 EKLENDİ: Arka planda (sync/refresh) veri her güncellendiğinde
    // bu sayfa otomatik olarak kendini yeniden çizsin, manuel refresh gerekmesin.
    _dataUpdateSub = _repo.onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromRepository();
      }
    });
  }

  @override
  void dispose() {
    _dataUpdateSub?.cancel();
    super.dispose();
  }

  // 🔥🔥🔥 FİLTRELENMİŞ BİLDİRİMLER (ANTRENÖR İÇİN) 🔥🔥🔥
  // 🔥🔥🔥 FİLTRELENMİŞ BİLDİRİMLER (ANTRENÖR İÇİN) - DÜZELTİLDİ!
  List<Notifications> _getFilteredNotificationsForCoach() {
    final coachUserId = widget.coachData.user_id
        .toString()
        .trim()
        .toLowerCase();
    final coachId = widget.coachData.coach_id.toString().trim().toLowerCase();

    final coachGroups = _repo.getGroupsByCoachId(coachId);
    Set<String> allGroupIds = coachGroups.map((g) => g.groups_id).toSet();

    if (widget.isAssistant) {
      final allCoaches = _repo.allCoaches;
      final assistantCoach = allCoaches.firstWhere(
        (c) => c.coach_id == coachId || c.user_id == widget.coachData.user_id,
        orElse: () => widget.coachData,
      );

      final supervisorRaw = assistantCoach.supervisor_coach_id ?? '';
      if (supervisorRaw.isNotEmpty) {
        final supervisorIds = supervisorRaw
            .split(RegExp(r'[,.]'))
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet(); // Set yaptık hızlı arama için

        // Üst hocaların gruplarını tek seferde topluyoruz, döngü içinde aratmak yok!
        for (var coach in allCoaches) {
          if (supervisorIds.contains(coach.coach_id) ||
              supervisorIds.contains(coach.user_id)) {
            if (coach.coach_id != assistantCoach.user_id &&
                coach.coach_id != assistantCoach.coach_id) {
              final supGroups = _repo.getGroupsByCoachId(coach.coach_id);
              allGroupIds.addAll(supGroups.map((g) => g.groups_id));
            }
          }
        }
      }
    }

    final filtered = _repo.allNotifications.where((d) {
      final recipientId = d.recipient_id?.toString().trim().toLowerCase() ?? '';
      final senderId = d.sender_id?.toString().trim().toLowerCase() ?? '';
      final groupId = d.groups_id?.toString().trim() ?? '';

      if (senderId == coachUserId) return false;
      if (recipientId == 'all' || recipientId == 'tümü') return true;
      if (recipientId == coachUserId || recipientId == coachId) return true;
      if (groupId.isNotEmpty && allGroupIds.contains(groupId)) return true;

      return false;
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.sent_at ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.sent_at ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  Future<void> _loadDataFromRepository() async {
    try {
      // ============================================================
      // 🔥 1. coach_id KONTROLÜ ve BULMA
      // ============================================================

      var coachId = widget.coachData.coach_id.trim();
      print("🔍 coachId: $coachId");

      // EĞER coach_id BOŞSA, user_id ile coaches tablosundan ara
      if (coachId.isEmpty) {
        print("⚠️ coachData.coach_id BOŞ! user_id ile aranıyor...");

        final userId = widget.users.app;
        final allCoaches = _repo.allCoaches;

        // Coaches tablosunda bu user_id'yi ara
        final coach = allCoaches.firstWhere(
          (c) => c.user_id == userId,
          orElse: () => Coach(
            coach_id: '',
            user_id: userId,
            branches_id: '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          ),
        );

        // Eğer coach bulunduysa kullan
        if (coach.coach_id.isNotEmpty) {
          coachId = coach.coach_id;
          print(
            "✅ Coach bulundu: coach_id=$coachId, supervisor=${coach.supervisor_coach_id}",
          );

          // widget.coachData'yı güncelle (ileride kullanmak için)
          // not: widget final olduğu için direkt değiştiremeyiz, ama coachId'yi kullanabiliriz
        } else {
          // Coach bulunamadıysa, kullanıcı yardımcı antrenör olabilir
          print("⚠️ Coach kaydı bulunamadı, yardımcı antrenör olabilir.");

          // Yardımcı antrenör ise özel işlem yap
          if (widget.isAssistant) {
            await _loadAssistantData(userId);
            return; // _loadAssistantData zaten setState yapıyor
          }

          setState(() {
            _error =
                "Antrenör kaydı bulunamadı! Lütfen yöneticinizle iletişime geçin.";
            _isLoading = false;
          });
          return;
        }
      }

      // ============================================================
      // 🔥 2. NORMAL COACH (ANA ANTRENÖR) VERİLERİNİ YÜKLE
      // ============================================================

      print("✅ coachId: $coachId");

      if (!_repo.isLoaded) {
        await _repo.loadCriticalData(
          onProgress: (p) {
            if (mounted && p < 0.95) {
              setState(() {});
            }
          },
        );
      }

      // Grupları al
      List<Group> myGroups = [];

      if (widget.isAssistant) {
        // Yardımcı antrenör ise özel işlem
        await _loadAssistantData(widget.users.app);
        return;
      } else {
        // Normal coach
        myGroups = _repo.getGroupsByCoachId(coachId);
      }

      // Öğrencileri al
      final myStudents = _repo.getStudentsByCoachId(coachId);

      // TÜM FİLTRELENMİŞ BİLDİRİMLER
      final allFilteredNotifications = _getFilteredNotificationsForCoach();

      // SADECE SON 7 GÜN FİLTRESİ
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final filteredByDate = allFilteredNotifications.where((notif) {
        if (notif.sent_at.isEmpty || notif.sent_at == 'null') {
          return false;
        }
        DateTime? notifDate = DateTime.tryParse(notif.sent_at);
        if (notifDate == null) {
          try {
            final parts = notif.sent_at.split('.');
            if (parts.length == 3) {
              notifDate = DateTime(
                int.parse(parts[2].split(' ')[0]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (_) {
            return false;
          }
        }
        if (notifDate == null) return false;
        return notifDate.isAfter(sevenDaysAgo);
      }).toList();

      final unreadCount = filteredByDate
          .where((n) => n.is_read?.toLowerCase() != "true")
          .length;

      final todaysGroups = _repo.getTodaysGroupsForCoach(coachId);

      final Map<String, int> studentCount = {};
      for (var group in myGroups) {
        final studentsInGroup = _repo
            .getGroupStudentsByGroupId(group.groups_id)
            .where((gs) => gs.is_active.toString().toUpperCase() == "TRUE")
            .length;
        studentCount[group.groups_id] = studentsInGroup;
      }

      final studentIds = myStudents.map((s) => s.app).toSet();
      final myPayments = _repo.allPayments
          .where((p) => studentIds.contains(p.student_id))
          .toList();

      if (mounted) {
        setState(() {
          _myGroups = myGroups;
          _myStudents = myStudents;
          _myPayments = myPayments;
          _studentCountByGroup = studentCount;
          _recentNotifications = filteredByDate.take(3).toList();
          _allNotificationsCount = filteredByDate.length;
          _unreadNotificationCount = unreadCount;
          _todaysGroups = todaysGroups;
          _isLoading = false;
        });
      }

      print(
        "✅ PersonalTrainer: ${_myGroups.length} grup, ${_myStudents.length} öğrenci, "
        "${_allNotificationsCount} bildirim (${_unreadNotificationCount} okunmamış)",
      );
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR VERİLERİNİ YÜKLE (ÖZEL METOD)
  // ============================================================

  Future<void> _loadAssistantData(String userId) async {
    print("🔍 _loadAssistantData BAŞLADI - userId: $userId");

    try {
      // Mükerrer loadCriticalData temizlendi, veri zaten yüklenmişti kanka.
      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;
      final allGroupStudents = _repo.allGroupStudents;

      List<Group> myGroups = [];
      final Set<String> groupIds = {};
      _supervisors.clear();

      Coach? myCoach;
      try {
        myCoach = allCoaches.firstWhere((c) => c.user_id == userId);
      } catch (_) {
        try {
          myCoach = allCoaches.firstWhere((c) => c.coach_id == userId);
        } catch (_) {}
      }

      // ⚡ O(1) HIZLANDIRMA MAP'I: 791 kullanıcıyı döngü içinde her seferinde taramamak için Map'e alıyoruz
      final Map<String, Users> userMap = {for (var u in allUsers) u.app: u};

      for (var coach in allCoaches) {
        final supervisor = coach.supervisor_coach_id.toString().trim();

        if (supervisor.isNotEmpty &&
            supervisor != "0" &&
            supervisor != "null") {
          List<String> supervisorIds = [];
          if (supervisor.contains(',')) {
            supervisorIds = supervisor.split(',').map((s) => s.trim()).toList();
          } else if (supervisor.contains('.')) {
            supervisorIds = supervisor.split('.').map((s) => s.trim()).toList();
          } else {
            supervisorIds = [supervisor.trim()];
          }

          bool isMySupervisor = supervisorIds.contains(userId);
          if (myCoach != null && !isMySupervisor) {
            isMySupervisor = supervisorIds.contains(myCoach.coach_id);
          }

          if (isMySupervisor) {
            // ⚡ Hızlı map erişimi (Gecikme 0ms'ye düştü!)
            final supUser = userMap[coach.user_id];
            final coachName = supUser != null
                ? "${supUser.first_name} ${supUser.last_name}"
                : "Hoca #${coach.coach_id}";
            final actualCoachId = coach.coach_id;

            final groups = allGroups
                .where((g) => g.coach_id == actualCoachId)
                .where((g) => g.is_active?.toUpperCase() == "TRUE")
                .toList();

            if (groups.isNotEmpty) {
              final alreadyExists = _supervisors.any(
                (s) => s['coach_id'] == actualCoachId,
              );
              if (!alreadyExists) {
                _supervisors.add({
                  'coach_id': actualCoachId,
                  'name': coachName,
                });
              }
              myGroups.addAll(groups);
            }
          }
        }
      }

      if (myGroups.isEmpty && myCoach != null) {
        final groups = allGroups
            .where((g) => g.coach_id == myCoach?.coach_id)
            .where((g) => g.is_active?.toUpperCase() == "TRUE")
            .toList();

        if (groups.isNotEmpty) {
          myGroups.addAll(groups);
          final myUser = userMap[myCoach.user_id];
          final myName = myUser != null
              ? "${myUser.first_name} ${myUser.last_name}"
              : "Ben";
          _supervisors.add({'coach_id': myCoach.coach_id, 'name': myName});
        }
      }

      for (var group in myGroups) {
        groupIds.add(group.groups_id);
      }

      final studentIds = allGroupStudents
          .where(
            (gs) =>
                groupIds.contains(gs.groups_id) &&
                gs.is_active.toUpperCase() == "TRUE",
          )
          .map((gs) => gs.student_id)
          .toSet();

      final myStudents = allUsers
          .where((u) => studentIds.contains(u.app))
          .toList();
      final todayName = _getTodayName().toLowerCase();

      final todaysGroups = myGroups.where((g) {
        final schedule = g.schedule.toLowerCase().trim();
        return schedule.contains(todayName) &&
            schedule.contains(RegExp(r'\d{1,2}:\d{2}'));
      }).toList();

      final allFilteredNotifications = _getFilteredNotificationsForCoach();
      final silverDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final filteredByDate = allFilteredNotifications.where((notif) {
        if (notif.sent_at.isEmpty || notif.sent_at == 'null') return false;
        DateTime? notifDate = DateTime.tryParse(notif.sent_at);
        if (notifDate == null) return false;
        return notifDate.isAfter(silverDaysAgo);
      }).toList();

      final unreadCount = filteredByDate
          .where((n) => n.is_read?.toLowerCase() != "true")
          .length;

      final Map<String, int> studentCount = {};
      for (var group in myGroups) {
        studentCount[group.groups_id] = allGroupStudents
            .where(
              (gs) =>
                  gs.groups_id == group.groups_id &&
                  gs.is_active.toUpperCase() == "TRUE",
            )
            .length;
      }

      if (mounted) {
        setState(() {
          _myGroups = myGroups;
          _myStudents = myStudents;
          _studentCountByGroup = studentCount;
          _recentNotifications = filteredByDate.take(3).toList();
          _allNotificationsCount = filteredByDate.length;
          _unreadNotificationCount = unreadCount;
          _todaysGroups = todaysGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ _loadAssistantData hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime(2000);
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

  Future<void> _openNotificationsPage(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.users,
          currentCoach: widget.coachData,
          isAssistant: widget.isAssistant,
        ),
      ),
    );
  }

  // 🔥 ANA SAYFADA GÖSTERİLECEK BİLDİRİM KARTI
  Widget _buildNotificationCardForHome(Notifications notif) {
    final isUrgent = notif.type?.toLowerCase() == "urgent";
    final isUnread = notif.is_read?.toLowerCase() != "true";
    final accent = isUrgent ? _T.danger : (isUnread ? _T.info : _T.muted);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isUnread ? _T.info.withOpacity(0.04) : _T.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? _T.info.withOpacity(0.15) : _T.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColor(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _getIcon(notif.type),
              color: _getIconColor(notif.type),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
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
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 12.5,
                          color: isUrgent ? _T.danger : _T.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _T.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          "Acil",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: _T.danger,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: const TextStyle(fontSize: 11, color: _T.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDateTurkish(notif.sent_at),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _T.muted.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: RefreshIndicator(
        color: _T.brand,
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: _T.headerB,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('saved_email');
                    await prefs.remove('saved_password');
                    await prefs.setBool('remember_me', false);
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UnifiedLoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
                collapseMode: CollapseMode.pin,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ptEyebrow("HIZLI İŞLEMLER"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            "Yoklama Al",
                            Icons.fact_check_rounded,
                            widget.isAssistant
                                ? const Color(0xFF0D9488)
                                : _T.success,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GrupListesiSayfasi(
                                  user: widget.users,
                                  coache: widget.coachData,
                                  isAssistant: widget.isAssistant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Duyurular",
                            Icons.campaign_rounded,
                            _T.info,
                            () => _openNotificationsPage(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Haftalık\nProgram",
                            Icons.calendar_month_rounded,
                            _T.brand,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PtWeeklyProgram(
                                  user: widget.users,
                                  coach: widget.coachData,
                                  isAssistant: widget.isAssistant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      _buildLoadingSection()
                    else if (_error != null)
                      _buildErrorSection()
                    else if (_recentNotifications.isNotEmpty) ...[
                      _ptEyebrow("SON DUYURULAR"),
                      _buildNotificationsSection(),
                    ],
                    const SizedBox(height: 20),
                    const VersionFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _T.brand,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Veriler yükleniyor…",
              style: TextStyle(color: _T.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _T.brand, size: 40),
            const SizedBox(height: 10),
            const Text(
              "Veriler yüklenemedi",
              style: TextStyle(
                color: _T.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refreshData,
              style: TextButton.styleFrom(foregroundColor: _T.brand),
              child: const Text("Tekrar dene"),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥🔥🔥 BİLDİRİMLER BÖLÜMÜ
  Widget _buildNotificationsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _T.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 17, color: _T.info),
              const SizedBox(width: 8),
              const Text(
                "Son 7 Günün Duyuruları",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _T.ink,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _T.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$_unreadNotificationCount yeni",
                    style: const TextStyle(
                      fontSize: 10,
                      color: _T.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          if (_allNotificationsCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _openNotificationsPage(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Tüm duyurular (${_allNotificationsCount - 3} daha)",
                      style: const TextStyle(
                        fontSize: 11,
                        color: _T.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: _T.info,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 GÜNCELLENMİŞ HEADER
  Widget _buildHeader() {
    final totalStudents = _myStudents.length;

    // 🔥 Branch bilgisini al
    String branchName = "";
    if (widget.coachData.branches_id.isNotEmpty && !widget.isAssistant) {
      final branch = _repo.getBranchById(widget.coachData.branches_id);
      if (branch != null) {
        branchName = branch.name;
      }
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
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isAssistant
                          ? const LinearGradient(
                              colors: [Colors.teal, Colors.tealAccent],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                            ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.users.profile_photo_url.isNotEmpty
                          ? NetworkImage(widget.users.profile_photo_url)
                          : null,
                      child: widget.users.profile_photo_url.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 "Hoş Geldin" mesajı
                        Text(
                          widget.isAssistant
                              ? "🤝 Hoş Geldin,"
                              : "👋 Hoş Geldin,",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${widget.users.first_name} ${widget.users.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // 🔥 ROL VE BRANCH BİLGİSİ
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Rol bilgisi
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isAssistant
                                    ? Colors.teal.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isAssistant
                                        ? Icons.assistant
                                        : Icons.sports_basketball,
                                    size: 12,
                                    color: widget.isAssistant
                                        ? Colors.teal
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isAssistant
                                        ? "Yardımcı Antrenör"
                                        : "Antrenör",
                                    style: TextStyle(
                                      color: widget.isAssistant
                                          ? Colors.teal
                                          : Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 🔥 Spor adı (normal coach için)
                            if (!widget.isAssistant &&
                                widget.sport.name.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sports,
                                      size: 12,
                                      color: Colors.purple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.sport.name,
                                      style: TextStyle(
                                        color: Colors.purple.shade300,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // 🔥 Branch bilgisi (normal coach için)
                            if (!widget.isAssistant && branchName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      branchName,
                                      style: TextStyle(
                                        color: Colors.blue.shade300,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // 🔥 Yardımcı antrenör için bağlı hocalar
                        if (widget.isAssistant && _supervisors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "Bağlı: ${_supervisors.map((s) => s['name']).join(', ')}",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.teal.shade300,
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
                    totalStudents,
                    "ÖĞRENCİ",
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    _myGroups.length,
                    "GRUP",
                    Icons.group,
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_T.r),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _T.panel(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: _T.ink,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCoachDetails(BuildContext context) {
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
                Icon(Icons.badge, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text(
                  "Antrenör Profili",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(
              Icons.verified,
              "Sertifika",
              widget.coachData.certificate_info,
            ),
            const Divider(),
            _infoRow(
              Icons.payments,
              "Maaş",
              "${widget.coachData.monthly_salary} TL",
            ),
            const Divider(),
            _infoRow(
              Icons.calendar_today,
              "İşe Başlangıç",
              _formatDateLongTurkish(widget.coachData.hired_at),
            ),
            const Divider(),
            if (widget.isAssistant) ...[
              _infoRow(Icons.assistant, "Rol", "Yardımcı Antrenör"),
              const Divider(),
              _infoRow(
                Icons.people,
                "Bağlı Hocalar",
                _supervisors.map((s) => s['name']).join(', ') ?? "Yok",
              ),
              const Divider(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value.isNotEmpty ? value : "Belirtilmemiş")),
        ],
      ),
    );
  }

  // ============================================================
  // 🆕 YARDIMCI METODLAR
  // ============================================================

  String _formatTimeTurkish(String time) {
    return time;
  }

  String _getTotalTrainingTime() {
    int totalMinutes = 0;
    final todayName = _getTodayName();

    for (var group in _todaysGroups) {
      final schedule = _getGroupScheduleForDay(group, todayName);
      final times = schedule.split(' - ');
      if (times.length == 2) {
        final start = _timeToMinutes(times[0]);
        final end = _timeToMinutes(times[1]);
        totalMinutes += (end - start);
      }
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return "$hours saat ${minutes > 0 ? '$minutes dk' : ''}";
    }
    return "$minutes dk";
  }

  String _getTrainingDuration(String schedule) {
    final times = schedule.split(' - ');
    if (times.length == 2) {
      final start = _timeToMinutes(times[0]);
      final end = _timeToMinutes(times[1]);
      final diff = end - start;
      return "$diff dk";
    }
    return "Belirtilmemiş";
  }

  bool _isTrainingSoon(String startTime) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final trainingMinutes = _timeToMinutes(startTime);
    final diff = trainingMinutes - nowMinutes;
    return diff > 0 && diff <= 30;
  }

  String _getTotalStudentsToday() {
    int total = 0;
    for (var group in _todaysGroups) {
      total += _studentCountByGroup[group.groups_id] ?? 0;
    }
    return total.toString();
  }

  void _showGroupDetails(Group group, String scheduleToday) {
    final studentCount = _studentCountByGroup[group.groups_id] ?? 0;
    final startTime = _getGroupStartTime(group, _getTodayName());
    final endTime = scheduleToday.split(' - ').length == 2
        ? scheduleToday.split(' - ')[1]
        : "Belirtilmemiş";

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.group, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.access_time, "Saat", "$startTime - $endTime"),
            const Divider(),
            _buildDetailRow(
              Icons.people,
              "Öğrenci Sayısı",
              "$studentCount öğrenci",
            ),
            const Divider(),
            _buildDetailRow(
              Icons.schedule,
              "Süre",
              _getTrainingDuration(scheduleToday),
            ),
            const Divider(),
            _buildDetailRow(
              Icons.location_on,
              "Lokasyon",
              _repo.getBranchById(group.branches_id)?.name ?? "Belirtilmemiş",
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Kapat"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GrupListesiSayfasi(
                            user: widget.users,
                            coache: widget.coachData,
                            isAssistant: widget.isAssistant,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      "Yoklama Al",
                      style: TextStyle(color: Colors.white),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  String _getTodayName() {
    final days = [
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

  String _getGroupScheduleForDay(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return "${match.group(1)} - ${match.group(2)}";
    }
    return "Saat belirtilmemiş";
  }

  String _getGroupStartTime(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return match.group(1) ?? "00:00";
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

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
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

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
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
}
*/

import 'dart:async';

import 'package:EVOM_SPOR/userInterfacepage/ptantrenmanprogram.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendance.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _T {
  static const canvas = Color(0xFFF0F4F8);
  static const surface = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF6B7280);
  static const brand = Color(0xFFF97316);
  static const brand2 = Color(0xFFEF4444);
  static const headerA = Color(0xFF1E293B);
  static const headerB = Color(0xFF0F172A);
  static const success = Color(0xFF2ECC71);
  static const danger = Color(0xFFE74C3C);
  static const info = Color(0xFF3B82F6);
  static const r = 18.0;
  static BoxDecoration panel() => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: border),
  );
}

Widget _ptEyebrow(String text) => Padding(
  padding: const EdgeInsets.only(left: 4, bottom: 12),
  child: Align(
    alignment: Alignment.centerLeft,
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

class PersonalTrainer extends StatefulWidget {
  final Users users;
  final Sports sport;
  final Coach coachData;
  final bool isAssistant;

  const PersonalTrainer({
    super.key,
    required this.users,
    required this.sport,
    required this.coachData,
    this.isAssistant = false,
  });

  @override
  State<PersonalTrainer> createState() => _PersonalTrainerState();
}

class _PersonalTrainerState extends State<PersonalTrainer> {
  final AppRepository _repo = AppRepository();

  List<Group> _myGroups = [];
  List<Users> _myStudents = [];
  List<Payment> _myPayments = [];
  List<Notifications> _recentNotifications = [];
  int _allNotificationsCount = 0;
  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  String? _error;
  List<Group> _todaysGroups = [];

  Map<String, int> _studentCountByGroup = {};
  List<Map<String, dynamic>> _supervisors = [];

  StreamSubscription<bool>? _dataUpdateSub;

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
        if (diff.inDays == 1) return "Dün";
        return "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) return "${diff.inHours} saat önce";
      if (diff.inMinutes > 0) return "${diff.inMinutes} dakika önce";
      return "Az önce";
    } catch (_) {
      return "Şimdi";
    }
  }

  String _formatDateLongTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  @override
  void initState() {
    super.initState();

    // 🔥 Akıllı Başlangıç: RAM'de veri varsa beklemeden aç, yoksa arka planda çek
    _initSmartData();

    // 🔥 Canlı Senkron: Arka planda veri güncellendiğinde ekranı otomatik yenile
    _dataUpdateSub = _repo.onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromRepository();
      }
    });
  }

  @override
  void dispose() {
    _dataUpdateSub?.cancel();
    super.dispose();
  }

  Future<void> _initSmartData() async {
    if (_repo.allUsers.isEmpty || !_repo.isLoaded) {
      if (mounted) setState(() => _isLoading = true);
      await _repo.loadAllData();
    }
    _loadDataFromRepository();
  }

  List<Notifications> _getFilteredNotificationsForCoach() {
    final coachUserId = widget.coachData.user_id
        .toString()
        .trim()
        .toLowerCase();
    final coachId = widget.coachData.coach_id.toString().trim().toLowerCase();

    final coachGroups = _repo.getGroupsByCoachId(coachId);
    Set<String> allGroupIds = coachGroups.map((g) => g.groups_id).toSet();

    if (widget.isAssistant) {
      final allCoaches = _repo.allCoaches;
      final assistantCoach = allCoaches.firstWhere(
        (c) => c.coach_id == coachId || c.user_id == widget.coachData.user_id,
        orElse: () => widget.coachData,
      );

      final supervisorRaw = assistantCoach.supervisor_coach_id ?? '';
      if (supervisorRaw.isNotEmpty) {
        final supervisorIds = supervisorRaw
            .split(RegExp(r'[,.]'))
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();

        for (var coach in allCoaches) {
          if (supervisorIds.contains(coach.coach_id) ||
              supervisorIds.contains(coach.user_id)) {
            if (coach.coach_id != assistantCoach.user_id &&
                coach.coach_id != assistantCoach.coach_id) {
              final supGroups = _repo.getGroupsByCoachId(coach.coach_id);
              allGroupIds.addAll(supGroups.map((g) => g.groups_id));
            }
          }
        }
      }
    }

    final filtered = _repo.allNotifications.where((d) {
      final recipientId = d.recipient_id?.toString().trim().toLowerCase() ?? '';
      final senderId = d.sender_id?.toString().trim().toLowerCase() ?? '';
      final groupId = d.groups_id?.toString().trim() ?? '';

      if (senderId == coachUserId) return false;
      if (recipientId == 'all' || recipientId == 'tümü') return true;
      if (recipientId == coachUserId || recipientId == coachId) return true;
      if (groupId.isNotEmpty && allGroupIds.contains(groupId)) return true;

      return false;
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.sent_at ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.sent_at ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  Future<void> _loadDataFromRepository() async {
    try {
      var coachId = widget.coachData.coach_id.trim();
      if (coachId.isEmpty) {
        final userId = widget.users.app;
        final allCoaches = _repo.allCoaches;
        final coach = allCoaches.firstWhere(
          (c) => c.user_id == userId,
          orElse: () => Coach(
            coach_id: '',
            user_id: userId,
            branches_id: '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          ),
        );

        if (coach.coach_id.isNotEmpty) {
          coachId = coach.coach_id;
        } else {
          if (widget.isAssistant) {
            await _loadAssistantData(userId);
            return;
          }
          if (mounted) {
            setState(() {
              _error = "Antrenör kaydı bulunamadı!";
              _isLoading = false;
            });
          }
          return;
        }
      }

      List<Group> myGroups = [];
      if (widget.isAssistant) {
        await _loadAssistantData(widget.users.app);
        return;
      } else {
        myGroups = _repo.getGroupsByCoachId(coachId);
      }

      final myStudents = _repo.getStudentsByCoachId(coachId);
      final allFilteredNotifications = _getFilteredNotificationsForCoach();

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final filteredByDate = allFilteredNotifications.where((notif) {
        if (notif.sent_at.isEmpty || notif.sent_at == 'null') return false;
        final notifDate = DateTime.tryParse(notif.sent_at);
        if (notifDate == null) return false;
        return notifDate.isAfter(sevenDaysAgo);
      }).toList();

      final unreadCount = filteredByDate
          .where((n) => n.is_read?.toLowerCase() != "true")
          .length;

      final todaysGroups = _repo.getTodaysGroupsForCoach(coachId);

      final Map<String, int> studentCount = {};
      for (var group in myGroups) {
        final studentsInGroup = _repo
            .getGroupStudentsByGroupId(group.groups_id)
            .where((gs) => gs.is_active.toString().toUpperCase() == "TRUE")
            .length;
        studentCount[group.groups_id] = studentsInGroup;
      }

      final studentIds = myStudents.map((s) => s.app).toSet();
      final myPayments = _repo.allPayments
          .where((p) => studentIds.contains(p.student_id))
          .toList();

      if (mounted) {
        setState(() {
          _myGroups = myGroups;
          _myStudents = myStudents;
          _myPayments = myPayments;
          _studentCountByGroup = studentCount;
          _recentNotifications = filteredByDate.take(3).toList();
          _allNotificationsCount = filteredByDate.length;
          _unreadNotificationCount = unreadCount;
          _todaysGroups = todaysGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAssistantData(String userId) async {
    try {
      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;
      final allGroupStudents = _repo.allGroupStudents;

      List<Group> myGroups = [];
      final Set<String> groupIds = {};
      _supervisors.clear();

      Coach? myCoach;
      try {
        myCoach = allCoaches.firstWhere((c) => c.user_id == userId);
      } catch (_) {
        try {
          myCoach = allCoaches.firstWhere((c) => c.coach_id == userId);
        } catch (_) {}
      }

      final Map<String, Users> userMap = {for (var u in allUsers) u.app: u};

      for (var coach in allCoaches) {
        final supervisor = coach.supervisor_coach_id.toString().trim();
        if (supervisor.isNotEmpty &&
            supervisor != "0" &&
            supervisor != "null") {
          List<String> supervisorIds = supervisor.contains(',')
              ? supervisor.split(',').map((s) => s.trim()).toList()
              : [supervisor.trim()];

          bool isMySupervisor = supervisorIds.contains(userId);
          if (myCoach != null && !isMySupervisor) {
            isMySupervisor = supervisorIds.contains(myCoach.coach_id);
          }

          if (isMySupervisor) {
            final supUser = userMap[coach.user_id];
            final coachName = supUser != null
                ? "${supUser.first_name} ${supUser.last_name}"
                : "Hoca #${coach.coach_id}";
            final actualCoachId = coach.coach_id;

            final groups = allGroups
                .where((g) => g.coach_id == actualCoachId)
                .where((g) => g.is_active?.toUpperCase() == "TRUE")
                .toList();

            if (groups.isNotEmpty) {
              _supervisors.add({'coach_id': actualCoachId, 'name': coachName});
              myGroups.addAll(groups);
            }
          }
        }
      }

      for (var group in myGroups) {
        groupIds.add(group.groups_id);
      }

      final studentIds = allGroupStudents
          .where(
            (gs) =>
                groupIds.contains(gs.groups_id) &&
                gs.is_active.toUpperCase() == "TRUE",
          )
          .map((gs) => gs.student_id)
          .toSet();

      final myStudents = allUsers
          .where((u) => studentIds.contains(u.app))
          .toList();
      final todayName = _getTodayName().toLowerCase();

      final todaysGroups = myGroups.where((g) {
        final schedule = g.schedule.toLowerCase().trim();
        return schedule.contains(todayName) &&
            schedule.contains(RegExp(r'\d{1,2}:\d{2}'));
      }).toList();

      final allFilteredNotifications = _getFilteredNotificationsForCoach();
      final silverDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final filteredByDate = allFilteredNotifications.where((notif) {
        if (notif.sent_at.isEmpty || notif.sent_at == 'null') return false;
        final notifDate = DateTime.tryParse(notif.sent_at);
        if (notifDate == null) return false;
        return notifDate.isAfter(silverDaysAgo);
      }).toList();

      final unreadCount = filteredByDate
          .where((n) => n.is_read?.toLowerCase() != "true")
          .length;

      final Map<String, int> studentCount = {};
      for (var group in myGroups) {
        studentCount[group.groups_id] = allGroupStudents
            .where(
              (gs) =>
                  gs.groups_id == group.groups_id &&
                  gs.is_active.toUpperCase() == "TRUE",
            )
            .length;
      }

      if (mounted) {
        setState(() {
          _myGroups = myGroups;
          _myStudents = myStudents;
          _studentCountByGroup = studentCount;
          _recentNotifications = filteredByDate.take(3).toList();
          _allNotificationsCount = filteredByDate.length;
          _unreadNotificationCount = unreadCount;
          _todaysGroups = todaysGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _repo.loadAllData(forceRefresh: true);
    await _loadDataFromRepository();
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.users,
          currentCoach: widget.coachData,
          isAssistant: widget.isAssistant,
        ),
      ),
    );
  }

  Widget _buildNotificationCardForHome(Notifications notif) {
    final isUrgent = notif.type?.toLowerCase() == "urgent";
    final isUnread = notif.is_read?.toLowerCase() != "true";
    final accent = isUrgent ? _T.danger : (isUnread ? _T.info : _T.muted);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isUnread ? _T.info.withOpacity(0.04) : _T.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? _T.info.withOpacity(0.15) : _T.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColor(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _getIcon(notif.type),
              color: _getIconColor(notif.type),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
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
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 12.5,
                          color: isUrgent ? _T.danger : _T.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _T.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          "Acil",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: _T.danger,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: const TextStyle(fontSize: 11, color: _T.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDateTurkish(notif.sent_at),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _T.muted.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: RefreshIndicator(
        color: _T.brand,
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: _T.headerB,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('saved_email');
                    await prefs.remove('saved_password');
                    await prefs.setBool('remember_me', false);
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UnifiedLoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
                collapseMode: CollapseMode.pin,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ptEyebrow("HIZLI İŞLEMLER"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            "Yoklama Al",
                            Icons.fact_check_rounded,
                            widget.isAssistant
                                ? const Color(0xFF0D9488)
                                : _T.success,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GrupListesiSayfasi(
                                  user: widget.users,
                                  coache: widget.coachData,
                                  isAssistant: widget.isAssistant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Duyurular",
                            Icons.campaign_rounded,
                            _T.info,
                            () => _openNotificationsPage(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Haftalık\nProgram",
                            Icons.calendar_month_rounded,
                            _T.brand,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PtWeeklyProgram(
                                  user: widget.users,
                                  coach: widget.coachData,
                                  isAssistant: widget.isAssistant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      _buildLoadingSection()
                    else if (_error != null)
                      _buildErrorSection()
                    else if (_recentNotifications.isNotEmpty) ...[
                      _ptEyebrow("SON DUYURULAR"),
                      _buildNotificationsSection(),
                    ],
                    const SizedBox(height: 20),
                    const VersionFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _T.brand,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Veriler yükleniyor…",
              style: TextStyle(color: _T.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _T.brand, size: 40),
            const SizedBox(height: 10),
            const Text(
              "Veriler yüklenemedi",
              style: TextStyle(
                color: _T.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refreshData,
              style: TextButton.styleFrom(foregroundColor: _T.brand),
              child: const Text("Tekrar dene"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _T.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 17, color: _T.info),
              const SizedBox(width: 8),
              const Text(
                "Son 7 Günün Duyuruları",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _T.ink,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _T.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$_unreadNotificationCount yeni",
                    style: const TextStyle(
                      fontSize: 10,
                      color: _T.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          if (_allNotificationsCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _openNotificationsPage(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Tüm duyurular (${_allNotificationsCount - 3} daha)",
                      style: const TextStyle(
                        fontSize: 11,
                        color: _T.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: _T.info,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalStudents = _myStudents.length;
    String branchName = "";
    if (widget.coachData.branches_id.isNotEmpty && !widget.isAssistant) {
      final branch = _repo.getBranchById(widget.coachData.branches_id);
      if (branch != null) branchName = branch.name;
    }

    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isAssistant
                          ? const LinearGradient(
                              colors: [Colors.teal, Colors.tealAccent],
                            )
                          : const LinearGradient(colors: [_T.brand, _T.brand2]),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.users.profile_photo_url.isNotEmpty
                          ? NetworkImage(widget.users.profile_photo_url)
                          : null,
                      child: widget.users.profile_photo_url.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 28,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isAssistant
                              ? "🤝 Yardımcı Antrenör"
                              : "👋 Antrenör",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.users.first_name} ${widget.users.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (!widget.isAssistant &&
                                widget.sport.name.isNotEmpty)
                              _headerChip(
                                widget.sport.name,
                                Icons.sports_rounded,
                              ),
                            if (!widget.isAssistant && branchName.isNotEmpty)
                              _headerChip(
                                branchName,
                                Icons.location_on_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      icon: Icons.people_alt_rounded,
                      color: _T.info,
                      value: totalStudents,
                      label: "Öğrenci",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniStat(
                      icon: Icons.groups_2_rounded,
                      color: _T.success,
                      value: _myGroups.length,
                      label: "Grup",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required int value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_T.r),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _T.panel(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: _T.ink,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCoachDetails(BuildContext context) {
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
            const Row(
              children: [
                Icon(Icons.badge_rounded, color: _T.brand, size: 26),
                SizedBox(width: 10),
                Text(
                  "Antrenör Profili",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(
              Icons.verified_rounded,
              "Sertifika",
              widget.coachData.certificate_info,
            ),
            const Divider(height: 20),
            _infoRow(
              Icons.payments_rounded,
              "Maaş",
              "${widget.coachData.monthly_salary} TL",
            ),
            const Divider(height: 20),
            _infoRow(
              Icons.calendar_today_rounded,
              "İşe Başlangıç",
              _formatDateLongTurkish(widget.coachData.hired_at),
            ),
            if (widget.isAssistant && _supervisors.isNotEmpty) ...[
              const Divider(height: 20),
              _infoRow(
                Icons.people_rounded,
                "Bağlı Hocalar",
                _supervisors.map((s) => s['name']).join(', '),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _T.brand),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: _T.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : "Belirtilmemiş",
            style: const TextStyle(fontWeight: FontWeight.w600, color: _T.ink),
          ),
        ),
      ],
    );
  }

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
    return days[DateTime.now().weekday - 1];
  }

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet_rounded;
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'announcement':
        return Icons.emoji_events_rounded;
      case 'attendance_alert':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return _T.brand;
      case 'urgent':
        return _T.danger;
      case 'announcement':
        return _T.success;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return _T.info;
    }
  }
}

/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';

class PtWeeklyProgram extends StatefulWidget {
  final Users user;
  final Coach coach;
  final bool isAssistant;

  const PtWeeklyProgram({
    super.key,
    required this.user,
    required this.coach,
    this.isAssistant = false,
  });

  @override
  State<PtWeeklyProgram> createState() => _PtWeeklyProgramState();
}

class _PtWeeklyProgramState extends State<PtWeeklyProgram> {
  final AppRepository _repo = AppRepository();
  bool _isLoading = true;
  String? _error;
  List<Group> _myGroups = [];
  Map<String, List<Map<String, dynamic>>> _groupedSchedule = {};
  List<Map<String, dynamic>> _supervisors = [];

  // 🔥 Açık olan günleri tut
  Set<String> _expandedDays = {};

  // 🔥 Grup listesi açık mı?
  bool _isGroupListExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;

      // ============================================================
      // 🔥 1. coach_id KONTROLÜ
      // ============================================================

      String coachId = widget.coach.coach_id.trim();
      String userId = widget.coach.user_id.trim();

      print("🔍 coachId: $coachId");
      print("🔍 userId: $userId");

      // Eğer coach_id BOŞSA, user_id ile ara
      Coach actualCoach = widget.coach;
      if (coachId.isEmpty && userId.isNotEmpty) {
        try {
          actualCoach = allCoaches.firstWhere((c) => c.user_id == userId);
          coachId = actualCoach.coach_id;
          print("✅ user_id ile coach bulundu: $coachId");
        } catch (_) {
          print("⚠️ user_id ile coach bulunamadı!");
        }
      }

      // Hala boşsa, supervisor listesinden ara
      if (coachId.isEmpty) {
        for (var coach in allCoaches) {
          if (coach.supervisor_coach_id.isNotEmpty) {
            List<String> supIds = [];
            if (coach.supervisor_coach_id.contains(',')) {
              supIds = coach.supervisor_coach_id
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            } else if (coach.supervisor_coach_id.contains('.')) {
              supIds = coach.supervisor_coach_id
                  .split('.')
                  .map((s) => s.trim())
                  .toList();
            } else {
              supIds = [coach.supervisor_coach_id.trim()];
            }

            if (supIds.contains(userId)) {
              actualCoach = coach;
              coachId = coach.coach_id;
              print("✅ Supervisor listesinden coach bulundu: $coachId");
              break;
            }
          }
        }
      }

      List<Group> allGroupsList = [];

      if (widget.isAssistant) {
        // ============================================================
        // 🔥 2. YARDIMCI ANTRENÖR - SADECE GERÇEK HOCALARI GÖSTER
        // ============================================================

        print("🔍 isAssistant: true");
        print("🔍 actualCoach.coach_id: ${actualCoach.coach_id}");
        print(
          "🔍 actualCoach.supervisor_coach_id: ${actualCoach.supervisor_coach_id}",
        );

        final assistantCoach = actualCoach;

        // 🔥 _supervisors listesini TEMİZLE!
        _supervisors.clear();

        // Önce kendi coach kaydımı bul
        Coach? myCoach;
        try {
          myCoach = allCoaches.firstWhere((c) => c.user_id == userId);
          print(
            "✅ Kendi coach kaydım bulundu: coach_id=${myCoach.coach_id}, supervisor=${myCoach.supervisor_coach_id}",
          );
        } catch (_) {
          print("⚠️ Kendi coach kaydım bulunamadı!");
          myCoach = actualCoach;
        }

        // supervisor_coach_id'deki ID'leri parse et
        final supervisorRaw = assistantCoach.supervisor_coach_id ?? '';
        List<String> supervisorIds = [];

        if (supervisorRaw.isNotEmpty) {
          supervisorIds = supervisorRaw
              .split(RegExp(r'[,.]'))
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList();
        }

        print("🔍 supervisorIds: $supervisorIds");

        // EĞER supervisorIds BOŞSA, tüm coach'ları tara
        if (supervisorIds.isEmpty) {
          print("🔍 supervisorIds BOŞ, tüm coach'lar taranıyor...");
          for (var coach in allCoaches) {
            if (coach.supervisor_coach_id.isNotEmpty) {
              List<String> supIds = [];
              if (coach.supervisor_coach_id.contains(',')) {
                supIds = coach.supervisor_coach_id
                    .split(',')
                    .map((s) => s.trim())
                    .toList();
              } else if (coach.supervisor_coach_id.contains('.')) {
                supIds = coach.supervisor_coach_id
                    .split('.')
                    .map((s) => s.trim())
                    .toList();
              } else {
                supIds = [coach.supervisor_coach_id.trim()];
              }

              if (supIds.contains(assistantCoach.user_id) &&
                  coach.coach_id != myCoach?.coach_id) {
                final supUser = allUsers.firstWhere(
                  (u) => u.app.toString() == coach.user_id,
                  orElse: () => Users(
                    app: '',
                    first_name: 'Hoca',
                    last_name: '#${coach.coach_id}',
                    email: '',
                    phone: '',
                    b_date: '',
                    role: '',
                    profile_photo_url: '',
                    mother_name: '',
                    father_name: '',
                    is_active: '',
                    branches_id: '',
                    password_hash: '',
                    amount: '',
                    created_at: '',
                    last_login: '',
                  ),
                );

                final coachName = "${supUser.first_name} ${supUser.last_name}";

                // Aynı hoca daha önce eklenmiş mi kontrol et
                final alreadyExists = _supervisors.any(
                  (s) => s['coach_id'] == coach.coach_id,
                );

                if (!alreadyExists) {
                  _supervisors.add({
                    'coach_id': coach.coach_id,
                    'name': coachName,
                  });
                }

                final groups = allGroups
                    .where((g) => g.coach_id == coach.coach_id)
                    .where((g) => g.is_active?.toUpperCase() == "TRUE")
                    .toList();

                allGroupsList.addAll(groups);
                print(
                  "📚 Üst hoca ${coach.coach_id} ($coachName): ${groups.length} grup",
                );
              }
            }
          }
        } else {
          // 🔥 supervisorIds DOLU - her birini dene
          for (var supId in supervisorIds) {
            // 🔥 Kendi ID'mi atla
            if (supId == assistantCoach.user_id ||
                supId == assistantCoach.coach_id) {
              print("⏭️ Kendi ID'm atlanıyor: $supId");
              continue;
            }

            // Bu ID ile coach kaydı var mı?
            Coach? supCoach;
            try {
              supCoach = allCoaches.firstWhere(
                (c) => c.coach_id == supId || c.user_id == supId,
              );
            } catch (_) {
              print("⚠️ $supId için coach kaydı bulunamadı!");
              continue;
            }

            if (supCoach != null) {
              final supUser = allUsers.firstWhere(
                (u) => u.app.toString() == supCoach?.user_id,
                orElse: () => Users(
                  app: '',
                  first_name: 'Hoca',
                  last_name: '#${supCoach?.coach_id}',
                  email: '',
                  phone: '',
                  b_date: '',
                  role: '',
                  profile_photo_url: '',
                  mother_name: '',
                  father_name: '',
                  is_active: '',
                  branches_id: '',
                  password_hash: '',
                  amount: '',
                  created_at: '',
                  last_login: '',
                ),
              );

              final coachName = "${supUser.first_name} ${supUser.last_name}";

              // Aynı hoca daha önce eklenmiş mi kontrol et
              final alreadyExists = _supervisors.any(
                (s) => s['coach_id'] == supCoach?.coach_id,
              );

              if (!alreadyExists) {
                _supervisors.add({
                  'coach_id': supCoach.coach_id,
                  'name': coachName,
                });
              }

              final groups = allGroups
                  .where((g) => g.coach_id == supCoach?.coach_id)
                  .where((g) => g.is_active?.toUpperCase() == "TRUE")
                  .toList();

              if (groups.isNotEmpty) {
                allGroupsList.addAll(groups);
                print(
                  "📚 Hoca ${supCoach.coach_id} ($coachName): ${groups.length} grup",
                );
              }
            }
          }
        }

        // Eğer hiç üst hoca bulunamadıysa, kendi gruplarını dene
        if (allGroupsList.isEmpty && myCoach != null) {
          final myGroups = allGroups
              .where((g) => g.coach_id == myCoach?.coach_id)
              .where((g) => g.is_active?.toUpperCase() == "TRUE")
              .toList();

          if (myGroups.isNotEmpty) {
            allGroupsList.addAll(myGroups);
            final myUser = allUsers.firstWhere(
              (u) => u.app.toString() == myCoach?.user_id,
              orElse: () => Users(
                app: '',
                first_name: 'Ben',
                last_name: '',
                email: '',
                phone: '',
                b_date: '',
                role: '',
                profile_photo_url: '',
                mother_name: '',
                father_name: '',
                is_active: '',
                branches_id: '',
                password_hash: '',
                amount: '',
                created_at: '',
                last_login: '',
              ),
            );

            _supervisors.add({
              'coach_id': myCoach.coach_id,
              'name': "${myUser.first_name} ${myUser.last_name}",
            });

            print("📚 Kendi gruplarım: ${myGroups.length} grup");
          }
        }
      } else {
        // ============================================================
        // 🔥 3. NORMAL ANTRENÖR
        // ============================================================
        allGroupsList = _repo.getGroupsByCoachId(coachId);
      }

      _myGroups = allGroupsList;
      print("📊 Toplam grup sayısı: ${_myGroups.length}");

      // ============================================================
      // 🔥 4. PROGRAMI PARSE ET
      // ============================================================

      const days = [
        "Pazartesi",
        "Salı",
        "Çarşamba",
        "Perşembe",
        "Cuma",
        "Cumartesi",
        "Pazar",
      ];

      final Map<String, List<Map<String, dynamic>>> tempSchedule = {};

      for (var group in _myGroups) {
        if (group.schedule.isNotEmpty) {
          final schedules = _parseSchedule(group.schedule);
          for (var schedule in schedules) {
            final dayInt = schedule['day'] as int;
            final dayIndex = dayInt - 1;
            final dayName = days[dayIndex];

            final training = {
              'time': '${schedule['start']} - ${schedule['end']}',
              'groupName': group.name,
              'groupId': group.groups_id,
              'group': group,
            };

            if (!tempSchedule.containsKey(dayName)) {
              tempSchedule[dayName] = [];
            }
            tempSchedule[dayName]!.add(training);
          }
        }
      }

      // Saate göre sırala
      for (var day in tempSchedule.keys) {
        tempSchedule[day]!.sort((a, b) {
          return a['time'].compareTo(b['time']);
        });
      }

      // 🔥 SADECE BUGÜN OLAN GÜNÜ OTOMATİK AÇ
      final todayName = _getTodayName();
      _expandedDays.clear();
      if (tempSchedule.containsKey(todayName) &&
          tempSchedule[todayName]!.isNotEmpty) {
        _expandedDays.add(todayName);
        print("🔥 Bugün ($todayName) otomatik açıldı");
      }

      if (mounted) {
        setState(() {
          _groupedSchedule = tempSchedule;
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

  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    final dayMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };

    if (schedule.isEmpty) return result;
    schedule = schedule.trim();

    final format1Regex = RegExp(
      r'(\w+)\s*:\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    final format1Matches = format1Regex.allMatches(schedule);
    if (format1Matches.isNotEmpty) {
      for (final match in format1Matches) {
        final day = match.group(1)!.toLowerCase().trim();
        final start = match.group(2)!.trim();
        final end = match.group(3)!.trim();
        if (dayMap.containsKey(day)) {
          result.add({'day': dayMap[day], 'start': start, 'end': end});
        }
      }
      return result;
    }

    if (schedule.contains(',')) {
      final parts = schedule.split(',');
      if (parts.length >= 2) {
        final daysPart = parts[0].trim();
        final timePart = parts.sublist(1).join(',').trim();

        final timeMatch = RegExp(
          r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
        ).firstMatch(timePart);

        if (timeMatch != null) {
          final start = timeMatch.group(1)!;
          final end = timeMatch.group(2)!;

          final days = daysPart
              .split('-')
              .map((d) => d.trim().toLowerCase())
              .where((d) => dayMap.containsKey(d))
              .toList();

          for (final day in days) {
            result.add({'day': dayMap[day]!, 'start': start, 'end': end});
          }
        }
      }
    }

    return result;
  }

  String _getWeekRange() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysToSubtract));
    final sunday = monday.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
    return "${formatter.format(monday)} - ${formatter.format(sunday)}";
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
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  Future<void> _refreshData() async {
    await _repo.refreshAllData();
    await _loadData();
  }

  void _navigateToAttendance(Group group) {
    if (group.groups_id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Grup bilgisi bulunamadı"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            YoklamaSayfasi(selectedGroup: group, currentUser: widget.user),
      ),
    );
  }

  // 🔥 Gün kartını aç/kapa
  void _toggleDay(String dayName) {
    setState(() {
      if (_expandedDays.contains(dayName)) {
        _expandedDays.remove(dayName);
      } else {
        _expandedDays.add(dayName);
      }
    });
  }

  void _toggleGroupList() {
    setState(() {
      _isGroupListExpanded = !_isGroupListExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAssistant
                  ? "Bağlı Olduğum Program"
                  : "Haftalık Antrenman Programı",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.isAssistant && _supervisors.isNotEmpty)
              Text(
                "${_supervisors.map((s) => s['name']).join(', ')} hocaya bağlı",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text("Program yükleniyor..."),
                ],
              ),
            )
          : (_error != null
                ? _buildErrorState()
                : (_myGroups.isEmpty ? _buildEmptyState() : _buildContent())),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text("Bir hata oluştu: $_error"),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar Dene"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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
            child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz bir program bulunamadı",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAssistant
                ? "Bağlı olduğunuz hocanın grupları için program oluşturulduğunda burada görünecektir"
                : "Gruplarınız için bir program oluşturulduğunda burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    bool hasAnyTraining = false;
    for (var trainings in _groupedSchedule.values) {
      if (trainings.isNotEmpty) {
        hasAnyTraining = true;
        break;
      }
    }

    if (!hasAnyTraining) {
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
              child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              "Antrenman programı henüz eklenmemiş",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isAssistant
                  ? "Bağlı olduğunuz hocanın grupları için bir program oluşturulduğunda burada görünecektir"
                  : "Gruplarınız için bir program oluşturulduğunda burada görünecektir",
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            const Text(
              "Haftalık Program",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(7, (index) {
              const days = [
                "Pazartesi",
                "Salı",
                "Çarşamba",
                "Perşembe",
                "Cuma",
                "Cumartesi",
                "Pazar",
              ];
              final dayName = days[index];
              final trainings = _groupedSchedule[dayName] ?? [];
              final isToday = dayName == _getTodayName();
              final isExpanded = _expandedDays.contains(dayName);
              return _buildDayCard(dayName, trainings, isToday, isExpanded);
            }),
          ],
        ),
      ),
    );
  }

  // 🔥 HEADER CARD - TIKLANABİLİR GRUP LİSTESİ
  Widget _buildHeaderCard() {
    final groupCount = _myGroups.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: widget.isAssistant
            ? const LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.orange, Colors.orangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAssistant
                          ? "$groupCount Gruba Erişimin Var"
                          : groupCount > 1
                          ? "$groupCount Grubunuz Var"
                          : "1 Grubunuz Var",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWeekRange(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (groupCount > 0) ...[
            const SizedBox(height: 12),
            // 🔥 TIKLANABİLİR GRUP LİSTESİ
            GestureDetector(
              onTap: _toggleGroupList,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGroupListExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isGroupListExpanded
                          ? "Grupları Gizle"
                          : "Grupları Göster (${_myGroups.length})",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 🔥 GRUPLAR (AÇIKSA GÖSTER)
            if (_isGroupListExpanded) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _myGroups.map((group) {
                  return GestureDetector(
                    onTap: () => _navigateToAttendance(group),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group,
                            size: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // 🔥 GÜN KARTI - AÇILIR/KAPANIR
  Widget _buildDayCard(
    String dayName,
    List<Map<String, dynamic>> trainings,
    bool isToday,
    bool isExpanded,
  ) {
    final bool hasTraining = trainings.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? (widget.isAssistant ? Colors.teal : Colors.orange)
              : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? (widget.isAssistant
                      ? Colors.teal.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15))
                : Colors.transparent,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 BAŞLIK - TIKLANABİLİR (Sadece antrenman varsa açılır)
          GestureDetector(
            onTap: () {
              if (hasTraining) {
                _toggleDay(dayName);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToday
                    ? (widget.isAssistant
                          ? Colors.teal.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1))
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday ? Icons.today : Icons.calendar_today,
                    size: 18,
                    color: isToday
                        ? (widget.isAssistant ? Colors.teal : Colors.orange)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? (widget.isAssistant ? Colors.teal : Colors.orange)
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isAssistant ? Colors.teal : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Bugün",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (trainings.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${trainings.length} antrenman",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (hasTraining) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 🔥 İÇERİK - AÇIKSA GÖSTER
          if (isExpanded && hasTraining)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: trainings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final training = entry.value;
                  final isFirst = index == 0;

                  Group group;
                  if (training.containsKey('group') &&
                      training['group'] != null) {
                    group = training['group'] as Group;
                  } else {
                    final groupId = training['groupId'] as String;
                    group = _myGroups.firstWhere(
                      (g) => g.groups_id == groupId,
                      orElse: () => Group(
                        groups_id: '',
                        branches_id: '',
                        coach_id: '',
                        sports_id: '',
                        name: 'Bilinmeyen Grup',
                        schedule: '',
                        capacity: '',
                        monthly_fee: '',
                        is_active: '',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (!isFirst) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                      ],
                      GestureDetector(
                        onTap: () => _navigateToAttendance(group),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (widget.isAssistant
                                        ? Colors.teal
                                        : Colors.orange)
                                    .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (widget.isAssistant
                                          ? Colors.teal
                                          : Colors.orange)
                                      .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      (widget.isAssistant
                                              ? Colors.teal
                                              : Colors.orange)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.sports,
                                    color: widget.isAssistant
                                        ? Colors.teal
                                        : Colors.orange,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      training['groupName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          training['time'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.isAssistant
                                                ? Colors.teal
                                                : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 10,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Yoklama",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            )
          else if (!hasTraining)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "Bu günde antrenman yok",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
*/
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';

class PtWeeklyProgram extends StatefulWidget {
  final Users user;
  final Coach coach;
  final bool isAssistant;

  const PtWeeklyProgram({
    super.key,
    required this.user,
    required this.coach,
    this.isAssistant = false,
  });

  @override
  State<PtWeeklyProgram> createState() => _PtWeeklyProgramState();
}

class _PtWeeklyProgramState extends State<PtWeeklyProgram> {
  final AppRepository _repo = AppRepository();
  bool _isLoading = true;
  String? _error;
  List<Group> _myGroups = [];
  Map<String, List<Map<String, dynamic>>> _groupedSchedule = {};
  List<Map<String, dynamic>> _supervisors = [];

  // 🔥 Açık olan günleri tut
  Set<String> _expandedDays = {};

  // 🔥 Grup listesi açık mı?
  bool _isGroupListExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;
      final allAttendances = _repo.allAttendances;

      // ============================================================
      // 🔥 1. coach_id KONTROLÜ - attendance.dart'daki gibi
      // ============================================================

      var coachId = widget.coach.coach_id.trim();
      final userId = widget.coach.user_id.trim();

      print("🔍 coachId: $coachId");
      print("🔍 userId: $userId");
      print("🔍 isAssistant: ${widget.isAssistant}");

      // Eğer coach_id BOŞSA, user_id ile ara
      if (coachId.isEmpty) {
        print("⚠️ coach_id BOŞ! user_id ile aranıyor...");
        try {
          final foundCoach = allCoaches.firstWhere((c) => c.user_id == userId);
          coachId = foundCoach.coach_id;
          print("✅ user_id ile coach bulundu: $coachId");
        } catch (_) {
          print(
            "⚠️ user_id ile coach bulunamadı, userId'yi coachId olarak kullan...",
          );
          coachId = userId;
        }
      }

      // Hala boşsa, supervisor listesinden ara
      if (coachId.isEmpty) {
        for (var coach in allCoaches) {
          if (coach.supervisor_coach_id.isNotEmpty) {
            List<String> supIds = [];
            if (coach.supervisor_coach_id.contains(',')) {
              supIds = coach.supervisor_coach_id
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            } else if (coach.supervisor_coach_id.contains('.')) {
              supIds = coach.supervisor_coach_id
                  .split('.')
                  .map((s) => s.trim())
                  .toList();
            } else {
              supIds = [coach.supervisor_coach_id.trim()];
            }

            if (supIds.contains(userId)) {
              coachId = coach.coach_id;
              print("✅ Supervisor listesinden coach bulundu: $coachId");
              break;
            }
          }
        }
      }

      // ============================================================
      // 🔥 2. YARDIMCI ANTRENÖR MANTIĞI - attendance.dart ile AYNI
      // ============================================================

      List<Group> allGroupsList = [];

      if (widget.isAssistant) {
        print("🔍 isAssistant: true");

        // Yardımcı antrenörün coach kaydını bul
        Coach assistantCoach;
        try {
          assistantCoach = allCoaches.firstWhere(
            (c) => c.coach_id == coachId || c.user_id == widget.user.app,
          );
        } catch (_) {
          assistantCoach = widget.coach;
        }

        print("🔍 assistantCoach.coach_id: ${assistantCoach.coach_id}");
        print(
          "🔍 assistantCoach.supervisor_coach_id: ${assistantCoach.supervisor_coach_id}",
        );

        // supervisor_coach_id'yi parse et
        final supervisorRaw = assistantCoach.supervisor_coach_id ?? '';
        List<String> supervisorIds = [];

        if (supervisorRaw.isNotEmpty) {
          supervisorIds = supervisorRaw
              .split(RegExp(r'[,.]'))
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList();
        }

        print("🔍 supervisorIds: $supervisorIds");

        // _supervisors listesini TEMİZLE!
        _supervisors.clear();

        Set<String> processedCoachIds = {};

        // ============================================================
        // 🔥 2a. supervisorIds'deki HER BİR ID İÇİN GRUPLARI AL
        // ============================================================

        if (supervisorIds.isNotEmpty) {
          for (var supId in supervisorIds) {
            // Kendi ID'mi atla
            if (supId == assistantCoach.user_id ||
                supId == assistantCoach.coach_id) {
              continue;
            }

            final supervisorCoach = allCoaches.firstWhere(
              (c) => c.coach_id == supId || c.user_id == supId,
              orElse: () => Coach(
                coach_id: supId,
                user_id: '',
                branches_id: '',
                sports_id: '',
                bio: '',
                certificate_info: '',
                monthly_salary: '',
                hired_at: '',
                supervisor_coach_id: '',
              ),
            );

            if (supervisorCoach.coach_id.isNotEmpty) {
              final supervisorUser = allUsers.firstWhere(
                (u) => u.app.toString() == supervisorCoach.user_id,
                orElse: () => Users(
                  app: '',
                  first_name: 'Hoca',
                  last_name: '#$supId',
                  email: '',
                  phone: '',
                  b_date: '',
                  role: '',
                  profile_photo_url: '',
                  mother_name: '',
                  father_name: '',
                  is_active: '',
                  branches_id: '',
                  password_hash: '',
                  amount: '',
                  created_at: '',
                  last_login: '',
                ),
              );

              final coachName =
                  "${supervisorUser.first_name} ${supervisorUser.last_name}";
              final groups = allGroups
                  .where((g) => g.coach_id == supervisorCoach.coach_id)
                  .where((g) => g.is_active?.toUpperCase() == "TRUE")
                  .toList();

              print(
                "📚 Hoca ${supervisorCoach.coach_id}: ${groups.length} grup - $coachName",
              );

              if (groups.isNotEmpty) {
                processedCoachIds.add(supervisorCoach.coach_id);

                // Supervisor listesine ekle
                final alreadyExists = _supervisors.any(
                  (s) => s['coach_id'] == supervisorCoach.coach_id,
                );
                if (!alreadyExists) {
                  _supervisors.add({
                    'coach_id': supervisorCoach.coach_id,
                    'name': coachName,
                  });
                }

                allGroupsList.addAll(groups);
              }
            }
          }
        }

        // ============================================================
        // 🔥 2b. TÜM COACH'LARI TARA (supervisorIds'de olmayanları da bul)
        // ============================================================

        for (var coach in allCoaches) {
          if (processedCoachIds.contains(coach.coach_id)) continue;
          if (coach.coach_id == assistantCoach.coach_id) continue;

          if (coach.supervisor_coach_id.isNotEmpty) {
            List<String> supIds = [];
            if (coach.supervisor_coach_id.contains(',')) {
              supIds = coach.supervisor_coach_id
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            } else if (coach.supervisor_coach_id.contains('.')) {
              supIds = coach.supervisor_coach_id
                  .split('.')
                  .map((s) => s.trim())
                  .toList();
            } else {
              supIds = [coach.supervisor_coach_id.trim()];
            }

            // Bu coach'un supervisor listesinde yardımcının user_id'si var mı?
            if (supIds.contains(assistantCoach.user_id) ||
                supIds.contains(assistantCoach.coach_id)) {
              final supUser = allUsers.firstWhere(
                (u) => u.app.toString() == coach.user_id,
                orElse: () => Users(
                  app: '',
                  first_name: 'Hoca',
                  last_name: '#${coach.coach_id}',
                  email: '',
                  phone: '',
                  b_date: '',
                  role: '',
                  profile_photo_url: '',
                  mother_name: '',
                  father_name: '',
                  is_active: '',
                  branches_id: '',
                  password_hash: '',
                  amount: '',
                  created_at: '',
                  last_login: '',
                ),
              );

              final coachName = "${supUser.first_name} ${supUser.last_name}";
              final groups = allGroups
                  .where((g) => g.coach_id == coach.coach_id)
                  .where((g) => g.is_active?.toUpperCase() == "TRUE")
                  .toList();

              print(
                "📚 Üst hoca ${coach.coach_id}: ${groups.length} grup - $coachName",
              );

              if (groups.isNotEmpty) {
                final alreadyExists = _supervisors.any(
                  (s) => s['coach_id'] == coach.coach_id,
                );
                if (!alreadyExists) {
                  _supervisors.add({
                    'coach_id': coach.coach_id,
                    'name': coachName,
                  });
                }

                allGroupsList.addAll(groups);
              }
            }
          }
        }

        // ============================================================
        // 🔥 2c. EĞER HİÇ HOCA BULUNAMADIYSA, KENDİ GRUPLARINI DENE
        // ============================================================

        if (allGroupsList.isEmpty) {
          print("⚠️ Hiç üst hoca bulunamadı, kendi grupları deneniyor...");
          final myGroups = allGroups
              .where((g) => g.coach_id == coachId)
              .where((g) => g.is_active?.toUpperCase() == "TRUE")
              .toList();

          if (myGroups.isNotEmpty) {
            final myUser = allUsers.firstWhere(
              (u) => u.app.toString() == assistantCoach.user_id,
              orElse: () => widget.user,
            );

            _supervisors.add({
              'coach_id': coachId,
              'name': "${myUser.first_name} ${myUser.last_name}",
            });

            allGroupsList.addAll(myGroups);
            print("📚 Kendi gruplarım: ${myGroups.length} grup");
          }
        }

        // ============================================================
        // 🔥 2d. SON ÇARE: TÜM GRUPLARI GÖSTER
        // ============================================================

        if (allGroupsList.isEmpty) {
          print("⚠️ Son çare: Tüm gruplar gösteriliyor...");
          allGroupsList = allGroups
              .where((g) => g.is_active?.toUpperCase() == "TRUE")
              .toList();

          _supervisors.add({'coach_id': 'all', 'name': 'Tüm Gruplar'});
        }

        print("📊 Toplam grup sayısı: ${allGroupsList.length}");
        if (_supervisors.isNotEmpty) {
          print(
            "👨‍🏫 Bağlı hocalar: ${_supervisors.map((s) => s['name']).join(', ')}",
          );
        }
      } else {
        // ============================================================
        // 🔥 3. NORMAL ANTRENÖR
        // ============================================================
        allGroupsList = _repo.getGroupsByCoachId(coachId);

        if (allGroupsList.isNotEmpty) {
          final coachUser = allUsers.firstWhere(
            (u) => u.app.toString() == widget.coach.user_id,
            orElse: () => widget.user,
          );
          _supervisors.add({
            'coach_id': coachId,
            'name': "${coachUser.first_name} ${coachUser.last_name}",
          });
        }
      }

      _myGroups = allGroupsList;
      print("📊 Toplam grup sayısı: ${_myGroups.length}");

      // ============================================================
      // 🔥 4. PROGRAMI PARSE ET
      // ============================================================

      const days = [
        "Pazartesi",
        "Salı",
        "Çarşamba",
        "Perşembe",
        "Cuma",
        "Cumartesi",
        "Pazar",
      ];

      final Map<String, List<Map<String, dynamic>>> tempSchedule = {};

      for (var group in _myGroups) {
        if (group.schedule.isNotEmpty) {
          final schedules = _parseSchedule(group.schedule);
          for (var schedule in schedules) {
            final dayInt = schedule['day'] as int;
            final dayIndex = dayInt - 1;
            final dayName = days[dayIndex];

            final training = {
              'time': '${schedule['start']} - ${schedule['end']}',
              'groupName': group.name,
              'groupId': group.groups_id,
              'group': group,
            };

            if (!tempSchedule.containsKey(dayName)) {
              tempSchedule[dayName] = [];
            }
            tempSchedule[dayName]!.add(training);
          }
        }
      }

      // Saate göre sırala
      for (var day in tempSchedule.keys) {
        tempSchedule[day]!.sort((a, b) {
          return a['time'].compareTo(b['time']);
        });
      }

      // ============================================================
      // 🔥 5. BUGÜNÜN YOKLAMALARINI KONTROL ET
      // ============================================================

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayAttendances = allAttendances
          .where((a) => a.attendance_date == todayStr)
          .toList();

      final Set<String> attendedGroupIds = {};
      for (var att in todayAttendances) {
        attendedGroupIds.add(att.groups_id);
      }

      for (var day in tempSchedule.keys) {
        for (var training in tempSchedule[day]!) {
          final groupId = training['groupId'] as String;
          training['hasAttendance'] = attendedGroupIds.contains(groupId);
        }
      }

      // 🔥 SADECE BUGÜN OLAN GÜNÜ OTOMATİK AÇ
      final todayName = _getTodayName();
      _expandedDays.clear();
      if (tempSchedule.containsKey(todayName) &&
          tempSchedule[todayName]!.isNotEmpty) {
        _expandedDays.add(todayName);
        print("🔥 Bugün ($todayName) otomatik açıldı");
      }

      if (mounted) {
        setState(() {
          _groupedSchedule = tempSchedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Program yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    final dayMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };

    if (schedule.isEmpty) return result;
    schedule = schedule.trim();

    final format1Regex = RegExp(
      r'(\w+)\s*:\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    final format1Matches = format1Regex.allMatches(schedule);
    if (format1Matches.isNotEmpty) {
      for (final match in format1Matches) {
        final day = match.group(1)!.toLowerCase().trim();
        final start = match.group(2)!.trim();
        final end = match.group(3)!.trim();
        if (dayMap.containsKey(day)) {
          result.add({'day': dayMap[day], 'start': start, 'end': end});
        }
      }
      return result;
    }

    if (schedule.contains(',')) {
      final parts = schedule.split(',');
      if (parts.length >= 2) {
        final daysPart = parts[0].trim();
        final timePart = parts.sublist(1).join(',').trim();

        final timeMatch = RegExp(
          r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
        ).firstMatch(timePart);

        if (timeMatch != null) {
          final start = timeMatch.group(1)!;
          final end = timeMatch.group(2)!;

          final days = daysPart
              .split('-')
              .map((d) => d.trim().toLowerCase())
              .where((d) => dayMap.containsKey(d))
              .toList();

          for (final day in days) {
            result.add({'day': dayMap[day]!, 'start': start, 'end': end});
          }
        }
      }
    }

    return result;
  }

  String _getWeekRange() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysToSubtract));
    final sunday = monday.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
    return "${formatter.format(monday)} - ${formatter.format(sunday)}";
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
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  Future<void> _refreshData() async {
    await _repo.refreshAllData();
    await _loadData();
  }

  void _navigateToAttendance(Group group) {
    if (group.groups_id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Grup bilgisi bulunamadı"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            YoklamaSayfasi(selectedGroup: group, currentUser: widget.user),
      ),
    );
  }

  // 🔥 Gün kartını aç/kapa
  void _toggleDay(String dayName) {
    setState(() {
      if (_expandedDays.contains(dayName)) {
        _expandedDays.remove(dayName);
      } else {
        _expandedDays.add(dayName);
      }
    });
  }

  void _toggleGroupList() {
    setState(() {
      _isGroupListExpanded = !_isGroupListExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAssistant
                  ? "Bağlı Olduğum Program"
                  : "Haftalık Antrenman Programı",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.isAssistant && _supervisors.isNotEmpty)
              Text(
                "${_supervisors.map((s) => s['name']).join(', ')} hocaya bağlı",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),

        centerTitle: false,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text("Program yükleniyor..."),
                ],
              ),
            )
          : (_error != null
                ? _buildErrorState()
                : (_myGroups.isEmpty ? _buildEmptyState() : _buildContent())),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text("Bir hata oluştu: $_error"),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar Dene"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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
            child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz bir program bulunamadı",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAssistant
                ? "Bağlı olduğunuz hocanın grupları için program oluşturulduğunda burada görünecektir"
                : "Gruplarınız için bir program oluşturulduğunda burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    bool hasAnyTraining = false;
    for (var trainings in _groupedSchedule.values) {
      if (trainings.isNotEmpty) {
        hasAnyTraining = true;
        break;
      }
    }

    if (!hasAnyTraining) {
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
              child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              "Antrenman programı henüz eklenmemiş",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isAssistant
                  ? "Bağlı olduğunuz hocanın grupları için bir program oluşturulduğunda burada görünecektir"
                  : "Gruplarınız için bir program oluşturulduğunda burada görünecektir",
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            const Text(
              "Haftalık Program",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(7, (index) {
              const days = [
                "Pazartesi",
                "Salı",
                "Çarşamba",
                "Perşembe",
                "Cuma",
                "Cumartesi",
                "Pazar",
              ];
              final dayName = days[index];
              final trainings = _groupedSchedule[dayName] ?? [];
              final isToday = dayName == _getTodayName();
              final isExpanded = _expandedDays.contains(dayName);
              return _buildDayCard(dayName, trainings, isToday, isExpanded);
            }),
            const VersionFooter(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // 🔥 HEADER CARD - TIKLANABİLİR GRUP LİSTESİ
  Widget _buildHeaderCard() {
    final groupCount = _myGroups.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: widget.isAssistant
            ? const LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.orange, Colors.orangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAssistant
                          ? "$groupCount Gruba Erişimin Var"
                          : groupCount > 1
                          ? "$groupCount Grubunuz Var"
                          : "1 Grubunuz Var",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWeekRange(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (groupCount > 0) ...[
            const SizedBox(height: 12),
            // 🔥 TIKLANABİLİR GRUP LİSTESİ
            GestureDetector(
              onTap: _toggleGroupList,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGroupListExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isGroupListExpanded
                          ? "Grupları Gizle"
                          : "Grupları Göster (${_myGroups.length})",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 🔥 GRUPLAR (AÇIKSA GÖSTER)
            if (_isGroupListExpanded) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _myGroups.map((group) {
                  return GestureDetector(
                    onTap: () => _navigateToAttendance(group),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group,
                            size: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // 🔥 GÜN KARTI - AÇILIR/KAPANIR
  Widget _buildDayCard(
    String dayName,
    List<Map<String, dynamic>> trainings,
    bool isToday,
    bool isExpanded,
  ) {
    final bool hasTraining = trainings.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? (widget.isAssistant ? Colors.teal : Colors.orange)
              : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? (widget.isAssistant
                      ? Colors.teal.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15))
                : Colors.transparent,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 BAŞLIK - TIKLANABİLİR (Sadece antrenman varsa açılır)
          GestureDetector(
            onTap: () {
              if (hasTraining) {
                _toggleDay(dayName);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToday
                    ? (widget.isAssistant
                          ? Colors.teal.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1))
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday ? Icons.today : Icons.calendar_today,
                    size: 18,
                    color: isToday
                        ? (widget.isAssistant ? Colors.teal : Colors.orange)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? (widget.isAssistant ? Colors.teal : Colors.orange)
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isAssistant ? Colors.teal : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Bugün",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (trainings.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${trainings.length} antrenman",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (hasTraining) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 🔥 İÇERİK - AÇIKSA GÖSTER
          if (isExpanded && hasTraining)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: trainings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final training = entry.value;
                  final isFirst = index == 0;
                  final bool hasAttendance = training['hasAttendance'] ?? false;

                  Group group;
                  if (training.containsKey('group') &&
                      training['group'] != null) {
                    group = training['group'] as Group;
                  } else {
                    final groupId = training['groupId'] as String;
                    group = _myGroups.firstWhere(
                      (g) => g.groups_id == groupId,
                      orElse: () => Group(
                        groups_id: '',
                        branches_id: '',
                        coach_id: '',
                        sports_id: '',
                        name: 'Bilinmeyen Grup',
                        schedule: '',
                        capacity: '',
                        monthly_fee: '',
                        is_active: '',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (!isFirst) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                      ],
                      GestureDetector(
                        onTap: () => _navigateToAttendance(group),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (widget.isAssistant
                                        ? Colors.teal
                                        : Colors.orange)
                                    .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (widget.isAssistant
                                          ? Colors.teal
                                          : Colors.orange)
                                      .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      (widget.isAssistant
                                              ? Colors.teal
                                              : Colors.orange)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.sports,
                                    color: widget.isAssistant
                                        ? Colors.teal
                                        : Colors.orange,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      training['groupName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          training['time'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.isAssistant
                                                ? Colors.teal
                                                : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 10,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // 🔥🔥🔥 YOKLAMA DURUMU (YENİ!)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: hasAttendance
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasAttendance
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasAttendance
                                          ? Icons.check_circle
                                          : Icons.pending,
                                      size: 12,
                                      color: hasAttendance
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasAttendance
                                          ? "✅ Yoklama\nAlındı"
                                          : "❌ Yoklama\nAlınmadı",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: hasAttendance
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

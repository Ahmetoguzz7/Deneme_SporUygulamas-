/*
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class GrupListesiSayfasi extends StatefulWidget {
  final Coach coache;
  final Users user;
  final bool isAssistant;

  const GrupListesiSayfasi({
    super.key,
    required this.coache,
    required this.user,
    this.isAssistant = false,
  });

  @override
  State<GrupListesiSayfasi> createState() => _GrupListesiSayfasiState();
}

class _GrupListesiSayfasiState extends State<GrupListesiSayfasi> {
  final AppRepository _repo = AppRepository();
  List<Group> _groups = [];
  List<Group> _filteredGroups = [];
  List<Map<String, dynamic>> _coachGroups = [];
  bool _isLoading = true;
  String? _error;

  // FİLTRELER
  String _searchQuery = "";
  String _selectedCoachId = "Tümü";
  String _selectedStatus = "Tümü";
  final List<String> _statusOptions = ["Tümü", "🔥 Bugün"];

  // Hoca listesi (Chip'ler için) - SADECE YARDIMCI ANTRENÖR İÇİN
  List<Map<String, dynamic>> _coachList = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _groups = [];
      _coachGroups = [];
      _coachList = [];
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;

      // 🔥 KÖK HATA ÇÖZÜMÜ: coach_id boşsa widget.user.app (userId) ile tablodan buluyoruz
      var coachId = widget.coache.coach_id.trim();
      if (coachId.isEmpty) {
        print("⚠️ GrupListesiSayfasi: coach_id BOŞ! user.app ile aranıyor...");
        final userId = widget.user.app;
        try {
          final foundCoach = allCoaches.firstWhere((c) => c.user_id == userId);
          coachId = foundCoach.coach_id;
        } catch (_) {
          // Eğer coaches tablosunda bulunamazsa userId'yi coachId kabul etmeyi dene
          coachId = userId;
        }
      }

      print("🔍 coachId: $coachId");
      print("🔍 isAssistant: ${widget.isAssistant}");
      print("🔍 allCoaches count: ${allCoaches.length}");

      if (widget.isAssistant) {
        // 🔥 YARDIMCI ANTRENÖR - Bağlı olduğu hocaları bul
        Coach assistantCoach;
        try {
          assistantCoach = allCoaches.firstWhere(
            (c) => c.coach_id == coachId || c.user_id == widget.user.app,
          );
        } catch (_) {
          assistantCoach = widget.coache;
        }

        print("🔍 assistantCoach.coach_id: ${assistantCoach.coach_id}");
        print(
          "🔍 assistantCoach.supervisor_coach_id: ${assistantCoach.supervisor_coach_id}",
        );

        final supervisorIds =
            assistantCoach.supervisor_coach_id
                ?.split(RegExp(r'[,.]'))
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList() ??
            [];

        print("🔍 supervisorIds: $supervisorIds");

        Set<String> processedCoachIds = {};

        if (supervisorIds.isNotEmpty) {
          for (var supervisorId in supervisorIds) {
            if (supervisorId == assistantCoach.user_id ||
                supervisorId == assistantCoach.coach_id) {
              continue;
            }

            final supervisorCoach = allCoaches.firstWhere(
              (c) => c.coach_id == supervisorId || c.user_id == supervisorId,
              orElse: () => Coach(
                coach_id: supervisorId,
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
                  last_name: '#$supervisorId',
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
                _coachList.add({
                  'coach_id': supervisorCoach.coach_id,
                  'coach_name': coachName,
                  'group_count': groups.length,
                });
                _coachGroups.add({
                  'coach_id': supervisorCoach.coach_id,
                  'coach_name': coachName,
                  'groups': groups,
                });
                _groups.addAll(groups);
              }
            }
          }
        }

        // Üst hocaları tara (supervisorIds'de olmayan ama bağlı olanları da yakala)
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
                _coachList.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'group_count': groups.length,
                });
                _coachGroups.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'groups': groups,
                });
                _groups.addAll(groups);
              }
            }
          }
        }

        if (_coachList.isEmpty) {
          _groups = _repo.getGroupsByCoachId(coachId);
          print(
            "⚠️ Yardımcının üst hocası yok, kendi grupları: ${_groups.length}",
          );
          if (_groups.isNotEmpty) {
            final myUser = allUsers.firstWhere(
              (u) => u.app.toString() == assistantCoach.user_id,
              orElse: () => widget.user,
            );
            _coachList.add({
              'coach_id': coachId,
              'coach_name': "${myUser.first_name} ${myUser.last_name}",
              'group_count': _groups.length,
            });
            _coachGroups.add({
              'coach_id': coachId,
              'coach_name': "${myUser.first_name} ${myUser.last_name}",
              'groups': _groups,
            });
          }
        }
      } else {
        // NORMAL ANTRENÖR
        _groups = _repo.getGroupsByCoachId(coachId);
        final coachUser = allUsers.firstWhere(
          (u) => u.app.toString() == widget.coache.user_id,
          orElse: () => widget.user,
        );
        final coachName = "${coachUser.first_name} ${coachUser.last_name}";
        _coachList.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'group_count': _groups.length,
        });
        _coachGroups.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'groups': _groups,
        });
      }

      _groups.sort((a, b) {
        final aHasToday = _hasTrainingToday(a);
        final bHasToday = _hasTrainingToday(b);
        if (aHasToday && !bHasToday) return -1;
        if (!aHasToday && bHasToday) return 1;
        return a.name.compareTo(b.name);
      });

      _applyFilters();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Grup yükleme hatası: $e");
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredGroups = _groups.where((group) {
        if (_searchQuery.isNotEmpty) {
          if (!group.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // SADECE YARDIMCI ANTRENÖR İÇİN HOCA FİLTRESİ
        if (widget.isAssistant && _selectedCoachId != "Tümü") {
          bool belongsToCoach = false;
          for (var cg in _coachGroups) {
            if (cg['coach_id'] == _selectedCoachId) {
              if ((cg['groups'] as List).contains(group)) {
                belongsToCoach = true;
                break;
              }
            }
          }
          if (!belongsToCoach) return false;
        }

        if (_selectedStatus == "🔥 Bugün") {
          if (!_hasTrainingToday(group)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
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

  bool _hasTrainingToday(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return false;

    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern1.hasMatch(schedule)) return true;

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    final pattern3 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern3.hasMatch(schedule)) return true;

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    return false;
  }

  String _getTodayTrainingTime(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return "";

    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    final match1 = pattern1.firstMatch(schedule);
    if (match1 != null) {
      return "${match1.group(1)} - ${match1.group(2)}";
    }

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      final match2 = timePattern.firstMatch(schedule);
      if (match2 != null) {
        return "${match2.group(1)} - ${match2.group(2)}";
      }
    }

    return "";
  }

  Future<void> _refreshData() async {
    await _repo.refreshAllData();
    await _loadGroups();
  }

  String _getGroupTime(String schedule) {
    if (schedule.contains(RegExp(r'\d{1,2}:\d{2}'))) {
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(schedule);
      if (match != null) return match.group(0)!;
    }
    return schedule;
  }

  int _getStudentCountForGroup(String groupId) {
    final relations = _repo.allGroupStudents
        .where((r) => r.groups_id == groupId)
        .where((r) => r.is_active.toUpperCase() == "TRUE")
        .toList();
    return relations.length;
  }

  String _getCoachNameForGroup(Group group) {
    for (var cg in _coachGroups) {
      if ((cg['groups'] as List).contains(group)) {
        return cg['coach_name'] ?? "";
      }
    }
    return "";
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
              widget.isAssistant ? "Bağlı Olduğum Gruplar" : "Gruplarım",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.isAssistant && _coachGroups.isNotEmpty)
              Text(
                "${_coachGroups.length} hocaya bağlı",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.indigo,
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
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Gruplar yükleniyor..."),
                ],
              ),
            )
          : (_error != null
                ? _buildErrorState()
                : (_groups.isEmpty
                      ? _buildEmptyState()
                      : _buildContentWithFilters())),
    );
  }

  Widget _buildContentWithFilters() {
    if (_coachList.isEmpty && widget.isAssistant) {
      print("⚠️ _coachList BOŞ! Filtreler gösterilmeyecek.");
    }

    String resultText = "";
    if (_filteredGroups.isNotEmpty) {
      final hasToday = _filteredGroups
          .where((g) => _hasTrainingToday(g))
          .length;
      String coachFilterText = "";
      if (widget.isAssistant && _selectedCoachId != "Tümü") {
        for (var coach in _coachList) {
          if (coach['coach_id'] == _selectedCoachId) {
            coachFilterText = " • ${coach['coach_name']}";
            break;
          }
        }
      }
      resultText =
          "${_filteredGroups.length} grup gösteriliyor$coachFilterText${hasToday > 0 ? " • $hasToday tanesi bugün 🔥" : ""}";
    }

    return Column(
      children: [
        _buildFilterBar(),
        if (_filteredGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                resultText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Expanded(
          child: _filteredGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ||
                                (widget.isAssistant &&
                                    _selectedCoachId != "Tümü") ||
                                _selectedStatus != "Tümü"
                            ? "Filtrelere uygun grup bulunamadı"
                            : "Gösterilecek grup yok",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _selectedCoachId = "Tümü";
                            _selectedStatus = "Tümü";
                            _applyFilters();
                          });
                        },
                        child: const Text("Filtreleri Temizle"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final grup = _filteredGroups[index];
                      final studentCount = _getStudentCountForGroup(
                        grup.groups_id,
                      );
                      final hasToday = _hasTrainingToday(grup);
                      final todayTime = _getTodayTrainingTime(grup);
                      final coachName = _getCoachNameForGroup(grup);

                      return _buildGroupCard(
                        context,
                        grup,
                        studentCount,
                        coachName,
                        hasToday,
                        todayTime,
                      );
                    },
                  ),
                ),
        ),
        const VersionFooter(),
        const SizedBox(height: 4),
      ],
    );
  }

  // FİLTRE ÇUBUĞU
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "🔍 Grup ara...",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _selectedStatus == "🔥 Bugün"
                          ? Colors.green.shade700
                          : Colors.grey.shade800,
                    ),
                    items: _statusOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Row(
                          children: [
                            if (option == "🔥 Bugün")
                              const Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: Colors.green,
                              ),
                            if (option == "🔥 Bugün") const SizedBox(width: 4),
                            Text(option),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value ?? "Tümü";
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // HOCA CHIP'LERİ (SADECE YARDIMCI ANTRENÖR)
          if (widget.isAssistant && _coachList.isNotEmpty) ...[
            Row(
              children: [
                const Text("👨‍🏫", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCoachChip("Tümü", "Tümü", _groups.length, true),
                        ..._coachList.map((coach) {
                          return _buildCoachChip(
                            coach['coach_name'],
                            coach['coach_id'],
                            coach['group_count'],
                            false,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_coachList.isEmpty && widget.isAssistant && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "⚠️ Bağlı olduğunuz hoca bulunamadı",
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),

          if (_selectedCoachId != "Tümü" ||
              _selectedStatus != "Tümü" ||
              _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _searchQuery = "";
                    _selectedCoachId = "Tümü";
                    _selectedStatus = "Tümü";
                    _applyFilters();
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Filtreleri Temizle",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // HOCA CHIP WIDGET
  Widget _buildCoachChip(
    String label,
    String coachId,
    int groupCount,
    bool isAll,
  ) {
    final isSelected = _selectedCoachId == coachId;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCoachId = coachId;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isAll ? Colors.grey.shade800 : Colors.teal)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? (isAll ? Colors.grey.shade800 : Colors.teal)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isAll ? Colors.grey : Colors.teal).withOpacity(
                        0.3,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAll && isSelected)
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
              if (!isAll && isSelected) const SizedBox(width: 4),
              Text(
                isAll ? "📋 Tümü" : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              if (!isAll && !isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
              if (!isAll && isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
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
              backgroundColor: Colors.indigo,
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
            child: Icon(
              widget.isAssistant ? Icons.assignment_ind : Icons.group_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isAssistant
                ? "Henüz bir hocaya bağlı değilsiniz"
                : "Henüz size atanmış bir grup bulunamadı",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAssistant
                ? "Yöneticiniz sizi bir hocaya atayınca burada görünecektir"
                : "Yöneticiniz sizi bir gruba atayınca burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group grup,
    int studentCount,
    String coachName,
    bool hasToday,
    String todayTime,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => YoklamaSayfasi(
                  selectedGroup: grup,
                  currentUser: widget.user,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasToday ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasToday ? Colors.green.shade400 : Colors.grey.shade200,
                width: hasToday ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasToday
                      ? Colors.green.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: hasToday
                        ? const LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
                          )
                        : widget.isAssistant
                        ? const LinearGradient(
                            colors: [Colors.teal, Colors.tealAccent],
                          )
                        : const LinearGradient(
                            colors: [Colors.indigo, Colors.indigoAccent],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hasToday ? Icons.today : Icons.group,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              grup.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasToday
                                    ? Colors.green.shade800
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (hasToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fitness_center,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "🔥 Bugün",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: hasToday
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasToday && todayTime.isNotEmpty
                                ? todayTime
                                : _getGroupTime(grup.schedule),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasToday
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: hasToday ? FontWeight.w600 : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$studentCount öğrenci",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (widget.isAssistant && coachName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 12,
                                color: Colors.teal.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                coachName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasToday
                        ? Colors.green.shade100
                        : widget.isAssistant
                        ? Colors.teal.shade50
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: hasToday
                        ? Colors.green.shade700
                        : widget.isAssistant
                        ? Colors.teal
                        : Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

*/
/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';

class GrupListesiSayfasi extends StatelessWidget {
  final Coach coache;
  final Users user;

  const GrupListesiSayfasi({
    super.key,
    required this.coache,
    required this.user,
  });

  String _getGroupTime(String schedule) {
    if (schedule.contains(RegExp(r'\d{1,2}:\d{2}'))) {
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(schedule);
      if (match != null) return match.group(0)!;
    }
    return schedule;
  }

  // 🔥 FUTURE - CACHE'Lİ OLARAK VERİLERİ ÇEK
  Future<List<Group>> get _groupsFuture async {
    final allGroups = await GoogleSheetService.getGroupsCached();
    return allGroups.where((g) => g.coach_id == coache.coach_id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Gruplarım",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 🔄 YENİLEME BUTONU
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Cache'i temizle ve sayfayı yenile
              GoogleSheetService.invalidateCache('groups');
              (context as Element).reassemble();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          // 1️⃣ YÜKLENİYOR DURUMU
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Gruplar yükleniyor..."),
                ],
              ),
            );
          }

          // 2️⃣ HATA DURUMU
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text("Bir hata oluştu"),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      GoogleSheetService.invalidateCache('groups');
                      (context as Element).reassemble();
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

          // 3️⃣ VERİ GELDİ - LİSTEYİ GÖSTER
          final gruplar = snapshot.data ?? [];

          if (gruplar.isEmpty) {
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
                      Icons.group_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Henüz size atanmış bir grup bulunamadı",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Yöneticiniz sizi bir gruba atayınca burada görünecektir",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              GoogleSheetService.invalidateCache('groups');
              (context as Element).reassemble();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: gruplar.length,
              itemBuilder: (context, index) {
                final grup = gruplar[index];
                return _buildGroupCard(context, grup);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Group grup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    YoklamaSayfasi(selectedGroup: grup, currentUser: user),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Grup ikonu
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Colors.indigoAccent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.group, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grup.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getGroupTime(grup.schedule),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.payments,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ok butonu
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/

/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class GrupListesiSayfasi extends StatefulWidget {
  final Coach coache;
  final Users user;
  final bool isAssistant;

  const GrupListesiSayfasi({
    super.key,
    required this.coache,
    required this.user,
    this.isAssistant = false,
  });

  @override
  State<GrupListesiSayfasi> createState() => _GrupListesiSayfasiState();
}

class _GrupListesiSayfasiState extends State<GrupListesiSayfasi> {
  final AppRepository _repo = AppRepository();
  List<Group> _groups = [];
  List<Group> _filteredGroups = [];
  List<Map<String, dynamic>> _coachGroups = [];
  bool _isLoading = true;
  String? _error;

  // 🔥 FİLTRELER
  String _searchQuery = "";
  String _selectedCoachId = "Tümü";
  String _selectedStatus = "Tümü";
  final List<String> _statusOptions = ["Tümü", "🔥 Bugün"];

  // 🔥 Hoca listesi (Chip'ler için)
  List<Map<String, dynamic>> _coachList = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _groups = [];
      _coachGroups = [];
      _coachList = [];
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final coachId = widget.coache.coach_id;
      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;

      print("🔍 coachId: $coachId");
      print("🔍 isAssistant: ${widget.isAssistant}");
      print("🔍 allCoaches count: ${allCoaches.length}");

      if (widget.isAssistant) {
        // 🔥 YARDIMCI ANTRENÖR - Bağlı olduğu hocaları bul
        final assistantCoach = allCoaches.firstWhere(
          (c) => c.coach_id == coachId,
          orElse: () => widget.coache,
        );

        print("🔍 assistantCoach.coach_id: ${assistantCoach.coach_id}");
        print(
          "🔍 assistantCoach.supervisor_coach_id: ${assistantCoach.supervisor_coach_id}",
        );

        final supervisorIds =
            assistantCoach.supervisor_coach_id
                ?.split(RegExp(r'[,.]')) // Virgül veya nokta ile ayır
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList() ??
            [];

        print("🔍 supervisorIds: $supervisorIds");

        // 🔥🔥🔥 DURUM 1: supervisor_coach_id dolu
        if (supervisorIds.isNotEmpty) {
          for (var supervisorId in supervisorIds) {
            // Hocanın coach kaydını bul
            final supervisorCoach = allCoaches.firstWhere(
              (c) => c.coach_id == supervisorId,
              orElse: () => Coach(
                coach_id: supervisorId,
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

            // Hocanın user bilgisini bul
            final supervisorUser = allUsers.firstWhere(
              (u) => u.app.toString() == supervisorCoach.user_id,
              orElse: () => Users(
                app: '',
                first_name: 'Hoca',
                last_name: '#$supervisorId',
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

            // 🔥 O hocanın tüm gruplarını al
            final groups = allGroups
                .where((g) => g.coach_id == supervisorId)
                .where((g) => g.is_active?.toUpperCase() == "TRUE")
                .toList();

            print("✅ Hoca $supervisorId: ${groups.length} grup - $coachName");

            // 🔥 Hoca listesine ekle
            _coachList.add({
              'coach_id': supervisorId,
              'coach_name': coachName,
              'group_count': groups.length,
            });

            _coachGroups.add({
              'coach_id': supervisorId,
              'coach_name': coachName,
              'groups': groups,
            });

            _groups.addAll(groups);
          }
        } else {
          // 🔥🔥🔥 DURUM 2: supervisor_coach_id BOŞ
          // getGroupsByCoachId metodu zaten üst hocaları bulup grupları döndürüyor
          // Ama biz _coachList'i doldurmak için üst hocaları bulmalıyız

          // Tüm coach'ları tara, supervisor_coach_id içinde bu user_id var mı?
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

              // Bu coach'un supervisor listesinde yardımcının user_id'si var mı?
              if (supIds.contains(assistantCoach.user_id)) {
                // Üst hocanın user bilgisini bul
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

                // O hocanın gruplarını al
                final groups = allGroups
                    .where((g) => g.coach_id == coach.coach_id)
                    .where((g) => g.is_active?.toUpperCase() == "TRUE")
                    .toList();

                print(
                  "✅ Üst hoca ${coach.coach_id}: ${groups.length} grup - $coachName",
                );

                // Hoca listesine ekle
                _coachList.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'group_count': groups.length,
                });

                _coachGroups.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'groups': groups,
                });

                _groups.addAll(groups);
              }
            }
          }

          // Eğer hiç üst hoca bulunamadıysa, kendi gruplarını dene
          if (_coachList.isEmpty) {
            _groups = _repo.getGroupsByCoachId(coachId);
            print(
              "⚠️ Yardımcının üst hocası yok, kendi grupları: ${_groups.length}",
            );
          }
        }
      } else {
        // 🔥 NORMAL ANTRENÖR - kendi grupları
        _groups = _repo.getGroupsByCoachId(coachId);
        final coachUser = allUsers.firstWhere(
          (u) => u.app.toString() == widget.coache.user_id,
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
        final coachName = "${coachUser.first_name} ${coachUser.last_name}";
        _coachList.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'group_count': _groups.length,
        });
        _coachGroups.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'groups': _groups,
        });
      }

      // 🔥 DEBUG: _coachList kontrolü
      print("🔥 _coachList: ${_coachList.length} hoca");
      for (var c in _coachList) {
        print("   - ${c['coach_name']}: ${c['group_count']} grup");
      }

      // 🔥 SIRALAMA: Bugün dersi olanlar yukarıda
      _groups.sort((a, b) {
        final aHasToday = _hasTrainingToday(a);
        final bHasToday = _hasTrainingToday(b);
        if (aHasToday && !bHasToday) return -1;
        if (!aHasToday && bHasToday) return 1;
        return a.name.compareTo(b.name);
      });

      _applyFilters();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Grup yükleme hatası: $e");
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // 🔥🔥🔥 FİLTRELEME METODU
  // ============================================================

  void _applyFilters() {
    setState(() {
      _filteredGroups = _groups.where((group) {
        // 1. ARAMA FİLTRESİ
        if (_searchQuery.isNotEmpty) {
          if (!group.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // 2. HOCA FİLTRESİ (Chip)
        if (_selectedCoachId != "Tümü") {
          bool belongsToCoach = false;
          for (var cg in _coachGroups) {
            if (cg['coach_id'] == _selectedCoachId) {
              if ((cg['groups'] as List).contains(group)) {
                belongsToCoach = true;
                break;
              }
            }
          }
          if (!belongsToCoach) return false;
        }

        // 3. DURUM FİLTRESİ
        if (_selectedStatus == "🔥 Bugün") {
          if (!_hasTrainingToday(group)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  // ============================================================
  // 🔥🔥🔥 TARİH KONTROL FONKSİYONLARI
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

  bool _hasTrainingToday(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return false;

    // Format 1: "pazartesi:21:00-22:00"
    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern1.hasMatch(schedule)) return true;

    // Format 2: "pazartesi-çarşamba-cuma,21:00-22:00"
    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    // Format 3: "perşembe-cuma:18:00-19:00"
    final pattern3 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern3.hasMatch(schedule)) return true;

    // Genel kontrol
    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    return false;
  }

  String _getTodayTrainingTime(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return "";

    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    final match1 = pattern1.firstMatch(schedule);
    if (match1 != null) {
      return "${match1.group(1)} - ${match1.group(2)}";
    }

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      final match2 = timePattern.firstMatch(schedule);
      if (match2 != null) {
        return "${match2.group(1)} - ${match2.group(2)}";
      }
    }

    return "";
  }

  // ============================================================
  // YARDIMCI FONKSİYONLAR
  // ============================================================

  Future<void> _refreshData() async {
    await _repo.refreshAllData();
    await _loadGroups();
  }

  String _getGroupTime(String schedule) {
    if (schedule.contains(RegExp(r'\d{1,2}:\d{2}'))) {
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(schedule);
      if (match != null) return match.group(0)!;
    }
    return schedule;
  }

  int _getStudentCountForGroup(String groupId) {
    final relations = _repo.allGroupStudents
        .where((r) => r.groups_id == groupId)
        .where((r) => r.is_active.toUpperCase() == "TRUE")
        .toList();
    return relations.length;
  }

  String _getCoachNameForGroup(Group group) {
    for (var cg in _coachGroups) {
      if ((cg['groups'] as List).contains(group)) {
        return cg['coach_name'] ?? "";
      }
    }
    return "";
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAssistant ? "Bağlı Olduğum Gruplar" : "Gruplarım",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.isAssistant && _coachGroups.isNotEmpty)
              Text(
                "${_coachGroups.length} hocaya bağlı",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.indigo,
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
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Gruplar yükleniyor..."),
                ],
              ),
            )
          : (_error != null
                ? _buildErrorState()
                : (_groups.isEmpty
                      ? _buildEmptyState()
                      : _buildContentWithFilters())),
    );
  }

  Widget _buildContentWithFilters() {
    // 🔥 DEBUG: _coachList boşsa göster
    if (_coachList.isEmpty && widget.isAssistant) {
      print("⚠️ _coachList BOŞ! Filtreler gösterilmeyecek.");
    }

    // 🔥 Filtre sonucu göster
    String resultText = "";
    if (_filteredGroups.isNotEmpty) {
      final hasToday = _filteredGroups
          .where((g) => _hasTrainingToday(g))
          .length;
      String coachFilterText = "";
      if (_selectedCoachId != "Tümü") {
        for (var coach in _coachList) {
          if (coach['coach_id'] == _selectedCoachId) {
            coachFilterText = " • ${coach['coach_name']}";
            break;
          }
        }
      }
      resultText =
          "${_filteredGroups.length} grup gösteriliyor$coachFilterText${hasToday > 0 ? " • $hasToday tanesi bugün 🔥" : ""}";
    }

    return Column(
      children: [
        // 🔥 FİLTRE ÇUBUĞU
        _buildFilterBar(),
        if (_filteredGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                resultText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Expanded(
          child: _filteredGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ||
                                _selectedCoachId != "Tümü" ||
                                _selectedStatus != "Tümü"
                            ? "Filtrelere uygun grup bulunamadı"
                            : "Gösterilecek grup yok",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _selectedCoachId = "Tümü";
                            _selectedStatus = "Tümü";
                            _applyFilters();
                          });
                        },
                        child: const Text("Filtreleri Temizle"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final grup = _filteredGroups[index];
                      final studentCount = _getStudentCountForGroup(
                        grup.groups_id,
                      );
                      final hasToday = _hasTrainingToday(grup);
                      final todayTime = _getTodayTrainingTime(grup);
                      final coachName = _getCoachNameForGroup(grup);

                      return _buildGroupCard(
                        context,
                        grup,
                        studentCount,
                        coachName,
                        hasToday,
                        todayTime,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // 🔥🔥🔥 FİLTRE ÇUBUĞU
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SATIR: Arama + Durum Filtresi
          Row(
            children: [
              // 🔍 ARAMA
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "🔍 Grup ara...",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 🔥 DURUM FİLTRESİ
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _selectedStatus == "🔥 Bugün"
                          ? Colors.green.shade700
                          : Colors.grey.shade800,
                    ),
                    items: _statusOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Row(
                          children: [
                            if (option == "🔥 Bugün")
                              const Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: Colors.green,
                              ),
                            if (option == "🔥 Bugün") const SizedBox(width: 4),
                            Text(option),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value ?? "Tümü";
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. SATIR: HOCA CHIP'LERİ
          if (_coachList.isNotEmpty) ...[
            Row(
              children: [
                const Text("👨‍🏫", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 🔥 "Tümü" Chip'i
                        _buildCoachChip("Tümü", "Tümü", _groups.length, true),

                        // 🔥 Her hoca için Chip
                        ..._coachList.map((coach) {
                          return _buildCoachChip(
                            coach['coach_name'],
                            coach['coach_id'],
                            coach['group_count'],
                            false,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Eğer _coachList boşsa uyarı göster
          if (_coachList.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                widget.isAssistant
                    ? "⚠️ Bağlı olduğunuz hoca bulunamadı"
                    : "⚠️ Hoca bilgisi bulunamadı",
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),

          // Filtreleri temizle butonu (aktif filtre varsa)
          if (_selectedCoachId != "Tümü" ||
              _selectedStatus != "Tümü" ||
              _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _searchQuery = "";
                    _selectedCoachId = "Tümü";
                    _selectedStatus = "Tümü";
                    _applyFilters();
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Filtreleri Temizle",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // 🔥🔥🔥 HOCA CHIP WIDGET
  Widget _buildCoachChip(
    String label,
    String coachId,
    int groupCount,
    bool isAll,
  ) {
    final isSelected = _selectedCoachId == coachId;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCoachId = coachId;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isAll ? Colors.grey.shade800 : Colors.teal)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? (isAll ? Colors.grey.shade800 : Colors.teal)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isAll ? Colors.grey : Colors.teal).withOpacity(
                        0.3,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAll && isSelected)
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
              if (!isAll && isSelected) const SizedBox(width: 4),
              Text(
                isAll ? "📋 Tümü" : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              if (!isAll && !isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
              if (!isAll && isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
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
              backgroundColor: Colors.indigo,
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
            child: Icon(
              widget.isAssistant ? Icons.assignment_ind : Icons.group_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isAssistant
                ? "Henüz bir hocaya bağlı değilsiniz"
                : "Henüz size atanmış bir grup bulunamadı",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAssistant
                ? "Yöneticiniz sizi bir hocaya atayınca burada görünecektir"
                : "Yöneticiniz sizi bir gruba atayınca burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group grup,
    int studentCount,
    String coachName,
    bool hasToday,
    String todayTime,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => YoklamaSayfasi(
                  selectedGroup: grup,
                  currentUser: widget.user,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasToday ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasToday ? Colors.green.shade400 : Colors.grey.shade200,
                width: hasToday ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasToday
                      ? Colors.green.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: hasToday
                        ? const LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
                          )
                        : widget.isAssistant
                        ? const LinearGradient(
                            colors: [Colors.teal, Colors.tealAccent],
                          )
                        : const LinearGradient(
                            colors: [Colors.indigo, Colors.indigoAccent],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hasToday ? Icons.today : Icons.group,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              grup.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasToday
                                    ? Colors.green.shade800
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (hasToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fitness_center,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "🔥 Bugün",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: hasToday
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasToday && todayTime.isNotEmpty
                                ? todayTime
                                : _getGroupTime(grup.schedule),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasToday
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: hasToday ? FontWeight.w600 : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$studentCount öğrenci",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      // Hoca ismi (Assistant için)
                      if (widget.isAssistant && coachName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 12,
                                color: Colors.teal.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                coachName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasToday
                        ? Colors.green.shade100
                        : widget.isAssistant
                        ? Colors.teal.shade50
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: hasToday
                        ? Colors.green.shade700
                        : widget.isAssistant
                        ? Colors.teal
                        : Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class GrupListesiSayfasi extends StatefulWidget {
  final Coach coache;
  final Users user;
  final bool isAssistant;

  const GrupListesiSayfasi({
    super.key,
    required this.coache,
    required this.user,
    this.isAssistant = false,
  });

  @override
  State<GrupListesiSayfasi> createState() => _GrupListesiSayfasiState();
}

class _GrupListesiSayfasiState extends State<GrupListesiSayfasi> {
  final AppRepository _repo = AppRepository();
  List<Group> _groups = [];
  List<Group> _filteredGroups = [];
  List<Map<String, dynamic>> _coachGroups = [];
  bool _isLoading = true;
  String? _error;

  // FİLTRELER
  String _searchQuery = "";
  String _selectedCoachId = "Tümü";
  String _selectedStatus = "Tümü";
  final List<String> _statusOptions = ["Tümü", "🔥 Bugün"];

  // Hoca listesi (Chip'ler için) - SADECE YARDIMCI ANTRENÖR İÇİN
  List<Map<String, dynamic>> _coachList = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _groups = [];
      _coachGroups = [];
      _coachList = [];
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allGroups = _repo.allGroups;
      final allUsers = _repo.allUsers;

      // 🔥 KÖK HATA ÇÖZÜMÜ: coach_id boşsa widget.user.app (userId) ile tablodan buluyoruz
      var coachId = widget.coache.coach_id.trim();
      if (coachId.isEmpty) {
        print("⚠️ GrupListesiSayfasi: coach_id BOŞ! user.app ile aranıyor...");
        final userId = widget.user.app;
        try {
          final foundCoach = allCoaches.firstWhere((c) => c.user_id == userId);
          coachId = foundCoach.coach_id;
        } catch (_) {
          // Eğer coaches tablosunda bulunamazsa userId'yi coachId kabul etmeyi dene
          coachId = userId;
        }
      }

      print("🔍 coachId: $coachId");
      print("🔍 isAssistant: ${widget.isAssistant}");
      print("🔍 allCoaches count: ${allCoaches.length}");

      if (widget.isAssistant) {
        // 🔥 YARDIMCI ANTRENÖR - Bağlı olduğu hocaları bul
        Coach assistantCoach;
        try {
          assistantCoach = allCoaches.firstWhere(
            (c) => c.coach_id == coachId || c.user_id == widget.user.app,
          );
        } catch (_) {
          assistantCoach = widget.coache;
        }

        print("🔍 assistantCoach.coach_id: ${assistantCoach.coach_id}");
        print(
          "🔍 assistantCoach.supervisor_coach_id: ${assistantCoach.supervisor_coach_id}",
        );

        final supervisorIds =
            assistantCoach.supervisor_coach_id
                ?.split(RegExp(r'[,.]'))
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList() ??
            [];

        print("🔍 supervisorIds: $supervisorIds");

        Set<String> processedCoachIds = {};

        if (supervisorIds.isNotEmpty) {
          for (var supervisorId in supervisorIds) {
            if (supervisorId == assistantCoach.user_id ||
                supervisorId == assistantCoach.coach_id) {
              continue;
            }

            final supervisorCoach = allCoaches.firstWhere(
              (c) => c.coach_id == supervisorId || c.user_id == supervisorId,
              orElse: () => Coach(
                coach_id: supervisorId,
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
                  last_name: '#$supervisorId',
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
                _coachList.add({
                  'coach_id': supervisorCoach.coach_id,
                  'coach_name': coachName,
                  'group_count': groups.length,
                });
                _coachGroups.add({
                  'coach_id': supervisorCoach.coach_id,
                  'coach_name': coachName,
                  'groups': groups,
                });
                _groups.addAll(groups);
              }
            }
          }
        }

        // Üst hocaları tara (supervisorIds'de olmayan ama bağlı olanları da yakala)
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
                _coachList.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'group_count': groups.length,
                });
                _coachGroups.add({
                  'coach_id': coach.coach_id,
                  'coach_name': coachName,
                  'groups': groups,
                });
                _groups.addAll(groups);
              }
            }
          }
        }

        if (_coachList.isEmpty) {
          _groups = _repo.getGroupsByCoachId(coachId);
          print(
            "⚠️ Yardımcının üst hocası yok, kendi grupları: ${_groups.length}",
          );
          if (_groups.isNotEmpty) {
            final myUser = allUsers.firstWhere(
              (u) => u.app.toString() == assistantCoach.user_id,
              orElse: () => widget.user,
            );
            _coachList.add({
              'coach_id': coachId,
              'coach_name': "${myUser.first_name} ${myUser.last_name}",
              'group_count': _groups.length,
            });
            _coachGroups.add({
              'coach_id': coachId,
              'coach_name': "${myUser.first_name} ${myUser.last_name}",
              'groups': _groups,
            });
          }
        }
      } else {
        // NORMAL ANTRENÖR
        _groups = _repo.getGroupsByCoachId(coachId);
        final coachUser = allUsers.firstWhere(
          (u) => u.app.toString() == widget.coache.user_id,
          orElse: () => widget.user,
        );
        final coachName = "${coachUser.first_name} ${coachUser.last_name}";
        _coachList.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'group_count': _groups.length,
        });
        _coachGroups.add({
          'coach_id': coachId,
          'coach_name': coachName,
          'groups': _groups,
        });
      }

      _groups.sort((a, b) {
        final aHasToday = _hasTrainingToday(a);
        final bHasToday = _hasTrainingToday(b);
        if (aHasToday && !bHasToday) return -1;
        if (!aHasToday && bHasToday) return 1;
        return a.name.compareTo(b.name);
      });

      _applyFilters();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Grup yükleme hatası: $e");
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredGroups = _groups.where((group) {
        if (_searchQuery.isNotEmpty) {
          if (!group.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // SADECE YARDIMCI ANTRENÖR İÇİN HOCA FİLTRESİ
        if (widget.isAssistant && _selectedCoachId != "Tümü") {
          bool belongsToCoach = false;
          for (var cg in _coachGroups) {
            if (cg['coach_id'] == _selectedCoachId) {
              if ((cg['groups'] as List).contains(group)) {
                belongsToCoach = true;
                break;
              }
            }
          }
          if (!belongsToCoach) return false;
        }

        if (_selectedStatus == "🔥 Bugün") {
          if (!_hasTrainingToday(group)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
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

  bool _hasTrainingToday(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return false;

    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern1.hasMatch(schedule)) return true;

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    final pattern3 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    if (pattern3.hasMatch(schedule)) return true;

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      if (timePattern.hasMatch(schedule)) return true;
    }

    return false;
  }

  String _getTodayTrainingTime(Group group) {
    final todayName = _getTodayName().toLowerCase();
    final schedule = group.schedule.toLowerCase().trim();

    if (schedule.isEmpty) return "";

    final pattern1 = RegExp('$todayName:(\\d{1,2}:\\d{2})-(\\d{1,2}:\\d{2})');
    final match1 = pattern1.firstMatch(schedule);
    if (match1 != null) {
      return "${match1.group(1)} - ${match1.group(2)}";
    }

    if (schedule.contains(todayName)) {
      final timePattern = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');
      final match2 = timePattern.firstMatch(schedule);
      if (match2 != null) {
        return "${match2.group(1)} - ${match2.group(2)}";
      }
    }

    return "";
  }

  Future<void> _refreshData() async {
    await _repo.refreshAllData();
    await _loadGroups();
  }

  String _getGroupTime(String schedule) {
    if (schedule.contains(RegExp(r'\d{1,2}:\d{2}'))) {
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(schedule);
      if (match != null) return match.group(0)!;
    }
    return schedule;
  }

  int _getStudentCountForGroup(String groupId) {
    final relations = _repo.allGroupStudents
        .where((r) => r.groups_id == groupId)
        .where((r) => r.is_active.toUpperCase() == "TRUE")
        .toList();

    // 🔥 Pasif öğrencileri sayma (grupta gösterilmeyenler sayılmasın)
    final activeStudentIds = _repo.allUsers
        .where((u) => _isStudentActive(u))
        .map((u) => u.app)
        .toSet();

    return relations
        .where((r) => activeStudentIds.contains(r.student_id))
        .length;
  }

  String _getCoachNameForGroup(Group group) {
    for (var cg in _coachGroups) {
      if ((cg['groups'] as List).contains(group)) {
        return cg['coach_name'] ?? "";
      }
    }
    return "";
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
              widget.isAssistant ? "Bağlı Olduğum Gruplar" : "Gruplarım",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.isAssistant && _coachGroups.isNotEmpty)
              Text(
                "${_coachGroups.length} hocaya bağlı",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.indigo,
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
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Gruplar yükleniyor..."),
                ],
              ),
            )
          : (_error != null
                ? _buildErrorState()
                : (_groups.isEmpty
                      ? _buildEmptyState()
                      : _buildContentWithFilters())),
    );
  }

  Widget _buildContentWithFilters() {
    if (_coachList.isEmpty && widget.isAssistant) {
      print("⚠️ _coachList BOŞ! Filtreler gösterilmeyecek.");
    }

    String resultText = "";
    if (_filteredGroups.isNotEmpty) {
      final hasToday = _filteredGroups
          .where((g) => _hasTrainingToday(g))
          .length;
      String coachFilterText = "";
      if (widget.isAssistant && _selectedCoachId != "Tümü") {
        for (var coach in _coachList) {
          if (coach['coach_id'] == _selectedCoachId) {
            coachFilterText = " • ${coach['coach_name']}";
            break;
          }
        }
      }
      resultText =
          "${_filteredGroups.length} grup gösteriliyor$coachFilterText${hasToday > 0 ? " • $hasToday tanesi bugün 🔥" : ""}";
    }

    return Column(
      children: [
        _buildFilterBar(),
        if (_filteredGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                resultText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Expanded(
          child: _filteredGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ||
                                (widget.isAssistant &&
                                    _selectedCoachId != "Tümü") ||
                                _selectedStatus != "Tümü"
                            ? "Filtrelere uygun grup bulunamadı"
                            : "Gösterilecek grup yok",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _selectedCoachId = "Tümü";
                            _selectedStatus = "Tümü";
                            _applyFilters();
                          });
                        },
                        child: const Text("Filtreleri Temizle"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final grup = _filteredGroups[index];
                      final studentCount = _getStudentCountForGroup(
                        grup.groups_id,
                      );
                      final hasToday = _hasTrainingToday(grup);
                      final todayTime = _getTodayTrainingTime(grup);
                      final coachName = _getCoachNameForGroup(grup);

                      return _buildGroupCard(
                        context,
                        grup,
                        studentCount,
                        coachName,
                        hasToday,
                        todayTime,
                      );
                    },
                  ),
                ),
        ),
        const VersionFooter(),
        const SizedBox(height: 4),
      ],
    );
  }

  // FİLTRE ÇUBUĞU
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "🔍 Grup ara...",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _selectedStatus == "🔥 Bugün"
                          ? Colors.green.shade700
                          : Colors.grey.shade800,
                    ),
                    items: _statusOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Row(
                          children: [
                            if (option == "🔥 Bugün")
                              const Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: Colors.green,
                              ),
                            if (option == "🔥 Bugün") const SizedBox(width: 4),
                            Text(option),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value ?? "Tümü";
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // HOCA CHIP'LERİ (SADECE YARDIMCI ANTRENÖR)
          if (widget.isAssistant && _coachList.isNotEmpty) ...[
            Row(
              children: [
                const Text("👨‍🏫", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCoachChip("Tümü", "Tümü", _groups.length, true),
                        ..._coachList.map((coach) {
                          return _buildCoachChip(
                            coach['coach_name'],
                            coach['coach_id'],
                            coach['group_count'],
                            false,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_coachList.isEmpty && widget.isAssistant && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "⚠️ Bağlı olduğunuz hoca bulunamadı",
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),

          if (_selectedCoachId != "Tümü" ||
              _selectedStatus != "Tümü" ||
              _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _searchQuery = "";
                    _selectedCoachId = "Tümü";
                    _selectedStatus = "Tümü";
                    _applyFilters();
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Filtreleri Temizle",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // HOCA CHIP WIDGET
  Widget _buildCoachChip(
    String label,
    String coachId,
    int groupCount,
    bool isAll,
  ) {
    final isSelected = _selectedCoachId == coachId;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCoachId = coachId;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isAll ? Colors.grey.shade800 : Colors.teal)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? (isAll ? Colors.grey.shade800 : Colors.teal)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isAll ? Colors.grey : Colors.teal).withOpacity(
                        0.3,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAll && isSelected)
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
              if (!isAll && isSelected) const SizedBox(width: 4),
              Text(
                isAll ? "📋 Tümü" : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              if (!isAll && !isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
              if (!isAll && isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    groupCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
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
              backgroundColor: Colors.indigo,
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
            child: Icon(
              widget.isAssistant ? Icons.assignment_ind : Icons.group_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isAssistant
                ? "Henüz bir hocaya bağlı değilsiniz"
                : "Henüz size atanmış bir grup bulunamadı",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAssistant
                ? "Yöneticiniz sizi bir hocaya atayınca burada görünecektir"
                : "Yöneticiniz sizi bir gruba atayınca burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group grup,
    int studentCount,
    String coachName,
    bool hasToday,
    String todayTime,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => YoklamaSayfasi(
                  selectedGroup: grup,
                  currentUser: widget.user,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasToday ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasToday ? Colors.green.shade400 : Colors.grey.shade200,
                width: hasToday ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasToday
                      ? Colors.green.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: hasToday
                        ? const LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
                          )
                        : widget.isAssistant
                        ? const LinearGradient(
                            colors: [Colors.teal, Colors.tealAccent],
                          )
                        : const LinearGradient(
                            colors: [Colors.indigo, Colors.indigoAccent],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hasToday ? Icons.today : Icons.group,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              grup.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasToday
                                    ? Colors.green.shade800
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (hasToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fitness_center,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "🔥 Bugün",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: hasToday
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasToday && todayTime.isNotEmpty
                                ? todayTime
                                : _getGroupTime(grup.schedule),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasToday
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: hasToday ? FontWeight.w600 : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$studentCount öğrenci",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (widget.isAssistant && coachName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 12,
                                color: Colors.teal.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                coachName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasToday
                        ? Colors.green.shade100
                        : widget.isAssistant
                        ? Colors.teal.shade50
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: hasToday
                        ? Colors.green.shade700
                        : widget.isAssistant
                        ? Colors.teal
                        : Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Öğrenci aktif mi? Pasifse gruplarda / yoklamada gösterilmez/sayılmaz.
/// Uygulama genelinde aktiflik 'is_active' + "TRUE"/"FALSE" kalıbıyla tutuluyor;
/// alan adı farklıysa (status/active/durum) yine yakalanır, yoksa öğrenci gösterilir.
bool _isStudentActive(dynamic u) {
  final candidates = <String>[];
  void add(dynamic v) {
    if (v != null) {
      final s = v.toString().trim();
      if (s.isNotEmpty) candidates.add(s.toUpperCase());
    }
  }

  try {
    add(u.is_active);
  } catch (_) {}
  try {
    add(u.status);
  } catch (_) {}
  try {
    add(u.active);
  } catch (_) {}
  try {
    add(u.durum);
  } catch (_) {}

  const passive = {
    "FALSE",
    "PASIF",
    "PASİF",
    "PASSIVE",
    "INACTIVE",
    "0",
    "HAYIR",
    "NO",
  };
  const active = {"TRUE", "AKTIF", "AKTİF", "ACTIVE", "1", "EVET", "YES"};

  if (candidates.any(passive.contains)) return false;
  if (candidates.any(active.contains)) return true;
  return true;
}

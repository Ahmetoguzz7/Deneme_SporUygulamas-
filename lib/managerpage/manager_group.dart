/*
import 'dart:async';

import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_assignment.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_group_service.dart';
import 'package:EVOM_SPOR/widgets/data_error_state.dart';

// =========================================================================
// SCHEDULE ITEM
// =========================================================================
class ScheduleItem {
  String day;
  TimeOfDay startTime;
  TimeOfDay endTime;

  ScheduleItem({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  String get formatted =>
      "$day:${_formatTime(startTime)}-${_formatTime(endTime)}";

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  @override
  String toString() => formatted;
}

// =========================================================================
// 🔥 ANA SAYFA - PROFESYONEL GROUP MANAGEMENT
// =========================================================================
class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  late final OfflineGroupService _offlineGroupService;
  StreamSubscription? _dataUpdateSubscription;

  // UI state
  String _selectedBranchId = "";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  List<Group> _displayedGroups = [];
  bool _isInitializing = true;
  bool _hasError = false;

  // Modern Tema Renkleri
  static const Color _bg = Color(0xFFF0F4F8);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _warning = Color(0xFFF39C12);
  static const Color _danger = Color(0xFFE74C3C);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const List<Color> _gradientHeader = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _initOfflineService();

    _dataUpdateSubscription = _repo.onDataUpdated.listen((_) {
      if (mounted) _refreshData();
    });

    _initialize();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initOfflineService() async {
    _offlineGroupService = OfflineGroupService();
    await _offlineGroupService.init();
    _offlineGroupService.onSyncComplete.listen((_) {
      if (mounted) _refreshData();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    if (_repo.allGroups.isEmpty || !_repo.isLoaded) {
      setState(() {
        _isInitializing = true;
        _hasError = false;
      });

      try {
        await _repo.loadAllData();
      } catch (e) {
        print("Grup ekranı veri yükleme hatası: $e");
      }
    }

    if (!mounted) return;

    if (_repo.hasError) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
      });
      return;
    }

    _applyFilters();
    setState(() => _isInitializing = false);
  }

  Future<void> _retryInitialize() async {
    await _initialize();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Group> groups = _selectedBranchId.isEmpty
        ? List.from(_repo.allGroups)
        : _repo.allGroups
              .where((g) => g.branches_id == _selectedBranchId)
              .toList();

    if (_searchQuery.isNotEmpty) {
      groups = groups.where((g) {
        return g.name.toLowerCase().contains(_searchQuery) ||
            _getBranchName(
              g.branches_id,
            ).toLowerCase().contains(_searchQuery) ||
            _getSportName(g.sports_id).toLowerCase().contains(_searchQuery);
      }).toList();
    }

    _displayedGroups = groups;
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId ?? "";
      _applyFilters();
    });
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  String _formatDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      DateTime? date = DateTime.tryParse(dateStr);
      if (date != null) {
        return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  int _getStudentCountInGroup(String groupId) =>
      _getStudentsInGroup(groupId).length;

  List<Users> _getStudentsInGroup(String groupId) {
    final relations = _repo.getGroupStudentsByGroupId(groupId);
    final studentIds = relations.map((r) => r.student_id).toSet();
    return _repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' &&
              studentIds.contains(u.app) &&
              u.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();
  }

  String _getCoachName(String coachId) {
    if (coachId.isEmpty) return "Atanmamış";
    try {
      final coach = _repo.allCoaches.firstWhere((c) => c.coach_id == coachId);
      final user = _repo.getUserById(coach.user_id);
      return user != null
          ? "${user.first_name} ${user.last_name}".trim()
          : "Atanmamış";
    } catch (_) {
      return "Atanmamış";
    }
  }

  String _getBranchName(String branchId) =>
      _repo.getBranchById(branchId)?.name ?? "Belirtilmemiş";
  String _getSportName(String sportId) =>
      _repo.getSportById(sportId)?.name ?? "Belirtilmemiş";

  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu $actionText yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE" ? _danger : _success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final index = _repo.allGroups.indexWhere(
      (g) => g.groups_id == group.groups_id,
    );
    if (index != -1) {
      _repo.allGroups[index] = Group(
        groups_id: group.groups_id,
        branches_id: group.branches_id,
        coach_id: group.coach_id,
        sports_id: group.sports_id,
        name: group.name,
        schedule: group.schedule,
        capacity: group.capacity,
        monthly_fee: group.monthly_fee,
        is_active: newStatus,
      );
      _refreshData();
    }

    unawaited(
      _offlineGroupService.toggleGroupStatus(
        group.groups_id,
        newStatus == "TRUE",
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Grup $actionText yapıldı!"),
        backgroundColor: _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _removeStudentFromGroup(
    Users student,
    Group currentGroup,
  ) async {
    final otherGroups = _repo.allGroups
        .where((g) => g.groups_id != currentGroup.groups_id)
        .toList();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Öğrenci İşlemleri"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _danger),
              title: const Text("Gruptan Çıkar"),
              subtitle: Text("${student.first_name} bu gruptan çıkarılacak"),
              onTap: () => Navigator.pop(ctx, "remove"),
            ),
            if (otherGroups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: _warning),
                title: const Text("Başka Gruba Taşı"),
                subtitle: Text(
                  "${student.first_name} başka bir gruba taşınacak",
                ),
                onTap: () => Navigator.pop(ctx, "transfer"),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("İptal"),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (result == "remove") {
        setState(() {
          _repo.allGroupStudents.removeWhere(
            (r) =>
                r.student_id == student.app &&
                r.groups_id == currentGroup.groups_id,
          );
          _repo.refreshMapsOnly();
        });

        _refreshData();

        unawaited(() async {
          try {
            await _repo.refreshSingleTable('groups');
            await _offlineGroupService.removeStudentFromGroup(
              student.app,
              currentGroup.groups_id,
            );
          } catch (e) {
            print("Arka plan gruptan çıkarma hatası: $e");
          }
        }());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${student.first_name} gruptan çıkarıldı"),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else if (result == "transfer") {
        final targetGroup = await showDialog<Group>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Hedef Grup Seçin"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: otherGroups.length,
                itemBuilder: (ctx, index) {
                  final group = otherGroups[index];
                  return ListTile(
                    leading: const Icon(Icons.group, color: _accent),
                    title: Text(group.name),
                    subtitle: Text(
                      "Kapasite: ${group.capacity} | ${_getStudentCountInGroup(group.groups_id)} öğrenci",
                    ),
                    onTap: () => Navigator.pop(ctx, group),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("İptal"),
              ),
            ],
          ),
        );

        if (targetGroup == null) return;

        setState(() {
          _repo.allGroupStudents.removeWhere(
            (r) =>
                r.student_id == student.app &&
                r.groups_id == currentGroup.groups_id,
          );

          _repo.allGroupStudents.add(
            GroupStudent(
              group_students_id:
                  "local_${DateTime.now().millisecondsSinceEpoch}",
              groups_id: targetGroup.groups_id,
              student_id: student.app,
              is_active: "TRUE",
              enrolled_at: DateTime.now().toIso8601String(),
            ),
          );

          _repo.refreshMapsOnly();
        });

        _refreshData();

        unawaited(() async {
          try {
            await _repo.refreshSingleTable('groups');
            await _offlineGroupService.transferStudentToGroup(
              student.app,
              targetGroup.groups_id,
            );
          } catch (e) {
            print("Arka plan gruba taşıma hatası: $e");
          }
        }());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🔄 ${student.first_name} ${targetGroup.name} grubuna taşındı.",
            ),
            backgroundColor: _warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Hata oluştu: $e"),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showEditGroupDialog(Group group) {
    final nameCtrl = TextEditingController(text: group.name);
    final scheduleCtrl = TextEditingController(text: group.schedule);
    final capCtrl = TextEditingController(text: group.capacity);
    final feeCtrl = TextEditingController(text: group.monthly_fee);
    String? selBranch = group.branches_id;
    String? selCoach = group.coach_id;
    String? selSport = group.sports_id;
    bool isSubmitting = false;

    List<Map<String, String>> coachList = [];
    for (var coach in _repo.allCoaches) {
      final user = _repo.getUserById(coach.user_id);
      coachList.add({
        'id': coach.coach_id,
        'name': user != null
            ? "${user.first_name} ${user.last_name}".trim()
            : "Bilinmeyen",
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: _accent),
              SizedBox(width: 10),
              Text(
                "Grubu Düzenle",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selBranch,
                    decoration: InputDecoration(
                      labelText: "Şube",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    items: _repo.allBranches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.branches_id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selBranch = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selSport,
                    decoration: InputDecoration(
                      labelText: "Spor Branşı",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.sports_basketball),
                    ),
                    items: _repo.allSports
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.sports_id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selSport = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selCoach,
                    hint: const Text("Antrenör Seçiniz"),
                    decoration: InputDecoration(
                      labelText: "Antrenör",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: coachList
                        .map(
                          (coach) => DropdownMenuItem(
                            value: coach['id'],
                            child: Text(coach['name']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selCoach = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Grup Adı",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.group),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleCtrl,
                    decoration: InputDecoration(
                      labelText: "Program (Saat/Gün)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Kapasite",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.people),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Aylık Ücret",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.payments),
                            suffixText: "TL",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "İptal",
                style: TextStyle(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (selBranch == null ||
                          selSport == null ||
                          nameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Lütfen tüm zorunlu alanları doldurun!",
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final updateData = {
                        "branches_id": selBranch,
                        "coach_id": selCoach ?? "",
                        "sports_id": selSport,
                        "groups_name": nameCtrl.text,
                        "schedule": scheduleCtrl.text,
                        "capacity": capCtrl.text.isEmpty ? "0" : capCtrl.text,
                        "monthly_fee": feeCtrl.text.isEmpty
                            ? "0"
                            : feeCtrl.text,
                        "is_active": group.is_active,
                      };

                      final idx = _repo.allGroups.indexWhere(
                        (g) => g.groups_id == group.groups_id,
                      );
                      if (idx != -1) {
                        _repo.allGroups[idx] = Group(
                          groups_id: group.groups_id,
                          branches_id: updateData['branches_id']!,
                          coach_id: updateData['coach_id']!,
                          sports_id: updateData['sports_id']!,
                          name: updateData['groups_name']!,
                          schedule: updateData['schedule']!,
                          capacity: updateData['capacity']!,
                          monthly_fee: updateData['monthly_fee']!,
                          is_active: group.is_active,
                        );

                        _refreshData();
                      }

                      unawaited(
                        _offlineGroupService.updateGroup(
                          group.groups_id,
                          updateData,
                        ),
                      );

                      setDialogState(() => isSubmitting = false);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("✅ Grup güncellendi!"),
                          backgroundColor: _success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
              child: const Text(
                "Güncelle",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 MODERN UI BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _textPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Grup Yönetimi",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _accent, size: 22),
            onPressed: () async {
              await _repo.loadAllData(forceRefresh: true);
              _refreshData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("🔄 Veriler yenilendi"),
                  backgroundColor: _accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: "Verileri Yenile",
          ),
        ],
      ),
      body: _isInitializing
          ? _buildLoadingScreen()
          : _hasError
          ? DataErrorState(
              message: _repo.lastErrorMessage,
              onRetry: _retryInitialize,
            )
          : Column(
              children: [
                // 🔥 Üst Filtre ve Arama Çubuğu
                Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Arama Kutusu
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Grup veya şube ara...",
                                  hintStyle: TextStyle(
                                    color: _textSecondary.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: _accent,
                                    size: 18,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear_rounded,
                                            color: _textSecondary,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = "";
                                              _applyFilters();
                                            });
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Şube Dropdown
                          if (_repo.allBranches.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedBranchId.isEmpty
                                        ? null
                                        : _selectedBranchId,
                                    isExpanded: true,
                                    isDense: true,
                                    hint: const Text(
                                      "Tüm Şubeler",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: _textSecondary,
                                      size: 18,
                                    ),
                                    dropdownColor: _surface,
                                    items: [
                                      const DropdownMenuItem(
                                        value: "",
                                        child: Text(
                                          "Tüm Şubeler",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      ..._repo.allBranches.map(
                                        (branch) => DropdownMenuItem(
                                          value: branch.branches_id,
                                          child: Text(
                                            branch.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: _onBranchChanged,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Grup Listesi
                Expanded(
                  child: _displayedGroups.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _repo.loadAllData(forceRefresh: true);
                            _refreshData();
                          },
                          color: _accent,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _displayedGroups.length,
                            itemBuilder: (context, index) =>
                                _buildGroupCard(_displayedGroups[index]),
                          ),
                        ),
                ),
                const VersionFooter(),
                const SizedBox(height: 4),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _textPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
        onPressed: () => _showAddGroupBottomSheet(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent),
          ),
          const SizedBox(height: 16),
          Text(
            "Gruplar yükleniyor...",
            style: TextStyle(fontSize: 15, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String branchName = _selectedBranchId.isNotEmpty
        ? (_repo.getBranchById(_selectedBranchId)?.name ?? "")
        : "";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group_off, size: 56, color: _accent),
            ),
            const SizedBox(height: 20),
            Text(
              branchName.isNotEmpty
                  ? "$branchName şubesinde grup bulunmuyor"
                  : "Henüz grup bulunmuyor",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Yeni grup eklemek için sağ alttaki + butonuna tıklayın",
              style: TextStyle(color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: _accent,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users user,
  ) {
    final String heroTag =
        'profile_photo_${user.profile_photo_url}_${user.app}';
    Widget imageWidget = imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(user, size),
            ),
          )
        : _buildDefaultAvatar(user, size);

    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Hero(tag: heroTag, child: imageWidget),
    );
  }

  Widget _buildGroupCard(Group group) {
    final coachName = _getCoachName(group.coach_id);
    final branchName = _getBranchName(group.branches_id);
    final sportName = _getSportName(group.sports_id);
    final studentsInGroup = _getStudentsInGroup(group.groups_id);
    final isActive = group.is_active == "TRUE";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _gradientHeader),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.group_rounded, color: Colors.white, size: 24),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${studentsInGroup.length} öğrenci • ${group.capacity} kapasite",
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                coachName != "Atanmamış"
                    ? "👨‍🏫 $coachName"
                    : "👨‍🏫 Antrenör atanmamış",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: coachName != "Atanmamış" ? _accent : _textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? _success.withOpacity(0.1)
                    : _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? _success.withOpacity(0.3)
                      : _danger.withOpacity(0.3),
                ),
              ),
              child: Text(
                isActive ? "Aktif" : "Pasif",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? _success : _danger,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: _textSecondary.withOpacity(0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditGroupDialog(group);
                } else if (value == 'toggle_status') {
                  await _toggleGroupStatus(group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: _accent),
                      SizedBox(width: 10),
                      Text("Düzenle", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                        color: isActive ? _danger : _success,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isActive ? "Pasif Yap" : "Aktif Yap",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.business_rounded,
                        "Şube",
                        branchName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoTile(
                        Icons.sports_basketball_rounded,
                        "Spor",
                        sportName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.schedule_rounded,
                        "Program",
                        group.schedule.isEmpty
                            ? "Belirtilmemiş"
                            : group.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Listesi (${studentsInGroup.length})",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                studentsInGroup.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            "Bu grupta henüz öğrenci yok",
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: studentsInGroup.map((student) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              leading: _buildProfileImage(
                                context,
                                student.profile_photo_url,
                                40.0,
                                student,
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                student.phone.isNotEmpty
                                    ? student.phone
                                    : "Telefon yok",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: _danger,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removeStudentFromGroup(student, group),
                                tooltip: "Gruptan Çıkar",
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StudentAssignmentScreen(group: group),
                          ),
                        ).then((_) {
                          _refreshData();
                        }),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text("Öğrenci Ata"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: _textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
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

  void _showAddGroupBottomSheet() {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    String? selBranch;
    String? selCoach;
    String? selSport;
    bool isSubmitting = false;
    List<ScheduleItem> scheduleItems = [];
    final List<String> days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];

    List<Map<String, String>> coachList = [];
    for (var coach in _repo.allCoaches) {
      final user = _repo.getUserById(coach.user_id);
      coachList.add({
        'id': coach.coach_id,
        'name': user != null
            ? "${user.first_name} ${user.last_name}".trim()
            : "Bilinmeyen",
      });
    }

    Future<TimeOfDay?> _selectTime(BuildContext context, String title) async {
      return await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: title,
        cancelText: "İptal",
        confirmText: "Seç",
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: _gradientHeader),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Yeni Grup Oluştur",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Şube",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                        hint: const Text("Şube Seçiniz"),
                        items: _repo.allBranches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.branches_id,
                                child: Text(b.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selBranch = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Spor Branşı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.sports_basketball),
                        ),
                        hint: const Text("Spor Seçiniz"),
                        items: _repo.allSports
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.sports_id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selSport = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        hint: const Text("Antrenör Seçiniz (Opsiyonel)"),
                        decoration: InputDecoration(
                          labelText: "Antrenör",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        items: coachList
                            .map(
                              (coach) => DropdownMenuItem(
                                value: coach['id'],
                                child: Text(coach['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selCoach = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Grup Adı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.schedule, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Program (Gün ve Saatler)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (scheduleItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: scheduleItems.asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: _accent,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.formatted,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: _danger,
                                            ),
                                            onPressed: () => setModalState(
                                              () => scheduleItems.removeAt(idx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  String? selectedDay =
                                      await showDialog<String>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Gün Seç"),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: days.length,
                                              itemBuilder: (ctx, index) {
                                                final day = days[index];
                                                final bool alreadyExists =
                                                    scheduleItems.any(
                                                      (item) => item.day == day,
                                                    );
                                                return ListTile(
                                                  title: Text(day),
                                                  trailing: alreadyExists
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: _success,
                                                        )
                                                      : null,
                                                  onTap: alreadyExists
                                                      ? null
                                                      : () => Navigator.pop(
                                                          ctx,
                                                          day,
                                                        ),
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text("İptal"),
                                            ),
                                          ],
                                        ),
                                      );
                                  if (selectedDay == null) return;
                                  final startTime = await _selectTime(
                                    context,
                                    "$selectedDay - Başlangıç Saati",
                                  );
                                  if (startTime == null) return;
                                  final endTime = await _selectTime(
                                    context,
                                    "$selectedDay - Bitiş Saati",
                                  );
                                  if (endTime == null) return;
                                  setModalState(
                                    () => scheduleItems.add(
                                      ScheduleItem(
                                        day: selectedDay,
                                        startTime: startTime,
                                        endTime: endTime,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Program Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: capCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Kapasite",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.people),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: feeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Aylık Ücret",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.payments),
                                suffixText: "TL",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selBranch == null ||
                                      selSport == null ||
                                      nameCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Lütfen zorunlu alanları doldurun!",
                                        ),
                                        backgroundColor: _danger,
                                      ),
                                    );
                                    return;
                                  }
                                  String scheduleString =
                                      scheduleItems.isNotEmpty
                                      ? scheduleItems
                                            .map((item) => item.formatted)
                                            .join(",")
                                      : "";

                                  setModalState(() => isSubmitting = true);

                                  final localId =
                                      "local_${DateTime.now().millisecondsSinceEpoch}";
                                  final newGroupData = {
                                    "branches_id": selBranch,
                                    "coach_id": selCoach ?? "",
                                    "sports_id": selSport,
                                    "groups_name": nameCtrl.text,
                                    "schedule": scheduleString,
                                    "capacity": capCtrl.text.isEmpty
                                        ? "0"
                                        : capCtrl.text,
                                    "monthly_fee": feeCtrl.text.isEmpty
                                        ? "0"
                                        : feeCtrl.text,
                                    "is_active": "TRUE",
                                  };

                                  _repo.allGroups.add(
                                    Group(
                                      groups_id: localId,
                                      branches_id: selBranch!,
                                      coach_id: selCoach ?? "",
                                      sports_id: selSport!,
                                      name: nameCtrl.text,
                                      schedule: scheduleString,
                                      capacity: capCtrl.text.isEmpty
                                          ? "0"
                                          : capCtrl.text,
                                      monthly_fee: feeCtrl.text.isEmpty
                                          ? "0"
                                          : feeCtrl.text,
                                      is_active: "TRUE",
                                    ),
                                  );

                                  _refreshData();
                                  unawaited(
                                    _offlineGroupService.addGroup(newGroupData),
                                  );

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "✅ Grup başarıyla oluşturuldu!",
                                      ),
                                      backgroundColor: _success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
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
                              : const Text(
                                  "Grubu Oluştur",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

import 'dart:async';

import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_assignment.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_group_service.dart';
import 'package:EVOM_SPOR/widgets/data_error_state.dart';

// =========================================================================
// SCHEDULE ITEM
// =========================================================================
class ScheduleItem {
  String day;
  TimeOfDay startTime;
  TimeOfDay endTime;

  ScheduleItem({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  String get formatted =>
      "$day:${_formatTime(startTime)}-${_formatTime(endTime)}";

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  @override
  String toString() => formatted;
}

// =========================================================================
// 🔥 ANA SAYFA - PROFESYONEL GROUP MANAGEMENT
// =========================================================================
class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  late final OfflineGroupService _offlineGroupService;
  StreamSubscription? _dataUpdateSubscription;
  StreamSubscription? _groupSyncSub;

  // UI state
  String _selectedBranchId = "";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  List<Group> _displayedGroups = [];
  bool _isInitializing = true;
  bool _hasError = false;

  // 🔒 İşlem Kilit / Yükleme Durumu
  bool _isGlobalProcessing = false;
  String _processingMessage = "İşlem yapılıyor, lütfen bekleyin...";

  // Modern Tema Renkleri
  static const Color _bg = Color(0xFFF0F4F8);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _warning = Color(0xFFF39C12);
  static const Color _danger = Color(0xFFE74C3C);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const List<Color> _gradientHeader = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _initOfflineService();

    _dataUpdateSubscription = _repo.onDataUpdated.listen((_) {
      if (mounted) _refreshData();
    });

    _initialize();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel();
    _groupSyncSub?.cancel();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initOfflineService() async {
    _offlineGroupService = OfflineGroupService();
    await _offlineGroupService.init();
    _groupSyncSub?.cancel();
    _groupSyncSub = _offlineGroupService.onSyncComplete.listen((_) async {
      if (!mounted) return;
      // Offline'dayken kuyruğa alınan işlemler sonradan buluta gittiyse,
      // kuyruk boşalınca öğrenci-grup tablosunu Sheets'ten eşitle.
      // (Ekrandan yapılan işlem sırasında zaten kendi akışı eşitliyor.)
      if (_offlineGroupService.pendingCount == 0 && !_isGlobalProcessing) {
        await _repo.refreshSingleTable('group_students');
      }
      if (mounted) _refreshData();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    if (_repo.allGroups.isEmpty || !_repo.isLoaded) {
      setState(() {
        _isInitializing = true;
        _hasError = false;
      });

      try {
        await _repo.loadAllData();
      } catch (e) {
        print("Grup ekranı veri yükleme hatası: $e");
      }
    }

    if (!mounted) return;

    if (_repo.hasError) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
      });
      return;
    }

    _applyFilters();
    setState(() => _isInitializing = false);
  }

  Future<void> _retryInitialize() async {
    await _initialize();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Group> groups = _selectedBranchId.isEmpty
        ? List.from(_repo.allGroups)
        : _repo.allGroups
              .where((g) => g.branches_id == _selectedBranchId)
              .toList();

    if (_searchQuery.isNotEmpty) {
      groups = groups.where((g) {
        return g.name.toLowerCase().contains(_searchQuery) ||
            _getBranchName(
              g.branches_id,
            ).toLowerCase().contains(_searchQuery) ||
            _getSportName(g.sports_id).toLowerCase().contains(_searchQuery);
      }).toList();
    }

    _displayedGroups = groups;
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId ?? "";
      _applyFilters();
    });
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  int _getStudentCountInGroup(String groupId) =>
      _getStudentsInGroup(groupId).length;

  List<Users> _getStudentsInGroup(String groupId) {
    final relations = _repo.getGroupStudentsByGroupId(groupId);
    final studentIds = relations.map((r) => r.student_id).toSet();
    return _repo.allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'student' &&
              studentIds.contains(u.app) &&
              u.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();
  }

  String _getCoachName(String coachId) {
    if (coachId.isEmpty) return "Atanmamış";
    try {
      final coach = _repo.allCoaches.firstWhere((c) => c.coach_id == coachId);
      final user = _repo.getUserById(coach.user_id);
      return user != null
          ? "${user.first_name} ${user.last_name}".trim()
          : "Atanmamış";
    } catch (_) {
      return "Atanmamış";
    }
  }

  String _getBranchName(String branchId) =>
      _repo.getBranchById(branchId)?.name ?? "Belirtilmemiş";
  String _getSportName(String sportId) =>
      _repo.getSportById(sportId)?.name ?? "Belirtilmemiş";

  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu $actionText yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE" ? _danger : _success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final index = _repo.allGroups.indexWhere(
      (g) => g.groups_id == group.groups_id,
    );
    if (index != -1) {
      _repo.allGroups[index] = Group(
        groups_id: group.groups_id,
        branches_id: group.branches_id,
        coach_id: group.coach_id,
        sports_id: group.sports_id,
        name: group.name,
        schedule: group.schedule,
        capacity: group.capacity,
        monthly_fee: group.monthly_fee,
        is_active: newStatus,
      );
      _refreshData();
    }

    unawaited(
      _offlineGroupService.toggleGroupStatus(
        group.groups_id,
        newStatus == "TRUE",
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Grup $actionText yapıldı!"),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _removeStudentFromGroup(
    Users student,
    Group currentGroup,
  ) async {
    final otherGroups = _repo.allGroups
        .where((g) => g.groups_id != currentGroup.groups_id)
        .toList();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Öğrenci İşlemleri"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _danger),
              title: const Text("Gruptan Çıkar"),
              subtitle: Text("${student.first_name} bu gruptan çıkarılacak"),
              onTap: () => Navigator.pop(ctx, "remove"),
            ),
            if (otherGroups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: _warning),
                title: const Text("Başka Gruba Taşı"),
                subtitle: Text(
                  "${student.first_name} başka bir gruba taşınacak",
                ),
                onTap: () => Navigator.pop(ctx, "transfer"),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("İptal"),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    if (_isGlobalProcessing) return; // çift tıklama koruması

    try {
      if (result == "remove") {
        setState(() {
          _isGlobalProcessing = true;
          _processingMessage = "Öğrenci gruptan çıkarılıyor...";
        });

        // 1. Hive'a yaz + Google Sheets'e gönder (yazım bitene kadar bekler)
        final saved = await _offlineGroupService.removeStudentFromGroup(
          student.app,
          currentGroup.groups_id,
          waitForCloud: true,
        );
        if (!saved) throw Exception("Yerel kayıt başarısız");
        final cloudDone = _offlineGroupService.pendingCount == 0;

        // 2. SQLite + RAM'i güncelle (ekrana girip çıkınca da kalıcı olsun)
        await _repo.applyStudentGroupChange(
          studentId: student.app,
          fromGroupId: currentGroup.groups_id,
        );

        if (!mounted) return;
        setState(() {
          _isGlobalProcessing = false;
          _applyFilters();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cloudDone
                  ? "✅ ${student.first_name} gruptan çıkarıldı"
                  : "✅ ${student.first_name} gruptan çıkarıldı (bağlantı gelince buluta eşitlenecek)",
            ),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // 3. Sheets ile arka planda sessizce eşitle (ekranı bekletmez)
        if (cloudDone) {
          unawaited(
            _silentSyncAfterChange(
              studentId: student.app,
              fromGroupId: currentGroup.groups_id,
            ),
          );
        }
      } else if (result == "transfer") {
        final targetGroup = await showDialog<Group>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Hedef Grup Seçin"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: otherGroups.length,
                itemBuilder: (ctx, index) {
                  final group = otherGroups[index];
                  return ListTile(
                    leading: const Icon(Icons.group, color: _accent),
                    title: Text(group.name),
                    subtitle: Text(
                      "Kapasite: ${group.capacity} | ${_getStudentCountInGroup(group.groups_id)} öğrenci",
                    ),
                    onTap: () => Navigator.pop(ctx, group),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("İptal"),
              ),
            ],
          ),
        );

        if (targetGroup == null || !mounted) return;

        setState(() {
          _isGlobalProcessing = true;
          _processingMessage =
              "Öğrenci ${targetGroup.name} grubuna taşınıyor...";
        });

        // 1. Hive'a yaz + Google Sheets'e gönder (yazım bitene kadar bekler)
        final saved = await _offlineGroupService.transferStudentToGroup(
          student.app,
          targetGroup.groups_id,
          waitForCloud: true,
        );
        if (!saved) throw Exception("Yerel kayıt başarısız");
        final cloudDone = _offlineGroupService.pendingCount == 0;

        // 2. SQLite + RAM'i güncelle (ekrana girip çıkınca da kalıcı olsun)
        await _repo.applyStudentGroupChange(
          studentId: student.app,
          fromGroupId: currentGroup.groups_id,
          toGroupId: targetGroup.groups_id,
        );

        if (!mounted) return;
        setState(() {
          _isGlobalProcessing = false;
          _applyFilters();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cloudDone
                  ? "🔄 ${student.first_name} ${targetGroup.name} grubuna taşındı."
                  : "🔄 ${student.first_name} ${targetGroup.name} grubuna taşındı (bağlantı gelince buluta eşitlenecek)",
            ),
            backgroundColor: _warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // 3. Sheets ile arka planda sessizce eşitle (ekranı bekletmez)
        if (cloudDone) {
          unawaited(
            _silentSyncAfterChange(
              studentId: student.app,
              fromGroupId: currentGroup.groups_id,
              toGroupId: targetGroup.groups_id,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGlobalProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Kaydedilmedi, lütfen birazdan tekrar deneyin! ($e)",
            ),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // -----------------------------------------------------------------------
  // ÖĞRENCİ TAŞI / ÇIKAR YARDIMCILARI
  // -----------------------------------------------------------------------

  bool _isStudentInGroup(String studentId, String groupId) => _repo
      .allGroupStudents
      .any((r) => r.student_id == studentId && r.groups_id == groupId);

  /// Sheets'ten SADECE group_students tablosunu çeker (hızlı).
  /// Sheets henüz değişikliği yansıtmadıysa (eski veri geldiyse)
  /// ekran geri dönmesin diye yerel sonucu tekrar uygular.
  Future<void> _silentSyncAfterChange({
    required String studentId,
    required String fromGroupId,
    String? toGroupId,
  }) async {
    try {
      await _repo.refreshSingleTable('group_students');

      final stale = toGroupId != null
          ? (!_isStudentInGroup(studentId, toGroupId) ||
                _isStudentInGroup(studentId, fromGroupId))
          : _isStudentInGroup(studentId, fromGroupId);

      if (stale) {
        await _repo.applyStudentGroupChange(
          studentId: studentId,
          fromGroupId: fromGroupId,
          toGroupId: toGroupId,
        );
      }
    } catch (e) {
      print("Arka plan senkron hatası: $e");
    }
    if (mounted) _refreshData();
  }

  void _showEditGroupDialog(Group group) {
    final nameCtrl = TextEditingController(text: group.name);
    final scheduleCtrl = TextEditingController(text: group.schedule);
    final capCtrl = TextEditingController(text: group.capacity);
    final feeCtrl = TextEditingController(text: group.monthly_fee);
    String? selBranch = group.branches_id;
    String? selCoach = group.coach_id;
    String? selSport = group.sports_id;
    bool isSubmitting = false;

    List<Map<String, String>> coachList = [];
    for (var coach in _repo.allCoaches) {
      final user = _repo.getUserById(coach.user_id);
      coachList.add({
        'id': coach.coach_id,
        'name': user != null
            ? "${user.first_name} ${user.last_name}".trim()
            : "Bilinmeyen",
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: _accent),
              SizedBox(width: 10),
              Text(
                "Grubu Düzenle",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selBranch,
                    decoration: InputDecoration(
                      labelText: "Şube",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    items: _repo.allBranches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.branches_id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selBranch = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selSport,
                    decoration: InputDecoration(
                      labelText: "Spor Branşı",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.sports_basketball),
                    ),
                    items: _repo.allSports
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.sports_id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selSport = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selCoach,
                    hint: const Text("Antrenör Seçiniz"),
                    decoration: InputDecoration(
                      labelText: "Antrenör",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: coachList
                        .map(
                          (coach) => DropdownMenuItem(
                            value: coach['id'],
                            child: Text(coach['name']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selCoach = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Grup Adı",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.group),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleCtrl,
                    decoration: InputDecoration(
                      labelText: "Program (Saat/Gün)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Kapasite",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.people),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Aylık Ücret",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.payments),
                            suffixText: "TL",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "İptal",
                style: TextStyle(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (selBranch == null ||
                          selSport == null ||
                          nameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Lütfen tüm zorunlu alanları doldurun!",
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final updateData = {
                        "branches_id": selBranch,
                        "coach_id": selCoach ?? "",
                        "sports_id": selSport,
                        "groups_name": nameCtrl.text,
                        "schedule": scheduleCtrl.text,
                        "capacity": capCtrl.text.isEmpty ? "0" : capCtrl.text,
                        "monthly_fee": feeCtrl.text.isEmpty
                            ? "0"
                            : feeCtrl.text,
                        "is_active": group.is_active,
                      };

                      final idx = _repo.allGroups.indexWhere(
                        (g) => g.groups_id == group.groups_id,
                      );
                      if (idx != -1) {
                        _repo.allGroups[idx] = Group(
                          groups_id: group.groups_id,
                          branches_id: updateData['branches_id']!,
                          coach_id: updateData['coach_id']!,
                          sports_id: updateData['sports_id']!,
                          name: updateData['groups_name']!,
                          schedule: updateData['schedule']!,
                          capacity: updateData['capacity']!,
                          monthly_fee: updateData['monthly_fee']!,
                          is_active: group.is_active,
                        );

                        _refreshData();
                      }

                      unawaited(
                        _offlineGroupService.updateGroup(
                          group.groups_id,
                          updateData,
                        ),
                      );

                      if (mounted) {
                        setDialogState(() => isSubmitting = false);
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("✅ Grup güncellendi!"),
                            backgroundColor: _success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
              child: const Text(
                "Güncelle",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 MODERN UI BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isGlobalProcessing,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _textPrimary,
              size: 24,
            ),
            onPressed: () {
              if (!_isGlobalProcessing) Navigator.pop(context);
            },
          ),
          title: const Text(
            "Grup Yönetimi",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: _accent, size: 22),
              onPressed: () async {
                if (_isGlobalProcessing) return;
                await _repo.loadAllData(forceRefresh: true);
                _refreshData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("🔄 Veriler yenilendi"),
                    backgroundColor: _accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: "Verileri Yenile",
            ),
          ],
        ),
        body: Stack(
          children: [
            _isInitializing
                ? _buildLoadingScreen()
                : _hasError
                ? DataErrorState(
                    message: _repo.lastErrorMessage,
                    onRetry: _retryInitialize,
                  )
                : Column(
                    children: [
                      Container(
                        color: _surface,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _bg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _border),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: const TextStyle(
                                        color: _textPrimary,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Grup veya şube ara...",
                                        hintStyle: TextStyle(
                                          color: _textSecondary.withOpacity(
                                            0.6,
                                          ),
                                          fontSize: 12,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          color: _accent,
                                          size: 18,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(
                                                  Icons.clear_rounded,
                                                  color: _textSecondary,
                                                  size: 16,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = "";
                                                    _applyFilters();
                                                  });
                                                },
                                              )
                                            : null,
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_repo.allBranches.isNotEmpty)
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedBranchId.isEmpty
                                              ? null
                                              : _selectedBranchId,
                                          isExpanded: true,
                                          isDense: true,
                                          hint: const Text(
                                            "Tüm Şubeler",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _textSecondary,
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: _textSecondary,
                                            size: 18,
                                          ),
                                          dropdownColor: _surface,
                                          items: [
                                            const DropdownMenuItem(
                                              value: "",
                                              child: Text(
                                                "Tüm Şubeler",
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            ..._repo.allBranches.map(
                                              (branch) => DropdownMenuItem(
                                                value: branch.branches_id,
                                                child: Text(
                                                  branch.name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: _onBranchChanged,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _displayedGroups.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: () async {
                                  if (_isGlobalProcessing) return;
                                  await _repo.loadAllData(forceRefresh: true);
                                  _refreshData();
                                },
                                color: _accent,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _displayedGroups.length,
                                  itemBuilder: (context, index) =>
                                      _buildGroupCard(_displayedGroups[index]),
                                ),
                              ),
                      ),
                      const VersionFooter(),
                      const SizedBox(height: 4),
                    ],
                  ),

            // 🔥 Tam Ekran İşlem Kilidi (Overlay)
            if (_isGlobalProcessing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: _accent),
                        const SizedBox(height: 20),
                        const Text(
                          "İşlem Devam Ediyor",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _processingMessage,
                          style: TextStyle(fontSize: 13, color: _textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Lütfen sayfadan çıkmayın ve bekleyin.",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: _isGlobalProcessing
            ? null
            : FloatingActionButton(
                backgroundColor: _textPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
                onPressed: () => _showAddGroupBottomSheet(),
              ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent),
          ),
          const SizedBox(height: 16),
          Text(
            "Gruplar yükleniyor...",
            style: TextStyle(fontSize: 15, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String branchName = _selectedBranchId.isNotEmpty
        ? (_repo.getBranchById(_selectedBranchId)?.name ?? "")
        : "";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group_off, size: 56, color: _accent),
            ),
            const SizedBox(height: 20),
            Text(
              branchName.isNotEmpty
                  ? "$branchName şubesinde grup bulunmuyor"
                  : "Henüz grup bulunmuyor",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Yeni grup eklemek için sağ alttaki + butonuna tıklayın",
              style: TextStyle(color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: _accent,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users user,
  ) {
    final String heroTag =
        'profile_photo_${user.profile_photo_url}_${user.app}';
    Widget imageWidget = imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(user, size),
            ),
          )
        : _buildDefaultAvatar(user, size);

    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Hero(tag: heroTag, child: imageWidget),
    );
  }

  Widget _buildGroupCard(Group group) {
    final coachName = _getCoachName(group.coach_id);
    final branchName = _getBranchName(group.branches_id);
    final sportName = _getSportName(group.sports_id);
    final studentsInGroup = _getStudentsInGroup(group.groups_id);
    final isActive = group.is_active == "TRUE";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        key: Key("group_${group.groups_id}_${studentsInGroup.length}"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _gradientHeader),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.group_rounded, color: Colors.white, size: 24),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${studentsInGroup.length} öğrenci • ${group.capacity} kapasite",
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                coachName != "Atanmamış"
                    ? "👨‍🏫 $coachName"
                    : "👨‍🏫 Antrenör atanmamış",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: coachName != "Atanmamış" ? _accent : _textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? _success.withOpacity(0.1)
                    : _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? _success.withOpacity(0.3)
                      : _danger.withOpacity(0.3),
                ),
              ),
              child: Text(
                isActive ? "Aktif" : "Pasif",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? _success : _danger,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: _textSecondary.withOpacity(0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditGroupDialog(group);
                } else if (value == 'toggle_status') {
                  await _toggleGroupStatus(group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: _accent),
                      SizedBox(width: 10),
                      Text("Düzenle", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                        color: isActive ? _danger : _success,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isActive ? "Pasif Yap" : "Aktif Yap",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.business_rounded,
                        "Şube",
                        branchName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoTile(
                        Icons.sports_basketball_rounded,
                        "Spor",
                        sportName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.schedule_rounded,
                        "Program",
                        group.schedule.isEmpty
                            ? "Belirtilmemiş"
                            : group.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Listesi (${studentsInGroup.length})",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                studentsInGroup.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            "Bu grupta henüz öğrenci yok",
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: studentsInGroup.map((student) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              leading: _buildProfileImage(
                                context,
                                student.profile_photo_url,
                                40.0,
                                student,
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                student.phone.isNotEmpty
                                    ? student.phone
                                    : "Telefon yok",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: _danger,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removeStudentFromGroup(student, group),
                                tooltip: "Gruptan Çıkar",
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StudentAssignmentScreen(group: group),
                          ),
                        ).then((_) {
                          _refreshData();
                        }),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text("Öğrenci Ata"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: _textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
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

  void _showAddGroupBottomSheet() {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    String? selBranch;
    String? selCoach;
    String? selSport;
    bool isSubmitting = false;
    List<ScheduleItem> scheduleItems = [];
    final List<String> days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];

    List<Map<String, String>> coachList = [];
    for (var coach in _repo.allCoaches) {
      final user = _repo.getUserById(coach.user_id);
      coachList.add({
        'id': coach.coach_id,
        'name': user != null
            ? "${user.first_name} ${user.last_name}".trim()
            : "Bilinmeyen",
      });
    }

    Future<TimeOfDay?> _selectTime(BuildContext context, String title) async {
      return await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: title,
        cancelText: "İptal",
        confirmText: "Seç",
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: _gradientHeader),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Yeni Grup Oluştur",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Şube",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                        hint: const Text("Şube Seçiniz"),
                        items: _repo.allBranches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.branches_id,
                                child: Text(b.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selBranch = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Spor Branşı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.sports_basketball),
                        ),
                        hint: const Text("Spor Seçiniz"),
                        items: _repo.allSports
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.sports_id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selSport = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        hint: const Text("Antrenör Seçiniz (Opsiyonel)"),
                        decoration: InputDecoration(
                          labelText: "Antrenör",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        items: coachList
                            .map(
                              (coach) => DropdownMenuItem(
                                value: coach['id'],
                                child: Text(coach['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => selCoach = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Grup Adı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.schedule, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Program (Gün ve Saatler)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (scheduleItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: scheduleItems.asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: _accent,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.formatted,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: _danger,
                                            ),
                                            onPressed: () => setModalState(
                                              () => scheduleItems.removeAt(idx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  String? selectedDay =
                                      await showDialog<String>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Gün Seç"),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: days.length,
                                              itemBuilder: (ctx, index) {
                                                final day = days[index];
                                                final bool alreadyExists =
                                                    scheduleItems.any(
                                                      (item) => item.day == day,
                                                    );
                                                return ListTile(
                                                  title: Text(day),
                                                  trailing: alreadyExists
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: _success,
                                                        )
                                                      : null,
                                                  onTap: alreadyExists
                                                      ? null
                                                      : () => Navigator.pop(
                                                          ctx,
                                                          day,
                                                        ),
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text("İptal"),
                                            ),
                                          ],
                                        ),
                                      );
                                  if (selectedDay == null) return;
                                  final startTime = await _selectTime(
                                    context,
                                    "$selectedDay - Başlangıç Saati",
                                  );
                                  if (startTime == null) return;
                                  final endTime = await _selectTime(
                                    context,
                                    "$selectedDay - Bitiş Saati",
                                  );
                                  if (endTime == null) return;
                                  setModalState(
                                    () => scheduleItems.add(
                                      ScheduleItem(
                                        day: selectedDay,
                                        startTime: startTime,
                                        endTime: endTime,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Program Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: capCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Kapasite",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.people),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: feeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Aylık Ücret",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.payments),
                                suffixText: "TL",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selBranch == null ||
                                      selSport == null ||
                                      nameCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Lütfen zorunlu alanları doldurun!",
                                        ),
                                        backgroundColor: _danger,
                                      ),
                                    );
                                    return;
                                  }
                                  String scheduleString =
                                      scheduleItems.isNotEmpty
                                      ? scheduleItems
                                            .map((item) => item.formatted)
                                            .join(",")
                                      : "";

                                  setModalState(() => isSubmitting = true);

                                  final localId =
                                      "local_${DateTime.now().millisecondsSinceEpoch}";
                                  final newGroupData = {
                                    "branches_id": selBranch,
                                    "coach_id": selCoach ?? "",
                                    "sports_id": selSport,
                                    "groups_name": nameCtrl.text,
                                    "schedule": scheduleString,
                                    "capacity": capCtrl.text.isEmpty
                                        ? "0"
                                        : capCtrl.text,
                                    "monthly_fee": feeCtrl.text.isEmpty
                                        ? "0"
                                        : feeCtrl.text,
                                    "is_active": "TRUE",
                                  };

                                  _repo.allGroups.add(
                                    Group(
                                      groups_id: localId,
                                      branches_id: selBranch!,
                                      coach_id: selCoach ?? "",
                                      sports_id: selSport!,
                                      name: nameCtrl.text,
                                      schedule: scheduleString,
                                      capacity: capCtrl.text.isEmpty
                                          ? "0"
                                          : capCtrl.text,
                                      monthly_fee: feeCtrl.text.isEmpty
                                          ? "0"
                                          : feeCtrl.text,
                                      is_active: "TRUE",
                                    ),
                                  );

                                  _refreshData();
                                  unawaited(
                                    _offlineGroupService.addGroup(newGroupData),
                                  );

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          "✅ Grup başarıyla oluşturuldu!",
                                        ),
                                        backgroundColor: _success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
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
                              : const Text(
                                  "Grubu Oluştur",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

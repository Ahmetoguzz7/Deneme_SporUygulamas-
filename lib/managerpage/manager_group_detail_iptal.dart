/* YENİ TASARIM*/
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
// 🔥 ANA SAYFA - OFFLINE-FIRST GROUP MANAGEMENT
// =========================================================================
class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final AppRepository _repo = AppRepository();
  late final OfflineGroupService _offlineGroupService;
  StreamSubscription? _dataUpdateSubscription; // 🔥 Canlı Dinleyici

  // UI state
  String _selectedBranchId = "";
  List<Group> _displayedGroups = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasError = false;

  // =========================================================================
  // 🔥 YAŞAM DÖNGÜSÜ
  // =========================================================================
  @override
  void initState() {
    super.initState();
    _initOfflineService();

    // 🔥 1. Arka planda veri güncellendiğinde ekranı otomatik yenilemek için dinle
    _dataUpdateSubscription = _repo.onDataUpdated.listen((_) {
      if (mounted) {
        _refreshData();
      }
    });

    _initialize();
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel(); // Sızıntıyı önle
    super.dispose();
  }

  Future<void> _initOfflineService() async {
    _offlineGroupService = OfflineGroupService();
    await _offlineGroupService.init();

    // Arka planda senkronizasyon bitince RAM'deki son halini ekrana basar
    _offlineGroupService.onSyncComplete.listen((_) {
      if (mounted) _refreshData();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    // 🔥 Akıllı Kontrol: RAM'de veri yoksa yükle, varsa bekleme yapma
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

    _applyBranchFilter();
    setState(() => _isInitializing = false);
  }

  Future<void> _retryInitialize() async {
    await _initialize();
  }

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================
  String _getTodayDateTurkish() =>
      DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now());
  String _formatDateShort(DateTime date) =>
      DateFormat('dd/MM/yyyy', 'tr_TR').format(date);
  String _formatDateTimeLong(DateTime date) =>
      DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(date);

  String _formatDateFromString(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      return _formatDateShort(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        final parts = dateStr.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('.');
          if (dateParts.length == 3) {
            date = DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
            );
          }
        }
      }
      if (date != null) {
        return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  // =========================================================================
  // 🔥 FİLTRELEME (RAM'DEN ANINDA YÜKLER)
  // =========================================================================
  void _applyBranchFilter() {
    if (_selectedBranchId.isEmpty) {
      _displayedGroups = List.from(_repo.allGroups);
    } else {
      _displayedGroups = _repo.allGroups
          .where((g) => g.branches_id == _selectedBranchId)
          .toList();
    }
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId ?? "";
      _applyBranchFilter();
    });
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _applyBranchFilter();
      });
    }
  }

  // =========================================================================
  // 🔥 YARDIMCI FONKSİYONLAR
  // =========================================================================
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

  // =========================================================================
  // 🔥 GRUP İŞLEMLERİ (RAM + OFFLINE-FIRST)
  // =========================================================================
  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu $actionText yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap"),
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
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Gruptan Çıkar"),
              subtitle: Text("${student.first_name} bu gruptan çıkarılacak"),
              onTap: () => Navigator.pop(ctx, "remove"),
            ),
            if (otherGroups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
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
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result == "transfer") {
        final targetGroup = await showDialog<Group>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Hedef Grup Seçin"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: otherGroups.length,
                itemBuilder: (ctx, index) {
                  final group = otherGroups[index];
                  return ListTile(
                    leading: const Icon(Icons.group, color: Colors.teal),
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
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Hata oluştu: $e"),
          backgroundColor: Colors.red,
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
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.indigo),
              SizedBox(width: 8),
              Text("Grubu Düzenle"),
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
                    decoration: const InputDecoration(
                      labelText: "Şube",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
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
                    decoration: const InputDecoration(
                      labelText: "Spor Branşı",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports_basketball),
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
                    decoration: const InputDecoration(
                      labelText: "Antrenör",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
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
                    decoration: const InputDecoration(
                      labelText: "Grup Adı",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Program (Saat/Gün)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Kapasite",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Aylık Ücret",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payments),
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
              child: const Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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
                        const SnackBar(
                          content: Text("✅ Grup güncellendi!"),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 UI BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Grup Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_repo.allBranches.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBranchId.isEmpty ? null : _selectedBranchId,
                  hint: const Text("Şube Seç"),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Tüm Şubeler"),
                    ),
                    ..._repo.allBranches.map(
                      (branch) => DropdownMenuItem(
                        value: branch.branches_id,
                        child: Text(branch.name),
                      ),
                    ),
                  ],
                  onChanged: _onBranchChanged,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _repo.loadAllData(forceRefresh: true);
              _refreshData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🔄 Veriler yenilendi"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const VersionFooter(),
          const SizedBox(height: 4),
        ],
      ),
      body: _isInitializing
          ? _buildLoadingScreen()
          : _hasError
          ? DataErrorState(
              message: _repo.lastErrorMessage,
              onRetry: _retryInitialize,
            )
          : _displayedGroups.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                await _repo.loadAllData(forceRefresh: true);
                _refreshData();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _displayedGroups.length,
                itemBuilder: (context, index) =>
                    _buildGroupCard(_displayedGroups[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E293B),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddGroupBottomSheet(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E293B)),
          SizedBox(height: 16),
          Text("Gruplar yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String branchName = _selectedBranchId.isNotEmpty
        ? (_repo.getBranchById(_selectedBranchId)?.name ?? "")
        : "";
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
            child: const Icon(Icons.group_off, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Text(
            branchName.isNotEmpty
                ? "$branchName şubesinde grup bulunmuyor"
                : "Henüz grup bulunmuyor",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            branchName.isNotEmpty
                ? "Bu şubeye yeni grup eklemek için + butonuna tıklayın"
                : "Yeni grup eklemek için + butonuna tıklayın",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.group, color: Colors.indigo),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${studentsInGroup.length} öğrenci • ${group.capacity} kapasite",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              coachName != "Atanmamış"
                  ? "👨‍🏫 $coachName"
                  : "👨‍🏫 Antrenör atanmamış",
              style: TextStyle(
                fontSize: 12,
                color: coachName != "Atanmamış" ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: group.is_active == "TRUE"
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                group.is_active == "TRUE" ? "Aktif" : "Pasif",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: group.is_active == "TRUE" ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
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
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text("Düzenle"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        group.is_active == "TRUE"
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: group.is_active == "TRUE"
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(Icons.business, "Şube", branchName),
                    ),
                    Expanded(
                      child: _buildInfoTile(
                        Icons.sports_basketball,
                        "Spor",
                        sportName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.schedule,
                        "Program",
                        group.schedule.isEmpty
                            ? "Belirtilmemiş"
                            : group.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (group.coach_id.isNotEmpty)
                  _buildInfoTile(Icons.person, "Antrenör ID", group.coach_id),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Listesi (${studentsInGroup.length})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                studentsInGroup.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Bu grupta henüz öğrenci yok",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Öğrenci eklemek için 'Öğrenci Ata' butonuna tıklayın",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: studentsInGroup.map((student) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: _buildProfileImage(
                                context,
                                student.profile_photo_url,
                                45.0,
                                student,
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                student.b_date.isNotEmpty
                                    ? _formatDateTurkish(student.b_date)
                                    : "Doğum tarihi yok",
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _removeStudentFromGroup(student, group),
                                tooltip: "Gruptan Çıkar",
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
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
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text("Öğrenci Ata"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Yeni Grup Oluştur",
                        style: TextStyle(
                          fontSize: 20,
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
                        decoration: const InputDecoration(
                          labelText: "Şube",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.business),
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
                        decoration: const InputDecoration(
                          labelText: "Spor Branşı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.sports_basketball),
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
                        decoration: const InputDecoration(
                          labelText: "Antrenör",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.person),
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
                        decoration: const InputDecoration(
                          labelText: "Grup Adı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.schedule, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Program (Gün ve Saatler)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (scheduleItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: scheduleItems.asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.teal.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.formatted,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red,
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
                              padding: const EdgeInsets.all(12),
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
                                                          color: Colors.green,
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
                                  if (startTime.hour > endTime.hour ||
                                      (startTime.hour == endTime.hour &&
                                          startTime.minute >= endTime.minute)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Bitiş saati, başlangıç saatinden sonra olmalıdır!",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
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
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text("Program Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
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
                              decoration: const InputDecoration(
                                labelText: "Kapasite",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.people),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: feeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Aylık Ücret",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.payments),
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
                            backgroundColor: const Color(0xFF1E293B),
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
                                        backgroundColor: Colors.red,
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
                                    const SnackBar(
                                      content: Text(
                                        "✅ Grup başarıyla oluşturuldu!",
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
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

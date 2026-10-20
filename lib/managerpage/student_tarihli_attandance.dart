// lib/managerpage/student_attendance_detail.dart

/*
import 'dart:math' as math;
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';

class StudentAttendanceDetailScreen extends StatefulWidget {
  const StudentAttendanceDetailScreen({super.key});

  @override
  State<StudentAttendanceDetailScreen> createState() =>
      _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState
    extends State<StudentAttendanceDetailScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  List<Branches> _branches = [];
  List<Group> _groups = [];
  List<Users> _students = [];

  String? _selectedBranchId;
  String? _selectedGroupId;
  Users? _selectedStudent;

  DateTimeRange? _selectedDateRange;
  String _activeDateChip = "Bu Ay";
  List<DateTime> _attendanceDates = [];
  Map<DateTime, Attendance> _attendanceMap = {};
  Map<DateTime, String> _dateGroupMap = {};

  bool _isLoading = false;
  bool _isRefreshing = false;

  int _totalDays = 0;
  int _presentDays = 0;
  int _absentDays = 0;
  double _attendanceRate = 0;

  late AnimationController _animController;
  late Animation<double> _rateAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rateAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _loadData();
    _applyDateChip("Bu Ay");
    _offlineService.init();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (force) _isRefreshing = true;
      });
    }

    if (force) {
      await _repo.loadAllData(forceRefresh: true);
    } else if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    if (mounted) {
      setState(() {
        _branches = _repo.allBranches;
        _groups = _repo.allGroups;
        _students = _repo.allUsers
            .where((u) => u.role.toLowerCase() == "student")
            .toList();
        _isLoading = false;
        _isRefreshing = false;
      });

      // Seçili öğrenci varsa verileri yeniden yükle
      if (_selectedStudent != null) {
        await _loadAttendanceData();
      }
    }
  }

  Set<int> _getActiveDaysFromSchedule(String schedule) {
    final Set<int> activeDays = {};

    if (schedule.isEmpty || schedule.trim().isEmpty) {
      return {1, 2, 3, 4, 5, 6, 7};
    }

    final lowerSchedule = schedule.toLowerCase().trim();

    if (lowerSchedule.contains("pazartesi")) activeDays.add(1);
    if (lowerSchedule.contains("salı")) activeDays.add(2);
    if (lowerSchedule.contains("çarşamba")) activeDays.add(3);
    if (lowerSchedule.contains("perşembe")) activeDays.add(4);
    if (lowerSchedule.contains("cuma")) activeDays.add(5);
    if (lowerSchedule.contains("cumartesi")) activeDays.add(6);
    if (lowerSchedule.contains("pazar") && !lowerSchedule.contains("pazartesi"))
      activeDays.add(7);

    if (activeDays.isEmpty) {
      activeDays.addAll([1, 2, 3, 4, 5]);
    }

    return activeDays;
  }

  String _getDayNameTurkish(DateTime date) {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[date.weekday - 1];
  }

  String _formatDateTurkish(DateTime date) =>
      DateFormat('dd MMMM yyyy', 'tr_TR').format(date);

  String _formatDateShort(DateTime date) =>
      DateFormat('dd MMM', 'tr_TR').format(date);

  Future<void> _loadAttendanceData() async {
    if (_selectedStudent == null || _selectedDateRange == null) return;
    if (mounted) setState(() => _isLoading = true);

    final startDate = _selectedDateRange!.start;
    final endDate = _selectedDateRange!.end;
    final studentId = _selectedStudent!.app;

    final studentRelations = _repo.getGroupStudentsByStudentId(studentId);
    final studentGroupIds = studentRelations
        .where((r) => r.is_active.toString().toUpperCase() == "TRUE")
        .map((r) => r.groups_id)
        .toSet();

    final studentGroups = _repo.allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();

    final Set<int> weeklyActiveDays = {};
    final Map<int, List<Group>> groupsByDay = {
      for (var d = 1; d <= 7; d++) d: [],
    };

    for (var group in studentGroups) {
      final activeDays = _getActiveDaysFromSchedule(group.schedule);
      for (var day in activeDays) {
        weeklyActiveDays.add(day);
        groupsByDay[day]?.add(group);
      }
    }

    final List<DateTime> scheduleDates = [];
    _dateGroupMap.clear();

    for (
      var date = startDate;
      !date.isAfter(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (weeklyActiveDays.contains(date.weekday)) {
        scheduleDates.add(date);
        final groupsForDay = groupsByDay[date.weekday] ?? [];
        if (groupsForDay.isNotEmpty) {
          _dateGroupMap[date] = groupsForDay.map((g) => g.name).join(", ");
        }
      }
    }

    _attendanceMap.clear();

    for (var att in _repo.allAttendances) {
      if (att.student_id != studentId) continue;
      try {
        final attDate = DateTime.parse(att.attendance_date.split('T')[0]);
        _attendanceMap[attDate] = att;
      } catch (_) {}
    }

    for (var groupId in studentGroupIds) {
      for (var date in scheduleDates) {
        try {
          final localList = await _offlineService.getLocalAttendances(
            groupId,
            date,
          );
          final local = localList
              .where((a) => a.student_id == studentId)
              .toList();
          if (local.isNotEmpty) {
            _attendanceMap[date] = local.first;
          }
        } catch (_) {}
      }
    }

    _attendanceDates = scheduleDates
        .where((date) => _attendanceMap.containsKey(date))
        .toList();

    _totalDays = scheduleDates.length;
    _presentDays = 0;
    _absentDays = 0;

    for (var date in scheduleDates) {
      final att = _attendanceMap[date];
      if (att != null && att.status.toString().toUpperCase() == "TRUE") {
        _presentDays++;
      } else if (att != null) {
        _absentDays++;
      }
    }

    _attendanceRate = _totalDays > 0 ? (_presentDays / _totalDays) * 100 : 0;

    _rateAnimation = Tween<double>(begin: 0, end: _attendanceRate / 100)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward(from: 0);

    if (mounted) setState(() => _isLoading = false);
  }

  List<Group> _getFilteredGroups() {
    if (_selectedBranchId == null) return _groups;
    return _groups.where((g) => g.branches_id == _selectedBranchId).toList();
  }

  List<Users> _getFilteredStudents() {
    if (_selectedGroupId == null) return [];
    final relations = _repo.getGroupStudentsByGroupId(_selectedGroupId!);
    final studentIds = relations.map((rel) => rel.student_id).toSet();
    return _students.where((s) => studentIds.contains(s.app)).toList();
  }

  String _getGroupName(String groupId) =>
      _repo.getGroupById(groupId)?.name ?? "Grup Yok";

  void _applyDateChip(String chip) {
    final now = DateTime.now();

    if (chip == "Bu Ay") {
      final range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      setState(() {
        _activeDateChip = chip;
        _selectedDateRange = range;
      });
      if (_selectedStudent != null) _loadAttendanceData();
    } else if (chip == "Geçen Ay") {
      final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastOfLastMonth = DateTime(now.year, now.month, 0);
      final range = DateTimeRange(
        start: firstOfLastMonth,
        end: lastOfLastMonth,
      );
      setState(() {
        _activeDateChip = chip;
        _selectedDateRange = range;
      });
      if (_selectedStudent != null) _loadAttendanceData();
    } else {
      _selectDateRange();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime initialStart;
    DateTime initialEnd;

    if (_selectedDateRange != null) {
      initialStart = _selectedDateRange!.start;
      initialEnd = _selectedDateRange!.end;
    } else {
      initialStart = DateTime(now.year, now.month, 1);
      initialEnd = DateTime(now.year, now.month + 1, 0);
    }

    if (initialEnd.isAfter(lastDate)) {
      initialEnd = lastDate;
    }
    if (initialStart.isAfter(lastDate)) {
      initialStart = lastDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Tarih Aralığı Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      saveText: 'Kaydet',
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activeDateChip = "Özel";
        _selectedDateRange = picked;
      });
      if (_selectedStudent != null) {
        await _loadAttendanceData();
      }
    }
  }

  Color get _rateColor {
    if (_attendanceRate >= 70) return const Color(0xFF10B981);
    if (_attendanceRate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _rateMessage {
    if (_attendanceRate >= 70) return "Devam durumu iyi";
    if (_attendanceRate >= 50) return "Orta – dikkat edilmeli";
    return "Devamsızlık oranı yüksek!";
  }

  IconData get _rateIcon {
    if (_attendanceRate >= 70) return Icons.sentiment_very_satisfied_rounded;
    if (_attendanceRate >= 50) return Icons.sentiment_neutral_rounded;
    return Icons.sentiment_very_dissatisfied_rounded;
  }

  // ======================== RENK PALETİ ========================
  static const Color _primaryColor = Color(0xFF0F172A);
  static const Color _secondaryColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF6366F1);
  static const Color _gradientStart = Color(0xFF1E293B);
  static const Color _gradientEnd = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _getFilteredGroups();
    final filteredStudents = _getFilteredStudents();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading && _branches.isEmpty && !_isRefreshing
          ? _buildLoadingState()
          : Column(
              children: [
                _buildFilterCard(filteredGroups, filteredStudents),
                Expanded(child: _buildContent()),
                const VersionFooter(),
                const SizedBox(height: 4),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Devamsızlık Takibi",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => _loadData(force: true),
          tooltip: "Verileri Yenile",
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(
    List<Group> filteredGroups,
    List<Users> filteredStudents,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _filterDropdown<String>(
                  label: "Şube",
                  icon: Icons.business_rounded,
                  value: _selectedBranchId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Tüm Şubeler"),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem(
                        value: b.branches_id,
                        child: Text(b.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedBranchId = v;
                    _selectedGroupId = null;
                    _selectedStudent = null;
                    _attendanceDates = [];
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown<String>(
                  label: "Grup",
                  icon: Icons.group_rounded,
                  value: _selectedGroupId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Grup Seçin"),
                    ),
                    ...filteredGroups.map(
                      (g) => DropdownMenuItem(
                        value: g.groups_id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedGroupId = v;
                    _selectedStudent = null;
                    _attendanceDates = [];
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _filterDropdown<Users>(
            label: "Öğrenci",
            icon: Icons.person_rounded,
            value: _selectedStudent,
            items: filteredStudents
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        _miniAvatar(s),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${s.first_name} ${s.last_name}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStudent = v);
              if (v != null) _loadAttendanceData();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _dateChip("Bu Ay"),
                const SizedBox(width: 8),
                _dateChip("Geçen Ay"),
                const SizedBox(width: 8),
                _customDateButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label) {
    final isActive = _activeDateChip == label;
    return GestureDetector(
      onTap: () => _applyDateChip(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _accentColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _customDateButton() {
    final isActive = _activeDateChip == "Özel";
    final dateText = _selectedDateRange != null && isActive
        ? "${_formatDateShort(_selectedDateRange!.start)} - ${_formatDateShort(_selectedDateRange!.end)}"
        : "📅 Özel Tarih";

    return GestureDetector(
      onTap: _selectDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _accentColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: _accentColor, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
      ),
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
      dropdownColor: Colors.white,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _miniAvatar(Users s) {
    if (s.profile_photo_url.isNotEmpty) {
      return CircleAvatar(
        radius: 13,
        backgroundImage: NetworkImage(s.profile_photo_url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 13,
      backgroundColor: _accentColor,
      child: Text(
        s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedStudent == null) {
      return _buildEmptyState(
        Icons.person_search_rounded,
        "Öğrenci seçin",
        "Devamsızlık raporunu görmek için\nyukarıdan öğrenci seçin",
      );
    }
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Veriler yükleniyor...",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_attendanceDates.isEmpty && _selectedStudent != null) {
      return _buildEmptyState(
        Icons.event_busy_rounded,
        "Kayıt bulunamadı",
        "Bu tarih aralığında yoklama kaydı yok",
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildStudentCard(),
          const SizedBox(height: 16),
          _buildCircularRateCard(),
          const SizedBox(height: 14),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildDailyList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: _accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    final s = _selectedStudent!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: s.profile_photo_url.isNotEmpty
                  ? Image.network(
                      s.profile_photo_url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarPlaceholder(s),
                    )
                  : _avatarPlaceholder(s),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${s.first_name} ${s.last_name}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGroupName(_selectedGroupId ?? ""),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                if (s.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse("tel:${s.phone}");
                      if (await canLaunchUrl(url)) launchUrl(url);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          s.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${s.amount} TL / ay",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _avatarPlaceholder(Users s) {
    return Container(
      color: const Color(0xFF312E81),
      child: Center(
        child: Text(
          s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
          style: const TextStyle(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularRateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _rateAnimation,
            builder: (_, __) => SizedBox(
              width: 110,
              height: 110,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: _rateAnimation.value,
                  color: _rateColor,
                  backgroundColor: const Color(0xFFE2E8F0),
                  strokeWidth: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(_rateAnimation.value * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _rateColor,
                        ),
                      ),
                      const Text(
                        "Katılım",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_rateIcon, color: _rateColor, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _rateMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _rateColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _rateDetailRow(
                  "Toplam ders",
                  "$_totalDays gün",
                  const Color(0xFF64748B),
                ),
                const SizedBox(height: 6),
                _rateDetailRow(
                  "Katıldığı",
                  "$_presentDays gün",
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 6),
                _rateDetailRow(
                  "Katılmadığı",
                  "$_absentDays gün",
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          "Ders Günü",
          _totalDays.toString(),
          Icons.calendar_month_rounded,
          _accentColor,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          "Geldi",
          _presentDays.toString(),
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          "Gelmedi",
          _absentDays.toString(),
          Icons.cancel_rounded,
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Günlük Detay",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_attendanceDates.length} gün",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
            itemCount: _attendanceDates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final date = _attendanceDates[index];
              final att = _attendanceMap[date];
              final isPresent =
                  att != null && att.status.toString().toUpperCase() == "TRUE";
              final groupNames = _dateGroupMap[date] ?? "";

              return _buildDayTile(date, isPresent, groupNames, att);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(
    DateTime date,
    bool isPresent,
    String groupNames,
    Attendance? att,
  ) {
    final color = isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'tr_TR').format(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDayNameTurkish(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (groupNames.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 12,
                        color: _accentColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          groupNames,
                          style: TextStyle(
                            fontSize: 11,
                            color: _accentColor.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (att?.note != null && att!.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          att.note,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  isPresent ? "Geldi" : "Gelmedi",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.color != color;
}
*/

// lib/managerpage/student_attendance_detail.dart
import 'dart:async'; // 🔥 Akış dinleyicisi için eklendi
import 'dart:math' as math;
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';

class StudentAttendanceDetailScreen extends StatefulWidget {
  const StudentAttendanceDetailScreen({super.key});

  @override
  State<StudentAttendanceDetailScreen> createState() =>
      _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState
    extends State<StudentAttendanceDetailScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  List<Branches> _branches = [];
  List<Group> _groups = [];
  List<Users> _students = [];

  String? _selectedBranchId;
  String? _selectedGroupId;
  Users? _selectedStudent;

  DateTimeRange? _selectedDateRange;
  String _activeDateChip = "Bu Ay";
  List<DateTime> _attendanceDates = [];
  Map<DateTime, Attendance> _attendanceMap = {};
  Map<DateTime, String> _dateGroupMap = {};

  bool _isLoading = false;
  bool _isRefreshing = false;
  StreamSubscription? _dataUpdateSubscription; // 🔥 Canlı dinleyici

  int _totalDays = 0;
  int _presentDays = 0;
  int _absentDays = 0;
  double _attendanceRate = 0;

  late AnimationController _animController;
  late Animation<double> _rateAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rateAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    // 🔥 1. Arka planda veri güncellendiğinde ekranı otomatik yenilemek için dinle
    _dataUpdateSubscription = AppRepository().onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromMemory();
      }
    });

    // 🔥 2. Sayfa açılışında akıllı veri yükleme kontrolü
    _initSmartData();

    _applyDateChip("Bu Ay");
    _offlineService.init();
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel(); // Sızıntıyı önle
    _animController.dispose();
    super.dispose();
  }

  // 🔥 Akıllı Veri Yükleme (RAM'de varsa anında aç, yoksa arka planda çek)
  Future<void> _initSmartData() async {
    if (_repo.allUsers.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
      await _repo.loadAllData();
    }
    _loadDataFromMemory();
  }

  void _loadDataFromMemory() {
    if (!mounted) return;
    setState(() {
      _branches = _repo.allBranches;
      _groups = _repo.allGroups;
      _students = _repo.allUsers
          .where((u) => u.role.toLowerCase() == "student")
          .toList();
      _isLoading = false;
      _isRefreshing = false;
    });

    if (_selectedStudent != null) {
      _loadAttendanceData();
    }
  }

  Future<void> _loadData({bool force = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (force) _isRefreshing = true;
      });
    }

    if (force) {
      await _repo.loadAllData(forceRefresh: true);
    } else if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    _loadDataFromMemory();
  }

  Set<int> _getActiveDaysFromSchedule(String schedule) {
    final Set<int> activeDays = {};

    if (schedule.isEmpty || schedule.trim().isEmpty) {
      return {1, 2, 3, 4, 5, 6, 7};
    }

    final lowerSchedule = schedule.toLowerCase().trim();

    if (lowerSchedule.contains("pazartesi")) activeDays.add(1);
    if (lowerSchedule.contains("salı")) activeDays.add(2);
    if (lowerSchedule.contains("çarşamba")) activeDays.add(3);
    if (lowerSchedule.contains("perşembe")) activeDays.add(4);
    if (lowerSchedule.contains("cuma")) activeDays.add(5);
    if (lowerSchedule.contains("cumartesi")) activeDays.add(6);
    if (lowerSchedule.contains("pazar") && !lowerSchedule.contains("pazartesi"))
      activeDays.add(7);

    if (activeDays.isEmpty) {
      activeDays.addAll([1, 2, 3, 4, 5]);
    }

    return activeDays;
  }

  String _getDayNameTurkish(DateTime date) {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[date.weekday - 1];
  }

  String _formatDateTurkish(DateTime date) =>
      DateFormat('dd MMMM yyyy', 'tr_TR').format(date);

  String _formatDateShort(DateTime date) =>
      DateFormat('dd MMM', 'tr_TR').format(date);

  Future<void> _loadAttendanceData() async {
    if (_selectedStudent == null || _selectedDateRange == null) return;
    if (mounted) setState(() => _isLoading = true);

    final startDate = _selectedDateRange!.start;
    final endDate = _selectedDateRange!.end;
    final studentId = _selectedStudent!.app;

    final studentRelations = _repo.getGroupStudentsByStudentId(studentId);
    final studentGroupIds = studentRelations
        .where((r) => r.is_active.toString().toUpperCase() == "TRUE")
        .map((r) => r.groups_id)
        .toSet();

    final studentGroups = _repo.allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();

    final Set<int> weeklyActiveDays = {};
    final Map<int, List<Group>> groupsByDay = {
      for (var d = 1; d <= 7; d++) d: [],
    };

    for (var group in studentGroups) {
      final activeDays = _getActiveDaysFromSchedule(group.schedule);
      for (var day in activeDays) {
        weeklyActiveDays.add(day);
        groupsByDay[day]?.add(group);
      }
    }

    final List<DateTime> scheduleDates = [];
    _dateGroupMap.clear();

    for (
      var date = startDate;
      !date.isAfter(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (weeklyActiveDays.contains(date.weekday)) {
        scheduleDates.add(date);
        final groupsForDay = groupsByDay[date.weekday] ?? [];
        if (groupsForDay.isNotEmpty) {
          _dateGroupMap[date] = groupsForDay.map((g) => g.name).join(", ");
        }
      }
    }

    _attendanceMap.clear();

    for (var att in _repo.allAttendances) {
      if (att.student_id != studentId) continue;
      try {
        final attDate = DateTime.parse(att.attendance_date.split('T')[0]);
        _attendanceMap[attDate] = att;
      } catch (_) {}
    }

    for (var groupId in studentGroupIds) {
      for (var date in scheduleDates) {
        try {
          final localList = await _offlineService.getLocalAttendances(
            groupId,
            date,
          );
          final local = localList
              .where((a) => a.student_id == studentId)
              .toList();
          if (local.isNotEmpty) {
            _attendanceMap[date] = local.first;
          }
        } catch (_) {}
      }
    }

    _attendanceDates = scheduleDates
        .where((date) => _attendanceMap.containsKey(date))
        .toList();

    _totalDays = scheduleDates.length;
    _presentDays = 0;
    _absentDays = 0;

    for (var date in scheduleDates) {
      final att = _attendanceMap[date];
      if (att != null && att.status.toString().toUpperCase() == "TRUE") {
        _presentDays++;
      } else if (att != null) {
        _absentDays++;
      }
    }

    _attendanceRate = _totalDays > 0 ? (_presentDays / _totalDays) * 100 : 0;

    _rateAnimation = Tween<double>(begin: 0, end: _attendanceRate / 100)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward(from: 0);

    if (mounted) setState(() => _isLoading = false);
  }

  List<Group> _getFilteredGroups() {
    if (_selectedBranchId == null) return _groups;
    return _groups.where((g) => g.branches_id == _selectedBranchId).toList();
  }

  List<Users> _getFilteredStudents() {
    if (_selectedGroupId == null) return [];
    final relations = _repo.getGroupStudentsByGroupId(_selectedGroupId!);
    final studentIds = relations.map((rel) => rel.student_id).toSet();
    return _students.where((s) => studentIds.contains(s.app)).toList();
  }

  String _getGroupName(String groupId) =>
      _repo.getGroupById(groupId)?.name ?? "Grup Yok";

  void _applyDateChip(String chip) {
    final now = DateTime.now();

    if (chip == "Bu Ay") {
      final range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      setState(() {
        _activeDateChip = chip;
        _selectedDateRange = range;
      });
      if (_selectedStudent != null) _loadAttendanceData();
    } else if (chip == "Geçen Ay") {
      final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastOfLastMonth = DateTime(now.year, now.month, 0);
      final range = DateTimeRange(
        start: firstOfLastMonth,
        end: lastOfLastMonth,
      );
      setState(() {
        _activeDateChip = chip;
        _selectedDateRange = range;
      });
      if (_selectedStudent != null) _loadAttendanceData();
    } else {
      _selectDateRange();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime initialStart;
    DateTime initialEnd;

    if (_selectedDateRange != null) {
      initialStart = _selectedDateRange!.start;
      initialEnd = _selectedDateRange!.end;
    } else {
      initialStart = DateTime(now.year, now.month, 1);
      initialEnd = DateTime(now.year, now.month + 1, 0);
    }

    if (initialEnd.isAfter(lastDate)) {
      initialEnd = lastDate;
    }
    if (initialStart.isAfter(lastDate)) {
      initialStart = lastDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Tarih Aralığı Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      saveText: 'Kaydet',
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activeDateChip = "Özel";
        _selectedDateRange = picked;
      });
      if (_selectedStudent != null) {
        await _loadAttendanceData();
      }
    }
  }

  Color get _rateColor {
    if (_attendanceRate >= 70) return const Color(0xFF10B981);
    if (_attendanceRate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _rateMessage {
    if (_attendanceRate >= 70) return "Devam durumu iyi";
    if (_attendanceRate >= 50) return "Orta – dikkat edilmeli";
    return "Devamsızlık oranı yüksek!";
  }

  IconData get _rateIcon {
    if (_attendanceRate >= 70) return Icons.sentiment_very_satisfied_rounded;
    if (_attendanceRate >= 50) return Icons.sentiment_neutral_rounded;
    return Icons.sentiment_very_dissatisfied_rounded;
  }

  // ======================== RENK PALETİ ========================
  static const Color _primaryColor = Color(0xFF0F172A);
  static const Color _secondaryColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF6366F1);
  static const Color _gradientStart = Color(0xFF1E293B);
  static const Color _gradientEnd = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _getFilteredGroups();
    final filteredStudents = _getFilteredStudents();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading && _branches.isEmpty && !_isRefreshing
          ? _buildLoadingState()
          : Column(
              children: [
                _buildFilterCard(filteredGroups, filteredStudents),
                Expanded(child: _buildContent()),
                const VersionFooter(),
                const SizedBox(height: 4),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Devamsızlık Takibi",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => _loadData(force: true),
          tooltip: "Verileri Yenile",
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(
    List<Group> filteredGroups,
    List<Users> filteredStudents,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _filterDropdown<String>(
                  label: "Şube",
                  icon: Icons.business_rounded,
                  value: _selectedBranchId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Tüm Şubeler"),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem(
                        value: b.branches_id,
                        child: Text(b.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedBranchId = v;
                    _selectedGroupId = null;
                    _selectedStudent = null;
                    _attendanceDates = [];
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown<String>(
                  label: "Grup",
                  icon: Icons.group_rounded,
                  value: _selectedGroupId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Grup Seçin"),
                    ),
                    ...filteredGroups.map(
                      (g) => DropdownMenuItem(
                        value: g.groups_id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedGroupId = v;
                    _selectedStudent = null;
                    _attendanceDates = [];
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _filterDropdown<Users>(
            label: "Öğrenci",
            icon: Icons.person_rounded,
            value: _selectedStudent,
            items: filteredStudents
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        _miniAvatar(s),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${s.first_name} ${s.last_name}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStudent = v);
              if (v != null) _loadAttendanceData();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _dateChip("Bu Ay"),
                const SizedBox(width: 8),
                _dateChip("Geçen Ay"),
                const SizedBox(width: 8),
                _customDateButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label) {
    final isActive = _activeDateChip == label;
    return GestureDetector(
      onTap: () => _applyDateChip(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _accentColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _customDateButton() {
    final isActive = _activeDateChip == "Özel";
    final dateText = _selectedDateRange != null && isActive
        ? "${_formatDateShort(_selectedDateRange!.start)} - ${_formatDateShort(_selectedDateRange!.end)}"
        : "📅 Özel Tarih";

    return GestureDetector(
      onTap: _selectDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _accentColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: _accentColor, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
      ),
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
      dropdownColor: Colors.white,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _miniAvatar(Users s) {
    if (s.profile_photo_url.isNotEmpty) {
      return CircleAvatar(
        radius: 13,
        backgroundImage: NetworkImage(s.profile_photo_url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 13,
      backgroundColor: _accentColor,
      child: Text(
        s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedStudent == null) {
      return _buildEmptyState(
        Icons.person_search_rounded,
        "Öğrenci seçin",
        "Devamsızlık raporunu görmek için\nyukarıdan öğrenci seçin",
      );
    }
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Veriler yükleniyor...",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_attendanceDates.isEmpty && _selectedStudent != null) {
      return _buildEmptyState(
        Icons.event_busy_rounded,
        "Kayıt bulunamadı",
        "Bu tarih aralığında yoklama kaydı yok",
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildStudentCard(),
          const SizedBox(height: 16),
          _buildCircularRateCard(),
          const SizedBox(height: 14),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildDailyList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: _accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    final s = _selectedStudent!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: s.profile_photo_url.isNotEmpty
                  ? Image.network(
                      s.profile_photo_url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarPlaceholder(s),
                    )
                  : _avatarPlaceholder(s),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${s.first_name} ${s.last_name}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGroupName(_selectedGroupId ?? ""),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                if (s.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse("tel:${s.phone}");
                      if (await canLaunchUrl(url)) launchUrl(url);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          s.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${s.amount} TL / ay",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _avatarPlaceholder(Users s) {
    return Container(
      color: const Color(0xFF312E81),
      child: Center(
        child: Text(
          s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
          style: const TextStyle(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularRateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _rateAnimation,
            builder: (_, __) => SizedBox(
              width: 110,
              height: 110,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: _rateAnimation.value,
                  color: _rateColor,
                  backgroundColor: const Color(0xFFE2E8F0),
                  strokeWidth: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(_rateAnimation.value * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _rateColor,
                        ),
                      ),
                      const Text(
                        "Katılım",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_rateIcon, color: _rateColor, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _rateMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _rateColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _rateDetailRow(
                  "Toplam ders",
                  "$_totalDays gün",
                  const Color(0xFF64748B),
                ),
                const SizedBox(height: 6),
                _rateDetailRow(
                  "Katıldığı",
                  "$_presentDays gün",
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 6),
                _rateDetailRow(
                  "Katılmadığı",
                  "$_absentDays gün",
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          "Ders Günü",
          _totalDays.toString(),
          Icons.calendar_month_rounded,
          _accentColor,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          "Geldi",
          _presentDays.toString(),
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          "Gelmedi",
          _absentDays.toString(),
          Icons.cancel_rounded,
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Günlük Detay",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_attendanceDates.length} gün",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
            itemCount: _attendanceDates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final date = _attendanceDates[index];
              final att = _attendanceMap[date];
              final isPresent =
                  att != null && att.status.toString().toUpperCase() == "TRUE";
              final groupNames = _dateGroupMap[date] ?? "";

              return _buildDayTile(date, isPresent, groupNames, att);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(
    DateTime date,
    bool isPresent,
    String groupNames,
    Attendance? att,
  ) {
    final color = isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'tr_TR').format(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDayNameTurkish(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (groupNames.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 12,
                        color: _accentColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          groupNames,
                          style: TextStyle(
                            fontSize: 11,
                            color: _accentColor.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (att?.note != null && att!.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          att.note,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  isPresent ? "Geldi" : "Gelmedi",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.color != color;
}

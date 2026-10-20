/*
import 'dart:async';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class StudentActivationScreen extends StatefulWidget {
  const StudentActivationScreen({Key? key}) : super(key: key);

  @override
  _StudentActivationScreenState createState() =>
      _StudentActivationScreenState();
}

class _StudentActivationScreenState extends State<StudentActivationScreen>
    with SingleTickerProviderStateMixin {
  // =========================================================================
  // VERİ LİSTELERİ
  // =========================================================================
  List<Users> allStudents = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];

  List<Users> activeStudents = [];
  List<Users> inactiveStudents = [];

  List<Users> filteredActiveStudents = [];
  List<Users> filteredInactiveStudents = [];

  bool _showActiveList = true;

  // =========================================================================
  // FİLTRELEME
  // =========================================================================
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String _selectedGroupFilter = "Tümü";
  List<String> _groupFilterOptions = ["Tümü"];

  // =========================================================================
  // CACHE
  // =========================================================================
  final Map<String, String> _studentGroupCache = {};

  // =========================================================================
  // DURUM
  // =========================================================================
  bool isLoading = true;
  bool _isRefreshing = false;
  Timer? _debounceTimer;
  StreamSubscription? _dataUpdateSubscription; // 🔥 REPO DİNLEYİCİSİ

  // =========================================================================
  // ANİMASYON
  // =========================================================================
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // =========================================================================
  // RENK PALETİ
  // =========================================================================
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6366F1);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _gradientStart = Color(0xFF1E293B);
  static const Color _gradientEnd = Color(0xFF0F172A);

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

    // 🔥 1. ADIM: Repository üzerindeki veri güncelleme stream'ini dinle
    _dataUpdateSubscription = AppRepository().onDataUpdated.listen((_) {
      if (mounted) {
        print("🔄 Otomatik güncelleme sinyali alındı, listeler yenileniyor...");
        _loadDataFromMemory();
      }
    });

    // 🔥 2. ADIM: Sayfa açılışında veri kontrolü (Boşsa otomatik çek)
    _initializeScreenData();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _studentGroupCache.clear();
    _animController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 🚀 AKILLI VERİ YÜKLEME KONTROLÜ
  // =========================================================================
  Future<void> _initializeScreenData() async {
    setState(() => isLoading = true);

    final ramUsers = AppRepository().allUsers;

    if (ramUsers.isEmpty) {
      print("⚠️ RAM'de veri bulunamadı, otomatik sunucu isteği atılıyor...");
      await AppRepository().loadAllData();
    }

    _loadDataFromMemory();
  }

  void _loadDataFromMemory() {
    try {
      allStudents = List.from(AppRepository().allUsers);
      allGroups = AppRepository().getAllGroups();
      allGroupStudents = AppRepository().allGroupStudents;

      if (allStudents.isEmpty) {
        _loadAllData(force: false);
        return;
      }

      _buildGroupFilterOptions();
      _loadGroupCache();
      _separateStudents();

      if (mounted) {
        setState(() {
          isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print("❌ Bellekten veri okuma hatası: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // 🚀 VERİ YÜKLEME (MANUEL / REFRESH)
  // =========================================================================
  void _loadAllData({bool force = false}) {
    if (mounted) {
      setState(() {
        isLoading = true;
        if (force) _isRefreshing = true;
      });
    }

    Future.microtask(() async {
      try {
        if (force) {
          await AppRepository().loadAllData(forceRefresh: true);
        }

        final users = await GoogleSheetService.getUsersCached(
          forceRefresh: force,
        );
        allStudents = users;

        allGroups = await GoogleSheetService.getGroupsCached(
          forceRefresh: force,
        );

        allGroupStudents = await GoogleSheetService.getGroupStudentsCached(
          forceRefresh: force,
        );

        _buildGroupFilterOptions();
        _loadGroupCache();
        _separateStudents();

        if (mounted) {
          setState(() {
            isLoading = false;
            _isRefreshing = false;
          });
        }
      } catch (e, stackTrace) {
        print("Yükleme hatası: $e");
        if (mounted) {
          setState(() {
            isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    });
  }

  // =========================================================================
  // GRUP CACHE
  // =========================================================================
  void _loadGroupCache() {
    _studentGroupCache.clear();

    for (var student in allStudents) {
      final groupRelations = allGroupStudents.where((gs) {
        if (gs.student_id != student.app) return false;
        return gs.is_active.toString().toUpperCase() == "TRUE";
      }).toList();

      if (groupRelations.isNotEmpty) {
        final groupId = groupRelations.first.groups_id;
        final group = allGroups.firstWhere(
          (g) => g.groups_id == groupId,
          orElse: () => Group(
            name: "Grup Yok",
            groups_id: '',
            branches_id: '',
            coach_id: '',
            sports_id: '',
            schedule: '',
            capacity: '',
            monthly_fee: '',
            is_active: '',
          ),
        );
        _studentGroupCache[student.app] = group.name.isNotEmpty
            ? group.name
            : "Grup Yok";
      } else {
        _studentGroupCache[student.app] = "Grup Yok";
      }
    }
  }

  // =========================================================================
  // GRUP FİLTRE SEÇENEKLERİ
  // =========================================================================
  void _buildGroupFilterOptions() {
    final groupNames = allGroups
        .map((g) => g.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    groupNames.sort();
    _groupFilterOptions = ["Tümü", ...groupNames];
  }

  String _getStudentGroup(String studentId) =>
      _studentGroupCache[studentId] ?? "Grup Yok";

  // =========================================================================
  // AKTİF/PASİF AYIR
  // =========================================================================
  void _separateStudents() {
    activeStudents = [];
    inactiveStudents = [];

    for (var student in allStudents) {
      final isActive = student.is_active.toString().toUpperCase() == "TRUE";

      if (isActive) {
        activeStudents.add(student);
      } else {
        inactiveStudents.add(student);
      }
    }

    activeStudents.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );
    inactiveStudents.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );

    _applyFilters();
  }

  // =========================================================================
  // FİLTRELEME
  // =========================================================================
  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    bool matchesFilter(Users s) {
      final name = "${s.first_name} ${s.last_name}".toLowerCase();
      final group = _getStudentGroup(s.app);

      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) return false;
      if (_selectedGroupFilter != "Tümü" && group != _selectedGroupFilter)
        return false;
      return true;
    }

    filteredActiveStudents = activeStudents.where(matchesFilter).toList();
    filteredInactiveStudents = inactiveStudents.where(matchesFilter).toList();
  }

  // =========================================================================
  // AKTİF YAP
  // =========================================================================
  Future<void> _activateStudent(Users student) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Yeni Kayıt Tarihi Seçin',
      cancelText: 'İptal',
      confirmText: 'Aktif Et',
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;

    setState(() => isLoading = true);

    try {
      final formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      final repoUsers = AppRepository().allUsers;
      final idx = repoUsers.indexWhere((u) => u.app == student.app);
      if (idx != -1) {
        repoUsers[idx] = Users(
          app: student.app,
          first_name: student.first_name,
          last_name: student.last_name,
          email: student.email,
          phone: student.phone,
          role: student.role,
          b_date: student.b_date,
          profile_photo_url: student.profile_photo_url,
          is_active: "TRUE",
          created_at: formattedDate,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository().refreshMapsOnly();
      }

      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      unawaited(() async {
        try {
          await GoogleSheetService.updateUser({
            "app": student.app,
            "is_active": true,
          });
          await GoogleSheetService.updateUser({
            "app": student.app,
            "created_at": formattedDate,
          });
          await AppRepository().refreshSingleTable('users');
        } catch (e) {
          print("❌ Arka plan aktif etme senkronizasyon hatası: $e");
        }
      }());

      _showSnack(
        "✅ ${student.first_name} ${student.last_name} aktif edildi!",
        _success,
      );

      setState(() => isLoading = false);
    } catch (e) {
      _showSnack("❌ Hata: $e", _danger);
      setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // PASİF YAP
  // =========================================================================
  Future<void> _deactivateStudent(Users student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _warning, size: 28),
            const SizedBox(width: 10),
            const Text(
              "Öğrenciyi Pasif Yap",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Bu öğrenciyi pasif yapmak istediğinize emin misiniz?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Pasif öğrenciler yoklamalara katılamaz ve sistemde görünmez olur.",
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Pasif Yap",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      final repoUsers = AppRepository().allUsers;
      final idx = repoUsers.indexWhere((u) => u.app == student.app);
      if (idx != -1) {
        repoUsers[idx] = Users(
          app: student.app,
          first_name: student.first_name,
          last_name: student.last_name,
          email: student.email,
          phone: student.phone,
          role: student.role,
          b_date: student.b_date,
          profile_photo_url: student.profile_photo_url,
          is_active: "FALSE",
          created_at: student.created_at,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository().refreshMapsOnly();
      }

      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      unawaited(() async {
        try {
          await GoogleSheetService.updateUser({
            "app": student.app,
            "is_active": "FALSE",
          });
          await AppRepository().refreshSingleTable('users');
        } catch (e) {
          print("❌ Arka plan pasife alma senkronizasyon hatası: $e");
        }
      }());

      _showSnack(
        "✅ ${student.first_name} ${student.last_name} pasif yapıldı!",
        _warning,
      );

      setState(() => isLoading = false);
    } catch (e) {
      _showSnack("❌ Hata: $e", _danger);
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _success
                  ? Icons.check_circle
                  : color == _warning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // =========================================================================
  // ÖĞRENCİ KARTI - PREMIUM TASARIM
  // =========================================================================
  Widget _buildStudentCard(Users user, {required bool isActive}) {
    final groupName = _getStudentGroup(user.app);
    final registerDate = _formatDate(user.created_at);

    final isStudent = user.role.trim().toLowerCase() == "student";
    final roleLabel = isStudent ? "Öğrenci" : user.role;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? _success.withOpacity(0.2)
              : _warning.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? _success.withOpacity(0.06)
                : _warning.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [_success, Color(0xFF059669)],
                      )
                    : const LinearGradient(
                        colors: [_warning, Color(0xFFD97706)],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  user.first_name.isNotEmpty
                      ? user.first_name[0].toUpperCase()
                      : "?",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${user.first_name} ${user.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isStudent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 12,
                        color: _textSecondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            color: _textSecondary.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: _textSecondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Kayıt: $registerDate",
                        style: TextStyle(
                          color: _textSecondary.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Aksiyon Butonu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? _danger.withOpacity(0.08)
                    : _success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? _danger.withOpacity(0.2)
                      : _success.withOpacity(0.2),
                ),
              ),
              child: GestureDetector(
                onTap: () => isActive
                    ? _deactivateStudent(user)
                    : _activateStudent(user),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.person_off_rounded
                          : Icons.person_add_rounded,
                      size: 16,
                      color: isActive ? _danger : _success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? "Pasif Yap" : "Aktif Et",
                      style: TextStyle(
                        color: isActive ? _danger : _success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LİSTE WIDGET
  // =========================================================================
  Widget _buildStudentList(List<Users> students, bool isActive) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isActive
                    ? _success.withOpacity(0.08)
                    : _warning.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.people_outline : Icons.person_off_outlined,
                size: 48,
                color: isActive ? _success : _warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? "Aktif öğrenci yok" : "Pasif öğrenci yok",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? "Tüm öğrenciler pasif durumda"
                  : "Tüm öğrenciler aktif durumda",
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (_, i) => _buildStudentCard(students[i], isActive: isActive),
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final totalActive = filteredActiveStudents.length;
    final totalInactive = filteredInactiveStudents.length;

    final currentStudents = _showActiveList
        ? filteredActiveStudents
        : filteredInactiveStudents;
    final isCurrentListActive = _showActiveList;
    final currentTitle = _showActiveList
        ? "Aktif Öğrenciler"
        : "Pasif Öğrenciler";
    final currentColor = _showActiveList ? _success : _warning;

    final currentCount = _showActiveList ? totalActive : totalInactive;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: () async => _loadAllData(force: true),
              color: _accent,
              child: Column(
                children: [
                  _buildFilterSection(
                    totalActive,
                    totalInactive,
                    currentColor,
                    currentCount,
                    currentTitle,
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStudentList(
                        currentStudents,
                        isCurrentListActive,
                      ),
                    ),
                  ),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Hesap Yönetimi",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => _loadAllData(force: true),
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
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    int totalActive,
    int totalInactive,
    Color currentColor,
    int currentCount,
    String currentTitle,
  ) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // TOGGLE BUTONU
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _toggleButton(
                  label: "Aktif",
                  count: totalActive,
                  icon: Icons.person,
                  isActive: true,
                  color: _success,
                ),
                _toggleButton(
                  label: "Pasif",
                  count: totalInactive,
                  icon: Icons.person_off,
                  isActive: false,
                  color: _warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Arama ve Grup Filtresi
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
                    decoration: InputDecoration(
                      hintText: "İsim veya grup ara...",
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
                    style: const TextStyle(color: _textPrimary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroupFilter,
                      isExpanded: true,
                      isDense: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textSecondary,
                        size: 18,
                      ),
                      dropdownColor: _surface,
                      items: _groupFilterOptions.map((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Text(
                            name,
                            style: TextStyle(
                              color: name == _selectedGroupFilter
                                  ? _accent
                                  : _textPrimary,
                              fontSize: 12,
                              fontWeight: name == _selectedGroupFilter
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedGroupFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Başlık ve sayaç
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: currentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: currentColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showActiveList ? Icons.person : Icons.person_off,
                      size: 14,
                      color: currentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$currentTitle • $currentCount",
                      style: TextStyle(
                        color: currentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_searchQuery.isNotEmpty || _selectedGroupFilter != "Tümü")
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, size: 12, color: _accent),
                      const SizedBox(width: 4),
                      Text(
                        "Filtre aktif",
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required int count,
    required IconData icon,
    required bool isActive,
    required Color color,
  }) {
    final isSelected = _showActiveList == isActive;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showActiveList = isActive;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                "$label ($count)",
                style: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
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
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class StudentActivationScreen extends StatefulWidget {
  const StudentActivationScreen({Key? key}) : super(key: key);

  @override
  _StudentActivationScreenState createState() =>
      _StudentActivationScreenState();
}

class _StudentActivationScreenState extends State<StudentActivationScreen>
    with SingleTickerProviderStateMixin {
  // =========================================================================
  // VERİ LİSTELERİ
  // =========================================================================
  List<Users> allStudents = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];

  List<Users> activeStudents = [];
  List<Users> inactiveStudents = [];

  List<Users> filteredActiveStudents = [];
  List<Users> filteredInactiveStudents = [];

  bool _showActiveList = true;

  // =========================================================================
  // FİLTRELEME
  // =========================================================================
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String _selectedGroupFilter = "Tümü";
  List<String> _groupFilterOptions = ["Tümü"];

  // =========================================================================
  // CACHE
  // =========================================================================
  final Map<String, String> _studentGroupCache = {};

  // =========================================================================
  // DURUM
  // =========================================================================
  bool isLoading = true;
  bool _isRefreshing = false;
  Timer? _debounceTimer;
  StreamSubscription? _dataUpdateSubscription;

  // =========================================================================
  // ANİMASYON
  // =========================================================================
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // =========================================================================
  // RENK PALETİ
  // =========================================================================
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6366F1);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _gradientStart = Color(0xFF1E293B);
  static const Color _gradientEnd = Color(0xFF0F172A);

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

    // 🔥 1. Arka planda veri güncellendiğinde ekranı otomatik yenile
    _dataUpdateSubscription = AppRepository().onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromMemory();
      }
    });

    // 🔥 2. Sayfa açıldığı an önce RAM'e bak, varsa beklemeden aç; yoksa arka planda çek
    _initializeScreenData();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _studentGroupCache.clear();
    _animController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 🚀 AKILLI VERİ YÜKLEME (0ms AÇILIŞ MANTIĞI)
  // =========================================================================
  Future<void> _initializeScreenData() async {
    // Önce RAM'deki verilere bakıyoruz
    final ramUsers = AppRepository().allUsers;

    if (ramUsers.isNotEmpty) {
      // Zaten veri var! Bekletmeden anında yükle
      _loadDataFromMemory();
    } else {
      // RAM boşsa ilk defa yükleniyordur, mecburen arka planda çek
      setState(() => isLoading = true);
      await AppRepository().loadAllData();
      _loadDataFromMemory();
    }
  }

  void _loadDataFromMemory() {
    try {
      allStudents = List.from(AppRepository().allUsers);
      allGroups = AppRepository().getAllGroups();
      allGroupStudents = AppRepository().allGroupStudents;

      _buildGroupFilterOptions();
      _loadGroupCache();
      _separateStudents();

      if (mounted) {
        setState(() {
          isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print("❌ Bellekten veri okuma hatası: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // 🚀 MANUEL / REFRESH VERİ YÜKLEME
  // =========================================================
  void _loadAllData({bool force = false}) {
    if (mounted) {
      setState(() {
        if (force) _isRefreshing = true;
      });
    }

    Future.microtask(() async {
      try {
        if (force) {
          await AppRepository().loadAllData(forceRefresh: true);
        }
        _loadDataFromMemory();
      } catch (e) {
        print("Yükleme hatası: $e");
        if (mounted) {
          setState(() {
            isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    });
  }

  // =========================================================================
  // GRUP CACHE
  // =========================================================================
  void _loadGroupCache() {
    _studentGroupCache.clear();

    for (var student in allStudents) {
      final groupRelations = allGroupStudents.where((gs) {
        if (gs.student_id != student.app) return false;
        return gs.is_active.toString().toUpperCase() == "TRUE";
      }).toList();

      if (groupRelations.isNotEmpty) {
        final groupId = groupRelations.first.groups_id;
        final group = allGroups.firstWhere(
          (g) => g.groups_id == groupId,
          orElse: () => Group(
            name: "Grup Yok",
            groups_id: '',
            branches_id: '',
            coach_id: '',
            sports_id: '',
            schedule: '',
            capacity: '',
            monthly_fee: '',
            is_active: '',
          ),
        );
        _studentGroupCache[student.app] = group.name.isNotEmpty
            ? group.name
            : "Grup Yok";
      } else {
        _studentGroupCache[student.app] = "Grup Yok";
      }
    }
  }

  // =========================================================================
  // GRUP FİLTRE SEÇENEKLERİ
  // =========================================================================
  void _buildGroupFilterOptions() {
    final groupNames = allGroups
        .map((g) => g.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    groupNames.sort();
    _groupFilterOptions = ["Tümü", ...groupNames];
  }

  String _getStudentGroup(String studentId) =>
      _studentGroupCache[studentId] ?? "Grup Yok";

  // =========================================================================
  // AKTİF/PASİF AYIR
  // =========================================================================
  void _separateStudents() {
    activeStudents = [];
    inactiveStudents = [];

    for (var student in allStudents) {
      final isActive = student.is_active.toString().toUpperCase() == "TRUE";

      if (isActive) {
        activeStudents.add(student);
      } else {
        inactiveStudents.add(student);
      }
    }

    activeStudents.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );
    inactiveStudents.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );

    _applyFilters();
  }

  // =========================================================================
  // FİLTRELEME
  // =========================================================================
  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    bool matchesFilter(Users s) {
      final name = "${s.first_name} ${s.last_name}".toLowerCase();
      final group = _getStudentGroup(s.app);

      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) return false;
      if (_selectedGroupFilter != "Tümü" && group != _selectedGroupFilter)
        return false;
      return true;
    }

    filteredActiveStudents = activeStudents.where(matchesFilter).toList();
    filteredInactiveStudents = inactiveStudents.where(matchesFilter).toList();
  }

  // =========================================================================
  // AKTİF YAP
  // =========================================================================
  Future<void> _activateStudent(Users student) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Yeni Kayıt Tarihi Seçin',
      cancelText: 'İptal',
      confirmText: 'Aktif Et',
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;

    setState(() => isLoading = true);

    try {
      final formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      final repoUsers = AppRepository().allUsers;
      final idx = repoUsers.indexWhere((u) => u.app == student.app);
      if (idx != -1) {
        repoUsers[idx] = Users(
          app: student.app,
          first_name: student.first_name,
          last_name: student.last_name,
          email: student.email,
          phone: student.phone,
          role: student.role,
          b_date: student.b_date,
          profile_photo_url: student.profile_photo_url,
          is_active: "TRUE",
          created_at: formattedDate,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository().refreshMapsOnly();
      }

      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      unawaited(() async {
        try {
          await GoogleSheetService.updateUser({
            "app": student.app,
            "is_active": true,
          });
          await GoogleSheetService.updateUser({
            "app": student.app,
            "created_at": formattedDate,
          });
          await AppRepository().refreshSingleTable('users');
        } catch (e) {
          print("❌ Arka plan aktif etme senkronizasyon hatası: $e");
        }
      }());

      _showSnack(
        "✅ ${student.first_name} ${student.last_name} aktif edildi!",
        _success,
      );

      setState(() => isLoading = false);
    } catch (e) {
      _showSnack("❌ Hata: $e", _danger);
      setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // PASİF YAP
  // =========================================================================
  Future<void> _deactivateStudent(Users student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _warning, size: 28),
            const SizedBox(width: 10),
            const Text(
              "Öğrenciyi Pasif Yap",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Bu öğrenciyi pasif yapmak istediğinize emin misiniz?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Pasif öğrenciler yoklamalara katılamaz ve sistemde görünmez olur.",
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Pasif Yap",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      final repoUsers = AppRepository().allUsers;
      final idx = repoUsers.indexWhere((u) => u.app == student.app);
      if (idx != -1) {
        repoUsers[idx] = Users(
          app: student.app,
          first_name: student.first_name,
          last_name: student.last_name,
          email: student.email,
          phone: student.phone,
          role: student.role,
          b_date: student.b_date,
          profile_photo_url: student.profile_photo_url,
          is_active: "FALSE",
          created_at: student.created_at,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository().refreshMapsOnly();
      }

      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      unawaited(() async {
        try {
          await GoogleSheetService.updateUser({
            "app": student.app,
            "is_active": "FALSE",
          });
          await AppRepository().refreshSingleTable('users');
        } catch (e) {
          print("❌ Arka plan pasife alma senkronizasyon hatası: $e");
        }
      }());

      _showSnack(
        "✅ ${student.first_name} ${student.last_name} pasif yapıldı!",
        _warning,
      );

      setState(() => isLoading = false);
    } catch (e) {
      _showSnack("❌ Hata: $e", _danger);
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _success
                  ? Icons.check_circle
                  : color == _warning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // =========================================================================
  // ÖĞRENCİ KARTI - PREMIUM TASARIM
  // =========================================================================
  Widget _buildStudentCard(Users user, {required bool isActive}) {
    final groupName = _getStudentGroup(user.app);
    final registerDate = _formatDate(user.created_at);

    final isStudent = user.role.trim().toLowerCase() == "student";
    final roleLabel = isStudent ? "Öğrenci" : user.role;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? _success.withOpacity(0.2)
              : _warning.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? _success.withOpacity(0.06)
                : _warning.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [_success, Color(0xFF059669)],
                      )
                    : const LinearGradient(
                        colors: [_warning, Color(0xFFD97706)],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  user.first_name.isNotEmpty
                      ? user.first_name[0].toUpperCase()
                      : "?",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${user.first_name} ${user.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isStudent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 12,
                        color: _textSecondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            color: _textSecondary.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: _textSecondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Kayıt: $registerDate",
                        style: TextStyle(
                          color: _textSecondary.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? _danger.withOpacity(0.08)
                    : _success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? _danger.withOpacity(0.2)
                      : _success.withOpacity(0.2),
                ),
              ),
              child: GestureDetector(
                onTap: () => isActive
                    ? _deactivateStudent(user)
                    : _activateStudent(user),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.person_off_rounded
                          : Icons.person_add_rounded,
                      size: 16,
                      color: isActive ? _danger : _success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? "Pasif Yap" : "Aktif Et",
                      style: TextStyle(
                        color: isActive ? _danger : _success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(List<Users> students, bool isActive) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isActive
                    ? _success.withOpacity(0.08)
                    : _warning.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.people_outline : Icons.person_off_outlined,
                size: 48,
                color: isActive ? _success : _warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? "Aktif öğrenci yok" : "Pasif öğrenci yok",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (_, i) => _buildStudentCard(students[i], isActive: isActive),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalActive = filteredActiveStudents.length;
    final totalInactive = filteredInactiveStudents.length;

    final currentStudents = _showActiveList
        ? filteredActiveStudents
        : filteredInactiveStudents;
    final isCurrentListActive = _showActiveList;
    final currentTitle = _showActiveList
        ? "Aktif Öğrenciler"
        : "Pasif Öğrenciler";
    final currentColor = _showActiveList ? _success : _warning;
    final currentCount = _showActiveList ? totalActive : totalInactive;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: () async => _loadAllData(force: true),
              color: _accent,
              child: Column(
                children: [
                  _buildFilterSection(
                    totalActive,
                    totalInactive,
                    currentColor,
                    currentCount,
                    currentTitle,
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStudentList(
                        currentStudents,
                        isCurrentListActive,
                      ),
                    ),
                  ),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Hesap Yönetimi",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => _loadAllData(force: true),
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
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    int totalActive,
    int totalInactive,
    Color currentColor,
    int currentCount,
    String currentTitle,
  ) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _toggleButton(
                  label: "Aktif",
                  count: totalActive,
                  icon: Icons.person,
                  isActive: true,
                  color: _success,
                ),
                _toggleButton(
                  label: "Pasif",
                  count: totalInactive,
                  icon: Icons.person_off,
                  isActive: false,
                  color: _warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                    decoration: InputDecoration(
                      hintText: "İsim veya grup ara...",
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
                    style: const TextStyle(color: _textPrimary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroupFilter,
                      isExpanded: true,
                      isDense: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textSecondary,
                        size: 18,
                      ),
                      dropdownColor: _surface,
                      items: _groupFilterOptions.map((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Text(
                            name,
                            style: TextStyle(
                              color: name == _selectedGroupFilter
                                  ? _accent
                                  : _textPrimary,
                              fontSize: 12,
                              fontWeight: name == _selectedGroupFilter
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedGroupFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required int count,
    required IconData icon,
    required bool isActive,
    required Color color,
  }) {
    final isSelected = _showActiveList == isActive;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showActiveList = isActive;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                "$label ($count)",
                style: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

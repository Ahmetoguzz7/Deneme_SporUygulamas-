import 'dart:async';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class AccountantStudentActivationScreen extends StatefulWidget {
  const AccountantStudentActivationScreen({Key? key}) : super(key: key);

  @override
  _AccountantStudentActivationScreenate createState() =>
      _AccountantStudentActivationScreenate();
}

class _AccountantStudentActivationScreenate
    extends State<AccountantStudentActivationScreen> {
  // =========================================================================
  // VERİ LİSTELERİ
  // =========================================================================
  List<Users> allStudents = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];

  List<Users> activeStudents = []; // Aktif öğrenciler
  List<Users> inactiveStudents = []; // Pasif öğrenciler

  List<Users> filteredActiveStudents = [];
  List<Users> filteredInactiveStudents = [];

  // 🔥 TOGGLE DURUMU: true = Aktif listesi, false = Pasif listesi
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
  Timer? _debounceTimer;

  // =========================================================================
  // RENKLER
  // =========================================================================
  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _studentGroupCache.clear();
    super.dispose();
  }

  // =========================================================================
  // 🚀 VERİ YÜKLEME
  // =========================================================================
  /*
  void _loadAllData() {
    setState(() => isLoading = true);

    Future.microtask(() async {
      try {
        final users = await GoogleSheetService.getUsersCached();
        allStudents = users;

        allGroups = await GoogleSheetService.getGroupsCached();

        allGroupStudents = await GoogleSheetService.getGroupStudentsCached();

        _buildGroupFilterOptions();
        _loadGroupCache();
        _separateStudents();

        if (mounted) setState(() => isLoading = false);
      } catch (e, stackTrace) {
        print("Yükleme hatası: $e");

        if (mounted) setState(() => isLoading = false);
      }
    });
  }
*/
  void _loadAllData() {
    setState(() => isLoading = true);

    Future.microtask(() async {
      try {
        // 1. AŞAMA: Önce gruplar gelsin, ekran hemen açılsın
        allGroups = await GoogleSheetService.getGroupsCached();
        _buildGroupFilterOptions();
        _loadGroupCache();
        if (mounted) setState(() => isLoading = false); // gruplar göründü

        // 2. AŞAMA: Öğrenciler + ilişkiler arkadan
        final results = await Future.wait([
          GoogleSheetService.getUsersCached(),
          GoogleSheetService.getGroupStudentsCached(),
        ]);
        allStudents = results[0] as List<Users>;
        allGroupStudents = results[1] as List<GroupStudent>;
        _separateStudents();

        if (mounted) setState(() {});
      } catch (e, stackTrace) {
        print("Yükleme hatası: $e");
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  // =========================================================================
  // GRUP CACHE
  // =========================================================================
  void _loadGroupCache() {
    _studentGroupCache.clear();

    for (var student in allStudents) {
      if (student.role.trim().toLowerCase() != "student") continue;

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
      if (student.role.trim().toLowerCase() != "student") continue;

      final isActive = student.is_active.toString().toUpperCase() == "TRUE";

      if (isActive) {
        activeStudents.add(student);
      } else {
        inactiveStudents.add(student);
      }
    }

    // Alfabetik sırala
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
  // AKTİF YAP (KAYIT TARİHİ SOR)
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
    );

    if (selectedDate == null) return;

    setState(() => isLoading = true);

    try {
      final formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      // ⚡⚡ 1. ADIM: RAM (AppRepository) ÜZERİNDE ANINDA GÜNCELLE (0ms UI Tepkisi)
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
          // gender: student.gender,
          profile_photo_url: student.profile_photo_url,
          is_active: "TRUE", // RAM'de durumu anında TRUE yapıyoruz
          created_at: formattedDate,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository()
            .refreshMapsOnly(); // RAM haritalarını milisaniyede yenile kanka
      }

      // 📥 LOKAL LİSTEYİ TAZELE VE ÖĞRENCİYİ ANINDA AKTİFLER LİSTESİNE UÇUR
      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      // 📡 2. ADIM: ARKA PLANDA BULUTA SIRA İLE GÖNDER (Unawaited - UI Beklemez)
      unawaited(() async {
        try {
          // Çakışmayı önlemek için önce SADECE is_active değerini TRUE yapıyoruz!
          print("📡 Arka plan: Durum TRUE yapılıyor...");
          await GoogleSheetService.updateUser({
            "app": student.app,
            "is_active": true,
          });

          // Hemen ardından tarihi set ediyoruz, böylece script tarafı şaşırmıyor
          print("📡 Arka plan: Kayıt tarihi güncelleniyor...");
          await GoogleSheetService.updateUser({
            "app": student.app,
            "created_at": formattedDate,
          });

          // Lokal cache'i arka planda güncelle kitle
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
  // =========================================================================
  // PASİF YAP (GARANTİLİ OFFLINE-FIRST GÜNCELLEME)
  // =========================================================================
  Future<void> _deactivateStudent(Users student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _warning),
            SizedBox(width: 8),
            Text("Öğrenciyi Pasif Yap"),
          ],
        ),
        content: Text(
          "${student.first_name} ${student.last_name} öğrencisini pasif yapmak istediğinize emin misiniz?\n\nBu öğrenci artık aktif olmayacak ve yoklamalara katılamayacak.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _danger),
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
      // ⚡⚡ 1. ADIM: RAM (AppRepository) ÜZERİNDE ANINDA PASİFE ÇEK
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
          // gender: student.gender,
          profile_photo_url: student.profile_photo_url,
          is_active: "FALSE", // RAM'de pasif yaptık
          created_at: student.created_at,
          branches_id: '',
          password_hash: '',
          amount: '',
          last_login: '',
        );
        AppRepository().refreshMapsOnly();
      }

      // 📥 LOKAL LİSTEYİ TAZELE VE ÖĞRENCİYİ ANINDA PASİFLER LİSTESİNE UÇUR
      allStudents = List.from(AppRepository().allUsers);
      _separateStudents();

      // 📡 2. ADIM: ARKA PLANDA SESSİZCE BULUTA GÖNDER
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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('dd/MM/yyyy', 'tr_TR').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // =========================================================================
  // ÖĞRENCİ KARTI
  // =========================================================================
  Widget _buildStudentCard(Users student, {required bool isActive}) {
    final groupName = _getStudentGroup(student.app);
    final registerDate = _formatDate(student.created_at);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isActive
                    ? _success.withOpacity(0.1)
                    : _warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  student.first_name.isNotEmpty
                      ? student.first_name[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: isActive ? _success : _warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${student.first_name} ${student.last_name}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 10,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          groupName,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "Kayıt: $registerDate",
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Buton
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? _danger.withOpacity(0.1)
                    : _success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? _danger.withOpacity(0.3)
                      : _success.withOpacity(0.3),
                ),
              ),
              child: // Buton Bölümü (Satır 278'deki hata veren Row içi)
              GestureDetector(
                onTap: () => isActive
                    ? _deactivateStudent(student)
                    : _activateStudent(student),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ), // padding biraz daraltıldı sığsın diye
                  decoration: BoxDecoration(
                    color: isActive
                        ? _danger.withOpacity(0.1)
                        : _success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? _danger.withOpacity(0.3)
                          : _success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive
                            ? Icons.person_off_rounded
                            : Icons.person_add_rounded,
                        size: 14,
                        color: isActive ? _danger : _success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? "Pasif Yap" : "Aktif Et",
                        style: TextStyle(
                          color: isActive ? _danger : _success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LİSTE WIDGET (TEK LİSTE)
  // =========================================================================
  Widget _buildStudentList(List<Users> students, bool isActive) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? Icons.sentiment_satisfied_alt
                    : Icons.hourglass_empty,
                size: 56,
                color: _textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                isActive ? "Aktif öğrenci yok" : "Pasif öğrenci yok",
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
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

    // Gösterilecek öğrenci listesi
    final currentStudents = _showActiveList
        ? filteredActiveStudents
        : filteredInactiveStudents;
    final isCurrentListActive = _showActiveList;
    final currentTitle = _showActiveList
        ? "AKTİF ÖĞRENCİLER"
        : "PASİF ÖĞRENCİLER";
    final currentColor = _showActiveList ? _success : _warning;
    final currentCount = _showActiveList ? totalActive : totalInactive;

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
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Öğrenci Aktif/Pasif Yönetimi",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: () => _loadAllData(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async => _loadAllData(),
              color: _accent,
              child: Column(
                children: [
                  // 🔥 TOGGLE SWITCH + FİLTRE BÖLÜMÜ
                  Container(
                    color: _surface,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                              // Aktif butonu
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showActiveList = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _showActiveList
                                          ? _success
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 18,
                                          color: _showActiveList
                                              ? Colors.white
                                              : _textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Aktif ($totalActive)",
                                          style: TextStyle(
                                            color: _showActiveList
                                                ? Colors.white
                                                : _textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Pasif butonu
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showActiveList = false;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_showActiveList
                                          ? _warning
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_off,
                                          size: 18,
                                          color: !_showActiveList
                                              ? Colors.white
                                              : _textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Pasif ($totalInactive)",
                                          style: TextStyle(
                                            color: !_showActiveList
                                                ? Colors.white
                                                : _textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Arama ve Grup Filtresi
                        Row(
                          children: [
                            // Arama kutusu
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: "İsim veya grup ara...",
                                    hintStyle: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 12,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _accent,
                                      size: 18,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
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
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Grup dropdown
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGroupFilter,
                                    isExpanded: true,
                                    isDense: true,
                                    icon: const Icon(
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
                                            fontWeight:
                                                name == _selectedGroupFilter
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
                        const SizedBox(height: 8),

                        // Başlık ve sayaç
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: currentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showActiveList
                                        ? Icons.person
                                        : Icons.person_off,
                                    size: 14,
                                    color: currentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$currentTitle • $currentCount kişi",
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
                            if (_searchQuery.isNotEmpty ||
                                _selectedGroupFilter != "Tümü")
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.filter_list,
                                      size: 12,
                                      color: _accent,
                                    ),
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
                  ),

                  // ÖĞRENCİ LİSTESİ
                  Expanded(
                    child: _buildStudentList(
                      currentStudents,
                      isCurrentListActive,
                    ),
                  ),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }
}

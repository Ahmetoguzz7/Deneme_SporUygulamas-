/*
// lib/managerpage/manager_student_attendance.dart
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/widgets/data_error_state.dart';
import 'package:uuid/uuid.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;
  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  List<Group> allGroups = [];
  Group? selectedGroup;
  DateTime selectedDate = DateTime.now();
  bool _hasError = false;
  bool _isLoadingGroups = true; // 🔥 Başlangıçta yükleniyor olarak başlatıldı

  // 🔥 EKLENDİ: Ağır tablolar (ödeme/yoklama) arka planda gelince ekranı
  // tazelemek için repo akışına abonelik. Bu olmadan sayfa açılışta veri
  // gelmemiş gibi boş görünüyordu.
  StreamSubscription<bool>? _repoSub;

  @override
  void initState() {
    super.initState();
    _initOfflineService();
    _loadGroups();

    // 🔥 EKLENDİ: repo veriyi (arka planda) tazeleyince yoklama ekranını yenile.
    _repoSub = _repo.onDataUpdated.listen((_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _repoSub?.cancel(); // 🔥 EKLENDİ
    super.dispose();
  }

  Future<void> _initOfflineService() async {
    await _offlineService.init();
    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("🔄 Senkronizasyon tamamlandı, UI güncelleniyor...");
        _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("☁️ Veriler bulut ile senkronize edildi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadGroups() async {
    if (mounted) {
      setState(() {
        _isLoadingGroups = true;
        _hasError = false;
      });
    }

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    if (mounted) {
      setState(() {
        allGroups = _repo.allGroups;
        _hasError = _repo.hasError;
        _isLoadingGroups = false; // 🔥 Veriler çekildiğinde yükleme biter
      });
    }
  }

  String _getDateTurkish(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<void> _syncGroupAttendanceInBackground() async {
    if (selectedGroup == null) return;
    try {
      print(
        "☁️ Arka Plan: Seçilen ${selectedGroup!.name} grubu için günlük yoklamalar tazelemeye alınıyor...",
      );
      Future.delayed(const Duration(seconds: 4), () async {
        await _repo.refreshSingleTable('attendances');
        if (mounted) _refreshData();
      });
    } catch (e) {
      print(
        "⚠️ Arka Plan Hatası: İnternet olmadığı için günlük yoklama eşitlemesi atlandı, lokale güveniliyor.",
      );
    }
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    if (selectedGroup == null) {
      return {'students': [], 'yoklamaListesi': []};
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == selectedGroup!.groups_id &&
              rel.is_active.toString().toUpperCase().trim() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student" &&
              user.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();

    // 🔥 DEĞİŞTİ: Yoklamayı İKİ kaynaktan birleştir.
    //   1) Sunucudan senkronlanan kayıtlar  -> _repo.allAttendances (SQLite)
    //   2) Bu cihazda henüz senkronlanmamış yerel işaretler -> _offlineService (Hive)
    // Eskiden yalnızca (2) okunuyordu; Hive boşsa (yeni cihaz / cache silinmiş)
    // sunucudaki veri görünmüyor, herkes "yok" çıkıyordu. Artık ikisi birleşiyor.
    final _attDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final serverAttendances = _repo.allAttendances.where((a) {
      final d = a.attendance_date.split('T')[0];
      return d == _attDate && a.groups_id == selectedGroup!.groups_id;
    }).toList();

    final localAttendances = await _offlineService.getLocalAttendances(
      selectedGroup!.groups_id,
      selectedDate,
    );

    // student_id -> Attendance. Önce sunucu doldurur, sonra yerelle ezilir
    // (yerel = kullanıcının en güncel, henüz gönderilmemiş işareti → o kazanır).
    final Map<String, Attendance> attByStudent = {
      for (final a in serverAttendances) a.student_id: a,
    };
    for (final a in localAttendances) {
      attByStudent[a.student_id] = a;
    }

    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final Map<String, bool> paymentStatus = {};

    for (var student in students) {
      final monthlyFee = double.tryParse(student.amount) ?? 0;
      if (monthlyFee == 0) {
        paymentStatus[student.app] = true;
        continue;
      }

      double paidThisMonth = 0;
      for (var payment in allPayments) {
        try {
          if (payment.student_id != student.app) continue;

          final status = payment.status.toString().toUpperCase();
          if (status != "TRUE" && status != "PAID") continue;

          final paymentDateStr = payment.paid_date;
          if (paymentDateStr == null || paymentDateStr.isEmpty) continue;

          String datePart = paymentDateStr;
          if (datePart.contains('T')) {
            datePart = datePart.split('T')[0];
          }

          final paidDate = DateTime.parse(datePart);
          if (paidDate.year == selectedMonth.year &&
              paidDate.month == selectedMonth.month) {
            paidThisMonth += double.tryParse(payment.amount) ?? 0;
          }
        } catch (e) {
          continue;
        }
      }
      paymentStatus[student.app] = paidThisMonth >= monthlyFee;
    }

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      final localAtt =
          attByStudent[ogrenci.app] ??
          Attendance(
            attendances_id: Uuid().v4(),
            groups_id: selectedGroup!.groups_id,
            student_id: ogrenci.app,
            taken_by: widget.currentUser.app,
            attendance_date: "",
            status: "FALSE",
            note: "",
          );

      final statusStr = localAtt.status.toString().toUpperCase().trim();
      final isPresent = (statusStr == "TRUE" || statusStr == "1");
      final hasPaid = paymentStatus[ogrenci.app] ?? false;

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": isPresent,
        "has_paid": hasPaid,
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': attByStudent.isNotEmpty,
    };
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null && picked != selectedDate) {
      if (mounted) {
        setState(() {
          selectedDate = picked;
          _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
        });
        unawaited(_syncGroupAttendanceInBackground());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedGroup?.name ?? "Yoklama Paneli",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _getDateTurkish(selectedDate),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: "Tarih Seç",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Group>(
                hint: const Text("Grup Seçiniz"),
                value: selectedGroup,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                // Veriler yüklenene kadar dropdown seçimini kapatabiliriz veya boş liste gösterebiliriz
                items: _isLoadingGroups
                    ? []
                    : [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("-- Grup Seçiniz --"),
                        ),
                        ...allGroups.map(
                          (g) =>
                              DropdownMenuItem(value: g, child: Text(g.name)),
                        ),
                      ],
                onChanged: _isLoadingGroups
                    ? null
                    : (group) {
                        setState(() {
                          selectedGroup = group;
                          _refreshKey = DateTime.now().millisecondsSinceEpoch
                              .toString();
                        });
                        unawaited(_syncGroupAttendanceInBackground());
                      },
              ),
            ),
          ),
          Expanded(
            child: _isLoadingGroups
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  ) // 🔥 Veriler gelene kadar sadece bu döner, içeriye girilmez
                : _hasError && allGroups.isEmpty
                ? DataErrorState(
                    message:
                        _repo.lastErrorMessage ??
                        "Gruplar yüklenemedi. Lütfen tekrar deneyin.",
                    onRetry: _loadGroups,
                  )
                : selectedGroup == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text("Lütfen bir grup seçin"),
                      ],
                    ),
                  )
                : FutureBuilder<Map<String, dynamic>>(
                    key: ValueKey(_refreshKey),
                    future: _loadAttendanceData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.indigo,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Veriler yüklenirken hata oluştu"),
                        );
                      }
                      final list =
                          snapshot.data?['yoklamaListesi']
                              as List<Map<String, dynamic>>? ??
                          [];
                      return _YoklamaWidget(
                        key: ValueKey('yoklama_widget_${_refreshKey}'),
                        yoklamaListesi: list,
                        selectedGroup: selectedGroup!,
                        currentUser: widget.currentUser,
                        selectedDate: selectedDate,
                        onSaveComplete: _refreshData,
                      );
                    },
                  ),
          ),
          const VersionFooter(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ============================================================================
// YOKLAMA WIDGET
// ============================================================================
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final DateTime selectedDate;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.selectedDate,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];
  bool _showSuccess = false;
  String? _lastSaveMessage;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _localStorage.init();
    _offlineService.init();

    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("🔄 Senkronizasyon tamamlandı, UI güncelleniyor...");
        _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("☁️ Veriler bulut ile senkronize edildi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _refreshData() {
    setState(() {});
  }

  void _updateAttendance(int index, bool value) {
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges || _isSaving) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    final formattedDate =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> allItems = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
      final isPresent = item["is_present"] == true;
      final note = item["note"] ?? "";

      final existingIndex = _repo.allAttendances.indexWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );

      String attendanceId;
      if (existingIndex != -1) {
        attendanceId = _repo.allAttendances[existingIndex].attendances_id;
      } else if (item["attendance_id"] != null &&
          item["attendance_id"].toString().isNotEmpty) {
        attendanceId = item["attendance_id"].toString();
      } else {
        attendanceId = const Uuid().v4();
      }

      final attRecord = Attendance(
        attendances_id: attendanceId,
        groups_id: widget.selectedGroup.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      _repo.allAttendances.removeWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );
      _repo.allAttendances.add(attRecord);

      allItems.add({
        "student": student,
        "is_present": isPresent,
        "note": note,
        "attendance_id": attendanceId,
        "taken_by": widget.currentUser.app,
      });
    }

    await _localStorage.saveAttendances(_repo.allAttendances);

    final result = await _offlineService.saveAttendanceBatch(
      allItems,
      widget.selectedDate,
      widget.selectedGroup,
      widget.currentUser,
    );

    await _repo.refreshSingleTable('attendances');

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${allItems.length} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    _successTimer?.cancel();
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    if (mounted) {
      widget.onSaveComplete();
    }
  }

  void _showNoteDialog(int index, Users student) {
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${student.first_name} ${student.last_name}"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Not ekle...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateNote(index, controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Not kaydedildi"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, double size, Users student) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(student, size),
            ),
          )
        : _buildDefaultAvatar(student, size);
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredList {
    var list = _yoklamaListesi;
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final ogrenci = item["student"] as Users;
        return ogrenci.first_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            ogrenci.last_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }
    if (_selectedFilter == "Gelenler") {
      list = list.where((item) => item["is_present"] == true).toList();
    } else if (_selectedFilter == "Gelmeyenler") {
      list = list.where((item) => item["is_present"] == false).toList();
    }
    return list;
  }

  int get presentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == true).length;
  int get absentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == false).length;
  int get totalCount => _yoklamaListesi.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Toplam", totalCount, Icons.people, Colors.white),
              _statItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _statItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _statItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),
        if (_showSuccess && _lastSaveMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastSaveMessage!,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 18),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFilter = value!),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return _buildStudentCard(
                      item["student"] as Users,
                      item["is_present"] == true,
                      (item["note"] ?? "").isNotEmpty,
                      item["has_paid"] == false,
                      _yoklamaListesi.indexOf(item),
                    );
                  },
                ),
        ),
        if (_hasUnsavedChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 20),
                label: Text(
                  _isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statItem(String title, dynamic value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    bool hasDebt,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPresent
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildProfileImage(student.profile_photo_url, 55, student),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${student.first_name} ${student.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDebt)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Tooltip(
                            message:
                                "Bu öğrencinin bu ay için ödenmemiş borcu var!",
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (student.b_date.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 12,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_formatDateTurkish(student.b_date)} ",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (student.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Colors.green.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            student.phone,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 12,
                            color: Colors.indigo.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _yoklamaListesi[index]["note"] ?? "",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.indigo.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(index, val),
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.shade100,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final url = Uri.parse("tel:${student.phone}");
                          if (await canLaunchUrl(url)) await launchUrl(url);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showNoteDialog(index, student),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasNote
                              ? Colors.indigo.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.note_alt_outlined,
                          color: hasNote ? Colors.indigo : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  String _formatDateTurkish(String b_date) {
    try {
      final date = DateTime.parse(b_date);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return b_date;
    }
  }
}

*/
// lib/managerpage/manager_student_attendance.dart
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/widgets/data_error_state.dart';
import 'package:uuid/uuid.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;
  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  List<Group> allGroups = [];
  Group? selectedGroup;
  DateTime selectedDate = DateTime.now();
  bool _hasError = false;
  bool _isLoadingGroups = true;
  bool _isRefreshing = false;

  StreamSubscription<bool>? _repoSub;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initOfflineService();
    _loadGroups();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _repoSub = _repo.onDataUpdated.listen((_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _repoSub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initOfflineService() async {
    await _offlineService.init();
    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.cloud_done, color: Colors.white),
                SizedBox(width: 12),
                Text("Veriler bulut ile senkronize edildi!"),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadGroups({bool force = false}) async {
    if (mounted) {
      setState(() {
        _isLoadingGroups = true;
        _hasError = false;
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
        allGroups = _repo.allGroups;
        _hasError = _repo.hasError;
        _isLoadingGroups = false;
        _isRefreshing = false;
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  String _getDateTurkish(DateTime date) {
    return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<void> _syncGroupAttendanceInBackground() async {
    if (selectedGroup == null) return;
    try {
      await Future.delayed(const Duration(seconds: 4), () async {
        await _repo.refreshSingleTable('attendances');
        if (mounted) _refreshData();
      });
    } catch (e) {}
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    if (selectedGroup == null) {
      return {'students': [], 'yoklamaListesi': []};
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == selectedGroup!.groups_id &&
              rel.is_active.toString().toUpperCase().trim() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student" &&
              user.is_active.toString().trim().toUpperCase() == "TRUE",
        )
        .toList();

    final _attDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final serverAttendances = _repo.allAttendances.where((a) {
      final d = a.attendance_date.split('T')[0];
      return d == _attDate && a.groups_id == selectedGroup!.groups_id;
    }).toList();

    final localAttendances = await _offlineService.getLocalAttendances(
      selectedGroup!.groups_id,
      selectedDate,
    );

    final Map<String, Attendance> attByStudent = {
      for (final a in serverAttendances) a.student_id: a,
    };
    for (final a in localAttendances) {
      attByStudent[a.student_id] = a;
    }

    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final Map<String, bool> paymentStatus = {};

    for (var student in students) {
      final monthlyFee = double.tryParse(student.amount) ?? 0;
      if (monthlyFee == 0) {
        paymentStatus[student.app] = true;
        continue;
      }

      double paidThisMonth = 0;
      for (var payment in allPayments) {
        try {
          if (payment.student_id != student.app) continue;
          final status = payment.status.toString().toUpperCase();
          if (status != "TRUE" && status != "PAID") continue;
          final paymentDateStr = payment.paid_date;
          if (paymentDateStr == null || paymentDateStr.isEmpty) continue;
          String datePart = paymentDateStr;
          if (datePart.contains('T')) {
            datePart = datePart.split('T')[0];
          }
          final paidDate = DateTime.parse(datePart);
          if (paidDate.year == selectedMonth.year &&
              paidDate.month == selectedMonth.month) {
            paidThisMonth += double.tryParse(payment.amount) ?? 0;
          }
        } catch (e) {
          continue;
        }
      }
      paymentStatus[student.app] = paidThisMonth >= monthlyFee;
    }

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      final localAtt =
          attByStudent[ogrenci.app] ??
          Attendance(
            attendances_id: Uuid().v4(),
            groups_id: selectedGroup!.groups_id,
            student_id: ogrenci.app,
            taken_by: widget.currentUser.app,
            attendance_date: "",
            status: "FALSE",
            note: "",
          );

      final statusStr = localAtt.status.toString().toUpperCase().trim();
      final isPresent = (statusStr == "TRUE" || statusStr == "1");
      final hasPaid = paymentStatus[ogrenci.app] ?? false;

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": isPresent,
        "has_paid": hasPaid,
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': attByStudent.isNotEmpty,
    };
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1E293B)),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      if (mounted) {
        setState(() {
          selectedDate = picked;
          _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
        });
        unawaited(_syncGroupAttendanceInBackground());
      }
    }
  }

  // ======================== RENK PALETİ ========================
  static const Color _primaryColor = Color(0xFF0F172A);
  static const Color _secondaryColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF6366F1);
  static const Color _gradientStart = Color(0xFF1E293B);
  static const Color _gradientEnd = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildGroupDropdown(),
          Expanded(
            child: _isLoadingGroups
                ? _buildLoadingState()
                : _hasError && allGroups.isEmpty
                ? DataErrorState(
                    message:
                        _repo.lastErrorMessage ??
                        "Gruplar yüklenemedi. Lütfen tekrar deneyin.",
                    onRetry: () => _loadGroups(force: true),
                  )
                : selectedGroup == null
                ? _buildEmptyGroupState()
                : FutureBuilder<Map<String, dynamic>>(
                    key: ValueKey(_refreshKey),
                    future: _loadAttendanceData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }
                      if (snapshot.hasError) {
                        return _buildErrorState();
                      }
                      final list =
                          snapshot.data?['yoklamaListesi']
                              as List<Map<String, dynamic>>? ??
                          [];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _YoklamaWidget(
                          key: ValueKey('yoklama_widget_${_refreshKey}'),
                          yoklamaListesi: list,
                          selectedGroup: selectedGroup!,
                          currentUser: widget.currentUser,
                          selectedDate: selectedDate,
                          onSaveComplete: _refreshData,
                        ),
                      );
                    },
                  ),
          ),
          const VersionFooter(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedGroup?.name ?? "Yoklama Paneli",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                _getDateTurkish(selectedDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          onPressed: _selectDate,
          tooltip: "Tarih Seç",
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => _loadGroups(force: true),
          tooltip: "Tüm Verileri Yenile",
        ),
      ],
    );
  }

  Widget _buildGroupDropdown() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Group>(
          hint: Row(
            children: [
              Icon(Icons.group, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                "Grup Seçiniz",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
          value: selectedGroup,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: _accentColor, size: 28),
          items: _isLoadingGroups
              ? []
              : [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("-- Grup Seçiniz --"),
                  ),
                  ...allGroups.map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getGroupColor(g.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(g.name)),
                        ],
                      ),
                    ),
                  ),
                ],
          onChanged: _isLoadingGroups
              ? null
              : (group) {
                  setState(() {
                    selectedGroup = group;
                    _refreshKey = DateTime.now().millisecondsSinceEpoch
                        .toString();
                  });
                  unawaited(_syncGroupAttendanceInBackground());
                },
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accentColor,
            ),
          ),
          SizedBox(height: 16),
          Text("Yükleniyor...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            "Veriler yüklenirken hata oluştu",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadGroups(force: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Tekrar Dene",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGroupState() {
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
            child: Icon(Icons.group_off, size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            "Lütfen bir grup seçin",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yoklama almak için yukarıdan bir grup seçin",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Color _getGroupColor(String groupName) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    final index = groupName.hashCode.abs() % colors.length;
    return colors[index];
  }
}

// ============================================================================
// YOKLAMA WIDGET - YENİ TASARIM
// ============================================================================
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final DateTime selectedDate;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.selectedDate,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];
  bool _showSuccess = false;
  String? _lastSaveMessage;
  Timer? _successTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _localStorage.init();
    _offlineService.init();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.cloud_done, color: Colors.white),
                SizedBox(width: 12),
                Text("Veriler bulut ile senkronize edildi!"),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _refreshData() {
    setState(() {});
  }

  void _updateAttendance(int index, bool value) {
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges || _isSaving) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    final formattedDate =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> allItems = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
      final isPresent = item["is_present"] == true;
      final note = item["note"] ?? "";

      final existingIndex = _repo.allAttendances.indexWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );

      String attendanceId;
      if (existingIndex != -1) {
        attendanceId = _repo.allAttendances[existingIndex].attendances_id;
      } else if (item["attendance_id"] != null &&
          item["attendance_id"].toString().isNotEmpty) {
        attendanceId = item["attendance_id"].toString();
      } else {
        attendanceId = const Uuid().v4();
      }

      final attRecord = Attendance(
        attendances_id: attendanceId,
        groups_id: widget.selectedGroup.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      _repo.allAttendances.removeWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );
      _repo.allAttendances.add(attRecord);

      allItems.add({
        "student": student,
        "is_present": isPresent,
        "note": note,
        "attendance_id": attendanceId,
        "taken_by": widget.currentUser.app,
      });
    }

    await _localStorage.saveAttendances(_repo.allAttendances);
    await _offlineService.saveAttendanceBatch(
      allItems,
      widget.selectedDate,
      widget.selectedGroup,
      widget.currentUser,
    );
    await _repo.refreshSingleTable('attendances');

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${allItems.length} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    _successTimer?.cancel();
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    if (mounted) {
      widget.onSaveComplete();
    }
  }

  void _showNoteDialog(int index, Users student) {
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
              child: Text(
                student.first_name.isNotEmpty
                    ? student.first_name[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${student.first_name} ${student.last_name}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Not ekle...",
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateNote(index, controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Not kaydedildi"),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, double size, Users student) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(student, size),
            ),
          )
        : _buildDefaultAvatar(student, size);
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredList {
    var list = _yoklamaListesi;
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final ogrenci = item["student"] as Users;
        return ogrenci.first_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            ogrenci.last_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }
    if (_selectedFilter == "Gelenler") {
      list = list.where((item) => item["is_present"] == true).toList();
    } else if (_selectedFilter == "Gelmeyenler") {
      list = list.where((item) => item["is_present"] == false).toList();
    }
    return list;
  }

  int get presentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == true).length;
  int get absentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == false).length;
  int get totalCount => _yoklamaListesi.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatisticsCard(),
        if (_showSuccess && _lastSaveMessage != null) _buildSuccessMessage(),
        _buildSearchBar(),
        Expanded(
          child: _filteredList.isEmpty
              ? _buildEmptySearchState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildStudentCard(
                        item["student"] as Users,
                        item["is_present"] == true,
                        (item["note"] ?? "").isNotEmpty,
                        item["has_paid"] == false,
                        _yoklamaListesi.indexOf(item),
                      ),
                    );
                  },
                ),
        ),
        if (_hasUnsavedChanges) _buildSaveButton(),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Toplam", totalCount, Icons.people, Colors.white),
          _statItem(
            "Gelen",
            presentCount,
            Icons.check_circle,
            const Color(0xFF34D399),
          ),
          _statItem(
            "Gelmeyen",
            absentCount,
            Icons.cancel,
            const Color(0xFFF87171),
          ),
          _statItem(
            "Katılım",
            "${presentPercentage.toStringAsFixed(0)}%",
            Icons.trending_up,
            const Color(0xFFFBBF24),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String title, dynamic value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF34D399)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _lastSaveMessage!,
                style: const TextStyle(
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Öğrenci ara...",
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(
                  Icons.filter_list,
                  color: Colors.grey.shade600,
                  size: 18,
                ),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _filterOptions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedFilter = value!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Öğrenci bulunamadı",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Farklı bir arama yapmayı deneyin",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _isSaving
                ? LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (!_isSaving)
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSaving ? null : _saveAttendance,
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Kaydediliyor...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.save, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Yoklamayı Kaydet",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    bool hasDebt,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF34D399).withOpacity(0.4)
              : const Color(0xFFF87171).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPresent
                ? const Color(0xFF34D399).withOpacity(0.08)
                : const Color(0xFFF87171).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _buildProfileImage(student.profile_photo_url, 52, student),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${student.first_name} ${student.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDebt)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                "Borç",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      if (student.b_date.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: 12,
                              color: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDateTurkish(student.b_date),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      if (student.phone.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 12,
                              color: const Color(0xFF34D399),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              student.phone,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 12,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _yoklamaListesi[index]["note"] ?? "",
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF6366F1),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(index, val),
                    activeColor: const Color(0xFF34D399),
                    inactiveThumbColor: const Color(0xFFF87171),
                    inactiveTrackColor: const Color(0xFFFEE2E2),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final url = Uri.parse("tel:${student.phone}");
                          if (await canLaunchUrl(url)) await launchUrl(url);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Color(0xFF34D399),
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showNoteDialog(index, student),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasNote
                              ? const Color(0xFF6366F1).withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.note_alt_outlined,
                          color: hasNote
                              ? const Color(0xFF6366F1)
                              : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _formatDateTurkish(String b_date) {
    try {
      final date = DateTime.parse(b_date);
      final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return b_date;
    }
  }
}

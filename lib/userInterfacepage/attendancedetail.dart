/*
import 'dart:async';

import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:uuid/uuid.dart'; // 🔥 YENİ: UUID paketi import edildi

class YoklamaSayfasi extends StatefulWidget {
  final Group selectedGroup;
  final Users currentUser;

  const YoklamaSayfasi({
    super.key,
    required this.selectedGroup,
    required this.currentUser,
  });

  @override
  State<YoklamaSayfasi> createState() => _YoklamaSayfasiState();
}

class _YoklamaSayfasiState extends State<YoklamaSayfasi> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();
    if (mounted) {
      setState(() {});
    }
  }

  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
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
              widget.selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(_getTodayDateTurkish(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(_refreshKey),
          future: _loadAttendanceData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text("Yoklama verileri yükleniyor..."),
                  ],
                ),
              );
            }

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
                    const Text("Veriler yüklenirken hata oluştu"),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              );
            }

            final yoklamaListesi =
                snapshot.data?['yoklamaListesi']
                    as List<Map<String, dynamic>>? ??
                [];
            final students = snapshot.data?['students'] as List<Users>? ?? [];

            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text("Bu grupta henüz öğrenci yok"),
                  ],
                ),
              );
            }

            return _YoklamaWidget(
              key: ValueKey('yoklama_widget_$_refreshKey'),
              yoklamaListesi: yoklamaListesi,
              selectedGroup: widget.selectedGroup,
              currentUser: widget.currentUser,
              onSaveComplete: _refreshData,
            );
          },
        ),
      ),
    );
  }

  /// 🔥 SADECE LOKAL VERİYİ KULLAN
  /*
  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    // 🔥 LOKAL VERİLERİ ÇEK
    await _offlineService.init();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    const uuid =
        Uuid(); // 🔥 YENİ: Cihazda anlık UUID üretici nesnesi tanımlandı
    final List<Map<String, dynamic>> yoklamaListesi = [];

    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          // 🔥 DÜZELTİLDİ: Boş string yerine daha en başta benzersiz bir UUID v4 mühürlüyoruz
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: ogrenci.app,
          taken_by: widget.currentUser.app,
          attendance_date: formattedDate,
          status: "FALSE",
          note: "",
        ),
      );

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        // 🔥 DÜZELTİLDİ: Sadece id kontrolü yerine listenin içinde var mı diye bakıyoruz
        "has_attendance": localAttendances.any(
          (att) => att.student_id == ogrenci.app,
        ),
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }
}
*/
  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments; // 🔥 YENİ: Ödemeleri al

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    // 🔥 LOKAL VERİLERİ ÇEK
    await _offlineService.init();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    // 🔥🔥🔥 BORÇ KONTROLÜ EKLENDİ
    final selectedMonth = DateTime(now.year, now.month);
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

    const uuid = Uuid();
    final List<Map<String, dynamic>> yoklamaListesi = [];

    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: ogrenci.app,
          taken_by: widget.currentUser.app,
          attendance_date: formattedDate,
          status: "FALSE",
          note: "",
        ),
      );

      final hasPaid = paymentStatus[ogrenci.app] ?? false; // 🔥 BORÇ DURUMU

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAttendances.any(
          (att) => att.student_id == ogrenci.app,
        ),
        "attendance_id": localAtt.attendances_id,
        "has_paid": hasPaid, // 🔥 EKLENDİ
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }
}

// 🔥 OFFLINE-FIRST YOKLAMA WIDGET
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;
  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  String? _lastSaveMessage;
  bool _showSuccess = false;
  StreamSubscription<List<Attendance>>? _syncSubscription;
  Timer? _successMessageTimer;
  bool _isLoadingLocalData = false;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();

    _syncSubscription = _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("📢 Sync tamamlandı, lokal veriler yenileniyor...");
        _refreshLocalData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocalData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _successMessageTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_YoklamaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yoklamaListesi != widget.yoklamaListesi && mounted) {
      setState(() {
        _yoklamaListesi = List.from(widget.yoklamaListesi);
        _hasUnsavedChanges = false;
      });
      _refreshLocalData();
    }
  }

  void _updateAttendance(int index, bool value) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    await _offlineService.init();

    final now = DateTime.now();
    final result = await _offlineService.saveAttendanceBatch(
      _yoklamaListesi,
      now,
      widget.selectedGroup,
      widget.currentUser,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${result['savedCount']} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    await _refreshLocalData();

    _successMessageTimer?.cancel();
    _successMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    widget.onSaveComplete();
  }

  /*
  Future<void> _refreshLocalData() async {
    if (!mounted) return;
    if (_isLoadingLocalData) return;

    _isLoadingLocalData = true;

    final now = DateTime.now();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    if (!mounted) {
      _isLoadingLocalData = false;
      return;
    }

    const uuid = Uuid(); // 🔥 YENİ: UUID nesnesi tanımlandı
    final List<Map<String, dynamic>> newList = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;

      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == student.app,
        orElse: () => Attendance(
          // 🔥 DÜZELTİLDİ: Yenileme esnasında da boş ID yerine kalıcı mühür basılıyor
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: student.app,
          taken_by: widget.currentUser.app,
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      newList.add({
        "student": student,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        // 🔥 DÜZELTİLDİ: Durum güncellendi
        "has_attendance": localAttendances.any(
          (att) => att.student_id == student.app,
        ),
        "attendance_id": localAtt.attendances_id,
      });
    }

    if (mounted) {
      setState(() {
        _yoklamaListesi = newList;
      });
    }

    _isLoadingLocalData = false;
  }
*/
  Future<void> _refreshLocalData() async {
    if (!mounted) return;
    if (_isLoadingLocalData) return;

    _isLoadingLocalData = true;

    final now = DateTime.now();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    if (!mounted) {
      _isLoadingLocalData = false;
      return;
    }

    // 🔥 BORÇ KONTROLÜ İÇİN ÖDEMELERİ AL
    final allPayments = _repo.allPayments;
    final selectedMonth = DateTime(now.year, now.month);
    final Map<String, bool> paymentStatus = {};

    // Öğrencilerin borç durumunu hesapla
    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
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

    const uuid = Uuid();
    final List<Map<String, dynamic>> newList = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;

      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == student.app,
        orElse: () => Attendance(
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: student.app,
          taken_by: widget.currentUser.app,
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      final hasPaid = paymentStatus[student.app] ?? false; // 🔥 BORÇ DURUMU

      newList.add({
        "student": student,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAttendances.any(
          (att) => att.student_id == student.app,
        ),
        "attendance_id": localAtt.attendances_id,
        "has_paid": hasPaid, // 🔥 EKLENDİ
      });
    }

    if (mounted) {
      setState(() {
        _yoklamaListesi = newList;
      });
    }

    _isLoadingLocalData = false;
  }

  String _formatDateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users student,
  ) {
    final String heroTag = 'profile_photo_${student.profile_photo_url}_$size';
    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultAvatar(student, size),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(student, size);
    }
    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
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

  void _showStudentDetailDialog(BuildContext context, Users student) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildProfileImage(
                    ctx,
                    student.profile_photo_url,
                    100,
                    student,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.phone,
                        Colors.green,
                        "Telefon",
                        student.phone.isNotEmpty
                            ? student.phone
                            : "Belirtilmemiş",
                        onCall: student.phone.isNotEmpty
                            ? () async {
                                final url = Uri.parse("tel:${student.phone}");
                                if (await canLaunchUrl(url))
                                  await launchUrl(url);
                              }
                            : null,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        _formatDateFromString(student.b_date),
                        subtitle: _calculateAge(student.b_date) > 0
                            ? "${_calculateAge(student.b_date)} yaşında"
                            : null,
                      ),
                      if (student.mother_name.isNotEmpty ||
                          student.father_name.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildDetailRow(
                          Icons.family_restroom,
                          Colors.purple,
                          "Aile",
                          [
                            if (student.mother_name.isNotEmpty)
                              "Anne: ${student.mother_name}",
                            if (student.father_name.isNotEmpty)
                              "Baba: ${student.father_name}",
                          ].join("\n"),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Kapat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value, {
    String? subtitle,
    VoidCallback? onCall,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (onCall != null)
            GestureDetector(
              onTap: onCall,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showNoteDialog(int index, Users student) {
    if (!mounted) return;

    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "${student.first_name} ${student.last_name}",
          style: const TextStyle(fontSize: 16),
        ),
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Not kaydedildi"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
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
              _buildStatItem("Toplam", totalCount, Icons.people, Colors.white),
              _buildStatItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _buildStatItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),
        if (_showSuccess && _lastSaveMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      if (mounted) setState(() => _searchQuery = value);
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                      if (mounted && value != null) {
                        setState(() => _selectedFilter = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
                      Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final originalIndex = _yoklamaListesi.indexOf(item);
                    final ogrenci = item["student"] as Users;
                    final isPresent = item["is_present"] == true;
                    final hasNote = (item["note"] ?? "").isNotEmpty;
                    return _buildStudentCard(
                      ogrenci,
                      isPresent,
                      hasNote,
                      originalIndex,
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
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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
        const VersionFooter(),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildStatItem(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
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

  /*
  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    int index,
  ) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

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
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${student.first_name} ${student.last_name}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
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
                    ],
                  ],
                ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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
*/
  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    int index,
  ) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

    // 🔥 YENİ: Borç durumunu al
    final hasDebt = _yoklamaListesi[index]["has_paid"] == false;

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
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
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
                        // 🔥🔥🔥 BORÇ UYARISI EKLENDİ
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
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
                    ],
                  ],
                ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
*/
/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';

class YoklamaSayfasi extends StatefulWidget {
  final Group selectedGroup;
  final Users currentUser;

  const YoklamaSayfasi({
    super.key,
    required this.selectedGroup,
    required this.currentUser,
  });

  @override
  State<YoklamaSayfasi> createState() => _YoklamaSayfasiState();
}

class _YoklamaSayfasiState extends State<YoklamaSayfasi> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();
    if (mounted) {
      setState(() {});
    }
  }

  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
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
              widget.selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(_getTodayDateTurkish(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(_refreshKey),
          future: _loadAttendanceData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text("Yoklama verileri yükleniyor..."),
                  ],
                ),
              );
            }

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
                    const Text("Veriler yüklenirken hata oluştu"),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              );
            }

            final yoklamaListesi =
                snapshot.data?['yoklamaListesi']
                    as List<Map<String, dynamic>>? ??
                [];
            final students = snapshot.data?['students'] as List<Users>? ?? [];

            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text("Bu grupta henüz öğrenci yok"),
                  ],
                ),
              );
            }

            return _YoklamaWidget(
              key: ValueKey('yoklama_widget_$_refreshKey'),
              yoklamaListesi: yoklamaListesi,
              selectedGroup: widget.selectedGroup,
              currentUser: widget.currentUser,
              onSaveComplete: _refreshData,
            );
          },
        ),
      ),
    );
  }

  /// 🔥 SADECE LOKAL VERİYİ KULLAN
  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    // 🔥 LOKAL VERİLERİ ÇEK
    await _offlineService.init();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: widget.selectedGroup.groups_id,
          student_id: ogrenci.app,
          taken_by: widget.currentUser.app, // 🔥 Doğru kullanıcı kimliği atandı
          attendance_date: formattedDate,
          status: "FALSE",
          note: "",
        ),
      );

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }
}

// 🔥 OFFLINE-FIRST YOKLAMA WIDGET
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;
  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  String? _lastSaveMessage;
  bool _showSuccess = false;
  StreamSubscription<List<Attendance>>? _syncSubscription;
  Timer? _successMessageTimer;
  bool _isLoadingLocalData = false;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();

    _syncSubscription = _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("📢 Sync tamamlandı, lokal veriler yenileniyor...");
        _refreshLocalData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocalData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _successMessageTimer?.cancel();
    // Service'i dispose ETME!
    super.dispose();
  }

  @override
  void didUpdateWidget(_YoklamaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yoklamaListesi != widget.yoklamaListesi && mounted) {
      setState(() {
        _yoklamaListesi = List.from(widget.yoklamaListesi);
        _hasUnsavedChanges = false;
      });
      _refreshLocalData();
    }
  }

  void _updateAttendance(int index, bool value) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    await _offlineService.init();

    final now = DateTime.now();
    final result = await _offlineService.saveAttendanceBatch(
      _yoklamaListesi,
      now,
      widget.selectedGroup,
      widget.currentUser,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${result['savedCount']} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    await _refreshLocalData();

    _successMessageTimer?.cancel();
    _successMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    widget.onSaveComplete();
  }

  Future<void> _refreshLocalData() async {
    if (!mounted) return;
    if (_isLoadingLocalData) return;

    _isLoadingLocalData = true;

    final now = DateTime.now();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    if (!mounted) {
      _isLoadingLocalData = false;
      return;
    }

    // 🔥 YEPYENİ BİR LİSTE OLUŞTUR
    final List<Map<String, dynamic>> newList = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;

      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == student.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: widget.selectedGroup.groups_id,
          student_id: student.app,
          // 🔥 İşte altından girip üstünden çıktığımız o can alıcı düzeltme:
          taken_by: widget.currentUser.app,
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      newList.add({
        "student": student,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    if (mounted) {
      setState(() {
        _yoklamaListesi = newList;
      });
    }

    _isLoadingLocalData = false;
  }

  String _formatDateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users student,
  ) {
    final String heroTag = 'profile_photo_${student.profile_photo_url}_$size';
    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultAvatar(student, size),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(student, size);
    }
    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
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

  void _showStudentDetailDialog(BuildContext context, Users student) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildProfileImage(
                    ctx,
                    student.profile_photo_url,
                    100,
                    student,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.phone,
                        Colors.green,
                        "Telefon",
                        student.phone.isNotEmpty
                            ? student.phone
                            : "Belirtilmemiş",
                        onCall: student.phone.isNotEmpty
                            ? () async {
                                final url = Uri.parse("tel:${student.phone}");
                                if (await canLaunchUrl(url))
                                  await launchUrl(url);
                              }
                            : null,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        _formatDateFromString(student.b_date),
                        subtitle: _calculateAge(student.b_date) > 0
                            ? "${_calculateAge(student.b_date)} yaşında"
                            : null,
                      ),
                      if (student.mother_name.isNotEmpty ||
                          student.father_name.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildDetailRow(
                          Icons.family_restroom,
                          Colors.purple,
                          "Aile",
                          [
                            if (student.mother_name.isNotEmpty)
                              "Anne: ${student.mother_name}",
                            if (student.father_name.isNotEmpty)
                              "Baba: ${student.father_name}",
                          ].join("\n"),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Kapat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value, {
    String? subtitle,
    VoidCallback? onCall,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (onCall != null)
            GestureDetector(
              onTap: onCall,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showNoteDialog(int index, Users student) {
    if (!mounted) return;

    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "${student.first_name} ${student.last_name}",
          style: const TextStyle(fontSize: 16),
        ),
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Not kaydedildi"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
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
              _buildStatItem("Toplam", totalCount, Icons.people, Colors.white),
              _buildStatItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _buildStatItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),
        if (_showSuccess && _lastSaveMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      if (mounted) setState(() => _searchQuery = value);
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                      if (mounted && value != null) {
                        setState(() => _selectedFilter = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
                      Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final originalIndex = _yoklamaListesi.indexOf(item);
                    final ogrenci = item["student"] as Users;
                    final isPresent = item["is_present"] == true;
                    final hasNote = (item["note"] ?? "").isNotEmpty;
                    return _buildStudentCard(
                      ogrenci,
                      isPresent,
                      hasNote,
                      originalIndex,
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
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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

  Widget _buildStatItem(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
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
    int index,
  ) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

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
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${student.first_name} ${student.last_name}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
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
                    ],
                  ],
                ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
*/
import 'dart:async';

import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:uuid/uuid.dart'; // 🔥 YENİ: UUID paketi import edildi

class YoklamaSayfasi extends StatefulWidget {
  final Group selectedGroup;
  final Users currentUser;

  const YoklamaSayfasi({
    super.key,
    required this.selectedGroup,
    required this.currentUser,
  });

  @override
  State<YoklamaSayfasi> createState() => _YoklamaSayfasiState();
}

class _YoklamaSayfasiState extends State<YoklamaSayfasi> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();
    if (mounted) {
      setState(() {});
    }
  }

  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
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
              widget.selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(_getTodayDateTurkish(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(_refreshKey),
          future: _loadAttendanceData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text("Yoklama verileri yükleniyor..."),
                  ],
                ),
              );
            }

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
                    const Text("Veriler yüklenirken hata oluştu"),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              );
            }

            final yoklamaListesi =
                snapshot.data?['yoklamaListesi']
                    as List<Map<String, dynamic>>? ??
                [];
            final students = snapshot.data?['students'] as List<Users>? ?? [];

            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text("Bu grupta henüz öğrenci yok"),
                  ],
                ),
              );
            }

            return _YoklamaWidget(
              key: ValueKey('yoklama_widget_$_refreshKey'),
              yoklamaListesi: yoklamaListesi,
              selectedGroup: widget.selectedGroup,
              currentUser: widget.currentUser,
              onSaveComplete: _refreshData,
            );
          },
        ),
      ),
    );
  }

  /// 🔥 SADECE LOKAL VERİYİ KULLAN
  /*
  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    // 🔥 LOKAL VERİLERİ ÇEK
    await _offlineService.init();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    const uuid =
        Uuid(); // 🔥 YENİ: Cihazda anlık UUID üretici nesnesi tanımlandı
    final List<Map<String, dynamic>> yoklamaListesi = [];

    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          // 🔥 DÜZELTİLDİ: Boş string yerine daha en başta benzersiz bir UUID v4 mühürlüyoruz
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: ogrenci.app,
          taken_by: widget.currentUser.app,
          attendance_date: formattedDate,
          status: "FALSE",
          note: "",
        ),
      );

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        // 🔥 DÜZELTİLDİ: Sadece id kontrolü yerine listenin içinde var mı diye bakıyoruz
        "has_attendance": localAttendances.any(
          (att) => att.student_id == ogrenci.app,
        ),
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }
}
*/
  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments; // 🔥 YENİ: Ödemeleri al

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student" &&
              _isStudentActive(user), // 🔥 pasif öğrenci grupta gözükmesin
        )
        .toList();

    // 🔥 LOKAL VERİLERİ ÇEK
    await _offlineService.init();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    // 🔥🔥🔥 BORÇ KONTROLÜ EKLENDİ
    final selectedMonth = DateTime(now.year, now.month);
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

    const uuid = Uuid();
    final List<Map<String, dynamic>> yoklamaListesi = [];

    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: ogrenci.app,
          taken_by: widget.currentUser.app,
          attendance_date: formattedDate,
          status: "FALSE",
          note: "",
        ),
      );

      final hasPaid = paymentStatus[ogrenci.app] ?? false; // 🔥 BORÇ DURUMU

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAttendances.any(
          (att) => att.student_id == ogrenci.app,
        ),
        "attendance_id": localAtt.attendances_id,
        "has_paid": hasPaid, // 🔥 EKLENDİ
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }
}

// 🔥 OFFLINE-FIRST YOKLAMA WIDGET
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  late final OfflineAttendanceService _offlineService;
  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  String? _lastSaveMessage;
  bool _showSuccess = false;
  StreamSubscription<List<Attendance>>? _syncSubscription;
  Timer? _successMessageTimer;
  bool _isLoadingLocalData = false;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _initOfflineService();
  }

  Future<void> _initOfflineService() async {
    _offlineService = OfflineAttendanceService();
    await _offlineService.init();

    _syncSubscription = _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("📢 Sync tamamlandı, lokal veriler yenileniyor...");
        _refreshLocalData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocalData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _successMessageTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_YoklamaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yoklamaListesi != widget.yoklamaListesi && mounted) {
      setState(() {
        _yoklamaListesi = List.from(widget.yoklamaListesi);
        _hasUnsavedChanges = false;
      });
      _refreshLocalData();
    }
  }

  void _updateAttendance(int index, bool value) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    if (!mounted) return;
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    await _offlineService.init();

    final now = DateTime.now();
    final result = await _offlineService.saveAttendanceBatch(
      _yoklamaListesi,
      now,
      widget.selectedGroup,
      widget.currentUser,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${result['savedCount']} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    await _refreshLocalData();

    _successMessageTimer?.cancel();
    _successMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    widget.onSaveComplete();
  }

  /*
  Future<void> _refreshLocalData() async {
    if (!mounted) return;
    if (_isLoadingLocalData) return;

    _isLoadingLocalData = true;

    final now = DateTime.now();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    if (!mounted) {
      _isLoadingLocalData = false;
      return;
    }

    const uuid = Uuid(); // 🔥 YENİ: UUID nesnesi tanımlandı
    final List<Map<String, dynamic>> newList = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;

      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == student.app,
        orElse: () => Attendance(
          // 🔥 DÜZELTİLDİ: Yenileme esnasında da boş ID yerine kalıcı mühür basılıyor
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: student.app,
          taken_by: widget.currentUser.app,
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      newList.add({
        "student": student,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        // 🔥 DÜZELTİLDİ: Durum güncellendi
        "has_attendance": localAttendances.any(
          (att) => att.student_id == student.app,
        ),
        "attendance_id": localAtt.attendances_id,
      });
    }

    if (mounted) {
      setState(() {
        _yoklamaListesi = newList;
      });
    }

    _isLoadingLocalData = false;
  }
*/
  Future<void> _refreshLocalData() async {
    if (!mounted) return;
    if (_isLoadingLocalData) return;

    _isLoadingLocalData = true;

    final now = DateTime.now();
    final localAttendances = await _offlineService.getLocalAttendances(
      widget.selectedGroup.groups_id,
      now,
    );

    if (!mounted) {
      _isLoadingLocalData = false;
      return;
    }

    // 🔥 BORÇ KONTROLÜ İÇİN ÖDEMELERİ AL
    final allPayments = _repo.allPayments;
    final selectedMonth = DateTime(now.year, now.month);
    final Map<String, bool> paymentStatus = {};

    // Öğrencilerin borç durumunu hesapla
    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
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

    const uuid = Uuid();
    final List<Map<String, dynamic>> newList = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;

      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == student.app,
        orElse: () => Attendance(
          attendances_id: uuid.v4(),
          groups_id: widget.selectedGroup.groups_id,
          student_id: student.app,
          taken_by: widget.currentUser.app,
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      final hasPaid = paymentStatus[student.app] ?? false; // 🔥 BORÇ DURUMU

      newList.add({
        "student": student,
        "is_present": localAtt.status == "TRUE",
        "note": localAtt.note,
        "has_attendance": localAttendances.any(
          (att) => att.student_id == student.app,
        ),
        "attendance_id": localAtt.attendances_id,
        "has_paid": hasPaid, // 🔥 EKLENDİ
      });
    }

    if (mounted) {
      setState(() {
        _yoklamaListesi = newList;
      });
    }

    _isLoadingLocalData = false;
  }

  String _formatDateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users student,
  ) {
    final String heroTag = 'profile_photo_${student.profile_photo_url}_$size';
    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultAvatar(student, size),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(student, size);
    }
    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
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

  void _showStudentDetailDialog(BuildContext context, Users student) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildProfileImage(
                    ctx,
                    student.profile_photo_url,
                    100,
                    student,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.phone,
                        Colors.green,
                        "Telefon",
                        student.phone.isNotEmpty
                            ? student.phone
                            : "Belirtilmemiş",
                        onCall: student.phone.isNotEmpty
                            ? () async {
                                final url = Uri.parse("tel:${student.phone}");
                                if (await canLaunchUrl(url))
                                  await launchUrl(url);
                              }
                            : null,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        _formatDateFromString(student.b_date),
                        subtitle: _calculateAge(student.b_date) > 0
                            ? "${_calculateAge(student.b_date)} yaşında"
                            : null,
                      ),
                      if (student.mother_name.isNotEmpty ||
                          student.father_name.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildDetailRow(
                          Icons.family_restroom,
                          Colors.purple,
                          "Aile",
                          [
                            if (student.mother_name.isNotEmpty)
                              "Anne: ${student.mother_name}",
                            if (student.father_name.isNotEmpty)
                              "Baba: ${student.father_name}",
                          ].join("\n"),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Kapat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value, {
    String? subtitle,
    VoidCallback? onCall,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (onCall != null)
            GestureDetector(
              onTap: onCall,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showNoteDialog(int index, Users student) {
    if (!mounted) return;

    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "${student.first_name} ${student.last_name}",
          style: const TextStyle(fontSize: 16),
        ),
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Not kaydedildi"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
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
              _buildStatItem("Toplam", totalCount, Icons.people, Colors.white),
              _buildStatItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _buildStatItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),
        if (_showSuccess && _lastSaveMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      if (mounted) setState(() => _searchQuery = value);
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                      if (mounted && value != null) {
                        setState(() => _selectedFilter = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
                      Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final originalIndex = _yoklamaListesi.indexOf(item);
                    final ogrenci = item["student"] as Users;
                    final isPresent = item["is_present"] == true;
                    final hasNote = (item["note"] ?? "").isNotEmpty;
                    return _buildStudentCard(
                      ogrenci,
                      isPresent,
                      hasNote,
                      originalIndex,
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
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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
        const VersionFooter(),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildStatItem(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
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

  /*
  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    int index,
  ) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

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
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${student.first_name} ${student.last_name}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
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
                    ],
                  ],
                ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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
*/
  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    int index,
  ) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

    // 🔥 YENİ: Borç durumunu al
    final hasDebt = _yoklamaListesi[index]["has_paid"] == false;

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
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
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
                        // 🔥🔥🔥 BORÇ UYARISI EKLENDİ
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
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
                    ],
                  ],
                ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

/// Öğrenci aktif mi? Pasifse gruplarda / yoklamada gösterilmez.
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

  // Herhangi bir alan açıkça 'pasif' diyorsa gizle
  if (candidates.any(passive.contains)) return false;
  // Açıkça 'aktif' diyen varsa göster
  if (candidates.any(active.contains)) return true;
  // Bilgi yoksa eski davranış: göster
  return true;
}

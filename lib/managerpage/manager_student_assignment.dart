/*
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:flutter/scheduler.dart';

class StudentAssignmentScreen extends StatefulWidget {
  final Group group;
  const StudentAssignmentScreen({required this.group});

  @override
  _StudentAssignmentScreenState createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  List<Users> allStudents = [];
  List<Users> filteredStudents = [];
  List<GroupStudent> allRelations = [];
  String searchQuery = "";

  // 🔥 YENİ: Loading state'leri
  bool _isInitialLoad = true;
  Set<String> _assigningStudents = {}; // Hangi öğrenci ekleniyor takip et

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadDataParallel();
  }

  // 🚀 PARALEL VERİ ÇEKEN METOD
  Future<Map<String, dynamic>> _loadDataParallel() async {
    final stopwatch = Stopwatch()..start();

    try {
      final results = await Future.wait([
        GoogleSheetService.getStudentsOnlyCached(),
        GoogleSheetService.getGroupStudentsCached(),
      ]);

      final students = results[0] as List<Users>;
      final relations = results[1] as List<GroupStudent>;

      stopwatch.stop();
      print(
        "⏱️ StudentAssignmentScreen verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
      );

      return {'students': students, 'relations': relations};
    } catch (e) {
      print("❌ Yükleme hatası: $e");
      return {'students': <Users>[], 'relations': <GroupStudent>[]};
    }
  }

  void _filterStudents(String query) {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            searchQuery = query;
            _applyFilter();
          });
        }
      });
    } else {
      setState(() {
        searchQuery = query;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    filteredStudents = allStudents.where((student) {
      final fullName = "${student.first_name} ${student.last_name}"
          .toLowerCase();
      final alreadyInGroup = allRelations.any(
        (rel) =>
            rel.groups_id == widget.group.groups_id &&
            rel.student_id == student.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
      return fullName.contains(searchQuery.toLowerCase()) && !alreadyInGroup;
    }).toList();
  }

  void _onDataLoaded() {
    if (!mounted) return;
    setState(() {
      _applyFilter();
    });
  }

  // 🔥 YENİ: Loading göstererek ekleme yap
  Future<void> _assignStudent(Users student) async {
    // Eğer bu öğrenci zaten ekleniyorsa, tekrar tıklanmasın
    if (_assigningStudents.contains(student.app)) return;

    setState(() {
      _assigningStudents.add(student.app);
    });

    bool ok = await GoogleSheetService.assignStudentToGroup(
      student.app,
      widget.group.groups_id,
    );

    setState(() {
      _assigningStudents.remove(student.app);
    });

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ ${student.first_name} ${student.last_name} eklendi!",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Verileri yeniden yükle
      setState(() {
        _dataFuture = _loadDataParallel();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Ekleme başarısız oldu!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("${widget.group.name} | Öğrenci Atama"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Öğrenciler yükleniyor..."),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text("Veriler yüklenirken hata oluştu"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadDataParallel();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          allStudents = data['students'] ?? [];
          allRelations = data['relations'] ?? [];

          if (_isInitialLoad) {
            _isInitialLoad = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _applyFilter();
            });
          }

          return Column(
            children: [
              // Arama çubuğu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: _filterStudents,
                  decoration: InputDecoration(
                    hintText: "Öğrenci ara (İsim/Soyisim)...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // İstatistik kartı (kaç öğrenci var)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Icons.people_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Eklenebilecek Öğrenciler",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              "${filteredStudents.length} öğrenci",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (searchQuery.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Aranıyor: $searchQuery",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Öğrenci listesi
              Expanded(
                child: filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty
                                  ? "Gruba eklenebilecek öğrenci bulunamadı"
                                  : "Aranan kriterde öğrenci yok",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (searchQuery.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _filterStudents(""),
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text("Aramayı Temizle"),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final s = filteredStudents[index];
                          final isAssigning = _assigningStudents.contains(
                            s.app,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.indigo.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showStudentDetailDialog(s),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Profil fotoğrafı / Avatar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 55,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.indigo.shade300,
                                                Colors.indigo.shade600,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: s.profile_photo_url.isNotEmpty
                                              ? Image.network(
                                                  s.profile_photo_url,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Center(
                                                          child: Text(
                                                            s
                                                                    .first_name
                                                                    .isNotEmpty
                                                                ? s.first_name[0]
                                                                      .toUpperCase()
                                                                : "?",
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 24,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                )
                                              : Center(
                                                  child: Text(
                                                    s.first_name.isNotEmpty
                                                        ? s.first_name[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Öğrenci bilgileri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${s.first_name} ${s.last_name}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 12,
                                                  color: Colors.green.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  s.phone.isNotEmpty
                                                      ? s.phone
                                                      : "Telefon yok",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: s.phone.isNotEmpty
                                                        ? Colors.grey.shade700
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.email_outlined,
                                                  size: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    s.email.isNotEmpty
                                                        ? s.email
                                                        : "E-posta yok",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 🔥 EKLE BUTONU - Loading gösteriyor!
                                      if (isAssigning)
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () => _assignStudent(s),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.person_add_alt_rounded,
                                              color: Colors.green,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 YENİ: Öğrenci detay dialog'u
  void _showStudentDetailDialog(Users student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
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
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.shade300,
                          Colors.indigo.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: student.profile_photo_url.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              student.profile_photo_url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    student.first_name.isNotEmpty
                                        ? student.first_name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              student.first_name.isNotEmpty
                                  ? student.first_name[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 22,
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
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.email,
                        Colors.blue,
                        "E-posta",
                        student.email.isNotEmpty
                            ? student.email
                            : "Belirtilmemiş",
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        student.b_date.isNotEmpty
                            ? student.b_date
                            : "Belirtilmemiş",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
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
    String value,
  ) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        onPressed: () {
          if (label == "Tümü") {
            _filterStudents("");
          }
        },
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}
*/

// ============================================================
// PROFESYONEL TASARIM GÜNCELLEMELERİ
// 1. Premium Renk Paleti
// 2. Animasyonlu Kartlar
// 3. Modern Tipografi
// 4. Şık UI Elementleri
// 5. Geliştirilmiş Öğrenci Kartları
// ============================================================
// ============================================================
// PROFESYONEL TASARIM GÜNCELLEMELERİ & AKILLI REPO ENTEGRASYONU
// ============================================================

import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/core/app_repository.dart'; // 🔥 Merkezi Repo
import 'package:flutter/scheduler.dart';

class StudentAssignmentScreen extends StatefulWidget {
  final Group group;
  const StudentAssignmentScreen({required this.group, super.key});

  @override
  _StudentAssignmentScreenState createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository(); // 🔥 Merkezi Repo Tanımlandı

  List<Users> allStudents = [];
  List<Users> filteredStudents = [];
  List<GroupStudent> allRelations = [];
  String searchQuery = "";

  bool _isLoading = true; // 🔥 Anlık yükleme durumu
  Set<String> _assigningStudents = {};
  StreamSubscription? _dataUpdateSubscription; // 🔥 Canlı Dinleyici

  // ============================================================
  // PROFESYONEL RENK PALETİ
  // ============================================================
  static const Color _bg = Color(0xFFF0F4F8);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _accentLight = Color(0xFF8B83FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _warning = Color(0xFFF39C12);
  static const Color _danger = Color(0xFFE74C3C);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE5E7EB);

  static const List<Color> _gradientAccent = [
    Color(0xFF6C63FF),
    Color(0xFF8B83FF),
  ];
  static const List<Color> _gradientCard = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];
  static const List<Color> _gradientSuccess = [
    Color(0xFF2ECC71),
    Color(0xFF82E0AA),
  ];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 🔥 1. Arka planda veri güncellendiğinde ekranı otomatik yenilemek için dinle
    _dataUpdateSubscription = _repo.onDataUpdated.listen((_) {
      if (mounted) {
        _loadDataFromMemory();
      }
    });

    // 🔥 2. Sayfa açılışında akıllı veri yükleme (RAM'de varsa anında aç)
    _initSmartData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel(); // Bellek sızıntısını önle
    _animationController.dispose();
    super.dispose();
  }

  // 🔥 Akıllı Veri Yükleme Yöntemi
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
      allStudents = _repo.getStudentsOnly();
      allRelations = _repo.allGroupStudents;
      _isLoading = false;
      _applyFilter();
    });
  }

  // Manuel / Refresh Veri Çekme
  Future<void> _loadDataParallel() async {
    setState(() => _isLoading = true);
    try {
      await _repo.loadAllData(forceRefresh: true);
      _loadDataFromMemory();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents(String query) {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            searchQuery = query;
            _applyFilter();
          });
        }
      });
    } else {
      setState(() {
        searchQuery = query;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    filteredStudents = allStudents.where((student) {
      final fullName = "${student.first_name} ${student.last_name}"
          .toLowerCase();
      final alreadyInGroup = allRelations.any(
        (rel) =>
            rel.groups_id == widget.group.groups_id &&
            rel.student_id == student.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
      return fullName.contains(searchQuery.toLowerCase()) && !alreadyInGroup;
    }).toList();
  }

  Future<void> _assignStudent(Users student) async {
    if (_assigningStudents.contains(student.app)) return;

    setState(() {
      _assigningStudents.add(student.app);
    });

    bool ok = await GoogleSheetService.assignStudentToGroup(
      student.app,
      widget.group.groups_id,
    );

    setState(() {
      _assigningStudents.remove(student.app);
    });

    if (ok && mounted) {
      _showSnackBar(
        "✅ ${student.first_name} ${student.last_name} eklendi!",
        _success,
      );
      await _repo.refreshSingleTable('group_students');
      _loadDataFromMemory();
    } else if (mounted) {
      _showSnackBar("❌ Ekleme başarısız oldu!", _danger);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // MODERN ÖĞRENCİ DETAY DİALOG
  // ============================================================
  void _showStudentDetailDialog(Users student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: _gradientAccent,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: student.profile_photo_url.isNotEmpty
                              ? Image.network(
                                  student.profile_photo_url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        student.first_name.isNotEmpty
                                            ? student.first_name[0]
                                                  .toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    student.first_name.isNotEmpty
                                        ? student.first_name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${student.first_name} ${student.last_name}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Öğrenci",
                          style: TextStyle(
                            fontSize: 12,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              Icons.phone,
                              _success,
                              "Telefon",
                              student.phone.isNotEmpty
                                  ? student.phone
                                  : "Belirtilmemiş",
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildDetailRow(
                              Icons.email,
                              _accent,
                              "E-posta",
                              student.email.isNotEmpty
                                  ? student.email
                                  : "Belirtilmemiş",
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildDetailRow(
                              Icons.cake,
                              _warning,
                              "Doğum Tarihi",
                              student.b_date.isNotEmpty
                                  ? student.b_date
                                  : "Belirtilmemiş",
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildDetailRow(
                              Icons.calendar_today,
                              _danger,
                              "Kayıt Tarihi",
                              student.created_at.isNotEmpty
                                  ? student.created_at
                                  : "Belirtilmemiş",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            "Kapat",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODERN BUILD
  // ============================================================
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              "Öğrenci Atama",
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: _accent, size: 22),
              onPressed: () => _loadDataParallel(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Öğrenciler yükleniyor...",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ========================================
                // ARAMA ÇUBUĞU - MODERN
                // ========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: _filterStudents,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Öğrenci ara (İsim/Soyisim)...",
                        hintStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _accent,
                          size: 22,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: _textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _filterStudents("");
                                  setState(() {
                                    searchQuery = "";
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                ),

                // ========================================
                // İSTATİSTİK KARTI - MODERN
                // ========================================
                FadeTransition(
                  opacity: _animationController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: _gradientCard,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.people_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Eklenebilecek Öğrenciler",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "${filteredStudents.length} öğrenci",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    searchQuery,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
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
                ),

                const SizedBox(height: 12),

                // ========================================
                // ÖĞRENCİ LİSTESİ
                // ========================================
                Expanded(
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _textSecondary.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  searchQuery.isEmpty
                                      ? Icons.people_outline
                                      : Icons.search_off_rounded,
                                  size: 56,
                                  color: _textSecondary.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty
                                    ? "Gruba eklenebilecek öğrenci bulunamadı"
                                    : "Aranan kriterde öğrenci yok",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                searchQuery.isEmpty
                                    ? "Tüm öğrenciler zaten bu gruba atanmış"
                                    : "Farklı bir arama yapmayı deneyin",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _textTertiary,
                                ),
                              ),
                              if (searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => _filterStudents(""),
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: _accent,
                                  ),
                                  label: Text(
                                    "Aramayı Temizle",
                                    style: TextStyle(
                                      color: _accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final s = filteredStudents[index];
                            final isAssigning = _assigningStudents.contains(
                              s.app,
                            );

                            return TweenAnimationBuilder<double>(
                              duration: Duration(
                                milliseconds: 300 + (index * 50),
                              ),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 15 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _border.withOpacity(0.6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => _showStudentDetailDialog(s),
                                    splashColor: _accent.withOpacity(0.05),
                                    highlightColor: _accent.withOpacity(0.03),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: _gradientAccent,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _accent.withOpacity(
                                                    0.25,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child:
                                                  s.profile_photo_url.isNotEmpty
                                                  ? Image.network(
                                                      s.profile_photo_url,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Center(
                                                          child: Text(
                                                            s
                                                                    .first_name
                                                                    .isNotEmpty
                                                                ? s.first_name[0]
                                                                      .toUpperCase()
                                                                : "?",
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 22,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        s.first_name.isNotEmpty
                                                            ? s.first_name[0]
                                                                  .toUpperCase()
                                                            : "?",
                                                        style: const TextStyle(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "${s.first_name} ${s.last_name}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: _textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_outlined,
                                                      size: 12,
                                                      color: _success,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      s.phone.isNotEmpty
                                                          ? s.phone
                                                          : "Telefon yok",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            s.phone.isNotEmpty
                                                            ? _textSecondary
                                                            : _textTertiary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.email_outlined,
                                                      size: 12,
                                                      color: _textTertiary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        s.email.isNotEmpty
                                                            ? s.email
                                                            : "E-posta yok",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: _textTertiary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isAssigning)
                                            Container(
                                              width: 46,
                                              height: 46,
                                              decoration: BoxDecoration(
                                                color: _accent.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: _accent,
                                                      ),
                                                ),
                                              ),
                                            )
                                          else
                                            GestureDetector(
                                              onTap: () => _assignStudent(s),
                                              child: Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors:
                                                            _gradientSuccess,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _success
                                                          .withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.person_add_alt_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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
}

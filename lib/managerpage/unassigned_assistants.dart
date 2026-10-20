/*
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';

class AssistantManagementPage extends StatefulWidget {
  const AssistantManagementPage({super.key});

  @override
  State<AssistantManagementPage> createState() =>
      _AssistantManagementPageState();
}

class _AssistantManagementPageState extends State<AssistantManagementPage> {
  final AppRepository _repo = AppRepository();
  bool _isLoading = true;
  List<Coach> _masterCoaches = [];
  List<Coach> _allAssistants = [];
  List<Users> _allUsers = [];
  Map<String, List<Coach>> _assistantsByMasterUserId = {};
  List<Coach> _unassignedAssistants = [];
  Set<String> _expandedMasters = {};

  // 🔥 HIZLI ERİŞİM İÇİN CACHE
  Map<String, Users> _userCache = {};

  // 🔥 ARKA PLAN GÜNCELLEME İÇİN
  bool _isBackgroundUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 🔥 Sayfaya girer girmez arka planda güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRefresh();
    });
  }

  // ============================================================
  // 🔥 SESSİZ GÜNCELLEME (ÇAKTIRMADAN)
  // ============================================================

  Future<void> _silentRefresh() async {
    if (_isBackgroundUpdating) return;
    _isBackgroundUpdating = true;

    try {
      print("🔄 Sessiz güncelleme başladı...");

      // 🔥 Sadece coaches tablosunu yenile
      GoogleSheetService.invalidateCache('coaches');
      await _repo.refreshSingleTable('coaches');

      // 🔥 Verileri işle
      final allCoaches = _repo.allCoaches;
      final allUsers = _repo.allUsers;

      // 🔥 UI'Yİ GÜNCELLE (setState ile)
      if (mounted) {
        setState(() {
          _allUsers = allUsers;
          _userCache.clear();
          _processData(allCoaches, allUsers);
        });
      }

      print("✅ Sessiz güncelleme tamamlandı!");
    } catch (e) {
      print("⚠️ Sessiz güncelleme hatası: $e");
    } finally {
      _isBackgroundUpdating = false;
    }
  }

  // ============================================================
  // 🔥 VERİ YÜKLEME
  // ============================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_repo.isLoaded) {
        print("📌 Veriler zaten yüklü, cache'den işleniyor...");
        final allCoaches = _repo.allCoaches;
        final allUsers = _repo.allUsers;
        _allUsers = allUsers;
        _userCache.clear();
        _processData(allCoaches, allUsers);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allUsers = _repo.allUsers;
      _allUsers = allUsers;
      _userCache.clear();
      _processData(allCoaches, allUsers);
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 🔥 VERİ İŞLEME
  // ============================================================

  void _processData(List<Coach> allCoaches, List<Users> allUsers) {
    print(
      "📌 Veriler işleniyor: ${allUsers.length} kullanıcı, ${allCoaches.length} koç",
    );

    final Map<String, Users> userMap = {};
    for (var u in allUsers) {
      userMap[u.app] = u;
    }

    final Map<String, Coach> coachByUserId = {};
    final Map<String, Coach> coachById = {};
    for (var c in allCoaches) {
      coachByUserId[c.user_id] = c;
      coachById[c.coach_id] = c;
    }

    final coachUserIds = <String>{};
    final assistantUserIds = <String>{};

    for (var u in allUsers) {
      final role = u.role.toLowerCase();
      if (role == 'coach' || role == 'antrenör') {
        coachUserIds.add(u.app);
      } else if (role == 'assistant_coach' || role == 'yardımcı_antrenör') {
        assistantUserIds.add(u.app);
      }
    }

    _masterCoaches = [];
    for (var userId in coachUserIds) {
      final coach =
          coachByUserId[userId] ??
          Coach(
            coach_id: '',
            user_id: userId,
            branches_id: userMap[userId]?.branches_id ?? '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          );
      _masterCoaches.add(coach);
    }

    if (_masterCoaches.isEmpty) {
      _masterCoaches = allCoaches.where((c) {
        final supervisor = c.supervisor_coach_id.toString().trim();
        return supervisor.isEmpty || supervisor == "0" || supervisor == "null";
      }).toList();
    }

    _allAssistants = [];
    for (var userId in assistantUserIds) {
      final coach =
          coachByUserId[userId] ??
          Coach(
            coach_id: '',
            user_id: userId,
            branches_id: userMap[userId]?.branches_id ?? '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          );
      _allAssistants.add(coach);
    }

    if (_allAssistants.isEmpty) {
      _allAssistants = allCoaches.where((c) {
        final supervisor = c.supervisor_coach_id.toString().trim();
        return supervisor.isNotEmpty &&
            supervisor != "0" &&
            supervisor != "null";
      }).toList();
    }

    _assistantsByMasterUserId = {};
    final Set<String> assignedAssistantUserIds = {};

    for (var master in _masterCoaches) {
      final supervisorValue = master.supervisor_coach_id.toString().trim();
      List<String> assistantUserIdsList = [];

      if (supervisorValue.isNotEmpty &&
          supervisorValue != "0" &&
          supervisorValue != "null") {
        assistantUserIdsList = supervisorValue
            .split(RegExp(r'[,.]'))
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList();
      }

      final assistants = _allAssistants
          .where((a) => assistantUserIdsList.contains(a.user_id))
          .toList();

      _assistantsByMasterUserId[master.user_id] = assistants;
      for (var a in assistants) {
        assignedAssistantUserIds.add(a.user_id);
      }
    }

    _unassignedAssistants = _allAssistants
        .where((a) => !assignedAssistantUserIds.contains(a.user_id))
        .toList();

    _userCache = Map.from(userMap);
  }

  // ============================================================
  // 🔥 REFRESH (KULLANICI ELİYLE)
  // ============================================================

  Future<void> _refreshData() async {
    // 🔥 Loading gösterme, sadece sessizce yenile
    await _silentRefresh();
  }

  // ============================================================
  // 🔥 HIZLI _getUser
  // ============================================================

  Users _getUser(String userId) {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    final user = _allUsers.firstWhere(
      (u) => u.app == userId,
      orElse: () => Users(
        app: "",
        branches_id: "",
        first_name: "Bilinmeyen",
        last_name: "",
        email: "",
        phone: "",
        password_hash: "",
        role: "",
        profile_photo_url: "",
        amount: "",
        b_date: "",
        created_at: "",
        last_login: "",
        is_active: "",
        mother_name: "",
        father_name: "",
      ),
    );
    _userCache[userId] = user;
    return user;
  }

  String _getUserFullName(String userId) {
    final user = _getUser(userId);
    return "${user.first_name} ${user.last_name}".trim();
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR BAĞLA (SESSİZ GÜNCELLEME İLE)
  // ============================================================

  Future<void> _assignAssistant(Coach assistant, Coach masterCoach) async {
    try {
      // ============================================================
      // 🔥 1. UI'Yİ HEMEN GÜNCELLE (Optimistik)
      // ============================================================
      setState(() {
        _unassignedAssistants.removeWhere(
          (a) => a.user_id == assistant.user_id,
        );

        final masterId = masterCoach.user_id;
        if (_assistantsByMasterUserId.containsKey(masterId)) {
          if (!_assistantsByMasterUserId[masterId]!.any(
            (a) => a.user_id == assistant.user_id,
          )) {
            _assistantsByMasterUserId[masterId]!.add(assistant);
          }
        } else {
          _assistantsByMasterUserId[masterId] = [assistant];
        }
      });

      // ============================================================
      // 🔥 2. ARKA PLANDA GÖNDER (LOADING GÖSTERME)
      // ============================================================
      final success = await GoogleSheetService.assignAssistant(
        assistantUserId: assistant.user_id,
        masterUserId: masterCoach.user_id,
      );

      // ============================================================
      // 🔥 3. BAŞARILIYSA SESSİZCE YENİLE
      // ============================================================
      if (success) {
        if (mounted) {
          // 🔥 Sessiz güncelleme yap
          _silentRefresh();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ ${_getUserFullName(assistant.user_id)} başarıyla bağlandı!",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 🔥 Başarısız olursa geri al
        _rollbackAssign(assistant, masterCoach);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Bağlama işlemi başarısız oldu. Geri alındı."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ _assignAssistant hatası: $e");
      _rollbackAssign(assistant, masterCoach);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Bağlama işlemi başarısız: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _rollbackAssign(Coach assistant, Coach masterCoach) {
    setState(() {
      final masterId = masterCoach.user_id;
      if (_assistantsByMasterUserId.containsKey(masterId)) {
        _assistantsByMasterUserId[masterId]!.removeWhere(
          (a) => a.user_id == assistant.user_id,
        );
      }
      if (!_unassignedAssistants.any((a) => a.user_id == assistant.user_id)) {
        _unassignedAssistants.add(assistant);
      }
    });
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR ÇIKAR (SESSİZ GÜNCELLEME İLE)
  // ============================================================

  Future<void> _removeAssistant(Coach assistant, Coach masterCoach) async {
    try {
      // ============================================================
      // 🔥 1. UI'Yİ HEMEN GÜNCELLE (Optimistik)
      // ============================================================
      setState(() {
        final masterId = masterCoach.user_id;
        if (_assistantsByMasterUserId.containsKey(masterId)) {
          _assistantsByMasterUserId[masterId]!.removeWhere(
            (a) => a.user_id == assistant.user_id,
          );
        }

        if (!_unassignedAssistants.any((a) => a.user_id == assistant.user_id)) {
          _unassignedAssistants.add(assistant);
        }

        if (!_allAssistants.any((a) => a.user_id == assistant.user_id)) {
          _allAssistants.add(assistant);
        }
      });

      // ============================================================
      // 🔥 2. ARKA PLANDA GÖNDER (LOADING GÖSTERME)
      // ============================================================
      final success = await GoogleSheetService.removeAssistant(
        assistantUserId: assistant.user_id,
        masterUserId: masterCoach.user_id,
      );

      // ============================================================
      // 🔥 3. BAŞARILIYSA SESSİZCE YENİLE
      // ============================================================
      if (success) {
        if (mounted) {
          // 🔥 Sessiz güncelleme yap
          _silentRefresh();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ ${_getUserFullName(assistant.user_id)} başarıyla çıkarıldı!",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 🔥 Başarısız olursa geri al
        _rollbackRemove(assistant, masterCoach);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Çıkarma işlemi başarısız oldu. Geri alındı."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ _removeAssistant hatası: $e");
      _rollbackRemove(assistant, masterCoach);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Çıkarma işlemi başarısız: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _rollbackRemove(Coach assistant, Coach masterCoach) {
    setState(() {
      final masterId = masterCoach.user_id;
      if (_assistantsByMasterUserId.containsKey(masterId)) {
        if (!_assistantsByMasterUserId[masterId]!.any(
          (a) => a.user_id == assistant.user_id,
        )) {
          _assistantsByMasterUserId[masterId]!.add(assistant);
        }
      }
      _unassignedAssistants.removeWhere((a) => a.user_id == assistant.user_id);
    });
  }

  // ============================================================
  // 🔥 BAĞLAMA DİYALOGU
  // ============================================================

  void _showAssignDialog(Coach masterCoach) {
    print("📌 _showAssignDialog çağrıldı - Ana hoca: ${masterCoach.user_id}");

    final alreadyAssignedIds =
        _assistantsByMasterUserId[masterCoach.user_id]
            ?.map((a) => a.user_id)
            .toSet() ??
        {};

    final availableAssistants = _allAssistants
        .where((a) => !alreadyAssignedIds.contains(a.user_id))
        .toList();

    if (availableAssistants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Bu hocaya bağlanabilecek yeni yardımcı antrenör bulunamadı!",
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String? selectedAssistantId;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Yardımcı Ekle",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage:
                              _getUser(
                                masterCoach.user_id,
                              ).profile_photo_url.isNotEmpty
                              ? NetworkImage(
                                  _getUser(
                                    masterCoach.user_id,
                                  ).profile_photo_url,
                                )
                              : null,
                          child:
                              _getUser(
                                masterCoach.user_id,
                              ).profile_photo_url.isEmpty
                              ? Text(
                                  _getUser(
                                        masterCoach.user_id,
                                      ).first_name.isNotEmpty
                                      ? _getUser(
                                          masterCoach.user_id,
                                        ).first_name[0].toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getUserFullName(masterCoach.user_id),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Ana Antrenör",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Bir yardımcı antrenör birden fazla ana hocaya bağlanabilir.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Bağlanacak Yardımcıyı Seçin",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedAssistantId,
                    hint: const Text("Yardımcı Seçin"),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    items: availableAssistants.map((assistant) {
                      final user = _getUser(assistant.user_id);
                      final connectedMasters = _masterCoaches
                          .where((m) {
                            final supervisors = m.supervisor_coach_id
                                .toString()
                                .split(RegExp(r'[,.]'))
                                .map((id) => id.trim())
                                .where((id) => id.isNotEmpty)
                                .toList();
                            return supervisors.contains(assistant.user_id);
                          })
                          .map((m) => _getUserFullName(m.user_id))
                          .join(', ');

                      return DropdownMenuItem<String>(
                        value: assistant.user_id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.teal.shade100,
                              backgroundImage: user.profile_photo_url.isNotEmpty
                                  ? NetworkImage(user.profile_photo_url)
                                  : null,
                              child: user.profile_photo_url.isEmpty
                                  ? Text(
                                      user.first_name.isNotEmpty
                                          ? user.first_name[0].toUpperCase()
                                          : "?",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${user.first_name} ${user.last_name}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (connectedMasters.isNotEmpty)
                                    Text(
                                      "Bağlı: $connectedMasters",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAssistantId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text("İptal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: selectedAssistantId == null
                      ? null
                      : () {
                          final assistant = _allAssistants.firstWhere(
                            (a) => a.user_id == selectedAssistantId,
                          );
                          Navigator.pop(context);
                          _assignAssistant(assistant, masterCoach);
                        },
                  child: const Text("Bağla"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 🔥 ÇIKARMA DİYALOGU
  // ============================================================

  void _showRemoveDialog(Coach assistant, Coach masterCoach) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Yardımcıyı Çıkar",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.red.shade100,
                    backgroundImage:
                        _getUser(assistant.user_id).profile_photo_url.isNotEmpty
                        ? NetworkImage(
                            _getUser(assistant.user_id).profile_photo_url,
                          )
                        : null,
                    child: _getUser(assistant.user_id).profile_photo_url.isEmpty
                        ? Text(
                            _getUser(assistant.user_id).first_name.isNotEmpty
                                ? _getUser(
                                    assistant.user_id,
                                  ).first_name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getUserFullName(assistant.user_id),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "Yardımcı Antrenör",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "${_getUserFullName(assistant.user_id)}'i ${_getUserFullName(masterCoach.user_id)}'ten çıkarmak istediğinize emin misiniz?",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeAssistant(assistant, masterCoach);
            },
            child: const Text("Çıkar"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Antrenör Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E293B),
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Yükleniyor...",
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _masterCoaches.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1E293B),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _masterCoaches.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildUnassignedSection();
                  }
                  final master = _masterCoaches[index - 1];
                  final masterUser = _getUser(master.user_id);
                  final assistants =
                      _assistantsByMasterUserId[master.user_id] ?? [];
                  final isExpanded = _expandedMasters.contains(master.coach_id);

                  return _buildMasterCard(
                    master,
                    masterUser,
                    assistants,
                    isExpanded,
                  );
                },
              ),
            ),
    );
  }

  // ============================================================
  // 🔥 ATANMAMIŞ YARDIMCILAR BÖLÜMÜ
  // ============================================================

  Widget _buildUnassignedSection() {
    if (_unassignedAssistants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                "Atanmamış Yardımcılar (${_unassignedAssistants.length})",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Bu yardımcı antrenörler henüz hiçbir ana hocaya bağlı değil. Bağlamak için bir ana hocanın kartındaki '+' butonunu kullanın.",
            style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unassignedAssistants.map((assistant) {
              final user = _getUser(assistant.user_id);
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.amber.shade200,
                  child: Text(
                    user.first_name.isNotEmpty
                        ? user.first_name[0].toUpperCase()
                        : "?",
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                label: Text(
                  "${user.first_name} ${user.last_name}",
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.amber.shade200),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_basketball,
              size: 72,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz Antrenör Bulunmuyor",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sisteme henüz bir antrenör kaydedilmemiş.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 MASTER CARD
  // ============================================================

  Widget _buildMasterCard(
    Coach master,
    Users masterUser,
    List<Coach> assistants,
    bool isExpanded,
  ) {
    final hasAssistants = assistants.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_expandedMasters.contains(master.coach_id)) {
                    _expandedMasters.remove(master.coach_id);
                  } else {
                    _expandedMasters.add(master.coach_id);
                  }
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: masterUser.profile_photo_url.isNotEmpty
                          ? NetworkImage(masterUser.profile_photo_url)
                          : null,
                      child: masterUser.profile_photo_url.isEmpty
                          ? Text(
                              masterUser.first_name.isNotEmpty
                                  ? masterUser.first_name[0].toUpperCase()
                                  : "?",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${masterUser.first_name} ${masterUser.last_name}",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Ana Antrenör",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade300,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hasAssistants
                                        ? "${assistants.length} Yardımcı"
                                        : "Yardımcı Yok",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasAssistants
                                          ? Colors.teal.shade300
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _showAssignDialog(master),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: "Yardımcı Ekle",
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white.withOpacity(0.6),
                          size: 28,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && hasAssistants)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: assistants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final assistant = entry.value;
                  final assistantUser = _getUser(assistant.user_id);

                  return Column(
                    children: [
                      if (index > 0)
                        const Divider(height: 1, color: Colors.grey),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.teal.shade100,
                              backgroundImage:
                                  assistantUser.profile_photo_url.isNotEmpty
                                  ? NetworkImage(
                                      assistantUser.profile_photo_url,
                                    )
                                  : null,
                              child: assistantUser.profile_photo_url.isEmpty
                                  ? Text(
                                      assistantUser.first_name.isNotEmpty
                                          ? assistantUser.first_name[0]
                                                .toUpperCase()
                                          : "?",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${assistantUser.first_name} ${assistantUser.last_name}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "Yardımcı",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "Bağlı: ${_getUserFullName(master.user_id)}",
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: "Yardımcıyı Çıkar",
                                onPressed: () =>
                                    _showRemoveDialog(assistant, master),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            )
          else if (isExpanded && !hasAssistants)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Bu hocaya bağlı yardımcı yok",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showAssignDialog(master),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Yardımcı Ekle"),
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
*/

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';

class AssistantManagementPage extends StatefulWidget {
  const AssistantManagementPage({super.key});

  @override
  State<AssistantManagementPage> createState() =>
      _AssistantManagementPageState();
}

class _AssistantManagementPageState extends State<AssistantManagementPage>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  bool _isLoading = true;
  List<Coach> _masterCoaches = [];
  List<Coach> _allAssistants = [];
  List<Users> _allUsers = [];
  Map<String, List<Coach>> _assistantsByMasterUserId = {};
  List<Coach> _unassignedAssistants = [];
  Set<String> _expandedMasters = {};

  // 🔥 HIZLI ERİŞİM İÇİN CACHE
  Map<String, Users> _userCache = {};

  // 🔥 ARKA PLAN GÜNCELLEME İÇİN
  bool _isBackgroundUpdating = false;

  // 🔥 ANİMASYON
  late AnimationController _animationController;

  // MODERN RENK PALETİ
  static const Color _bg = Color(0xFFF0F4F8);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _accentLight = Color(0xFF8B83FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _warning = Color(0xFFF39C12);
  static const Color _danger = Color(0xFFE74C3C);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  static const List<Color> _gradientPrimary = [
    Color(0xFF6C63FF),
    Color(0xFF8B83FF),
  ];
  static const List<Color> _gradientCard = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRefresh();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔥 SESSİZ GÜNCELLEME
  // ============================================================

  Future<void> _silentRefresh() async {
    if (_isBackgroundUpdating) return;
    _isBackgroundUpdating = true;

    try {
      print("🔄 Sessiz güncelleme başladı...");
      GoogleSheetService.invalidateCache('coaches');
      await _repo.refreshSingleTable('coaches');

      final allCoaches = _repo.allCoaches;
      final allUsers = _repo.allUsers;

      if (mounted) {
        setState(() {
          _allUsers = allUsers;
          _userCache.clear();
          _processData(allCoaches, allUsers);
        });
      }
      print("✅ Sessiz güncelleme tamamlandı!");
    } catch (e) {
      print("⚠️ Sessiz güncelleme hatası: $e");
    } finally {
      _isBackgroundUpdating = false;
    }
  }

  // ============================================================
  // 🔥 VERİ YÜKLEME
  // ============================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_repo.isLoaded) {
        final allCoaches = _repo.allCoaches;
        final allUsers = _repo.allUsers;
        _allUsers = allUsers;
        _userCache.clear();
        _processData(allCoaches, allUsers);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      final allCoaches = _repo.allCoaches;
      final allUsers = _repo.allUsers;
      _allUsers = allUsers;
      _userCache.clear();
      _processData(allCoaches, allUsers);
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 🔥 VERİ İŞLEME
  // ============================================================

  void _processData(List<Coach> allCoaches, List<Users> allUsers) {
    print(
      "📌 Veriler işleniyor: ${allUsers.length} kullanıcı, ${allCoaches.length} koç",
    );

    final Map<String, Users> userMap = {};
    for (var u in allUsers) {
      userMap[u.app] = u;
    }

    final Map<String, Coach> coachByUserId = {};
    final Map<String, Coach> coachById = {};
    for (var c in allCoaches) {
      coachByUserId[c.user_id] = c;
      coachById[c.coach_id] = c;
    }

    final coachUserIds = <String>{};
    final assistantUserIds = <String>{};

    for (var u in allUsers) {
      final role = u.role.toLowerCase();
      if (role == 'coach' || role == 'antrenör') {
        coachUserIds.add(u.app);
      } else if (role == 'assistant_coach' || role == 'yardımcı_antrenör') {
        assistantUserIds.add(u.app);
      }
    }

    _masterCoaches = [];
    for (var userId in coachUserIds) {
      final coach =
          coachByUserId[userId] ??
          Coach(
            coach_id: '',
            user_id: userId,
            branches_id: userMap[userId]?.branches_id ?? '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          );
      _masterCoaches.add(coach);
    }

    if (_masterCoaches.isEmpty) {
      _masterCoaches = allCoaches.where((c) {
        final supervisor = c.supervisor_coach_id.toString().trim();
        return supervisor.isEmpty || supervisor == "0" || supervisor == "null";
      }).toList();
    }

    _allAssistants = [];
    for (var userId in assistantUserIds) {
      final coach =
          coachByUserId[userId] ??
          Coach(
            coach_id: '',
            user_id: userId,
            branches_id: userMap[userId]?.branches_id ?? '',
            sports_id: '',
            bio: '',
            certificate_info: '',
            monthly_salary: '',
            hired_at: '',
            supervisor_coach_id: '',
          );
      _allAssistants.add(coach);
    }

    if (_allAssistants.isEmpty) {
      _allAssistants = allCoaches.where((c) {
        final supervisor = c.supervisor_coach_id.toString().trim();
        return supervisor.isNotEmpty &&
            supervisor != "0" &&
            supervisor != "null";
      }).toList();
    }

    _assistantsByMasterUserId = {};
    final Set<String> assignedAssistantUserIds = {};

    for (var master in _masterCoaches) {
      final supervisorValue = master.supervisor_coach_id.toString().trim();
      List<String> assistantUserIdsList = [];

      if (supervisorValue.isNotEmpty &&
          supervisorValue != "0" &&
          supervisorValue != "null") {
        assistantUserIdsList = supervisorValue
            .split(RegExp(r'[,.]'))
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList();
      }

      final assistants = _allAssistants
          .where((a) => assistantUserIdsList.contains(a.user_id))
          .toList();

      _assistantsByMasterUserId[master.user_id] = assistants;
      for (var a in assistants) {
        assignedAssistantUserIds.add(a.user_id);
      }
    }

    _unassignedAssistants = _allAssistants
        .where((a) => !assignedAssistantUserIds.contains(a.user_id))
        .toList();

    _userCache = Map.from(userMap);
  }

  // ============================================================
  // 🔥 REFRESH
  // ============================================================

  Future<void> _refreshData() async {
    await _silentRefresh();
  }

  // ============================================================
  // 🔥 HIZLI _getUser
  // ============================================================

  Users _getUser(String userId) {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    final user = _allUsers.firstWhere(
      (u) => u.app == userId,
      orElse: () => Users(
        app: "",
        branches_id: "",
        first_name: "Bilinmeyen",
        last_name: "",
        email: "",
        phone: "",
        password_hash: "",
        role: "",
        profile_photo_url: "",
        amount: "",
        b_date: "",
        created_at: "",
        last_login: "",
        is_active: "",
        mother_name: "",
        father_name: "",
      ),
    );
    _userCache[userId] = user;
    return user;
  }

  String _getUserFullName(String userId) {
    final user = _getUser(userId);
    return "${user.first_name} ${user.last_name}".trim();
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR BAĞLA
  // ============================================================

  Future<void> _assignAssistant(Coach assistant, Coach masterCoach) async {
    try {
      setState(() {
        _unassignedAssistants.removeWhere(
          (a) => a.user_id == assistant.user_id,
        );

        final masterId = masterCoach.user_id;
        if (_assistantsByMasterUserId.containsKey(masterId)) {
          if (!_assistantsByMasterUserId[masterId]!.any(
            (a) => a.user_id == assistant.user_id,
          )) {
            _assistantsByMasterUserId[masterId]!.add(assistant);
          }
        } else {
          _assistantsByMasterUserId[masterId] = [assistant];
        }
      });

      final success = await GoogleSheetService.assignAssistant(
        assistantUserId: assistant.user_id,
        masterUserId: masterCoach.user_id,
      );

      if (success) {
        if (mounted) {
          _silentRefresh();
          _showSnackBar(
            "✅ ${_getUserFullName(assistant.user_id)} başarıyla bağlandı!",
            _success,
          );
        }
      } else {
        _rollbackAssign(assistant, masterCoach);
        if (mounted) {
          _showSnackBar("❌ Bağlama işlemi başarısız oldu.", _danger);
        }
      }
    } catch (e) {
      print("❌ _assignAssistant hatası: $e");
      _rollbackAssign(assistant, masterCoach);
      if (mounted) {
        _showSnackBar("❌ Bağlama işlemi başarısız: $e", _danger);
      }
    }
  }

  void _rollbackAssign(Coach assistant, Coach masterCoach) {
    setState(() {
      final masterId = masterCoach.user_id;
      if (_assistantsByMasterUserId.containsKey(masterId)) {
        _assistantsByMasterUserId[masterId]!.removeWhere(
          (a) => a.user_id == assistant.user_id,
        );
      }
      if (!_unassignedAssistants.any((a) => a.user_id == assistant.user_id)) {
        _unassignedAssistants.add(assistant);
      }
    });
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR ÇIKAR
  // ============================================================

  Future<void> _removeAssistant(Coach assistant, Coach masterCoach) async {
    try {
      setState(() {
        final masterId = masterCoach.user_id;
        if (_assistantsByMasterUserId.containsKey(masterId)) {
          _assistantsByMasterUserId[masterId]!.removeWhere(
            (a) => a.user_id == assistant.user_id,
          );
        }

        if (!_unassignedAssistants.any((a) => a.user_id == assistant.user_id)) {
          _unassignedAssistants.add(assistant);
        }

        if (!_allAssistants.any((a) => a.user_id == assistant.user_id)) {
          _allAssistants.add(assistant);
        }
      });

      final success = await GoogleSheetService.removeAssistant(
        assistantUserId: assistant.user_id,
        masterUserId: masterCoach.user_id,
      );

      if (success) {
        if (mounted) {
          _silentRefresh();
          _showSnackBar(
            "✅ ${_getUserFullName(assistant.user_id)} başarıyla çıkarıldı!",
            _success,
          );
        }
      } else {
        _rollbackRemove(assistant, masterCoach);
        if (mounted) {
          _showSnackBar("❌ Çıkarma işlemi başarısız oldu.", _danger);
        }
      }
    } catch (e) {
      print("❌ _removeAssistant hatası: $e");
      _rollbackRemove(assistant, masterCoach);
      if (mounted) {
        _showSnackBar("❌ Çıkarma işlemi başarısız: $e", _danger);
      }
    }
  }

  void _rollbackRemove(Coach assistant, Coach masterCoach) {
    setState(() {
      final masterId = masterCoach.user_id;
      if (_assistantsByMasterUserId.containsKey(masterId)) {
        if (!_assistantsByMasterUserId[masterId]!.any(
          (a) => a.user_id == assistant.user_id,
        )) {
          _assistantsByMasterUserId[masterId]!.add(assistant);
        }
      }
      _unassignedAssistants.removeWhere((a) => a.user_id == assistant.user_id);
    });
  }

  // ============================================================
  // 🔥 SNACKBAR
  // ============================================================

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
  // 🔥 BAĞLAMA DİYALOGU - MODERN
  // ============================================================

  void _showAssignDialog(Coach masterCoach) {
    final alreadyAssignedIds =
        _assistantsByMasterUserId[masterCoach.user_id]
            ?.map((a) => a.user_id)
            .toSet() ??
        {};

    final availableAssistants = _allAssistants
        .where((a) => !alreadyAssignedIds.contains(a.user_id))
        .toList();

    if (availableAssistants.isEmpty) {
      _showSnackBar(
        "Bu hocaya bağlanabilecek yeni yardımcı antrenör bulunamadı!",
        _warning,
      );
      return;
    }

    String? selectedAssistantId;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: _gradientPrimary,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            "Yardımcı Ekle",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: _textSecondary),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ana Hoca Bilgisi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _accent.withOpacity(0.08),
                            _accent.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _accent.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: _gradientPrimary,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                _getUser(
                                      masterCoach.user_id,
                                    ).first_name.isNotEmpty
                                    ? _getUser(
                                        masterCoach.user_id,
                                      ).first_name[0].toUpperCase()
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
                                Text(
                                  _getUserFullName(masterCoach.user_id),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  "Ana Antrenör",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "Bağlanacak Yardımcıyı Seçin",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedAssistantId,
                        hint: const Text(
                          "Yardımcı Seçin",
                          style: TextStyle(color: _textSecondary),
                        ),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                        ),
                        items: availableAssistants.map((assistant) {
                          final user = _getUser(assistant.user_id);
                          final connectedMasters = _masterCoaches
                              .where((m) {
                                final supervisors = m.supervisor_coach_id
                                    .toString()
                                    .split(RegExp(r'[,.]'))
                                    .map((id) => id.trim())
                                    .where((id) => id.isNotEmpty)
                                    .toList();
                                return supervisors.contains(assistant.user_id);
                              })
                              .map((m) => _getUserFullName(m.user_id))
                              .join(', ');

                          return DropdownMenuItem<String>(
                            value: assistant.user_id,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _accent.withOpacity(0.3),
                                        _accent.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      user.first_name.isNotEmpty
                                          ? user.first_name[0].toUpperCase()
                                          : "?",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${user.first_name} ${user.last_name}",
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      if (connectedMasters.isNotEmpty)
                                        Text(
                                          "Bağlı: $connectedMasters",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedAssistantId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: _textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "İptal",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: selectedAssistantId == null
                                ? null
                                : () {
                                    final assistant = _allAssistants.firstWhere(
                                      (a) => a.user_id == selectedAssistantId,
                                    );
                                    Navigator.pop(context);
                                    _assignAssistant(assistant, masterCoach);
                                  },
                            child: const Text(
                              "Bağla",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 🔥 ÇIKARMA DİYALOGU - MODERN
  // ============================================================

  void _showRemoveDialog(Coach assistant, Coach masterCoach) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Yardımcıyı Çıkar",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _danger.withOpacity(0.3),
                            _danger.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getUser(assistant.user_id).first_name.isNotEmpty
                              ? _getUser(
                                  assistant.user_id,
                                ).first_name[0].toUpperCase()
                              : "?",
                          style: TextStyle(
                            color: _danger,
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
                          Text(
                            _getUserFullName(assistant.user_id),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            "Yardımcı Antrenör",
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                "${_getUserFullName(assistant.user_id)}'i ${_getUserFullName(masterCoach.user_id)}'ten çıkarmak istediğinize emin misiniz?",
                style: const TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "İptal",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _removeAssistant(assistant, masterCoach);
                      },
                      child: const Text(
                        "Çıkar",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Antrenör Yönetimi",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: _textPrimary,
                size: 22,
              ),
              onPressed: _refreshData,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Yükleniyor...",
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _masterCoaches.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: _accent,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _masterCoaches.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildUnassignedSection();
                  }
                  final master = _masterCoaches[index - 1];
                  final masterUser = _getUser(master.user_id);
                  final assistants =
                      _assistantsByMasterUserId[master.user_id] ?? [];
                  final isExpanded = _expandedMasters.contains(master.coach_id);

                  return FadeTransition(
                    opacity: _animationController,
                    child: _buildMasterCard(
                      master,
                      masterUser,
                      assistants,
                      isExpanded,
                    ),
                  );
                },
              ),
            ),
    );
  }

  // ============================================================
  // 🔥 ATANMAMIŞ YARDIMCILAR BÖLÜMÜ - MODERN
  // ============================================================

  Widget _buildUnassignedSection() {
    if (_unassignedAssistants.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _animationController,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_warning.withOpacity(0.08), _warning.withOpacity(0.02)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _warning.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_search, color: _warning, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  "Atanmamış Yardımcılar (${_unassignedAssistants.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _warning,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Bu yardımcı antrenörler henüz hiçbir ana hocaya bağlı değil.",
              style: TextStyle(fontSize: 12, color: _textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _unassignedAssistants.map((assistant) {
                final user = _getUser(assistant.user_id);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _warning.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            user.first_name.isNotEmpty
                                ? user.first_name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _warning,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${user.first_name} ${user.last_name}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 EMPTY STATE - MODERN
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withOpacity(0.08), _accent.withOpacity(0.02)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_basketball,
              size: 80,
              color: _accent.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz Antrenör Bulunmuyor",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sisteme henüz bir antrenör kaydedilmemiş.",
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 MASTER CARD - MODERN
  // ============================================================

  Widget _buildMasterCard(
    Coach master,
    Users masterUser,
    List<Coach> assistants,
    bool isExpanded,
  ) {
    final hasAssistants = assistants.isNotEmpty;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_expandedMasters.contains(master.coach_id)) {
                      _expandedMasters.remove(master.coach_id);
                    } else {
                      _expandedMasters.add(master.coach_id);
                    }
                  });
                },
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _gradientCard,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _accent.withOpacity(0.3),
                              _accent.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            masterUser.first_name.isNotEmpty
                                ? masterUser.first_name[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Bilgiler
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${masterUser.first_name} ${masterUser.last_name}",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Ana Antrenör",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _accentLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasAssistants
                                        ? _success.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hasAssistants
                                        ? "${assistants.length} Yardımcı"
                                        : "Yardımcı Yok",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasAssistants
                                          ? _success
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => _showAssignDialog(master),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: "Yardımcı Ekle",
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withOpacity(0.5),
                            size: 28,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded Content
            if (isExpanded)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: hasAssistants
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: assistants.asMap().entries.map((entry) {
                            final index = entry.key;
                            final assistant = entry.value;
                            final assistantUser = _getUser(assistant.user_id);

                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(height: 1, color: _border),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _accent.withOpacity(0.15),
                                              _accent.withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            assistantUser.first_name.isNotEmpty
                                                ? assistantUser.first_name[0]
                                                      .toUpperCase()
                                                : "?",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: _accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${assistantUser.first_name} ${assistantUser.last_name}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: _textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _accent.withOpacity(
                                                      0.08,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "Yardımcı",
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _accent,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: _danger.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.person_remove,
                                            color: _danger,
                                            size: 20,
                                          ),
                                          tooltip: "Yardımcıyı Çıkar",
                                          onPressed: () => _showRemoveDialog(
                                            assistant,
                                            master,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Bu hocaya bağlı yardımcı yok",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showAssignDialog(master),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Yardımcı Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
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
}

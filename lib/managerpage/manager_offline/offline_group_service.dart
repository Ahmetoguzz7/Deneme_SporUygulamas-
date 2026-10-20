/*
import 'dart:async';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

class OfflineGroupService {
  static final OfflineGroupService _instance = OfflineGroupService._internal();
  factory OfflineGroupService() => _instance;
  OfflineGroupService._internal();

  late final LocalStorageService _localStorage;
  late Box _groupQueueBox;
  final List<QueuedGroupOperation> _operationQueue = [];
  final StreamController<void> _syncController = StreamController.broadcast();
  Stream<void> get onSyncComplete => _syncController.stream;

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // 🔥 İnternet durumu için
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();

  Future<void> init() async {
    if (_isInitialized) return;
    _localStorage = LocalStorageService();
    await _localStorage.init();
    _groupQueueBox = await Hive.openBox('group_queue_box');
    await _loadQueueFromStorage();

    // 🔥 İnternet değişikliklerini dinle
    _connectivity.onConnectivityChanged.listen((result) {
      _lastConnectivity = result as ConnectivityResult;
      if (result != ConnectivityResult.none && _operationQueue.isNotEmpty) {
        print("🌐 İnternet bağlantısı geldi, hemen senkronize ediliyor...");
        _processQueue();
      }
    });

    // 🔥 Başlangıçta internet durumunu kontrol et
    _checkConnectivityAndSync();

    _startPeriodicSync();
    _isInitialized = true;
    print(
      "✅ OfflineGroupService başlatıldı, kuyrukta ${_operationQueue.length} işlem",
    );
  }

  // 🔥 Başlangıçta internet varsa hemen senkronize et
  Future<void> _checkConnectivityAndSync() async {
    final result = await _connectivity.checkConnectivity();
    _lastConnectivity = result as ConnectivityResult;
    if (result != ConnectivityResult.none && _operationQueue.isNotEmpty) {
      print("🌐 Başlangıçta internet var, hemen senkronize ediliyor...");
      _processQueue();
    }
  }

  Future<bool> addGroup(Map<String, dynamic> groupData) async {
    if (_isDisposed) return false;

    try {
      final localId = "local_${DateTime.now().millisecondsSinceEpoch}";
      final newGroup = Group(
        groups_id: localId,
        branches_id: groupData['branches_id'],
        coach_id: groupData['coach_id'] ?? "",
        sports_id: groupData['sports_id'],
        name: groupData['groups_name'],
        schedule: groupData['schedule'] ?? "",
        capacity: groupData['capacity'] ?? "0",
        monthly_fee: groupData['monthly_fee'] ?? "0",
        is_active: groupData['is_active'] ?? "TRUE",
      );

      // 📥 HIVE'YE YAZ (5-10ms)
      final localGroups = _localStorage.getGroups();
      localGroups.add(newGroup);
      await _localStorage.saveGroups(localGroups);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: localId,
          operation: "add_group",
          data: groupData,
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Yeni grup Hive diske başarıyla çakıldı: ${newGroup.name}",
      );

      // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET (ARKA PLANDA)
      if (_lastConnectivity != ConnectivityResult.none) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        unawaited(_processQueue());
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Lokal grup kayıt hatası: $e");
      return false;
    }
  }

  Future<bool> updateGroup(
    String groupId,
    Map<String, dynamic> updateData,
  ) async {
    if (_isDisposed) return false;

    try {
      final localGroups = _localStorage.getGroups();
      final index = localGroups.indexWhere((g) => g.groups_id == groupId);
      if (index != -1) {
        final oldGroup = localGroups[index];
        final updatedGroup = Group(
          groups_id: groupId,
          branches_id: updateData['branches_id'] ?? oldGroup.branches_id,
          coach_id: updateData['coach_id'] ?? oldGroup.coach_id,
          sports_id: updateData['sports_id'] ?? oldGroup.sports_id,
          name: updateData['groups_name'] ?? oldGroup.name,
          schedule: updateData['schedule'] ?? oldGroup.schedule,
          capacity: updateData['capacity'] ?? oldGroup.capacity,
          monthly_fee: updateData['monthly_fee'] ?? oldGroup.monthly_fee,
          is_active: updateData['is_active'] ?? oldGroup.is_active,
        );
        localGroups[index] = updatedGroup;
        await _localStorage.saveGroups(localGroups);

        _operationQueue.add(
          QueuedGroupOperation(
            localId: groupId,
            operation: "update_group",
            data: updateData,
            createdAt: DateTime.now(),
          ),
        );
        await _saveQueueToStorage();

        print(
          "🔍 [LOKAL KONTROL]: Grup güncellemesi Hive diske kilitlendi: $groupId",
        );

        // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET
        if (_lastConnectivity != ConnectivityResult.none) {
          print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
          unawaited(_processQueue());
        } else {
          print(
            "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
          );
        }

        return true;
      }
      return false;
    } catch (e) {
      print("❌ Lokal grup güncelleme hatası: $e");
      return false;
    }
  }

  Future<bool> toggleGroupStatus(String groupId, bool isActive) async {
    return updateGroup(groupId, {"is_active": isActive ? "TRUE" : "FALSE"});
  }

  Future<bool> transferStudentToGroup(
    String studentId,
    String newGroupId,
  ) async {
    if (_isDisposed) return false;

    try {
      final localRelations = _localStorage.getGroupStudents();

      // Eski aktif ilişkileri temizle
      localRelations.removeWhere((r) => r.student_id == studentId);

      // Yeni ilişki kaydını ekle
      final newRel = GroupStudent(
        group_students_id: "local_rel_${DateTime.now().millisecondsSinceEpoch}",
        groups_id: newGroupId,
        student_id: studentId,
        is_active: "TRUE",
        enrolled_at: DateTime.now().toIso8601String(),
      );
      localRelations.add(newRel);
      await _localStorage.saveGroupStudents(localRelations);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: studentId,
          operation: "transfer_student",
          data: {"student_id": studentId, "new_group_id": newGroupId},
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Öğrenci taşıma Hive doğrulandı. Öğrenci: $studentId -> Yeni Grup: $newGroupId",
      );

      // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET
      if (_lastConnectivity != ConnectivityResult.none) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        unawaited(_processQueue());
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Öğrenci taşıma hatası: $e");
      return false;
    }
  }

  Future<bool> removeStudentFromGroup(String studentId, String groupId) async {
    if (_isDisposed) return false;

    try {
      final localRelations = _localStorage.getGroupStudents();

      localRelations.removeWhere(
        (r) => r.student_id == studentId && r.groups_id == groupId,
      );
      await _localStorage.saveGroupStudents(localRelations);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: studentId,
          operation: "remove_student",
          data: {"student_id": studentId, "group_id": groupId},
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Öğrenci gruptan çıkarıldı, Hive temizlendi. Öğrenci: $studentId",
      );

      // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET
      if (_lastConnectivity != ConnectivityResult.none) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        unawaited(_processQueue());
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Öğrenci çıkarma hatası: $e");
      return false;
    }
  }

  // 🔥 SENKRONİZASYON - İNTERNET VARSA HEMEN ÇALIŞIR
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (_isDisposed) return;
    if (_operationQueue.isEmpty) return;

    _isProcessing = true;

    try {
      // 🔥 İnternet kontrolü
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print("📡 İnternet yok, senkronizasyon ertelendi.");
        _isProcessing = false;
        return;
      }

      print(
        "🌐 İnternet var, ${_operationQueue.length} işlem senkronize ediliyor...",
      );

      final queueSnapshot = List<QueuedGroupOperation>.from(_operationQueue);
      final succeeded = <QueuedGroupOperation>[];

      for (var op in queueSnapshot) {
        try {
          bool success = false;
          print("🔄 İşleniyor: ${op.operation} - ${op.localId}");

          if (op.operation == "add_group") {
            success = await GoogleSheetService.insertData("groups", op.data);
          } else if (op.operation == "update_group") {
            success = await GoogleSheetService.updateGroup(op.localId, op.data);
          } else if (op.operation == "transfer_student") {
            success = await GoogleSheetService.transferStudentToGroup(
              op.data['student_id'],
              op.data['new_group_id'],
            );
          } else if (op.operation == "remove_student") {
            success = await GoogleSheetService.removeStudentFromGroup(
              op.data['student_id'],
              op.data['group_id'],
            );
          }

          if (success) {
            succeeded.add(op);
            print("✅ Başarılı: ${op.operation} - ${op.localId}");
          } else {
            print("❌ Başarısız: ${op.operation} - ${op.localId}");
          }
        } catch (e) {
          print("❌ Bulut Senkronizasyon Hatası: $e");
        }
      }

      // Başarılı olanları kuyruktan temizle
      if (succeeded.isNotEmpty) {
        _operationQueue.removeWhere((q) => succeeded.contains(q));
        await _saveQueueToStorage();

        // 🔥 SENKRONİZASYON TAMAMLANDI - UI'ı güncellemek için stream tetikle
        _syncController.add(null);
        print(
          "✅ ${succeeded.length} işlem senkronize edildi. Kuyrukta ${_operationQueue.length} işlem kaldı.",
        );

        // 🔥 VERİLERİ YENİDEN ÇEK (Google Sheets'ten güncel verileri al)
        await _refreshDataFromCloud();
      }
    } catch (e) {
      print("❌ _processQueue hatası: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // 🔥 YENİ: Google Sheets'ten güncel verileri çek
  Future<void> _refreshDataFromCloud() async {
    try {
      print("🔄 Google Sheets'ten güncel veriler çekiliyor...");

      // 🔥 fetchTable kullan - fetchAllData yok!
      final groupsData = await GoogleSheetService.fetchTable('groups');
      final groupStudentsData = await GoogleSheetService.fetchTable(
        'group_students',
      );

      if (groupsData.isNotEmpty) {
        // Grupları güncelle
        final updatedGroups = groupsData
            .map((json) => Group.fromJson(json))
            .toList();
        await _localStorage.saveGroups(updatedGroups);
        print("✅ ${updatedGroups.length} grup güncellendi");
      }

      if (groupStudentsData.isNotEmpty) {
        // İlişkileri güncelle
        final updatedRelations = groupStudentsData
            .map((json) => GroupStudent.fromJson(json))
            .toList();
        await _localStorage.saveGroupStudents(updatedRelations);
        print("✅ ${updatedRelations.length} ilişki güncellendi");
      }

      print("✅ Bulut verileri başarıyla güncellendi!");
    } catch (e) {
      print("❌ Bulut verileri çekilirken hata: $e");
    }
  }

  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
      } else if (_operationQueue.isNotEmpty) {
        print("⏰ Periyodik senkronizasyon çalışıyor...");
        _processQueue();
      }
    });
  }

  Future<void> _saveQueueToStorage() async {
    if (_isDisposed) return;
    final queueJson = _operationQueue.map((q) => q.toJson()).toList();
    await _groupQueueBox.put('queue', queueJson);
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _groupQueueBox.get('queue');
      if (queueJson != null && queueJson is List) {
        for (var item in queueJson) {
          try {
            Map<String, dynamic> typedItem;
            if (item is Map<String, dynamic>) {
              typedItem = item;
            } else if (item is Map<dynamic, dynamic>) {
              typedItem = Map<String, dynamic>.from(item);
            } else {
              print("❌ Geçersiz item tipi: ${item.runtimeType}");
              continue;
            }

            final operation = QueuedGroupOperation.fromJson(typedItem);
            _operationQueue.add(operation);
          } catch (e) {
            print("❌ Queue item yüklenirken hata: $e");
            print("   Item: $item");
          }
        }
        print("📦 Kuyruktan ${_operationQueue.length} öğe yüklendi");
      }
    } catch (e) {
      print("❌ _loadQueueFromStorage hatası: $e");
    }
  }

  void dispose() {
    _isDisposed = true;
    _syncController.close();
    _groupQueueBox.close();
  }
}

class QueuedGroupOperation {
  final String localId;
  final String operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  QueuedGroupOperation({
    required this.localId,
    required this.operation,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'operation': operation,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedGroupOperation.fromJson(Map<String, dynamic> json) {
    return QueuedGroupOperation(
      localId: json['localId'] as String,
      operation: json['operation'] as String,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
*/
import 'dart:async';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

class OfflineGroupService {
  static final OfflineGroupService _instance = OfflineGroupService._internal();
  factory OfflineGroupService() => _instance;
  OfflineGroupService._internal();

  late final LocalStorageService _localStorage;
  late Box _groupQueueBox;
  final List<QueuedGroupOperation> _operationQueue = [];
  final StreamController<void> _syncController = StreamController.broadcast();
  Stream<void> get onSyncComplete => _syncController.stream;

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // 🔥 Şu an çalışan kuyruk işlemi (ekranlar bunun bitmesini bekleyebilsin)
  Future<void>? _inFlight;

  /// Buluta (Google Sheets) henüz gitmemiş işlem sayısı. 0 ise bulut güncel.
  int get pendingCount => _operationQueue.length;

  // 🔥 İnternet durumu için
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();

  // 🔥 YARDIMCI FONKSİYON: İnternet kontrolü
  // 🔥 YARDIMCI FONKSİYON: İnternet kontrolü
  // 🔥 YARDIMCI FONKSİYON: İnternet kontrolü

  Future<bool> _checkInternet() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result is List) {
        return result.isNotEmpty && result.first != ConnectivityResult.none;
      }
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _localStorage = LocalStorageService();
    await _localStorage.init();
    _groupQueueBox = await Hive.openBox('group_queue_box');
    await _loadQueueFromStorage();

    // 🔥 İnternet değişikliklerini dinle - DÜZELTİLDİ
    _connectivity.onConnectivityChanged.listen((result) {
      // 🔥 result BİR LİSTE! İlk elemanı al
      if (result is List) {
        _lastConnectivity = result.isNotEmpty
            ? result.first
            : ConnectivityResult.none;
      } else {
        _lastConnectivity = result as ConnectivityResult;
      }

      if (_lastConnectivity != ConnectivityResult.none &&
          _operationQueue.isNotEmpty) {
        print("🌐 İnternet bağlantısı geldi, hemen senkronize ediliyor...");
        _processQueue();
      }
    });

    // 🔥 Başlangıçta internet durumunu kontrol et
    _checkConnectivityAndSync();

    _startPeriodicSync();
    _isInitialized = true;
    print(
      "✅ OfflineGroupService başlatıldı, kuyrukta ${_operationQueue.length} işlem",
    );
  }

  // 🔥 Başlangıçta internet varsa hemen senkronize et - DÜZELTİLDİ
  // 🔥 Başlangıçta internet varsa hemen senkronize et - DÜZELTİLDİ
  Future<void> _checkConnectivityAndSync() async {
    final hasInternet = await _checkInternet(); // ✅ DOĞRU
    if (hasInternet && _operationQueue.isNotEmpty) {
      print("🌐 Başlangıçta internet var, hemen senkronize ediliyor...");
      _processQueue();
    }
  }

  Future<bool> addGroup(Map<String, dynamic> groupData) async {
    if (_isDisposed) return false;

    try {
      final localId = "local_${DateTime.now().millisecondsSinceEpoch}";
      final newGroup = Group(
        groups_id: localId,
        branches_id: groupData['branches_id'],
        coach_id: groupData['coach_id'] ?? "",
        sports_id: groupData['sports_id'],
        name: groupData['groups_name'],
        schedule: groupData['schedule'] ?? "",
        capacity: groupData['capacity'] ?? "0",
        monthly_fee: groupData['monthly_fee'] ?? "0",
        is_active: groupData['is_active'] ?? "TRUE",
      );

      final localGroups = _localStorage.getGroups();
      localGroups.add(newGroup);
      await _localStorage.saveGroups(localGroups);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: localId,
          operation: "add_group",
          data: groupData,
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Yeni grup Hive diske başarıyla çakıldı: ${newGroup.name}",
      );

      // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET
      final hasInternet = await _checkInternet();
      if (hasInternet) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        unawaited(_processQueue());
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Lokal grup kayıt hatası: $e");
      return false;
    }
  }

  Future<bool> updateGroup(
    String groupId,
    Map<String, dynamic> updateData,
  ) async {
    if (_isDisposed) return false;

    try {
      final localGroups = _localStorage.getGroups();
      final index = localGroups.indexWhere((g) => g.groups_id == groupId);
      if (index != -1) {
        final oldGroup = localGroups[index];
        final updatedGroup = Group(
          groups_id: groupId,
          branches_id: updateData['branches_id'] ?? oldGroup.branches_id,
          coach_id: updateData['coach_id'] ?? oldGroup.coach_id,
          sports_id: updateData['sports_id'] ?? oldGroup.sports_id,
          name: updateData['groups_name'] ?? oldGroup.name,
          schedule: updateData['schedule'] ?? oldGroup.schedule,
          capacity: updateData['capacity'] ?? oldGroup.capacity,
          monthly_fee: updateData['monthly_fee'] ?? oldGroup.monthly_fee,
          is_active: updateData['is_active'] ?? oldGroup.is_active,
        );
        localGroups[index] = updatedGroup;
        await _localStorage.saveGroups(localGroups);

        _operationQueue.add(
          QueuedGroupOperation(
            localId: groupId,
            operation: "update_group",
            data: updateData,
            createdAt: DateTime.now(),
          ),
        );
        await _saveQueueToStorage();

        print(
          "🔍 [LOKAL KONTROL]: Grup güncellemesi Hive diske kilitlendi: $groupId",
        );

        // 🔥 İNTERNET VARSA HEMEN SENKRONİZE ET
        final hasInternet = await _checkInternet();
        if (hasInternet) {
          print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
          unawaited(_processQueue());
        } else {
          print(
            "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
          );
        }

        return true;
      }
      return false;
    } catch (e) {
      print("❌ Lokal grup güncelleme hatası: $e");
      return false;
    }
  }

  Future<bool> toggleGroupStatus(String groupId, bool isActive) async {
    return updateGroup(groupId, {"is_active": isActive ? "TRUE" : "FALSE"});
  }

  /// [waitForCloud] = true ise Google Sheets yazımı BİTENE kadar bekler
  /// (kuyruk boşalınca döner). Offline ise beklemeden döner; işlem kuyrukta kalır.
  Future<bool> transferStudentToGroup(
    String studentId,
    String newGroupId, {
    bool waitForCloud = false,
  }) async {
    if (_isDisposed) return false;

    try {
      final localRelations = _localStorage.getGroupStudents();

      localRelations.removeWhere((r) => r.student_id == studentId);

      final newRel = GroupStudent(
        group_students_id: "local_rel_${DateTime.now().millisecondsSinceEpoch}",
        groups_id: newGroupId,
        student_id: studentId,
        is_active: "TRUE",
        enrolled_at: DateTime.now().toIso8601String(),
      );
      localRelations.add(newRel);
      await _localStorage.saveGroupStudents(localRelations);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: studentId,
          operation: "transfer_student",
          data: {"student_id": studentId, "new_group_id": newGroupId},
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Öğrenci taşıma Hive doğrulandı. Öğrenci: $studentId -> Yeni Grup: $newGroupId",
      );

      final hasInternet = await _checkInternet();
      if (hasInternet) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        if (waitForCloud) {
          await _processQueue();
        } else {
          unawaited(_processQueue());
        }
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Öğrenci taşıma hatası: $e");
      return false;
    }
  }

  Future<bool> removeStudentFromGroup(
    String studentId,
    String groupId, {
    bool waitForCloud = false,
  }) async {
    if (_isDisposed) return false;

    try {
      final localRelations = _localStorage.getGroupStudents();

      localRelations.removeWhere(
        (r) => r.student_id == studentId && r.groups_id == groupId,
      );
      await _localStorage.saveGroupStudents(localRelations);

      _operationQueue.add(
        QueuedGroupOperation(
          localId: studentId,
          operation: "remove_student",
          data: {"student_id": studentId, "group_id": groupId},
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      print(
        "🔍 [LOKAL KONTROL]: Öğrenci gruptan çıkarıldı, Hive temizlendi. Öğrenci: $studentId",
      );

      final hasInternet = await _checkInternet();
      if (hasInternet) {
        print("🌐 İnternet mevcut, hemen Google Sheets'e yazılıyor...");
        if (waitForCloud) {
          await _processQueue();
        } else {
          unawaited(_processQueue());
        }
      } else {
        print(
          "📡 İnternet yok, işlem kuyruğa alındı. (${_operationQueue.length} işlem)",
        );
      }

      return true;
    } catch (e) {
      print("❌ Öğrenci çıkarma hatası: $e");
      return false;
    }
  }

  /// Aynı anda tek işlem çalışır; çağıran, devam eden işlemin bitmesini bekler
  /// ve kuyrukta kalan (sonradan eklenen) işlemler de işlenir.
  Future<void> _processQueue() async {
    if (_isDisposed) return;
    while (_inFlight != null) {
      await _inFlight;
    }
    if (_operationQueue.isEmpty) return;
    final f = _processQueueOnce();
    _inFlight = f;
    try {
      await f;
    } finally {
      if (identical(_inFlight, f)) _inFlight = null;
    }
  }

  Future<void> _processQueueOnce() async {
    if (_isProcessing) return;
    if (_isDisposed) return;
    if (_operationQueue.isEmpty) return;

    _isProcessing = true;

    try {
      final hasInternet = await _checkInternet();
      if (!hasInternet) {
        print("📡 İnternet yok, senkronizasyon ertelendi.");
        _isProcessing = false;
        return;
      }

      print(
        "🌐 İnternet var, ${_operationQueue.length} işlem senkronize ediliyor...",
      );

      final queueSnapshot = List<QueuedGroupOperation>.from(_operationQueue);
      final succeeded = <QueuedGroupOperation>[];

      for (var op in queueSnapshot) {
        try {
          bool success = false;
          print("🔄 İşleniyor: ${op.operation} - ${op.localId}");

          if (op.operation == "add_group") {
            success = await GoogleSheetService.insertData("groups", op.data);
          } else if (op.operation == "update_group") {
            success = await GoogleSheetService.updateGroup(op.localId, op.data);
          } else if (op.operation == "transfer_student") {
            success = await GoogleSheetService.transferStudentToGroup(
              op.data['student_id'],
              op.data['new_group_id'],
            );
          } else if (op.operation == "remove_student") {
            success = await GoogleSheetService.removeStudentFromGroup(
              op.data['student_id'],
              op.data['group_id'],
            );
          }

          if (success) {
            succeeded.add(op);
            print("✅ Başarılı: ${op.operation} - ${op.localId}");
          } else {
            print("❌ Başarısız: ${op.operation} - ${op.localId}");
          }
        } catch (e) {
          print("❌ Bulut Senkronizasyon Hatası: $e");
        }
      }

      if (succeeded.isNotEmpty) {
        _operationQueue.removeWhere((q) => succeeded.contains(q));
        await _saveQueueToStorage();

        _syncController.add(null);
        print(
          "✅ ${succeeded.length} işlem senkronize edildi. Kuyrukta ${_operationQueue.length} işlem kaldı.",
        );
        unawaited(_refreshDataFromCloud()); // beklemeden, arka planda
      }
    } catch (e) {
      print("❌ _processQueue hatası: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _refreshDataFromCloud() async {
    try {
      print("🔄 Google Sheets'ten güncel veriler çekiliyor...");

      final groupsData = await GoogleSheetService.fetchTable('groups');
      final groupStudentsData = await GoogleSheetService.fetchTable(
        'group_students',
      );

      if (groupsData.isNotEmpty) {
        final updatedGroups = groupsData
            .map((json) => Group.fromJson(json))
            .toList();
        await _localStorage.saveGroups(updatedGroups);
        print("✅ ${updatedGroups.length} grup güncellendi");
      }

      if (groupStudentsData.isNotEmpty) {
        final updatedRelations = groupStudentsData
            .map((json) => GroupStudent.fromJson(json))
            .toList();
        await _localStorage.saveGroupStudents(updatedRelations);
        print("✅ ${updatedRelations.length} ilişki güncellendi");
      }

      print("✅ Bulut verileri başarıyla güncellendi!");
    } catch (e) {
      print("❌ Bulut verileri çekilirken hata: $e");
    }
  }

  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
      } else if (_operationQueue.isNotEmpty) {
        print("⏰ Periyodik senkronizasyon çalışıyor...");
        _processQueue();
      }
    });
  }

  Future<void> _saveQueueToStorage() async {
    if (_isDisposed) return;
    final queueJson = _operationQueue.map((q) => q.toJson()).toList();
    await _groupQueueBox.put('queue', queueJson);
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _groupQueueBox.get('queue');
      if (queueJson != null && queueJson is List) {
        for (var item in queueJson) {
          try {
            Map<String, dynamic> typedItem;
            if (item is Map<String, dynamic>) {
              typedItem = item;
            } else if (item is Map<dynamic, dynamic>) {
              typedItem = Map<String, dynamic>.from(item);
            } else {
              print("❌ Geçersiz item tipi: ${item.runtimeType}");
              continue;
            }

            final operation = QueuedGroupOperation.fromJson(typedItem);
            _operationQueue.add(operation);
          } catch (e) {
            print("❌ Queue item yüklenirken hata: $e");
            print("   Item: $item");
          }
        }
        print("📦 Kuyruktan ${_operationQueue.length} öğe yüklendi");
      }
    } catch (e) {
      print("❌ _loadQueueFromStorage hatası: $e");
    }
  }

  void dispose() {
    _isDisposed = true;
    _syncController.close();
    _groupQueueBox.close();
  }
}

class QueuedGroupOperation {
  final String localId;
  final String operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  QueuedGroupOperation({
    required this.localId,
    required this.operation,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'operation': operation,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedGroupOperation.fromJson(Map<String, dynamic> json) {
    return QueuedGroupOperation(
      localId: json['localId'] as String,
      operation: json['operation'] as String,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

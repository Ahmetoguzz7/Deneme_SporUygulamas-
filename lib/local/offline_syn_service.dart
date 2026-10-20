// lib/core/offline_sync_manager.dart
import 'dart:async';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 🚀 OFFLINE-FIRST SENKRONİZASYON YÖNETİCİSİ
class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  late final LocalStorageService _localStorage;
  late final AppRepository _repository;

  Timer? _syncTimer;
  bool _isSyncing = false;

  final List<QueuedOperation> _operationQueue = [];

  final StreamController<void> _dataChangeController =
      StreamController.broadcast();
  Stream<void> get onDataChanged => _dataChangeController.stream;

  Future<void> init(AppRepository repository) async {
    _repository = repository;
    _localStorage = LocalStorageService();
    await _localStorage.init();

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());

    print("✅ OfflineSyncManager başlatıldı");
  }

  // ============================================================
  // ✍️ VERİ YAZMA - ÖNCE LOKAL, SONRA ARKA PLANDA SYNC
  // ============================================================

  Future<Users> addStudent(Users student) async {
    final updatedList = [..._localStorage.getUsers(), student];
    await _localStorage.saveUsers(updatedList);

    _repository.updateAllData(
      users: updatedList,
      groups: _repository.allGroups,
      groupStudents: _repository.allGroupStudents,
      payments: _repository.allPayments,
      attendances: _repository.allAttendances,
      coaches: _repository.allCoaches,
      notifications: _repository.allNotifications,
    );

    _dataChangeController.add(null);

    _operationQueue.add(
      QueuedOperation(
        type: OperationType.addStudent,
        data: student.toJson(),
        timestamp: DateTime.now(),
      ),
    );

    unawaited(_processQueue());
    return student;
  }

  Future<void> updateStudent(Users student) async {
    final users = _localStorage.getUsers();
    final index = users.indexWhere((u) => u.app == student.app);
    if (index != -1) {
      users[index] = student;
      await _localStorage.saveUsers(users);

      _repository.updateAllData(
        users: users,
        groups: _repository.allGroups,
        groupStudents: _repository.allGroupStudents,
        payments: _repository.allPayments,
        attendances: _repository.allAttendances,
        coaches: _repository.allCoaches,
        notifications: _repository.allNotifications,
      );

      _dataChangeController.add(null);

      _operationQueue.add(
        QueuedOperation(
          type: OperationType.updateStudent,
          data: student.toJson(),
          timestamp: DateTime.now(),
        ),
      );

      unawaited(_processQueue());
    }
  }

  Future<void> deleteStudent(String studentId) async {
    final users = _localStorage.getUsers();
    final updated = users.where((u) => u.app != studentId).toList();
    await _localStorage.saveUsers(updated);

    _repository.updateAllData(
      users: updated,
      groups: _repository.allGroups,
      groupStudents: _repository.allGroupStudents,
      payments: _repository.allPayments,
      attendances: _repository.allAttendances,
      coaches: _repository.allCoaches,
      notifications: _repository.allNotifications,
    );

    _dataChangeController.add(null);

    _operationQueue.add(
      QueuedOperation(
        type: OperationType.deleteStudent,
        data: {'student_id': studentId},
        timestamp: DateTime.now(),
      ),
    );

    unawaited(_processQueue());
  }

  Future<Payment> addPayment(Payment payment) async {
    final payments = [..._localStorage.getPayments(), payment];
    await _localStorage.savePayments(payments);

    _repository.updateAllData(
      users: _repository.allUsers,
      groups: _repository.allGroups,
      groupStudents: _repository.allGroupStudents,
      payments: payments,
      attendances: _repository.allAttendances,
      coaches: _repository.allCoaches,
      notifications: _repository.allNotifications,
    );

    _dataChangeController.add(null);

    _operationQueue.add(
      QueuedOperation(
        type: OperationType.addPayment,
        data: payment.toJson(),
        timestamp: DateTime.now(),
      ),
    );

    unawaited(_processQueue());
    return payment;
  }

  Future<Attendance> addAttendance(Attendance attendance) async {
    final attendances = [..._localStorage.getAttendances(), attendance];
    await _localStorage.saveAttendances(attendances);

    _repository.updateAllData(
      users: _repository.allUsers,
      groups: _repository.allGroups,
      groupStudents: _repository.allGroupStudents,
      payments: _repository.allPayments,
      attendances: attendances,
      coaches: _repository.allCoaches,
      notifications: _repository.allNotifications,
    );

    _dataChangeController.add(null);

    _operationQueue.add(
      QueuedOperation(
        type: OperationType.addAttendance,
        data: attendance.toJson(),
        timestamp: DateTime.now(),
      ),
    );

    unawaited(_processQueue());
    return attendance;
  }

  // ============================================================
  // 🔄 ARKA PLAN SENKRONİZASYONU
  // ============================================================

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    print("🔄 Senkronizasyon başladı...");

    try {
      await _processQueue();
      await _pullFromGoogle();
      print("✅ Senkronizasyon tamamlandı!");
    } catch (e) {
      print("❌ Senkronizasyon hatası: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueue() async {
    if (_operationQueue.isEmpty) return;

    print("📤 ${_operationQueue.length} işlem senkronize ediliyor...");

    final List<QueuedOperation> succeeded = [];
    final List<QueuedOperation> failed = [];

    for (final op in _operationQueue) {
      try {
        final success = await _executeOperation(op);
        if (success) {
          succeeded.add(op);
          print("  ✅ ${op.type} başarılı");
        } else {
          failed.add(op);
          print("  ❌ ${op.type} başarısız");
        }
      } catch (e) {
        failed.add(op);
        print("  ❌ ${op.type} hata: $e");
      }
    }

    _operationQueue.removeWhere((op) => succeeded.contains(op));

    if (_operationQueue.isNotEmpty) {
      print("⚠️ ${_operationQueue.length} işlem bekliyor (internet yok)");
    }
  }

  Future<bool> _executeOperation(QueuedOperation op) async {
    final url = Uri.parse(
      "https://script.google.com/macros/s/AKfycbyXYvvBgO5z4PWhH5X1IiiDeOJ3-_fxskrPulIi9xOLBx8EKH2Wm9ckGITM7SLbjx23rQ/exec",
    );

    try {
      final response = await http
          .post(
            url,
            body: {
              'action': _getActionForOperation(op.type),
              'data': jsonEncode(op.data),
              'timestamp': op.timestamp.toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String _getActionForOperation(OperationType type) {
    switch (type) {
      case OperationType.addStudent:
        return 'addStudent';
      case OperationType.updateStudent:
        return 'updateStudent';
      case OperationType.deleteStudent:
        return 'deleteStudent';
      case OperationType.addPayment:
        return 'addPayment';
      case OperationType.addAttendance:
        return 'addAttendance';
    }
  }

  Future<void> _pullFromGoogle() async {
    print("📥 Google'dan güncel veriler çekiliyor...");

    final results = await Future.wait([
      GoogleSheetService.getUsersCached(forceRefresh: true),
      GoogleSheetService.getGroupsCached(forceRefresh: true),
      GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
      GoogleSheetService.getPaymentsCached(forceRefresh: true),
      GoogleSheetService.getAttendancesCached(forceRefresh: true),
      GoogleSheetService.getCoachesCached(forceRefresh: true),
      GoogleSheetService.getNotifications(userId: "all", forceRefresh: true),
    ]);

    final users = results[0] as List<Users>;
    final groups = results[1] as List<Group>;
    final groupStudents = results[2] as List<GroupStudent>;
    final payments = results[3] as List<Payment>;
    final attendances = results[4] as List<Attendance>;
    final coaches = results[5] as List<Coach>;
    final notifications = results[6] as List<Notifications>;

    await _localStorage.saveAllData(
      users: users,
      groups: groups,
      groupStudents: groupStudents,
      payments: payments,
      attendances: attendances,
      coaches: coaches,
      notifications: notifications,
    );

    await _localStorage.setLastSyncTime(DateTime.now());

    _repository.updateAllData(
      users: users,
      groups: groups,
      groupStudents: groupStudents,
      payments: payments,
      attendances: attendances,
      coaches: coaches,
      notifications: notifications,
    );

    _dataChangeController.add(null);

    print(
      "✅ Google verileri lokal cache'e kaydedildi: ${users.length} kullanıcı",
    );
  }

  void dispose() {
    _syncTimer?.cancel();
    _dataChangeController.close();
  }
}

enum OperationType {
  addStudent,
  updateStudent,
  deleteStudent,
  addPayment,
  addAttendance,
}

class QueuedOperation {
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  QueuedOperation({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

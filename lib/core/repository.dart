import 'package:flutter/foundation.dart';
import '../core/db/local_db.dart';
import '../core/net/api_client.dart';
import '../core/sync/sync_engine.dart';

/// Ekranların konuştuğu TEK kapı.
///   • Okuma  -> her zaman yerelden (SQLite), anında.
///   • Yazma  -> önce yerele bas (optimistic) + outbox'a at + arka planda gönder.
///   • Sync   -> SyncEngine outbox'ı boşaltır ve tabloları tazeler.
class AppRepository extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  late final SyncEngine _sync = SyncEngine(_api, notifyListeners);

  /// Manuel/arka plan senkron tetikleyici.
  Future<void> syncNow() => _sync.sync();

  /// Sadece bir tabloyu tazele (ör. bildirim gelince).
  Future<void> pullTable(String table) => _sync.pullTable(table);

  // ==========================================================================
  // OKUMA (hep yerelden, anında)
  // ==========================================================================
  Future<List<Map<String, dynamic>>> users({String? role}) {
    return LocalDb.I.query(
      'users',
      where: role == null ? null : 'role=?',
      args: role == null ? null : [role],
    );
  }

  Future<Map<String, dynamic>?> userById(String id) async {
    final r = await LocalDb.I.query('users', where: 'id=?', args: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, dynamic>>> groups({String? coachId}) {
    return LocalDb.I.query(
      'groups',
      where: coachId == null ? null : 'coach_id=?',
      args: coachId == null ? null : [coachId],
    );
  }

  Future<List<Map<String, dynamic>>> groupStudents({String? groupId}) {
    return LocalDb.I.query(
      'group_students',
      where: groupId == null ? null : 'groups_id=?',
      args: groupId == null ? null : [groupId],
    );
  }

  // ==========================================================================
  // 🔥 ÖĞRENCİ TOPLAMA (student_data)
  // ==========================================================================
  Future<List<Map<String, dynamic>>> studentData() =>
      LocalDb.I.query('student_data');

  Future<void> saveStudentData({
    required String firstName,
    required String lastName,
    required String phone,
    required String bDate,
    required String branches,
    String createdAt = '',
  }) {
    final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final m = {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'b_date': bDate,
      'branches': branches,
      'created_at': createdAt.isEmpty
          ? DateTime.now().toIso8601String()
          : createdAt,
    };
    return _write(
      table: 'student_data',
      data: m,
      cols: const [],
      pk: 'id',
      queuePayload: {
        'action': 'insertExtra',
        'table': 'student_data',
        'data': m,
      },
    );
  }

  // ==========================================================================
  // 🔥 GİDER YÖNETİMİ (expense_management)
  // ==========================================================================
  Future<List<Map<String, dynamic>>> expenses() =>
      LocalDb.I.query('expense_management');

  Future<void> saveExpense({
    required String title, // gider açıklaması -> note
    required String amount, // tutar -> money
    required String paidDate, // tarih -> paid_date
  }) {
    final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final m = {
      'id': id,
      'first_name': '',
      'last_name': '',
      'money': amount,
      'mont_money': '',
      'paid_date': paidDate,
      'note': title,
    };
    return _write(
      table: 'expense_management',
      data: m,
      cols: const [],
      pk: 'id',
      queuePayload: {
        'action': 'insertExtra',
        'table': 'expense_management',
        'data': m,
      },
    );
  }

  Future<List<Map<String, dynamic>>> coaches() => LocalDb.I.query('coaches');
  Future<List<Map<String, dynamic>>> branches() => LocalDb.I.query('branches');
  Future<List<Map<String, dynamic>>> sports() => LocalDb.I.query('sports');

  Future<List<Map<String, dynamic>>> attendances({
    String? groupId,
    String? date,
    String? studentId,
  }) {
    final w = <String>[], a = <Object?>[];
    if (groupId != null) {
      w.add('groups_id=?');
      a.add(groupId);
    }
    if (date != null) {
      w.add('attendance_date=?');
      a.add(date);
    }
    if (studentId != null) {
      w.add('student_id=?');
      a.add(studentId);
    }
    return LocalDb.I.query(
      'attendances',
      where: w.isEmpty ? null : w.join(' AND '),
      args: a,
    );
  }

  Future<List<Map<String, dynamic>>> payments({
    String? studentId,
    String? groupId,
  }) {
    final w = <String>[], a = <Object?>[];
    if (studentId != null) {
      w.add('student_id=?');
      a.add(studentId);
    }
    if (groupId != null) {
      w.add('groups_id=?');
      a.add(groupId);
    }
    return LocalDb.I.query(
      'payments',
      where: w.isEmpty ? null : w.join(' AND '),
      args: a,
    );
  }

  Future<List<Map<String, dynamic>>> notifications() =>
      LocalDb.I.query('notifications');

  // Oturumdaki kullanıcı
  Future<String?> currentUserId() => LocalDb.I.getMeta('current_user_id');

  // ==========================================================================
  // LOGIN (sadece online — yerelde parola tutulmaz)
  // ==========================================================================
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await _api.post({
      'action': 'login',
      'email': email,
      'password': password,
    });
    if (res != null && res['success'] == true) {
      final user = Map<String, dynamic>.from(res['data']['user']);
      await LocalDb.I.setMeta(
        'current_user_id',
        (user['app'] ?? '').toString(),
      );
      return user;
    }
    return null;
  }

  Future<void> logout() async {
    await LocalDb.I.wipe();
    notifyListeners();
  }

  // ==========================================================================
  // YAZMA (optimistic + outbox)
  // ==========================================================================

  /// Ortak yardımcı: yerele bas + kuyruğa at + arka planda gönder.
  Future<void> _write({
    required String table,
    required Map<String, dynamic> data,
    required List<String> cols,
    required String pk,
    required Map<String, dynamic> queuePayload,
  }) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await LocalDb.I.putLocal(table, data, cols, pk);
    notifyListeners();
    await LocalDb.I.enqueue(queuePayload);
    _sync.sync();
  }

  // --- YOKLAMA ---
  Future<void> saveAttendance({
    required String studentId,
    required String groupsId,
    required String date,
    required String status,
    String takenBy = '',
    String note = '',
    String? attendanceId,
  }) {
    final id = (attendanceId != null && attendanceId.isNotEmpty)
        ? attendanceId
        : 'local_${DateTime.now().microsecondsSinceEpoch}';
    final m = {
      'attendances_id': id,
      'student_id': studentId,
      'groups_id': groupsId,
      'attendance_date': date,
      'status': status,
      'taken_by': takenBy,
      'note': note,
    };
    return _write(
      table: 'attendances',
      data: m,
      cols: ['student_id', 'groups_id', 'attendance_date'],
      pk: 'attendances_id',
      queuePayload: {'action': 'saveAttendance', 'data': m},
    );
  }

  /// Toplu yoklama (bir grubun tüm öğrencileri tek seferde)
  Future<void> saveBulkAttendance(List<Map<String, dynamic>> rows) async {
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      r['attendances_id'] ??=
          'local_${DateTime.now().microsecondsSinceEpoch}_${r['student_id']}';
      r['updated_at'] = now;
      await LocalDb.I.putLocal('attendances', r, [
        'student_id',
        'groups_id',
        'attendance_date',
      ], 'attendances_id');
    }
    notifyListeners();
    await LocalDb.I.enqueue({'action': 'saveBulkAttendance', 'data': rows});
    _sync.sync();
  }

  // --- ÖDEME ---
  Future<void> savePayment(Map<String, dynamic> p) {
    final id = (p['payments_id']?.toString().isNotEmpty == true)
        ? p['payments_id'].toString()
        : 'local_${DateTime.now().microsecondsSinceEpoch}';
    p['payments_id'] = id;
    return _write(
      table: 'payments',
      data: p,
      cols: ['student_id', 'groups_id', 'due_date'],
      pk: 'payments_id',
      queuePayload: {'action': 'insert', 'table': 'payments', 'data': p},
    );
  }

  // --- KULLANICI GÜNCELLE ---
  Future<void> updateUser(Map<String, dynamic> user) {
    return _write(
      table: 'users',
      data: user,
      cols: ['role', 'email'],
      pk: 'app',
      queuePayload: {'action': 'updateUser', 'data': user},
    );
  }

  // --- BİLDİRİM OKUNDU ---
  Future<void> markNotificationRead(String notifId) async {
    final r = await LocalDb.I.query(
      'notifications',
      where: 'id=?',
      args: [notifId],
    );
    if (r.isEmpty) return;
    final m = r.first..['is_read'] = 'TRUE';
    return _write(
      table: 'notifications',
      data: m,
      cols: ['recipient_id', 'groups_id'],
      pk: 'notifications_id',
      queuePayload: {
        'action': 'updateNotification',
        'notifications_id': notifId,
        'is_read': true,
      },
    );
  }

  // --- ÖĞRENCİYİ GRUBA ATA ---
  Future<void> assignStudentToGroup(String studentId, String groupId) async {
    await LocalDb.I.enqueue({
      'action': 'assignStudentToGroup',
      'student_id': studentId,
      'group_id': groupId,
      'is_active': 'TRUE',
    });
    _sync.sync();
  }
}

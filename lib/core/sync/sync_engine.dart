import '../db/local_db.dart';
import '../net/api_client.dart';

/// Sync bittikten sonra Repository'yi (UI'yi) haberdar etmek için.
typedef OnChanged = void Function();

/// 🔥 Senkronizasyon hatalarını UI'ye bildirmek için callback
typedef OnSyncError =
    void Function(Map<String, dynamic> payload, String errorMsg);

/// Bir tablonun sync kimliği.
class _T {
  final String table; // yerel SQLite tablo adı
  final String sheet; // sunucudaki sayfa adı
  final String serverPk; // sunucu satırındaki birincil anahtar alanı
  final List<String> cols; // filtre için gerçek sütuna yazılacak alanlar
  final bool whole; // true: replaceAll, false: upsert
  const _T(this.table, this.sheet, this.serverPk, this.cols, this.whole);
}

class SyncEngine {
  final ApiClient _api;
  final OnChanged _onChanged;
  final OnSyncError? _onError; // 🔥 Hata bildirimi için callback

  SyncEngine(this._api, this._onChanged, [this._onError]);

  bool _running = false;

  static const List<_T> _tables = [
    _T('users', 'users', 'app', ['role', 'email'], false),
    _T('branches', 'branches', 'branches_id', [], false),
    _T('sports', 'sports', 'sports_id', [], false),
    _T('coaches', 'coaches', 'coach_id', ['user_id'], false),
    _T('groups', 'groups', 'groups_id', ['coach_id'], false),
    // whole=true: Sheet'ten silinen / taşınan öğrenci kayıtları yerelden de
    // temizlensin (upsert silme yapmadığı için eski satırlar hayalet kalıyordu).
    _T('group_students', 'group_students', 'group_students_id', [
      'student_id',
      'groups_id',
    ], true),
    _T('attendances', 'attendances', 'attendances_id', [
      'student_id',
      'groups_id',
      'attendance_date',
    ], false),
    _T('payments', 'payments', 'payments_id', [
      'student_id',
      'groups_id',
      'due_date',
    ], false),
    _T('notifications', 'notifications', 'notifications_id', [
      'recipient_id',
      'groups_id',
    ], false),
    _T('student_data', 'student_data', 'id', [], false),
    _T('expense_management', 'expense_management', 'id', [], false),
  ];

  static const List<String> liveTables = [
    'notifications',
    'payments',
    'attendances',
  ];

  static const List<String> criticalTables = [
    'users',
    'branches',
    'sports',
    'coaches',
    'groups',
    'group_students',
  ];

  Future<bool> syncCritical() async {
    if (_running) return false;
    _running = true;
    try {
      final pushed = await _drainOutbox();
      final crit = _tables.where((t) => criticalTables.contains(t.table));
      final results = await Future.wait(crit.map(_pullOne));
      final pulled = results.any((x) => x);
      final changed = pushed || pulled;
      if (changed) _onChanged();
      return changed;
    } finally {
      _running = false;
    }
  }

  Future<bool> syncRest() async {
    if (_running) return false;
    _running = true;
    try {
      var pulled = false;
      for (final t in _tables) {
        if (criticalTables.contains(t.table)) continue;
        if (await _pullOne(t)) pulled = true;
      }
      if (pulled) _onChanged();
      return pulled;
    } finally {
      _running = false;
    }
  }

  Future<bool> sync() async {
    if (_running) return false;
    _running = true;
    try {
      final pushed = await _drainOutbox();
      final pulled = await _pullAll();
      final changed = pushed || pulled;
      if (changed) _onChanged();
      return changed;
    } finally {
      _running = false;
    }
  }

  Future<bool> syncLive() async {
    if (_running) return false;
    _running = true;
    try {
      final pushed = await _drainOutbox();
      var pulled = false;
      for (final t in _tables) {
        if (!liveTables.contains(t.table)) continue;
        if (await _pullOne(t)) pulled = true;
      }
      final changed = pushed || pulled;
      if (changed) _onChanged();
      return changed;
    } finally {
      _running = false;
    }
  }

  Future<void> pullTable(String table) async {
    _T? spec;
    for (final t in _tables) {
      if (t.table == table || t.sheet == table) {
        spec = t;
        break;
      }
    }
    if (spec == null) return;
    final ok = await _pullOne(spec);
    if (ok) _onChanged();
  }

  Future<bool> syncStudentPayments(String studentId) async {
    if (studentId.isEmpty) return false;
    try {
      await _drainOutbox();

      final rows = await _api.getSheet('payments');
      if (rows.isEmpty) return false;

      final pending = await LocalDb.I.pendingIdsFor('payments', 'payments_id');

      await LocalDb.I.replaceForStudent(
        'payments',
        rows,
        ['student_id', 'groups_id', 'due_date'],
        serverPk: 'payments_id',
        studentId: studentId,
        keepIds: pending,
      );
      _onChanged();
      return true;
    } catch (e) {
      print("⚠️ syncStudentPayments($studentId) hatası: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 1) OUTBOX -> SUNUCU
  // ---------------------------------------------------------------------------
  Future<bool> _drainOutbox() async {
    var any = false;
    final items = await LocalDb.I.outbox();
    for (final it in items) {
      final id = it['id'] as int;
      final payload = Map<String, dynamic>.from(it['payload'] as Map);
      final retries = it['retries'] as int;

      final res = await _api.post(payload);

      if (res == null) {
        break;
      }
      if (res['success'] == true) {
        await LocalDb.I.dropOutbox(id);
        any = true;
      } else {
        await LocalDb.I.bumpRetry(id);
        final errorMsg = res['error']?.toString() ?? "Sunucu reddetti";

        // 🔥 Deneme limiti dolduğunda (örn: 5 deneme) UI'ye hata bildirimi gönder
        if (retries + 1 >= 5) {
          if (_onError != null) {
            _onError(payload, errorMsg);
          }
          await LocalDb.I.dropOutbox(id);
        }
      }
    }
    return any;
  }

  // ---------------------------------------------------------------------------
  // 2) SUNUCU -> YEREL
  // ---------------------------------------------------------------------------
  Future<bool> _pullAll() async {
    var any = false;
    for (final t in _tables) {
      if (await _pullOne(t)) any = true;
    }
    return any;
  }

  Future<bool> _pullOne(_T t) async {
    final rows = await _api.getSheet(t.sheet);
    if (rows.isEmpty) return false;
    if (t.whole) {
      final keepIds = await LocalDb.I.pendingIdsFor(t.table, t.serverPk);
      await LocalDb.I.replaceAll(
        t.table,
        rows,
        t.cols,
        serverPk: t.serverPk,
        keepIds: keepIds,
      );
    } else {
      await LocalDb.I.upsert(t.table, rows, t.cols, serverPk: t.serverPk);
    }
    return true;
  }
}

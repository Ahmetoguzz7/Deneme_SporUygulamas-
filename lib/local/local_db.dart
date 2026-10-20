import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sport_app.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Ana tablolar
    await db.execute('''
      CREATE TABLE users (
        app TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        groups_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        payments_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE attendances (
        attendances_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        notifications_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE coaches (
        coach_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE branches (
        branches_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sports (
        sports_id TEXT PRIMARY KEY,
        data TEXT,
        last_sync INTEGER
      )
    ''');

    // PENDING OPERATIONS (offline'da yapılan işlemler)
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT,
        table_name TEXT,
        data TEXT,
        created_at INTEGER,
        retry_count INTEGER
      )
    ''');

    // Sync log
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        sync_time INTEGER,
        status TEXT,
        record_count INTEGER
      )
    ''');
  }

  // =========================================================================
  // CRUD İŞLEMLERİ
  // =========================================================================

  Future<void> insertOrUpdate(
    String tableName,
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    await db.insert(tableName, {
      '${tableName}_id': id,
      'data': jsonEncode(data),
      'last_sync': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAll(String tableName) async {
    final db = await database;
    final result = await db.query(tableName);
    return result
        .map((row) => {...row, 'data': jsonDecode(row['data'] as String)})
        .toList();
  }

  Future<Map<String, dynamic>?> getById(String tableName, String id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '${tableName}_id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return jsonDecode(result.first['data'] as String);
  }

  Future<void> deleteById(String tableName, String id) async {
    final db = await database;
    await db.delete(tableName, where: '${tableName}_id = ?', whereArgs: [id]);
  }

  Future<void> clearTable(String tableName) async {
    final db = await database;
    await db.delete(tableName);
  }

  // =========================================================================
  // PENDING OPERATIONS
  // =========================================================================

  Future<void> addPendingOperation({
    required String operation,
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.insert('pending_operations', {
      'operation': operation,
      'table_name': tableName,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'created_at ASC');
  }

  Future<void> removePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_operations SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> clearAllPendingOperations() async {
    final db = await database;
    await db.delete('pending_operations');
  }

  // =========================================================================
  // SYNC LOG
  // =========================================================================

  Future<void> addSyncLog(
    String tableName,
    String status,
    int recordCount,
  ) async {
    final db = await database;
    await db.insert('sync_log', {
      'table_name': tableName,
      'sync_time': DateTime.now().millisecondsSinceEpoch,
      'status': status,
      'record_count': recordCount,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncLogs({int limit = 50}) async {
    final db = await database;
    return await db.query('sync_log', orderBy: 'sync_time DESC', limit: limit);
  }

  // =========================================================================
  // TEMİZLİK
  // =========================================================================

  Future<void> clearOldData(String tableName, {int olderThanDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;
    await db.delete(tableName, where: 'last_sync < ?', whereArgs: [cutoff]);
  }

  Future<void> cleanupOldSyncLogs({int olderThanDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;
    await db.delete('sync_log', where: 'sync_time < ?', whereArgs: [cutoff]);
  }

  // =========================================================================
  // VERİTABANI DURUMU
  // =========================================================================

  Future<int> getTableRowCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );
    return result.first['count'] as int;
  }

  Future<Map<String, int>> getAllTableCounts() async {
    final tables = [
      'users',
      'groups',
      'payments',
      'attendances',
      'notifications',
      'coaches',
      'branches',
      'sports',
    ];
    final counts = <String, int>{};
    for (var table in tables) {
      counts[table] = await getTableRowCount(table);
    }
    counts['pending_operations'] = await getTableRowCount('pending_operations');
    return counts;
  }
}

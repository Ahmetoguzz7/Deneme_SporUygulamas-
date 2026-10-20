import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite: tek gerçek kaynak. Her tabloda id + data(JSON) + updated_at + deleted.
/// Filtrelenen alanlar gerçek sütun (hızlı WHERE), gerisi data(JSON) içinde.
class LocalDb {
  static final LocalDb I = LocalDb._();
  LocalDb._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'evom.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int _) async {
    // Domain tabloları — filtrelenen alanlar gerçek sütun, gerisi data(JSON)
    await db.execute('''CREATE TABLE users(
      id TEXT PRIMARY KEY, role TEXT, email TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE groups(
      id TEXT PRIMARY KEY, coach_id TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE group_students(
      id TEXT PRIMARY KEY, student_id TEXT, groups_id TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE coaches(
      id TEXT PRIMARY KEY, user_id TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE payments(
      id TEXT PRIMARY KEY, student_id TEXT, groups_id TEXT, due_date TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE attendances(
      id TEXT PRIMARY KEY, student_id TEXT, groups_id TEXT, attendance_date TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE notifications(
      id TEXT PRIMARY KEY, recipient_id TEXT, groups_id TEXT,
      data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''');
    await db.execute(
      '''CREATE TABLE branches(
      id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
    );
    await db.execute(
      '''CREATE TABLE sports(
      id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
    );
    // 🔥 EK TABLOLAR
    await db.execute(
      '''CREATE TABLE student_data(
      id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
    );
    await db.execute(
      '''CREATE TABLE expense_management(
      id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
    );
    // Index'ler (filtre hızı)
    await db.execute(
      'CREATE INDEX ix_att ON attendances(groups_id, attendance_date)',
    );
    await db.execute('CREATE INDEX ix_pay ON payments(student_id)');
    await db.execute('CREATE INDEX ix_gs  ON group_students(groups_id)');

    // Sistem tabloları
    await db.execute('''CREATE TABLE outbox(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payload TEXT, created_at TEXT, retries INTEGER DEFAULT 0)''');
    await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
  }

  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute(
        '''CREATE TABLE IF NOT EXISTS student_data(
        id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
      );
      await db.execute(
        '''CREATE TABLE IF NOT EXISTS expense_management(
        id TEXT PRIMARY KEY, data TEXT, updated_at TEXT, deleted INTEGER DEFAULT 0)''',
      );
    }
  }
  // ==========================================================================
  // SUNUCUDAN GELEN VERİYİ YAZMA
  // ==========================================================================

  /// Upsert: sunucudan gelen ham satır listesini tabloya yaz (var olanı günceller).
  Future<void> upsert(
    String table,
    List rows,
    List<String> cols, {
    required String serverPk,
  }) async {
    if (rows.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = (m[serverPk] ?? '').toString();
      if (id.isEmpty) continue;
      final row = <String, Object?>{
        'id': id,
        'data': jsonEncode(m),
        'updated_at': (m['updated_at'] ?? '').toString(),
        'deleted': (m['deleted'] == true || m['deleted'] == 'TRUE') ? 1 : 0,
      };
      for (final c in cols) row[c] = (m[c] ?? '').toString();
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// 🎯 ÖĞRENCİ BAZLI SENKRON (payments için)
  /// Sadece [studentId]'ye ait ödemeleri, sunucudan gelen [rows] içindeki AYNI
  /// öğrencinin kayıtlarıyla değiştirir. DİĞER öğrencilerin ödemelerine ve
  /// bu öğrencinin outbox'ta bekleyen (keepIds) kayıtlarına DOKUNMAZ.
  ///
  /// Böylece bir öğrenciye ödeme alınca sadece onun satırları tazelenir;
  /// başka aylar/öğrenciler yanlışlıkla silinmez.
  Future<void> replaceForStudent(
    String table,
    List rows,
    List<String> cols, {
    required String serverPk,
    required String studentId,
    Set<String>? keepIds,
  }) async {
    final d = await db;

    // Sunucudan gelen satırlardan SADECE bu öğrenciye ait olanları al.
    final mine = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      if ((m['student_id'] ?? '').toString() == studentId) mine.add(m);
    }

    // 🛡️ KISMİ VERİ KALKANI: Bu öğrencinin YERELDEKİ (silinmemiş) ödeme sayısı
    //   ile Sheet'ten dönen sayısını karşılaştır. Sheet, yereldekinin
    //   yarısından AZ döndürdüyse -> Sheet henüz güncel değil / eksik geldi;
    //   senkronu İPTAL et, local veriyi (ödenmiş aylar) KORU.
    final localCntRes = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE deleted=0 AND student_id=?',
      [studentId],
    );
    final localCount = (localCntRes.first['c'] as int?) ?? 0;
    if (localCount > 2 && mine.length < (localCount / 2)) {
      // ignore: avoid_print
      print(
        "🛡️ replaceForStudent iptal ($studentId): Sheet ${mine.length} ödeme "
        "döndü ama yerelde $localCount var. Eksik veri, korundu.",
      );
      return;
    }

    // Bu öğrencinin sunucudan gelen id'leri
    final serverIds = mine.map((m) => (m[serverPk] ?? '').toString()).toSet();

    // Korunacak (outbox'ta bekleyen ama sunucuda olmayan) yerel satırları sakla
    List<Map<String, Object?>> preserved = const [];
    if (keepIds != null && keepIds.isNotEmpty) {
      final toPreserve = keepIds.difference(serverIds);
      if (toPreserve.isNotEmpty) {
        final ph = List.filled(toPreserve.length, '?').join(',');
        preserved = await d.query(
          table,
          where: 'id IN ($ph)',
          whereArgs: toPreserve.toList(),
        );
      }
    }

    await d.transaction((txn) async {
      // Sadece bu öğrencinin mevcut satırlarını sil
      await txn.delete(table, where: 'student_id=?', whereArgs: [studentId]);

      final batch = txn.batch();
      for (final m in mine) {
        final id = (m[serverPk] ?? '').toString();
        if (id.isEmpty) continue;
        final row = <String, Object?>{
          'id': id,
          'data': jsonEncode(m),
          'updated_at': (m['updated_at'] ?? '').toString(),
          'deleted': 0,
        };
        for (final c in cols) row[c] = (m[c] ?? '').toString();
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Korunan yerel satırları geri yaz
      for (final row in preserved) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Tabloyu tamamen replace eder (küçük tablolar için: silinenler de temizlenir)
  /// [keepIds] verilirse, o id'lere sahip mevcut yerel satırlar SİLİNMEZ —
  /// sunucudan gelmese bile korunur (ör. henüz Sheet'e gitmemiş, outbox'ta
  /// bekleyen optimistic kayıtlar).
  Future<void> replaceAll(
    String table,
    List rows,
    List<String> cols, {
    required String serverPk,
    Set<String>? keepIds,
  }) async {
    final d = await db;

    // 🛡️ Sadece birincil anahtarı OLAN satırlar yazılabilir. Hiç geçerli satır
    //   yoksa (kolon adı değişmiş, bozuk cevap vb.) tabloyu SİLME.
    final validCount = rows.where((raw) {
      try {
        final m = Map<String, dynamic>.from(raw as Map);
        return (m[serverPk] ?? '').toString().isNotEmpty;
      } catch (_) {
        return false;
      }
    }).length;
    if (validCount == 0) {
      // ignore: avoid_print
      print(
        "🛡️ replaceAll iptal ($table): ${rows.length} satırın hiçbirinde "
        "'$serverPk' yok. Tablo korundu.",
      );
      return;
    }

    // 🛡️ KISMİ VERİ KORUMASI: Sheet'ten gelen satır sayısı, mevcut yerel
    //   (silinmemiş) satır sayısının yarısından AZSA, bunu bozuk/eksik veri
    //   kabul edip replace'i İPTAL et. Böylece API bir tur eksik/boş dönerse
    //   local veriyi (ör. eski ödemeler) yanlışlıkla silmeyiz.
    final cntRes = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE deleted=0',
    );
    final localCount = (cntRes.first['c'] as int?) ?? 0;
    if (localCount > 4 && validCount < (localCount / 2)) {
      // ignore: avoid_print
      print(
        "🛡️ replaceAll iptal ($table): Sheet ${rows.length} satır döndü ama "
        "yerelde $localCount var. Bozuk/eksik veri, tablo korundu.",
      );
      return;
    }

    if (rows.length != localCount) {
      // ignore: avoid_print
      print(
        "🔁 replaceAll($table): yerel $localCount -> sunucu ${rows.length}",
      );
    }

    // Korunacak satırları önceden oku (silmeden önce), sonra geri yaz.
    List<Map<String, Object?>> preserved = const [];
    if (keepIds != null && keepIds.isNotEmpty) {
      final serverIds = <String>{};
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        serverIds.add((m[serverPk] ?? '').toString());
      }
      // Sunucudan da gelenler zaten yazılacak; sadece sunucuda OLMAYAN
      // ama korunması gereken yerel satırları sakla.
      final toPreserve = keepIds.difference(serverIds);
      if (toPreserve.isNotEmpty) {
        final placeholders = List.filled(toPreserve.length, '?').join(',');
        preserved = await d.query(
          table,
          where: 'id IN ($placeholders)',
          whereArgs: toPreserve.toList(),
        );
      }
    }

    await d.transaction((txn) async {
      await txn.delete(table);
      final batch = txn.batch();
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m[serverPk] ?? '').toString();
        if (id.isEmpty) continue;
        final row = <String, Object?>{
          'id': id,
          'data': jsonEncode(m),
          'updated_at': (m['updated_at'] ?? '').toString(),
          'deleted': 0,
        };
        for (final c in cols) row[c] = (m[c] ?? '').toString();
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Korunan yerel satırları geri yaz
      for (final row in preserved) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // ==========================================================================
  // 🔥 YEREL (OPTIMISTIC) YAZMA — kullanıcının yaptığı değişikliği hemen yerele bas.
  //     Repository._write / saveAttendance / savePayment bunu çağırır.
  // ==========================================================================
  Future<void> putLocal(
    String table,
    Map<String, dynamic> data,
    List<String> cols,
    String pk,
  ) async {
    final d = await db;
    final id = (data[pk] ?? '').toString();
    if (id.isEmpty) return;
    final row = <String, Object?>{
      'id': id,
      'data': jsonEncode(data),
      'updated_at': (data['updated_at'] ?? DateTime.now().toIso8601String())
          .toString(),
      'deleted': (data['deleted'] == true || data['deleted'] == 'TRUE') ? 1 : 0,
    };
    for (final c in cols) row[c] = (data[c] ?? '').toString();
    await d.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==========================================================================
  // OKUMA
  // ==========================================================================
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? args,
  }) async {
    final d = await db;
    final rows = await d.query(
      table,
      where: ['deleted=0', if (where != null) where].join(' AND '),
      whereArgs: args,
    );
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ==========================================================================
  // 🔥 OUTBOX — offline'da yapılan yazma işlemlerinin kuyruğu.
  //     Repository.enqueue() ekler, SyncEngine online olunca boşaltır.
  // ==========================================================================
  Future<void> enqueue(Map<String, dynamic> payload) async {
    final d = await db;
    await d.insert('outbox', {
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retries': 0,
    });
  }

  /// Kuyruktaki işleri sırayla döner: [{id, payload(Map), retries}]
  Future<List<Map<String, dynamic>>> outbox() async {
    final d = await db;
    final rows = await d.query('outbox', orderBy: 'id ASC');
    return rows.map((r) {
      return {
        'id': r['id'] as int,
        'payload': jsonDecode(r['payload'] as String) as Map<String, dynamic>,
        'retries': (r['retries'] as int?) ?? 0,
      };
    }).toList();
  }

  Future<void> dropOutbox(int id) async {
    final d = await db;
    await d.delete('outbox', where: 'id=?', whereArgs: [id]);
  }

  Future<void> bumpRetry(int id) async {
    final d = await db;
    await d.rawUpdate('UPDATE outbox SET retries = retries + 1 WHERE id = ?', [
      id,
    ]);
  }

  Future<int> outboxCount() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Belirli bir tabloya ait, outbox'ta gönderilmeyi bekleyen kayıtların
  /// id'lerini döner. Sync sırasında bu id'ler korunur (silinmez).
  /// [dataIdKey] = payload['data'] içindeki birincil anahtar alanı (ör. payments_id).
  Future<Set<String>> pendingIdsFor(String table, String dataIdKey) async {
    final items = await outbox();
    final ids = <String>{};
    for (final it in items) {
      final payload = it['payload'] as Map<String, dynamic>?;
      if (payload == null) continue;
      if (payload['table'] != table) continue;
      final data = payload['data'];
      if (data is Map) {
        final v = data[dataIdKey];
        if (v != null && v.toString().isNotEmpty) ids.add(v.toString());
      }
    }
    return ids;
  }

  /// 🧹 Tek bir tablonun TÜM yerel kayıtlarını siler (SADECE local; Sheet'e
  /// dokunmaz). "Local veriyi sıfırla" için. Bir sonraki sync tabloyu
  /// Sheet'ten yeniden doldurur.
  Future<void> clearTable(String table) async {
    final d = await db;
    await d.delete(table);
  }

  // ==========================================================================
  // META — küçük anahtar/değer (current_user_id, last_sync vb.)
  // ==========================================================================
  Future<void> setMeta(String k, String v) async {
    final d = await db;
    await d.insert('meta', {
      'k': k,
      'v': v,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String k) async {
    final d = await db;
    final r = await d.query('meta', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  // ==========================================================================
  // ÇIKIŞ — kullanıcı değişince tüm yerel veriyi temizle.
  // ==========================================================================
  Future<void> wipe() async {
    final d = await db;
    const tables = [
      'users',
      'groups',
      'group_students',
      'coaches',
      'payments',
      'attendances',
      'notifications',
      'branches',
      'sports',
      'student_data',
      'expense_management',
      'outbox',
      'meta',
    ];
    await d.transaction((txn) async {
      for (final t in tables) {
        await txn.delete(t);
      }
    });
  }
}

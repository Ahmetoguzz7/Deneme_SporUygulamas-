import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'db/local_db.dart';
import 'net/api_client.dart';
import 'sync/sync_engine.dart';

/// 🔥 UYGULAMANIN HAFIZA ODASI (RAM) — artık SQLite (LocalDb) ile besleniyor.
///
/// Sayfalar bu sınıfı eskisi gibi `AppRepository()` diye kullanır; tüm
/// `all*` listeleri, `get*` aramaları ve stream'ler AYNI. Fark: veri artık
/// Google Sheets yerine yerel SQLite'tan okunuyor (anında + offline), tazeleme
/// ise SyncEngine ile arka planda yapılıyor.
///
///   SQLite (LocalDb) ──loadAllData──> RAM (all*) ──> Ekranlar
///        ▲ refreshAllData/refreshSingleTable = SyncEngine (Sheets -> SQLite)
class AppRepository {
  static final AppRepository _instance = AppRepository._internal();
  factory AppRepository() => _instance;
  AppRepository._internal();
  Future<void> syncNow() => _sync.sync();
  // --------------------------------------------------------------------------
  // 🧠 RAM VERİLERİ (sayfalar doğrudan okur)
  // --------------------------------------------------------------------------
  List<Users> allUsers = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];
  List<Payment> allPayments = [];
  List<Attendance> allAttendances = [];
  List<Branches> allBranches = [];
  List<Sports> allSports = [];
  List<Coach> allCoaches = [];
  List<Notifications> allNotifications = [];
  List<ParentStudent> allParentStudents = [];

  // --------------------------------------------------------------------------
  // ⚡ HIZLI ERİŞİM İÇİN INDEX MAP'LERİ
  // --------------------------------------------------------------------------
  Map<String, List<GroupStudent>> _groupStudentsByGroupId = {};
  Map<String, List<GroupStudent>> _groupStudentsByStudentId = {};
  Map<String, List<Payment>> _paymentsByStudentId = {};
  Map<String, List<Attendance>> _attendancesByStudentId = {};
  Map<String, List<Attendance>> _attendancesByGroupId = {};
  Map<String, Users> _usersById = {};
  Map<String, Group> _groupsById = {};
  Map<String, Branches> _branchesById = {};
  Map<String, Sports> _sportsById = {};
  Map<String, Notifications> _notificationsById = {};

  // --------------------------------------------------------------------------
  // 📶 DURUM + STREAM'LER
  // --------------------------------------------------------------------------
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  bool _isFromCache = false;
  bool get isFromCache => _isFromCache;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isBackgroundLoading = false;

  bool _hasError = false;
  bool get hasError => _hasError;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  final List<String> _operationLogs = [];
  List<String> get operationLogs => _operationLogs;

  final List<VoidCallback> _onPhotoLoadCallbacks = [];
  // 🔥 Senkronizasyon hata mesajlarını dinlemek için akış (Stream)
  final StreamController<String> _syncErrorController =
      StreamController<String>.broadcast();
  Stream<String> get onSyncError => _syncErrorController.stream;

  // Hata tetikleme metodu
  void notifySyncError(String errorMsg) {
    _syncErrorController.add(errorMsg);
  }

  final StreamController<bool> _dataUpdateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onDataUpdated => _dataUpdateController.stream;

  final StreamController<bool> _errorController =
      StreamController<bool>.broadcast();
  Stream<bool> get onErrorChanged => _errorController.stream;

  final StreamController<bool> _opLogsController =
      StreamController<bool>.broadcast();
  Stream<bool> get onOperationLogsUpdated => _opLogsController.stream;

  // --------------------------------------------------------------------------
  // 🔌 ALTYAPI (SQLite + Sync)
  // --------------------------------------------------------------------------
  final ApiClient _api = ApiClient();
  late final SyncEngine _sync = SyncEngine(_api, () {});

  // Otomatik sessiz senkron
  Timer? _autoSyncTimer;
  bool _autoSyncing = false;
  int _autoTick = 0;

  // ==========================================================================
  // 🚀 YÜKLEME / TAZELEME
  // ==========================================================================

  Future<void> init() => loadAllData();

  // ==========================================================================
  // 🔁 OTOMATİK SESSİZ SENKRON
  //   Ana ekran açılınca başlat: aralıklarla arka planda kontrol eder,
  //   yeni veri gelmişse sessizce yansıtır. Çakışmaz, hata göstermez,
  //   offline'da veriye dokunmaz; bağlantı gelince kendini toparlar.
  // ==========================================================================
  void startAutoSync({Duration interval = const Duration(seconds: 45)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => _silentSync());
    _silentSync(); // açılışta hemen bir kez
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Uygulama arka plana geçince duraklat / öne gelince devam et (opsiyonel).
  void pauseAutoSync() => stopAutoSync();
  void resumeAutoSync({Duration interval = const Duration(seconds: 45)}) =>
      startAutoSync(interval: interval);

  Future<void> _silentSync() async {
    if (_autoSyncing || _isProcessing) return; // çakışma yok
    _autoSyncing = true;
    try {
      _autoTick++;
      // Çoğu tur hafif (canlı tablolar); her 8 turda bir tam senkron.
      final changed = (_autoTick % 8 == 0)
          ? await _sync.sync()
          : await _sync.syncLive();
      if (changed) {
        await _loadFromDisk();
        _dataUpdateController.add(true); // sessizce ekranları tazele
      }
    } catch (_) {
      // sessiz: bir sonraki tur toparlar
    } finally {
      _autoSyncing = false;
    }
  }

  /// Diskten (SQLite) RAM'e yükler. İnternet BEKLEMEZ.
  /// İlk açılışta sadece KRİTİK küçük tabloları bekler (hızlı), ağır tabloları
  /// (ödeme/yoklama/bildirim) arkada doldurur → ekran anında gelir.
  Future<void> loadAllData({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) return;
    _isProcessing = true;
    try {
      await _loadFromDisk(); // hızlı / offline
      _isFromCache = true;
      final firstRun = _isAllEmpty();

      if (firstRun) {
        // Sadece kritik küçük tabloları bekle (saniyeler), gerisi arkada.
        await _sync.syncCritical();
        await _loadFromDisk();
      }
      _isLoaded = true;
      _clearError();
      _isProcessing = false;
      _dataUpdateController.add(true);

      // 🔽 Ağır veriyi ARKADA doldur (await YOK → ekranı bekletmez).
      _backgroundFill(restOnly: firstRun);
    } catch (e) {
      _isProcessing = false;
      _setError('loadAllData: $e');
      _dataUpdateController.add(true);
    }
  }

  /// Kritik veriyi yükle (progress bildirimli). Overlay bunu çağırır;
  /// artık tam senkronu BEKLEMEZ, hızlı 1.0'a ulaşır.
  Future<void> loadCriticalData({
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    if (_isLoaded) {
      onProgress?.call(1.0);
      return;
    }
    _isProcessing = true;
    try {
      onMessage?.call('Yerel veriler yükleniyor...');
      await _loadFromDisk();
      onProgress?.call(0.4);
      final firstRun = _isAllEmpty();

      if (firstRun) {
        onMessage?.call('İlk veriler hazırlanıyor...');
        await _sync.syncCritical(); // sadece kritikler (hızlı)
        await _loadFromDisk();
      }
      onProgress?.call(1.0);
      _isLoaded = true;
      _clearError();
      _isProcessing = false;
      _dataUpdateController.add(true);

      _backgroundFill(restOnly: firstRun); // ağır tablolar arkada
    } catch (e) {
      _isProcessing = false;
      _setError('loadCriticalData: $e');
      onProgress?.call(1.0);
      _dataUpdateController.add(true);
    }
  }

  /// Ağır/kalan tabloları arka planda çeker; bitince sessizce ekranı tazeler.
  /// await EDİLMEZ — UI'yi asla bekletmez.
  void _backgroundFill({required bool restOnly}) {
    () async {
      try {
        final changed = restOnly ? await _sync.syncRest() : await _sync.sync();
        if (changed) {
          await _loadFromDisk();
          _dataUpdateController.add(true);
        }
      } catch (_) {
        // sessiz: periyodik senkron zaten toparlar
      }
    }();
  }

  /// Sunucudan her şeyi tazele (Sheets -> SQLite -> RAM).
  Future<void> refreshAllData() async {
    _isProcessing = true;
    try {
      await _sync.sync();
      await _loadFromDisk();
      _isLoaded = true;
      _isFromCache = false;
      _clearError();
    } catch (e) {
      _setError('refreshAllData: $e');
    } finally {
      _isProcessing = false;
      _dataUpdateController.add(true);
    }
  }

  /// 🧹 SADECE ÖDEMELERİ yerelden sıfırla, sonra Sheet'ten taze çek.
  /// Sheet'te olmayan hayalet/eski local ödemeleri temizlemek için.
  /// Google Sheet'e DOKUNMAZ — sadece local (SQLite + RAM). Ardından
  /// payments tablosu Sheet neyse ona göre yeniden dolar.
  Future<void> resetPaymentsFromSheet() async {
    _isProcessing = true;
    try {
      await LocalDb.I.clearTable('payments'); // local'i boşalt
      allPayments = []; // RAM'i boşalt
      _buildMaps();
      _dataUpdateController.add(true);

      await _sync.pullTable('payments'); // Sheet'ten taze çek
      await _loadFromDisk(); // RAM'e yükle
      _clearError();
      print("🧹 Ödemeler sıfırlandı ve Sheet'ten yeniden yüklendi.");
    } catch (e) {
      _setError('resetPaymentsFromSheet: $e');
    } finally {
      _isProcessing = false;
      _dataUpdateController.add(true);
    }
  }

  /// 🧹 TÜM yerel veriyi sıfırla ve sunucudan baştan çek.
  /// "Local veriyi sıfırla" düğmesi bunu çağırır. Sheet'e dokunmaz.
  /// UYARI: outbox'ta bekleyen (henüz gönderilmemiş) işler de silinir —
  /// yalnızca her şeyin Sheet'e gittiğinden eminken kullan.
  Future<void> hardResetLocal() async {
    _isProcessing = true;
    try {
      await LocalDb.I.wipe(); // tüm local tablolar + outbox
      // RAM'i boşalt
      allUsers = [];
      allGroups = [];
      allGroupStudents = [];
      allPayments = [];
      allAttendances = [];
      allBranches = [];
      allSports = [];
      allCoaches = [];
      allNotifications = [];
      allParentStudents = [];
      _buildMaps();
      _isLoaded = false;
      _dataUpdateController.add(true);

      await loadAllData(forceRefresh: true); // sunucudan baştan
      _clearError();
      print("🧹 Tüm yerel veri sıfırlandı ve sunucudan yeniden yüklendi.");
    } catch (e) {
      _setError('hardResetLocal: $e');
    } finally {
      _isProcessing = false;
      _dataUpdateController.add(true);
    }
  }

  /// Eski API uyumu: tek tablo tazele (tümünü senkron eder, sonra yeniler).
  Future<void> refreshTable(String tableName, String s) =>
      refreshSingleTable(tableName);

  /// Sadece tek bir tabloyu sunucudan tazele, sonra RAM'i güncelle.
  Future<void> refreshSingleTable(String tableName) async {
    try {
      await _sync.pullTable(tableName);
      await _loadFromDisk();
      _dataUpdateController.add(true);
    } catch (e) {
      _setError('refreshSingleTable($tableName): $e');
    }
  }

  /// Sadece index map'lerini yeniden kur (liste zaten güncelse).
  void refreshMapsOnly() => _buildMaps();

  // ==========================================================================
  // 👥 ÖĞRENCİ ↔ GRUP (taşı / çıkar) — SQLite + RAM
  // ==========================================================================
  // Bulut yazımını OfflineGroupService yapar. Ama ekranlar verisini SQLite'tan
  // okuduğu için değişiklik BURAYA da yazılmalı; yoksa ekrandan çıkıp girince
  // (veya periyodik senkronda) _loadFromDisk eski veriyi geri getirir.
  // İdempotent: aynı çağrı tekrar yapılırsa sonuç değişmez.

  /// [toGroupId] verilirse taşıma, verilmezse gruptan çıkarma.
  Future<void> applyStudentGroupChange({
    required String studentId,
    required String fromGroupId,
    String? toGroupId,
  }) async {
    try {
      final d = await LocalDb.I.db;

      // Eski gruptaki satır(lar)ı oku (taşırken aynı satırı yeni gruba çevireceğiz,
      // böylece Sheet'teki group_students_id ile uyumlu kalır).
      final fromRows = await LocalDb.I.query(
        'group_students',
        where: 'student_id=? AND groups_id=?',
        args: [studentId, fromGroupId],
      );

      // Eski gruptaki kayıtları SQLite'tan kalıcı sil
      await d.delete(
        'group_students',
        where: 'student_id=? AND groups_id=?',
        whereArgs: [studentId, fromGroupId],
      );

      if (toGroupId != null) {
        final already = await LocalDb.I.query(
          'group_students',
          where: 'student_id=? AND groups_id=?',
          args: [studentId, toGroupId],
        );
        if (already.isEmpty) {
          final data = fromRows.isNotEmpty
              ? Map<String, dynamic>.from(fromRows.first)
              : <String, dynamic>{
                  'student_id': studentId,
                  'enrolled_at': DateTime.now().toIso8601String(),
                };
          if ((data['group_students_id'] ?? '').toString().isEmpty) {
            data['group_students_id'] =
                'local_${DateTime.now().microsecondsSinceEpoch}';
          }
          data['groups_id'] = toGroupId;
          data['is_active'] = 'TRUE';
          await LocalDb.I.putLocal('group_students', data, [
            'student_id',
            'groups_id',
          ], 'group_students_id');
        }
      }

      await _reloadGroupStudentsFromDisk();
    } catch (e) {
      _setError('applyStudentGroupChange: $e');
    }
  }

  /// Sadece group_students tablosunu SQLite'tan RAM'e yükler (hızlı).
  Future<void> _reloadGroupStudentsFromDisk() async {
    final gs = await _load('group_students', (m) => GroupStudent.fromJson(m));
    if (gs == null) return;
    allGroupStudents = _dedupeGroupStudents(gs);
    _buildMaps();
    _dataUpdateController.add(true);
  }

  /// Aynı öğrenci aynı grupta birden fazla satırsa tek satıra indirir
  /// (taşıma sırasında local/sheet id farkından doğan çift kayıtları engeller).
  List<GroupStudent> _dedupeGroupStudents(List<GroupStudent> list) {
    final seen = <String>{};
    return list
        .where((r) => seen.add('${r.student_id}|${r.groups_id}'))
        .toList();
  }

  /// 🎯 Bir öğrencinin ödemelerini Sheet ile senkronla (hedefli).
  /// Ödeme alındıktan sonra çağır: sadece o öğrencinin ödemeleri Sheet'ten
  /// tazelenir, diğer öğrenciler/aylar hiç etkilenmez. Ekranın "eksik/fazla"
  /// hesabı güncel Sheet verisiyle yeniden yapılır.
  Future<void> syncStudentPayments(String studentId) async {
    if (studentId.isEmpty) return;
    try {
      final changed = await _sync.syncStudentPayments(studentId);
      if (changed) {
        await _loadFromDisk(); // RAM'i tazele
        _dataUpdateController.add(true);
      }
    } catch (e) {
      _setError('syncStudentPayments($studentId): $e');
    }
  }

  /// 💰 Öğrencinin aylık ücretini (users.amount) ANINDA SQLite + RAM'e yazar.
  /// Neden: _loadFromDisk RAM'i her seferinde SQLite'tan yeniden kurar. Ücret
  /// sadece RAM'e/Sheet'e yazılırsa, Sheet'ten tazelenene kadar (tam senkron
  /// ~6 dk) diğer ekranlar ESKİ ücreti görürdü. Burada yerel kaynak güncellenir.
  Future<void> setUserAmountLocal(String userId, double amount) async {
    if (userId.isEmpty) return;
    try {
      final rows = await LocalDb.I.query(
        'users',
        where: 'id=?',
        args: [userId],
      );
      if (rows.isEmpty) return;
      final data = Map<String, dynamic>.from(rows.first);
      data['amount'] = amount.toStringAsFixed(0);
      data['updated_at'] = DateTime.now().toIso8601String();
      await LocalDb.I.putLocal('users', data, ['role', 'email'], 'app');

      final updated = Users.fromJson(data);
      final i = allUsers.indexWhere((u) => u.app == userId);
      if (i >= 0) {
        allUsers[i] = updated;
      } else {
        allUsers.add(updated);
      }
      _buildMaps();
      _dataUpdateController.add(true);
    } catch (e) {
      _setError('setUserAmountLocal($userId): $e');
    }
  }

  /// OfflineSyncManager vb. için public map yeniden kurma.
  void rebuildMaps() => _buildMaps();

  /// Toplu güncelleme (dışarıdan hazır listelerle).
  void updateAllData({
    required List<Users> users,
    required List<Group> groups,
    required List<GroupStudent> groupStudents,
    required List<Payment> payments,
    required List<Attendance> attendances,
    required List<Coach> coaches,
    required List<Notifications> notifications,
  }) {
    allUsers = users;
    allGroups = groups;
    allGroupStudents = groupStudents;
    allPayments = payments;
    allAttendances = attendances;
    allCoaches = coaches;
    allNotifications = notifications;
    _buildMaps();
    _isLoaded = true;
    _dataUpdateController.add(true);
  }

  Map<String, dynamic> getAllData() => {
    'users': allUsers,
    'groups': allGroups,
    'groupStudents': allGroupStudents,
    'payments': allPayments,
    'attendances': allAttendances,
    'coaches': allCoaches,
    'notifications': allNotifications,
  };

  // ==========================================================================
  // 🖼️ PROFİL FOTOĞRAFLARI (arka planda önden yükle)
  // ==========================================================================
  Future<void> preloadProfilePhotosAsync(
    BuildContext context, {
    Function(int loaded, int total)? onProgress,
  }) async {
    if (_isBackgroundLoading) return;
    _isBackgroundLoading = true;
    try {
      final urls = allUsers
          .map((u) => u.profile_photo_url)
          .where((s) => s.isNotEmpty)
          .toList();
      var loaded = 0;
      for (final url in urls) {
        try {
          await precacheImage(NetworkImage(url), context);
        } catch (_) {}
        loaded++;
        onProgress?.call(loaded, urls.length);
      }
      for (final cb in _onPhotoLoadCallbacks) {
        cb();
      }
    } finally {
      _isBackgroundLoading = false;
    }
  }

  void onPhotoLoadComplete(VoidCallback callback) {
    _onPhotoLoadCallbacks.add(callback);
  }

  // ==========================================================================
  // 🧹 TTEMİZLİK
  // ==========================================================================
  void clearCache() {
    _groupStudentsByGroupId.clear();
    _groupStudentsByStudentId.clear();
    _paymentsByStudentId.clear();
    _attendancesByStudentId.clear();
    _attendancesByGroupId.clear();
    _usersById.clear();
    _groupsById.clear();
    _branchesById.clear();
    _sportsById.clear();
    _notificationsById.clear();
  }

  void reset() {
    _isLoaded = false;
    _isBackgroundLoading = false;
    clearCache();
  }

  void dispose() {
    stopAutoSync();
    _dataUpdateController.close();
    _errorController.close();
    _opLogsController.close();
  }

  // --- ÖDEME KAYDETME (Mükerrer Korumalı) ---
  /// [enqueue] = false ise ödeme SADECE yerele + RAM'e yazılır, outbox'a
  /// atılmaz. Ödeme ekranı zaten GoogleSheetService.addPayment ile ödemeyi
  /// doğrudan internete yazdığında bunu false geçer; böylece sync sırasında
  /// aynı ödeme sheet'e ikinci kez YAZILMAZ (çift kayıt engellenir).
  Future<void> savePayment(
    Map<String, dynamic> p, {
    bool enqueue = true,
  }) async {
    // NOT: Aynı ay + aynı tutar "mükerrer" sayılıp engellenmiyor artık —
    //   çünkü bir aya birden fazla (limit dahilinde) ödeme MEŞRU olabilir
    //   (ör. taksitli 2 x 2250). Gerçek çift-tık koruması aşağıda payments_id
    //   bazlı yapılıyor; ay limiti ise ödeme ekranında (UI) uygulanıyor.

    final id = (p['payments_id']?.toString().isNotEmpty == true)
        ? p['payments_id'].toString()
        : 'local_${DateTime.now().microsecondsSinceEpoch}';
    p['payments_id'] = id;

    // Aynı ID zaten RAM'de varsa (tekrar tık / çift çağrı) tekrar ekleme
    if (allPayments.any((x) => x.payments_id == id)) {
      print("⚠️ Aynı payments_id zaten mevcut, atlanıyor: $id");
      return;
    }

    // 1. Yerel SQLite veritabanına bas
    await LocalDb.I.putLocal('payments', p, [
      'student_id',
      'groups_id',
      'due_date',
    ], 'payments_id');

    // 2. Outbox kuyruğuna SADECE offline kayıt gerektiğinde ekle.
    //    Online yazımda (enqueue=false) atlanır -> sheet'e tek kayıt.
    if (enqueue) {
      final existingOutbox = await LocalDb.I.outbox();
      // Aynı payments_id kuyrukta varsa tekrar ekleme (çift-tık koruması).
      //   Ay/tutar bazlı DEĞİL — aynı aya meşru 2. ödeme engellenmesin.
      final bool alreadyInQueue = existingOutbox.any((item) {
        final payload = item['payload'] as Map<String, dynamic>?;
        final data = payload?['data'] as Map<String, dynamic>?;
        return data?['payments_id'] == id;
      });

      if (!alreadyInQueue) {
        await LocalDb.I.enqueue({
          'action': 'insert',
          'table': 'payments',
          'data': p,
        });
      }
    }

    // 3. RAM'e anında yansıt
    final paymentObj = Payment.fromJson(p);
    allPayments.removeWhere((x) => x.payments_id == id);
    allPayments.insert(0, paymentObj);
    _buildMaps();

    // Not: Kalıcılık zaten adım 1'deki LocalDb.I.putLocal (SQLite) ile yapıldı;
    // bu mimaride ayrı bir Hive cache yok, o yüzden ekstra kayıt gerekmez.

    _dataUpdateController.add(true);
  }

  Future<void> deletePaymentLocalAndCloud(String paymentId) async {
    try {
      // 1. RAM'den anında uçur
      allPayments.removeWhere((p) => p.payments_id == paymentId);
      _buildMaps();
      _dataUpdateController.add(true);

      // 2. Yerel SQLite'tan tamamen sil (kayıtlar payments_id ile basılıyor,
      //    SQLite'ta birincil anahtar kolonu 'id' (payments_id JSON içinde))
      final d = await LocalDb.I.db;
      await d.delete('payments', where: 'id = ?', whereArgs: [paymentId]);

      // 3. Outbox kuyruğuna silme emri at
      await LocalDb.I.enqueue({
        'action': 'deletePayment',
        'payments_id': paymentId,
      });

      // 4. Arka planda senkronizasyonu tetikle
      _sync.sync();
      print("✅ Ödeme lokalden silindi ve silme kuyruğuna eklendi.");
    } catch (e) {
      print("❌ Silme hatası: $e");
    }
  }

  // ==========================================================================
  // 🔎 ARAMALAR (hepsi RAM üstünde — orijinalle birebir)
  // ==========================================================================
  List<Users> getStudentsOnly() =>
      allUsers.where((u) => u.role.toLowerCase() == 'student').toList();

  List<Users> getCoachesOnly() =>
      allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();

  List<Users> getParentsOnly() =>
      allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();

  Users? getUserById(String userId) => _usersById[userId];

  List<Group> getActiveGroups() =>
      allGroups.where((g) => g.is_active.toUpperCase() == "TRUE").toList();

  List<Group> getAllGroups() => List.from(allGroups);

  List<Group> getGroupsByBranch(String branchId) =>
      allGroups.where((g) => g.branches_id == branchId).toList();

  List<Group> getGroupsByCoach(String coachId) =>
      allGroups.where((g) => g.coach_id == coachId).toList();

  Group? getGroupById(String groupId) => _groupsById[groupId];

  List<GroupStudent> getGroupStudentsByGroupId(String groupId) =>
      _groupStudentsByGroupId[groupId] ?? [];

  List<GroupStudent> getGroupStudentsByStudentId(String studentId) =>
      _groupStudentsByStudentId[studentId] ?? [];

  List<Group> getGroupsByStudentId(String studentId) {
    final groupIds = getGroupStudentsByStudentId(studentId)
        .where((gs) => gs.is_active.toString().toUpperCase() == "TRUE")
        .map((gs) => gs.groups_id)
        .toSet();
    return allGroups.where((g) => groupIds.contains(g.groups_id)).toList();
  }

  List<Payment> getPaymentsByStudentId(String studentId) =>
      _paymentsByStudentId[studentId] ?? [];

  double getStudentBalance(String studentId) {
    double totalPaid = 0.0;
    for (final p in getPaymentsByStudentId(studentId)) {
      if (p.status.toLowerCase() == 'paid') {
        totalPaid += double.tryParse(p.amount) ?? 0;
      }
    }
    return totalPaid;
  }

  List<Attendance> getAttendancesByStudentId(String studentId) =>
      _attendancesByStudentId[studentId] ?? [];

  List<Attendance> getAttendancesByGroupId(String groupId) =>
      _attendancesByGroupId[groupId] ?? [];

  Coach? getCoachById(String coachId) {
    try {
      return allCoaches.firstWhere((c) => c.coach_id == coachId);
    } catch (_) {
      return null;
    }
  }

  Coach? getCoachByStudentId(String studentId) {
    final groups = getGroupsByStudentId(studentId);
    if (groups.isEmpty) return null;
    final coachId = groups.first.coach_id;
    if (coachId.isEmpty) return null;
    return getCoachById(coachId);
  }

  Users? getStudentCoach(String studentId) {
    final coach = getCoachByStudentId(studentId);
    if (coach == null) return null;
    return getUserById(coach.user_id);
  }

  Users? getCoachUser(String coachId) {
    final coach = getCoachById(coachId);
    if (coach == null) return null;
    return getUserById(coach.user_id);
  }

  Branches? getBranchById(String branchId) => _branchesById[branchId];
  Sports? getSportById(String sportId) => _sportsById[sportId];
  Notifications? getNotificationById(String id) => _notificationsById[id];

  List<Payment> getAllPayments() => List.from(allPayments);

  List<Notifications> getNotificationsByRecipient(String recipientId) {
    return allNotifications.where((n) {
      final rId = n.recipient_id.toString();
      return rId == recipientId ||
          rId == "all" ||
          rId == "ALL" ||
          rId == "Tümü";
    }).toList();
  }

  // ---- Antrenöre özel (yardımcı antrenör destekli) ----
  List<Group> getGroupsByCoachId(String coachId) {
    if (coachId.isEmpty) return [];

    Coach? currentCoach;
    try {
      currentCoach = allCoaches.firstWhere(
        (c) => c.user_id == coachId || c.coach_id == coachId,
      );
    } catch (_) {
      return [];
    }

    // supervisor_coach_id BOŞ ise yardımcı antrenör olabilir -> üst hocaları bul.
    if (currentCoach.supervisor_coach_id.isEmpty) {
      final masterCoachIds = <String>[];
      for (final coach in allCoaches) {
        if (coach.supervisor_coach_id.isNotEmpty) {
          List<String> supervisorIds;
          if (coach.supervisor_coach_id.contains(',')) {
            supervisorIds = coach.supervisor_coach_id
                .split(',')
                .map((s) => s.trim())
                .toList();
          } else if (coach.supervisor_coach_id.contains('.')) {
            supervisorIds = coach.supervisor_coach_id
                .split('.')
                .map((s) => s.trim())
                .toList();
          } else {
            supervisorIds = [coach.supervisor_coach_id.trim()];
          }
          if (supervisorIds.contains(currentCoach.user_id)) {
            masterCoachIds.add(coach.coach_id);
          }
        }
      }
      if (masterCoachIds.isNotEmpty) {
        final result = <Group>[];
        for (final masterId in masterCoachIds) {
          result.addAll(
            allGroups
                .where((g) => g.coach_id == masterId)
                .where((g) => g.is_active.toUpperCase() == "TRUE"),
          );
        }
        return result;
      }
    }

    // Normal ana koç: kendi grupları.
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  List<Users> getStudentsByCoachId(String coachId) {
    final myGroupIds = getGroupsByCoachId(
      coachId,
    ).map((g) => g.groups_id).toSet();
    final studentIds = allGroupStudents
        .where(
          (gs) =>
              myGroupIds.contains(gs.groups_id) &&
              gs.is_active.toString().toUpperCase() == "TRUE",
        )
        .map((gs) => gs.student_id)
        .toSet();
    return allUsers.where((u) => studentIds.contains(u.app)).toList();
  }

  List<Notifications> getNotificationsForCoach(
    String coachId, {
    int? lastNDays,
  }) {
    final myGroupIds = getGroupsByCoachId(
      coachId,
    ).map((g) => g.groups_id).toSet();
    var filtered = allNotifications.where((n) {
      final recipientId = n.recipient_id.toString();
      if (recipientId == "all" ||
          recipientId == "Tümü" ||
          recipientId == "ALL") {
        return true;
      }
      if (recipientId.isNotEmpty && myGroupIds.contains(recipientId))
        return true;
      if (n.groups_id.isNotEmpty && myGroupIds.contains(n.groups_id))
        return true;
      return false;
    }).toList();

    if (lastNDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: lastNDays));
      filtered = filtered.where((n) {
        try {
          return DateTime.parse(n.sent_at).isAfter(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    filtered.sort((a, b) {
      try {
        return DateTime.parse(b.sent_at).compareTo(DateTime.parse(a.sent_at));
      } catch (_) {
        return 0;
      }
    });
    return filtered;
  }

  List<Group> getTodaysGroupsForCoach(String coachId) {
    final myGroups = getGroupsByCoachId(coachId);
    final todayName = _getTodayNameTurkish();
    final todaysGroups = myGroups
        .where((g) => g.schedule.contains(todayName))
        .toList();
    todaysGroups.sort(
      (a, b) => _timeToMinutes(
        _extractStartTime(a, todayName),
      ).compareTo(_timeToMinutes(_extractStartTime(b, todayName))),
    );
    return todaysGroups;
  }

  List<Group> getTodaysGroupsForStudent(String studentId) {
    final myGroups = getGroupsByStudentId(studentId);
    final todayName = _getTodayNameTurkish();
    final todaysGroups = myGroups
        .where((g) => g.schedule.contains(todayName))
        .toList();
    todaysGroups.sort(
      (a, b) => _timeToMinutes(
        _extractStartTime(a, todayName),
      ).compareTo(_timeToMinutes(_extractStartTime(b, todayName))),
    );
    return todaysGroups;
  }

  Users? getParentByStudentId(
    String studentId,
    List<ParentStudent> parentStudents,
  ) {
    final link = parentStudents.firstWhere(
      (ps) => ps.student_id == studentId,
      orElse: () =>
          ParentStudent(parent_student_id: "", parent_id: "", student_id: ""),
    );
    if (link.parent_id.isEmpty) return null;
    return getUserById(link.parent_id);
  }

  List<Users> getChildrenByParentId(
    String parentId,
    List<ParentStudent> parentStudents,
  ) {
    final childIds = parentStudents
        .where((ps) => ps.parent_id == parentId)
        .map((ps) => ps.student_id)
        .toList();
    return allUsers.where((u) => childIds.contains(u.app)).toList();
  }

  // ---- Sayaç / gelir ----
  int getTotalStudentCount() => getStudentsOnly().length;
  int getTotalGroupCount() => allGroups.length;
  int getTotalPaymentCount() => allPayments.length;
  int getTotalNotificationCount() => allNotifications.length;

  double getTotalRevenue() {
    double total = 0;
    for (final p in allPayments) {
      if (p.status.toLowerCase() == 'paid') {
        total += double.tryParse(p.amount) ?? 0;
      }
    }
    return total;
  }

  double getRevenueByMonth(int year, int month) {
    double total = 0;
    for (final p in allPayments) {
      if (p.status.toLowerCase() != 'paid') continue;
      try {
        final date = DateTime.parse(p.paid_date.split('T')[0]);
        if (date.year == year && date.month == month) {
          total += double.tryParse(p.amount) ?? 0;
        }
      } catch (_) {}
    }
    return total;
  }

  // ---- Aramalar ----
  List<Users> searchStudents(String query) {
    if (query.isEmpty) return getStudentsOnly();
    final q = query.toLowerCase();
    return getStudentsOnly().where((s) {
      return s.first_name.toLowerCase().contains(q) ||
          s.last_name.toLowerCase().contains(q) ||
          "${s.first_name} ${s.last_name}".toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.phone.contains(query);
    }).toList();
  }

  List<Group> searchGroups(String query) {
    if (query.isEmpty) return allGroups;
    final q = query.toLowerCase();
    return allGroups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  List<Notifications> searchNotifications(String query) {
    if (query.isEmpty) return allNotifications;
    final q = query.toLowerCase();
    return allNotifications.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.message.toLowerCase().contains(q);
    }).toList();
  }

  // ==========================================================================
  // 🔧 İÇ YARDIMCILAR
  // ==========================================================================

  // Aynı anda birden fazla _loadFromDisk çağrısı (45sn timer, arka plan dolum,
  // elle yenileme...) üst üste binip ESKİ bir okumayla yenisini ezmesin diye
  // tek kuyrukta çalıştırılır. Çalışırken yeni istek gelirse bir tur daha döner.
  Future<void>? _diskLoadInFlight;
  bool _diskLoadAgain = false;

  Future<void> _loadFromDisk() {
    final running = _diskLoadInFlight;
    if (running != null) {
      _diskLoadAgain = true;
      return running;
    }
    final f = () async {
      try {
        do {
          _diskLoadAgain = false;
          await _loadFromDiskOnce();
        } while (_diskLoadAgain);
      } finally {
        _diskLoadInFlight = null;
      }
    }();
    _diskLoadInFlight = f;
    return f;
  }

  /// SQLite'tan RAM'e yükler (tipli modellere çevirir).
  /// 🔥 Bir tablo OKUNAMAZSA RAM'deki mevcut liste KORUNUR (eskiden boş liste
  /// atanıyordu -> gruplar/ilişkiler bir anda "Grup Yok"a düşüyordu).
  /// Tüm tablolar okunduktan sonra TEK SEFERDE atanır (yarım durum görünmez).
  Future<void> _loadFromDiskOnce() async {
    final users = await _load('users', (m) => Users.fromJson(m));
    final groups = await _load('groups', (m) => Group.fromJson(m));
    final groupStudents = await _load(
      'group_students',
      (m) => GroupStudent.fromJson(m),
    );
    final payments = await _load('payments', (m) => Payment.fromJson(m));
    final attendances = await _load(
      'attendances',
      (m) => Attendance.fromJson(m),
    );
    final branches = await _load('branches', (m) => Branches.fromJson(m));
    final sports = await _load('sports', (m) => Sports.fromJson(m));
    final coaches = await _load('coaches', (m) => Coach.fromJson(m));
    final notifications = await _load(
      'notifications',
      (m) => Notifications.fromJson(m),
    );

    // 🔎 Teşhis: grup verisi küçülürse konsolda görünsün
    _logShrink('users', allUsers.length, users?.length);
    _logShrink('groups', allGroups.length, groups?.length);
    _logShrink(
      'group_students',
      allGroupStudents.length,
      groupStudents?.length,
    );

    // 🔥 Eskiyi göster, yenisi gelince değiştir: BOŞ okuma, dolu RAM'in yerine
    //   geçmez. (Veri gerçekten silinecekse hardResetLocal RAM'i kendisi boşaltır.)
    if (_accept(users, allUsers, 'users')) allUsers = users!;
    if (_accept(groups, allGroups, 'groups')) allGroups = groups!;
    if (_accept(groupStudents, allGroupStudents, 'group_students')) {
      allGroupStudents = _dedupeGroupStudents(groupStudents!);
    }
    if (_accept(payments, allPayments, 'payments')) allPayments = payments!;
    if (_accept(attendances, allAttendances, 'attendances')) {
      allAttendances = attendances!;
    }
    if (_accept(branches, allBranches, 'branches')) allBranches = branches!;
    if (_accept(sports, allSports, 'sports')) allSports = sports!;
    if (_accept(coaches, allCoaches, 'coaches')) allCoaches = coaches!;
    if (_accept(notifications, allNotifications, 'notifications')) {
      allNotifications = notifications!;
    }
    _buildMaps();
  }

  /// Yeni okunan liste kabul edilsin mi?
  ///  • null (okuma başarısız)            -> hayır, eski RAM kalsın
  ///  • boş ama RAM'de veri var           -> hayır, eski RAM kalsın
  bool _accept<T>(List<T>? fresh, List<T> current, String name) {
    if (fresh == null) return false;
    if (fresh.isEmpty && current.isNotEmpty) {
      // ignore: avoid_print
      print(
        "🛡️ RAM $name: boş okuma yok sayıldı, eski veri korunuyor "
        "(${current.length} kayıt).",
      );
      return false;
    }
    return true;
  }

  void _logShrink(String name, int oldLen, int? newLen) {
    if (newLen == null) return;
    if (oldLen > 0 && newLen < oldLen) {
      // ignore: avoid_print
      print("📉 RAM $name: $oldLen -> $newLen (azaldı)");
    }
  }

  /// Bir tabloyu güvenle okur.
  ///  • Tek bir bozuk satır tüm tabloyu düşürmez (sadece o satır atlanır).
  ///  • Tablo okuması tamamen başarısız olursa null döner (RAM korunur).
  Future<List<T>?> _load<T>(
    String table,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final rows = await LocalDb.I.query(table);
      final out = <T>[];
      var bad = 0;
      for (final r in rows) {
        try {
          out.add(fromJson(r));
        } catch (e) {
          bad++;
          // ignore: avoid_print
          print("⚠️ $table: bozuk satır atlandı ($e)");
        }
      }
      if (bad > 0) {
        // ignore: avoid_print
        print("⚠️ $table: $bad satır parse edilemedi, kalanlar yüklendi.");
      }
      return out;
    } catch (e) {
      // ignore: avoid_print
      print("❌ $table okunamadı, RAM'deki mevcut liste korundu: $e");
      return null;
    }
  }

  bool _isAllEmpty() =>
      allUsers.isEmpty &&
      allGroups.isEmpty &&
      allPayments.isEmpty &&
      allAttendances.isEmpty &&
      allCoaches.isEmpty &&
      allBranches.isEmpty &&
      allSports.isEmpty &&
      allNotifications.isEmpty &&
      allGroupStudents.isEmpty;

  void _buildMaps() {
    _usersById = {for (final u in allUsers) u.app: u};
    _groupsById = {for (final g in allGroups) g.groups_id: g};
    _branchesById = {for (final b in allBranches) b.branches_id: b};
    _sportsById = {for (final s in allSports) s.sports_id: s};
    _notificationsById = {
      for (final n in allNotifications) n.notifications_id: n,
    };

    _groupStudentsByGroupId = {};
    _groupStudentsByStudentId = {};
    for (final gs in allGroupStudents) {
      (_groupStudentsByGroupId[gs.groups_id] ??= []).add(gs);
      (_groupStudentsByStudentId[gs.student_id] ??= []).add(gs);
    }

    _paymentsByStudentId = {};
    for (final p in allPayments) {
      (_paymentsByStudentId[p.student_id] ??= []).add(p);
    }

    _attendancesByStudentId = {};
    _attendancesByGroupId = {};
    for (final a in allAttendances) {
      (_attendancesByStudentId[a.student_id] ??= []).add(a);
      (_attendancesByGroupId[a.groups_id] ??= []).add(a);
    }
  }

  String _getTodayNameTurkish() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[DateTime.now().weekday - 1];
  }

  String _extractStartTime(Group group, String dayName) {
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(group.schedule);
    return match?.group(1) ?? "23:59";
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }

  void _setError(String message) {
    _hasError = true;
    _lastErrorMessage = message;
    _operationLogs.add(message);
    _errorController.add(true);
    _opLogsController.add(true);
  }

  void _clearError() {
    if (_hasError) {
      _hasError = false;
      _lastErrorMessage = null;
      _errorController.add(false);
    }
  }
}

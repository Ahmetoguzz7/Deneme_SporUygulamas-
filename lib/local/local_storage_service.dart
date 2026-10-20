// lib/core/local_storage_service.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late Box _dataBox;
  bool _isInitialized = false;

  // Veri son güncelleme zamanı
  DateTime? _lastUpdateTime;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  Future<void> init() async {
    if (_isInitialized) return;

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Kayıtlı kutuları aç
    _dataBox = await Hive.openBox('app_data');
    _isInitialized = true;

    print("📦 LocalStorageService başlatıldı");
  }

  // ============================================================
  // 📥 VERİ KAYDETME
  // ============================================================

  Future<void> saveUsers(List<Users> users) async {
    await _dataBox.put('users', users.map((u) => u.toJson()).toList());
    _updateLastUpdateTime();
    print("💾 ${users.length} kullanıcı kaydedildi");
  }

  Future<void> saveGroups(List<Group> groups) async {
    await _dataBox.put('groups', groups.map((g) => g.toJson()).toList());
    _updateLastUpdateTime();
    print("💾 ${groups.length} grup kaydedildi");
  }

  Future<void> saveGroupStudents(List<GroupStudent> relations) async {
    await _dataBox.put(
      'groupStudents',
      relations.map((r) => r.toJson()).toList(),
    );
    _updateLastUpdateTime();
    print("💾 ${relations.length} ilişki kaydedildi");
  }

  Future<void> savePayments(List<Payment> payments) async {
    final jsonList = await _toJsonInChunks(payments, (p) => p.toJson());
    await _dataBox.put('payments', jsonList);
    _updateLastUpdateTime();
    print("💾 ${payments.length} ödeme kaydedildi (parçalı)");
  }

  Future<void> saveAttendances(List<Attendance> attendances) async {
    final jsonList = await _toJsonInChunks(attendances, (a) => a.toJson());
    await _dataBox.put('attendances', jsonList);
    _updateLastUpdateTime();
    print("💾 ${attendances.length} yoklama kaydedildi (parçalı)");
  }

  Future<List<Map<String, dynamic>>> _toJsonInChunks<T>(
    List<T> items,
    Map<String, dynamic> Function(T) toJson, {
    int chunkSize = 500,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      for (var j = i; j < end; j++) {
        result.add(toJson(items[j]));
      }
      await Future.delayed(Duration.zero); // event loop'a sıra → UI donmaz
    }
    return result;
  }

  Future<void> saveCoaches(List<Coach> coaches) async {
    await _dataBox.put('coaches', coaches.map((c) => c.toJson()).toList());
    _updateLastUpdateTime();
    print("💾 ${coaches.length} koç kaydedildi");
  }

  Future<void> saveNotifications(List<Notifications> notifications) async {
    await _dataBox.put(
      'notifications',
      notifications.map((n) => n.toJson()).toList(),
    );
    _updateLastUpdateTime();
    print("💾 ${notifications.length} bildirim kaydedildi");
  }

  Future<void> saveAllData({
    required List<Users> users,
    required List<Group> groups,
    required List<GroupStudent> groupStudents,
    required List<Payment> payments,
    required List<Attendance> attendances,
    required List<Coach> coaches,
    required List<Notifications> notifications,
  }) async {
    await saveUsers(users);
    await saveGroups(groups);
    await saveGroupStudents(groupStudents);
    await savePayments(payments); // artık parçalı
    await saveAttendances(attendances); // artık parçalı
    await saveCoaches(coaches);
    await saveNotifications(notifications);

    await _dataBox.put('last_full_update', DateTime.now().toIso8601String());
    print("💾 Tüm veriler başarıyla kaydedildi!");
  }
  // ============================================================
  // 📤 VERİ OKUMA
  // ============================================================

  List<Users> getUsers() {
    final data = _dataBox.get('users');
    if (data == null) return [];
    return (data as List).map((json) => Users.fromJson(json)).toList();
  }

  List<Group> getGroups() {
    final data = _dataBox.get('groups');
    if (data == null) return [];
    return (data as List).map((json) => Group.fromJson(json)).toList();
  }

  List<GroupStudent> getGroupStudents() {
    final data = _dataBox.get('groupStudents');
    if (data == null) return [];
    return (data as List).map((json) => GroupStudent.fromJson(json)).toList();
  }

  List<Payment> getPayments() {
    final data = _dataBox.get('payments');
    if (data == null) return [];
    return (data as List).map((json) => Payment.fromJson(json)).toList();
  }

  List<Attendance> getAttendances() {
    final data = _dataBox.get('attendances');
    if (data == null) return [];
    return (data as List).map((json) => Attendance.fromJson(json)).toList();
  }

  List<Coach> getCoaches() {
    final data = _dataBox.get('coaches');
    if (data == null) return [];
    return (data as List).map((json) => Coach.fromJson(json)).toList();
  }

  List<Notifications> getNotifications() {
    final data = _dataBox.get('notifications');
    if (data == null) return [];
    return (data as List).map((json) => Notifications.fromJson(json)).toList();
  }

  bool hasCachedData() {
    return _dataBox.containsKey('users') &&
        _dataBox.containsKey('groups') &&
        _dataBox.get('users', defaultValue: []).isNotEmpty;
  }

  DateTime? getLastFullUpdate() {
    final dateStr = _dataBox.get('last_full_update');
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  void _updateLastUpdateTime() {
    _lastUpdateTime = DateTime.now();
  }

  // ============================================================
  // 🔄 CACHE YÖNETİMİ
  // ============================================================

  Future<void> clearTable(String tableName) async {
    await _dataBox.delete(tableName);
    print("🗑️ $tableName tablosu temizlendi");
  }

  bool isCacheValid({Duration maxAge = const Duration(hours: 24)}) {
    final lastUpdate = getLastFullUpdate();
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate) < maxAge;
  }
  // lib/core/local_storage_service.dart
  // MEVCUT KODUNUN EN ALTINA BUNLARI EKLE

  // ============================================================
  // 🔥 OFFLINE SYNC İÇİN EKLENEN METODLAR
  // ============================================================

  Future<DateTime?> getLastSyncTime() async {
    final dateStr = _dataBox.get('last_sync_time');
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _dataBox.put('last_sync_time', time.toIso8601String());
  }

  Future<Map<String, dynamic>> getAllData() async {
    return {
      'users': getUsers(),
      'groups': getGroups(),
      'groupStudents': getGroupStudents(),
      'payments': getPayments(),
      'attendances': getAttendances(),
      'coaches': getCoaches(),
      'notifications': getNotifications(),
    };
  }

  bool hasAnyData() {
    return getUsers().isNotEmpty || getGroups().isNotEmpty;
  }
  // local_storage_service.dart - EN ALTA EKLE

  // ============================================================
  // 🔥 OFFLINE SYNC İÇİN GENEL METODLAR
  // ============================================================
  // local_storage_service.dart - Yanlış olanı sil, bunu ekle

  // ============================================================
  // 🔥 GENEL VERİ OKUMA/YAZMA (Hive kullanarak)
  // ============================================================

  Future<void> saveData(String key, dynamic value) async {
    try {
      await _dataBox.put(key, value);
      print("💾 Veri kaydedildi: $key");
    } catch (e) {
      print("❌ saveData hatası ($key): $e");
    }
  }

  dynamic getData(String key) {
    try {
      return _dataBox.get(key);
    } catch (e) {
      print("❌ getData hatası ($key): $e");
      return null;
    }
  }

  Future<void> removeData(String key) async {
    try {
      await _dataBox.delete(key);
      print("🗑️ Veri silindi: $key");
    } catch (e) {
      print("❌ removeData hatası ($key): $e");
    }
  }

  bool containsKey(String key) {
    try {
      return _dataBox.containsKey(key);
    } catch (e) {
      return false;
    }
  }
}

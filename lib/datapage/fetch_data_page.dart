import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

// =========================================================================
// 🔥 CACHE MEKANİZMASI (RAM + DISK - KALICI)
// =========================================================================

class _CacheItem {
  final dynamic data;
  final DateTime expiry;
  _CacheItem({required this.data, required this.expiry});
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class DataCache {
  static final DataCache _instance = DataCache._internal();
  factory DataCache() => _instance;
  DataCache._internal();

  final Map<String, _CacheItem> _cache = {};
  final Map<String, Future> _pendingFetches = {};

  static const int CACHE_LONG = 3600;
  static const int CACHE_MEDIUM = 300;
  static const int CACHE_SHORT = 60;
  static const int CACHE_VERY_SHORT = 30;

  Future<void> persistToDisk(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$key', jsonEncode(data));
      await prefs.setString(
        'cache_${key}_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Disk yazma hatası
    }
  }

  Future<dynamic> loadFromDisk(
    String key, {
    int ttlSeconds = CACHE_MEDIUM,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString('cache_${key}_time');
      if (timeStr == null) return null;

      final savedTime = DateTime.parse(timeStr);
      if (DateTime.now().difference(savedTime).inSeconds > ttlSeconds) {
        return null;
      }

      final raw = prefs.getString('cache_$key');
      if (raw == null) return null;

      return jsonDecode(raw);
    } catch (e) {
      return null;
    }
  }

  Future<void> removeFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
      await prefs.remove('cache_${key}_time');
    } catch (e) {
      // Disk silme hatası
    }
  }

  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    int ttlSeconds = CACHE_MEDIUM,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _cache.remove(key);
      await removeFromDisk(key);
    }

    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }

    final diskData = await loadFromDisk(key, ttlSeconds: ttlSeconds);
    if (diskData != null) {
      _cache[key] = _CacheItem(
        data: diskData,
        expiry: DateTime.now().add(Duration(seconds: ttlSeconds)),
      );
      return diskData as T;
    }

    if (_pendingFetches.containsKey(key)) {
      return _pendingFetches[key] as Future<T>;
    }

    final future = fetcher()
        .then((value) async {
          _cache[key] = _CacheItem(
            data: value,
            expiry: DateTime.now().add(Duration(seconds: ttlSeconds)),
          );
          persistToDisk(key, value);
          _pendingFetches.remove(key);
          return value;
        })
        .catchError((e) {
          _pendingFetches.remove(key);
          throw e;
        });

    _pendingFetches[key] = future;
    return future;
  }

  void invalidate(String key) {
    _cache.remove(key);
    removeFromDisk(key);
  }

  void invalidateAll() {
    _cache.clear();
    _clearAllDiskCache();
  }

  void invalidateTable(String tableName) {
    invalidate('table_$tableName');
  }

  void invalidateExpired() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    _cache.forEach((key, item) {
      if (item.isExpired) keysToRemove.add(key);
    });
    for (var key in keysToRemove) {
      _cache.remove(key);
    }
  }

  Future<void> _clearAllDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith('cache_'))
          .toList();
      for (var key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Disk cache temizleme hatası
    }
  }
}

class GoogleSheetService {
  static final DataCache _cache = DataCache();

  static const String _baseUrl =
      "https://script.google.com/macros/s/AKfycbxfckQuoK2uuc7C2ZI9HFwy6zJ6d06ucQPKBD8MoLXljM0GLFQSStco0wTP1aClfPWkDw/exec";

  // =========================================================================
  // 🔥 MERKEZİ POST FONKSİYONU
  // =========================================================================
  /*static Future<http.Response?> _postRequest(
    Map<String, dynamic> bodyData,
  ) async {
    print("🌐 _postRequest gönderiliyor:");
    print("   URL: $_baseUrl");
    print("   Body: ${jsonEncode(bodyData)}");

    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      print("🌐 _postRequest yanıtı:");
      print("   Status: ${response.statusCode}");
      print(
        "   Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}",
      );

      if (response.statusCode == 302) {
        String? redirectUrl = response.headers['location'];
        if (redirectUrl == null && response.body.contains('HREF="')) {
          final start = response.body.indexOf('HREF="') + 6;
          final end = response.body.indexOf('"', start);
          redirectUrl = response.body
              .substring(start, end)
              .replaceAll('&amp;', '&');
        }
        if (redirectUrl != null) {
          print("🌐 Redirect: $redirectUrl");
          response = await http.get(Uri.parse(redirectUrl));
          print("🌐 Redirect yanıtı: ${response.statusCode}");
        }
      }

      return response;
    } catch (e) {
      print("❌ _postRequest hatası: $e");
      return null;
    }
  }
*/
  static Future<http.Response?> _postRequest(Map<String, dynamic> body) async {
    try {
      var url = Uri.parse(
        "https://script.google.com/macros/s/AKfycbxfckQuoK2uuc7C2ZI9HFwy6zJ6d06ucQPKBD8MoLXljM0GLFQSStco0wTP1aClfPWkDw/exec",
      );

      print("🌐 _postRequest gönderiliyor:");
      print("   URL: $url");
      print("   Body: ${jsonEncode(body)}");

      // Otomatik redirect'i kapatıp kontrolü ele alıyoruz
      var request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body)
        ..followRedirects = false; // ❌ Otomatik yönlendirmeyi durdur

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("🌐 _postRequest ilk yanıtı: Status ${response.statusCode}");

      // Eğer Apps Script 302 yönlendirmesi attıysa (Normal bir durumdur)
      if (response.statusCode == 302 || response.statusCode == 301) {
        String? redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          print("🌐 Redirect adresi alındı: $redirectUrl");

          // Google Macroları yönlendirmeden sonra veriyi GET ile okutur
          final redirectResponse = await http.get(Uri.parse(redirectUrl));
          print(
            "🌐 Redirect nihai yanıtı: Status ${redirectResponse.statusCode}",
          );
          return redirectResponse;
        }
      }

      return response;
    } catch (e) {
      print("❌ _postRequest Hatası: $e");
      return null;
    }
  }
  // =========================================================================
  // ✅ CACHE'Lİ FETCH TABLE
  // =========================================================================

  static Future<List<dynamic>> fetchTableCached(
    String sheetName, {
    bool forceRefresh = false,
    int? ttlSeconds,
  }) async {
    int ttl;
    switch (sheetName) {
      case 'branches':
      case 'sports':
        ttl = DataCache.CACHE_LONG;
        break;
      case 'groups':
      case 'users':
      case 'coaches':
      case 'group_students':
        ttl = DataCache.CACHE_MEDIUM;
        break;
      case 'attendances':
      case 'payments':
        ttl = DataCache.CACHE_SHORT;
        break;
      case 'notifications':
        ttl = DataCache.CACHE_VERY_SHORT;
        break;
      default:
        ttl = DataCache.CACHE_MEDIUM;
    }

    if (ttlSeconds != null) ttl = ttlSeconds;

    return _cache.getOrFetch(
      'table_$sheetName',
      () => fetchTable(sheetName),
      ttlSeconds: ttl,
      forceRefresh: forceRefresh,
    );
  }

  // =========================================================================
  // ✅ TEMEL OKUMA FONKSİYONU
  // =========================================================================
  static Future<List<dynamic>> fetchTable(String sheetName) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl?sheet=$sheetName"));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map && decoded.containsKey('success')) {
          if (decoded['success'] == true && decoded['data'] is List) {
            return decoded['data'] as List<dynamic>;
          } else {
            return [];
          }
        } else if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // =========================================================================
  // ✅ CACHE YÖNETİM METODLARI
  // =========================================================================

  static void invalidateCache(String tableName) {
    _cache.invalidateTable(tableName);
  }

  static void invalidateAllCache() {
    _cache.invalidateAll();
  }

  static void invalidateExpiredCache() {
    _cache.invalidateExpired();
  }

  // =========================================================================
  // ✅ CACHE'Lİ GET METODLARI
  // =========================================================================

  static Future<List<Users>> getUsersCached({bool forceRefresh = false}) async {
    final rawData = await fetchTableCached('users', forceRefresh: forceRefresh);
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Group>> getGroupsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'groups',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Group.fromJson(item)).toList();
  }

  static Future<List<GroupStudent>> getGroupStudentsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'group_students',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => GroupStudent.fromJson(item)).toList();
  }

  static Future<List<Payment>> getPaymentsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'payments',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Payment.fromJson(item)).toList();
  }

  static Future<List<Attendance>> getAttendancesCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'attendances',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Attendance.fromJson(item)).toList();
  }

  static Future<List<Branches>> getBranchesCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'branches',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Branches.fromJson(item)).toList();
  }

  static Future<List<Sports>> getSportsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'sports',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Sports.fromJson(item)).toList();
  }

  static Future<List<Coach>> getCoachesCached({
    bool forceRefresh = false,
  }) async {
    try {
      final rawData = await fetchTableCached(
        'coaches',
        forceRefresh: forceRefresh,
      );

      if (rawData.isEmpty) {
        return [];
      }

      final List<Coach> coaches = [];
      for (var item in rawData) {
        try {
          if (item is Map<String, dynamic>) {
            coaches.add(Coach.fromJson(item));
          }
        } catch (e) {
          // Dönüşüm hatası
        }
      }
      return coaches;
    } catch (e) {
      return [];
    }
  }

  static Future<List<Users>> getStudentsOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'student').toList();
  }

  static Future<List<Users>> getCoachesOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();
  }

  static Future<List<Users>> getParentsOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();
  }

  // =========================================================================
  // ✅ ORİJİNAL GET METODLARI (CACHE'SİZ)
  // =========================================================================

  static Future<List<Users>> getUsers() async {
    final rawData = await fetchTable("users");
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Group>> getGroups() async {
    final rawData = await fetchTable("groups");
    return rawData.map((item) => Group.fromJson(item)).toList();
  }

  static Future<List<GroupStudent>> getGroupStudents() async {
    final rawData = await fetchTable("group_students");
    return rawData.map((item) => GroupStudent.fromJson(item)).toList();
  }

  static Future<List<Payment>> getPayments() async {
    final rawData = await fetchTable("payments");
    return rawData.map((item) => Payment.fromJson(item)).toList();
  }

  static Future<List<Attendance>> getAttendances() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?sheet=attendances'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          final List<Attendance> attendances = data.map((item) {
            String statusValue = item['status']?.toString() ?? "FALSE";
            bool isTrue = statusValue.toUpperCase() == "TRUE";

            return Attendance(
              attendances_id: item['attendances_id']?.toString() ?? '',
              groups_id: item['groups_id']?.toString() ?? '',
              student_id: item['student_id']?.toString() ?? '',
              taken_by: item['taken_by']?.toString() ?? '',
              attendance_date: item['attendance_date']?.toString() ?? '',
              status: isTrue ? "TRUE" : "FALSE",
              note: item['note']?.toString() ?? '',
              updated_at: item['updated_at']?.toString() ?? '',
            );
          }).toList();

          return attendances;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Branches>> getBranches() async {
    final rawData = await fetchTable("branches");
    return rawData.map((item) => Branches.fromJson(item)).toList();
  }

  static Future<List<Sports>> getSports() async {
    final rawData = await fetchTable("sports");
    return rawData.map((item) => Sports.fromJson(item)).toList();
  }

  static Future<List<Coach>> getCoaches() async {
    final rawData = await fetchTable("coaches");

    final coaches = <Coach>[];
    for (var item in rawData) {
      final Map<String, dynamic> cleanItem = {};
      item.forEach((key, value) {
        String cleanKey = key.toString().trim();
        cleanItem[cleanKey] = value;
      });

      final coach = Coach.fromJson(cleanItem);
      if (coach.coach_id.isNotEmpty) {
        coaches.add(coach);
      }
    }

    return coaches;
  }

  static Future<List<Users>> getStudents() async {
    final rawData = await fetchTable("users");
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Users>> getStudentsForCoach(String coachBranchId) async {
    final allStudents = await getStudents();
    return allStudents.where((s) => s.branches_id == coachBranchId).toList();
  }

  static Future<List<Users>> getStudentsOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'student').toList();
  }

  static Future<List<Users>> getParentsOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();
  }

  static Future<List<Users>> getCoachesOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();
  }

  // =========================================================================
  // ✅ BİLDİRİM İŞLEMLERİ
  // =========================================================================

  static Future<List<Notifications>> getNotifications({
    required String userId,
    required bool forceRefresh,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?sheet=notifications'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          final List<Notifications> notifications = data.map((item) {
            return Notifications(
              notifications_id: item['notifications_id']?.toString() ?? '',
              sender_id: item['sender_id']?.toString() ?? '',
              recipient_id: item['recipient_id']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              message: item['message']?.toString() ?? '',
              type: item['type']?.toString() ?? 'announcement',
              is_read: item['is_read']?.toString() ?? 'FALSE',
              sent_at: item['sent_at']?.toString() ?? '',
              groups_id: item['groups_id']?.toString() ?? '',
            );
          }).toList();

          return notifications;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNotificationsForUser(
    String userId,
  ) async {
    try {
      // 1. Bildirimler tablosunu RAM veya Disk Cache'den getiriyoruz
      final rawData = await fetchTableCached(
        'notifications',
        forceRefresh: false,
      );
      if (rawData.isEmpty) return [];

      final String currentUserIdStr = userId.toString().trim();

      // 2. RAM Cache'den diğer ilişkili tabloları çekiyoruz
      final allGroupStudents = await getGroupStudentsCached();
      final allGroups = await getGroupsCached();
      final allUsers = await getUsersCached();
      final allCoaches = await getCoachesCached();

      // Kullanıcının sistemdeki rolünü bulalım
      String userRole = '';
      for (var user in allUsers) {
        if (user.app.toString().trim() == currentUserIdStr) {
          userRole = user.role.toLowerCase().trim();
          break;
        }
      }

      final bool isStudent = (userRole == 'student' || userRole == 'öğrenci');
      final bool isCoach = (userRole == 'coach' || userRole == 'antrenör');
      final bool isAdmin = (userRole == 'admin' || userRole == 'manager');

      // Kullanıcının (Öğrenci veya Hocanın) dahil olduğu/yönettiği GRUP ID'leri
      final Set<String> userGroupIds = {};

      print("📊 Kullanıcı Bilgisi - ID: $currentUserIdStr, Rol: $userRole");

      if (isStudent) {
        // Öğrenci ise: Aktif olduğu grupları Set'e ekle
        for (var gs in allGroupStudents) {
          if (gs.student_id.toString().trim() == currentUserIdStr &&
              gs.is_active.toUpperCase() == "TRUE") {
            userGroupIds.add(gs.groups_id.toString().trim());
          }
        }
        print("📚 Öğrenci grupları: $userGroupIds");
      } else if (isCoach) {
        // Antrenör ise: Önce coaches tablosundaki coach_id karşılığını bulalım
        String myCoachId = currentUserIdStr;
        try {
          final myCoachMeta = allCoaches.firstWhere(
            (c) => c.user_id.toString().trim() == currentUserIdStr,
          );
          myCoachId = myCoachMeta.coach_id.toString().trim();
        } catch (_) {
          print(
            "⚠️ Coach kaydı bulunamadı, user_id kullanılıyor: $currentUserIdStr",
          );
        }

        // Hoca bu gruplardan birinin başındaysa, o grubun ID'sini listesine ekle
        for (var group in allGroups) {
          final gCoach = group.coach_id.toString().trim();
          if (gCoach == currentUserIdStr || gCoach == myCoachId) {
            userGroupIds.add(group.groups_id.toString().trim());
          }
        }
        print("📚 Antrenör grupları: $userGroupIds");
      } else if (isAdmin) {
        // Admin tüm grupları görebilir
        for (var group in allGroups) {
          userGroupIds.add(group.groups_id.toString().trim());
        }
        print("👑 Admin - Tüm gruplar: ${userGroupIds.length} grup");
      }

      // 3. Bildirimleri süzme aşaması (DETAYLI LOGLAMA İLE)
      List<Map<String, dynamic>> filteredNotifications = [];

      print("📬 Toplam bildirim sayısı: ${rawData.length}");

      for (var item in rawData) {
        final String rId = item['recipient_id']?.toString().trim() ?? '';
        final String gId = item['groups_id']?.toString().trim() ?? '';
        final String sId = item['sender_id']?.toString().trim() ?? '';
        final String title = item['title']?.toString() ?? '';

        bool isTarget = false;
        String reason = "";

        // 🎯 SENARYO 1: GENEL DUYURU (all)
        if (rId.toLowerCase() == 'all' || rId.toLowerCase() == 'tümü') {
          isTarget = true;
          reason = "GENEL DUYURU (all)";
        }
        // 🎯 SENARYO 2: KİŞİYE ÖZEL BİREYSEL DUYURU
        else if (rId == currentUserIdStr) {
          isTarget = true;
          reason = "KİŞİYE ÖZEL (recipient_id eşleşmesi)";
        }
        // 🎯 SENARYO 3: GRUBA ÖZEL DUYURU (groups_id dolu ve kullanıcının grubuyla eşleşiyor)
        else if (gId.isNotEmpty && gId != 'null' && gId != '0') {
          if (userGroupIds.contains(gId)) {
            isTarget = true;
            reason = "GRUBA ÖZEL (groups_id: $gId, kullanıcının grubu)";
          } else {
            reason =
                "GRUBA ÖZEL ama kullanıcının grubu değil (gId: $gId, userGroups: $userGroupIds)";
          }
        }
        // 🎯 SENARYO 4: recipient_id "group" olarak gelmiş (manager panelinden grup seçilerek atılmış)
        else if (rId.toLowerCase() == 'group') {
          if (gId.isNotEmpty &&
              gId != 'null' &&
              gId != '0' &&
              userGroupIds.contains(gId)) {
            isTarget = true;
            reason = "GRUBA ÖZEL (recipient=group, groups_id: $gId)";
          } else {
            reason =
                "GRUBA ÖZEL ama groups_id geçersiz veya kullanıcının grubu değil";
          }
        }

        // Detaylı log (sadece debug için, isteğe bağlı kaldırabilirsin)
        if (isTarget) {
          print("   ✅ [${reason}] $title");
        }

        if (isTarget) {
          filteredNotifications.add(Map<String, dynamic>.from(item));
        }
      }

      // 4. Tarihe göre yeniden eskiye sıralama
      filteredNotifications.sort((a, b) {
        DateTime dateA = _parseDateTime(a['sent_at']?.toString() ?? '');
        DateTime dateB = _parseDateTime(b['sent_at']?.toString() ?? '');
        return dateB.compareTo(dateA);
      });

      print("📬 Filtrelenmiş bildirim sayısı: ${filteredNotifications.length}");

      return filteredNotifications;
    } catch (e, stackTrace) {
      print("❌ getNotificationsForUser Filtreleme Hatası: $e");
      print(stackTrace);
      return [];
    }
  }

  // 🔥 YARDIMCI FONKSİYON: Kullanıcının gruplarını bul
  static Future<List<String>> _getUserGroups(String userId) async {
    List<String> groups = [];

    try {
      final allGroupStudents = await getGroupStudentsCached();
      final allGroups = await getGroupsCached();
      final allUsers = await getUsersCached();

      // Kullanıcının rolünü bul
      String role = '';
      for (var user in allUsers) {
        if (user.app.toString() == userId) {
          role = user.role.toLowerCase();
          break;
        }
      }

      final isStudent = (role == 'student' || role == 'öğrenci');
      final isCoach = (role == 'coach' || role == 'antrenör');

      if (isStudent) {
        // ÖĞRENCİ: Bağlı olduğu gruplar
        for (var gs in allGroupStudents) {
          if (gs.student_id == userId && gs.is_active.toUpperCase() == "TRUE") {
            groups.add(gs.groups_id);
          }
        }
      } else if (isCoach) {
        // ANTRENÖR: Yönettiği gruplar
        for (var group in allGroups) {
          if (group.coach_id == userId) {
            groups.add(group.groups_id);
          }
        }
      }

      print("📚 Kullanıcı $userId için gruplar: $groups");
    } catch (e) {
      print("❌ _getUserGroups hatası: $e");
    }

    return groups;
  }

  // 🔥 YARDIMCI FONKSİYONLAR (GoogleSheetService içine ekle)

  static Future<Map<String, dynamic>> _getUserRoleAndGroups(
    String userId,
  ) async {
    try {
      final allUsers = await getUsersCached();
      final allGroupStudents = await getGroupStudentsCached();
      final allGroups = await getGroupsCached();

      String role = '';
      bool isStudent = false;
      bool isCoach = false;
      List<String> groupIds = [];

      // Kullanıcı rolünü bul
      for (var user in allUsers) {
        if (user.app.toString() == userId) {
          role = user.role.toLowerCase();
          isStudent = (role == 'student' || role == 'öğrenci');
          isCoach = (role == 'coach' || role == 'antrenör');
          break;
        }
      }

      // Öğrenciyse gruplarını bul
      if (isStudent) {
        for (var gs in allGroupStudents) {
          if (gs.student_id == userId && gs.is_active.toUpperCase() == "TRUE") {
            groupIds.add(gs.groups_id);
          }
        }
      }

      // Antrenörse gruplarını bul
      if (isCoach) {
        for (var group in allGroups) {
          if (group.coach_id == userId) {
            groupIds.add(group.groups_id);
          }
        }
      }

      return {
        'role': role,
        'isStudent': isStudent,
        'isCoach': isCoach,
        'groupIds': groupIds,
      };
    } catch (e) {
      print("_getUserRoleAndGroups hatası: $e");
      return {'role': '', 'isStudent': false, 'isCoach': false, 'groupIds': []};
    }
  }

  static Future<String> _getGroupCoach(String groupId) async {
    try {
      final allGroups = await getGroupsCached();
      for (var group in allGroups) {
        if (group.groups_id == groupId) {
          return group.coach_id;
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // Mevcut _parseDateTime fonksiyonunu kullan (zaten var)

  static Future<void> markNotificationAsRead(
    String notificationId,
    String userId,
  ) async {
    try {
      final response = await _postRequest({
        "action": "updateNotification",
        "notifications_id": notificationId,
        "is_read": "TRUE",
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          invalidateCache('notifications');
        }
      }
    } catch (e) {
      // Hata
    }
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final notifications = await getNotificationsForUser(userId);
    final unreadCount = notifications.where((n) {
      String isRead = n['is_read']?.toString().toUpperCase() ?? '';
      return isRead != 'TRUE';
    }).length;
    return unreadCount;
  }

  static Future<bool> addNotification(
    Map<String, dynamic> notificationData,
  ) async {
    if (notificationData['groups_id'] != null) {
      notificationData['groups_id'] = notificationData['groups_id'].toString();
    }

    final response = await _postRequest({
      "action": "insert",
      "table": "notifications",
      "data": notificationData,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          invalidateCache('notifications');
        }
        return success;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  static DateTime _parseDateTime(String dateTimeStr) {
    try {
      if (dateTimeStr.contains('T')) {
        return DateTime.parse(dateTimeStr);
      } else if (dateTimeStr.contains(' ')) {
        return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
      }
      return DateTime(2000);
    } catch (e) {
      return DateTime(2000);
    }
  }

  // =========================================================================
  // ✅ SMS İLE KOD GÖNDERME
  // =========================================================================

  static Future<bool> send2FACode(String phoneNumber, String code) async {
    try {
      final response = await _postRequest({
        "action": "send2FACode",
        "phone": phoneNumber,
        "code": code,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateLastLogin(String userId) async {
    try {
      final response = await _postRequest({
        "action": "updateLastLogin",
        "user_id": userId,
        "last_login": DateTime.now().toIso8601String(),
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          invalidateCache('users');
        }
      }
    } catch (e) {
      // Hata
    }
  }

  // =========================================================================
  // ✅ KULLANICI İŞLEMLERİ
  // =========================================================================

  static Future<Users?> login(String email, String password) async {
    // 🔥 Şifreyi SHA256 ile hash'le
    final hashedPassword = _hashPassword(password);

    final response = await _postRequest({
      "action": "login",
      "email": email,
      "password": hashedPassword, // Hash'lenmiş şifre gönder
    });

    if (response != null && response.statusCode == 200) {
      try {
        final decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          Map<String, dynamic>? userMap;

          if (decoded['data'] != null && decoded['data']['user'] != null) {
            userMap = Map<String, dynamic>.from(decoded['data']['user']);
          } else if (decoded['user'] != null) {
            userMap = Map<String, dynamic>.from(decoded['user']);
          }

          if (userMap != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('logged_user', jsonEncode(userMap));
            return Users.fromJson(userMap);
          }
        }
      } catch (e) {
        print("Login catch hatası: $e");
        return null;
      }
    }
    return null;
  }

  // 🔥 Hash fonksiyonunu da ekle (class içine)
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<Users?> loginRequest(String email, String password) async {
    return await login(email, password);
  }

  static Future<bool> registerUser(Users newUser) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "users",
      "data": newUser.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    final response = await _postRequest({"action": "updateUser", "data": data});

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  static Future<Users?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('logged_user');

    if (userJson != null) {
      final Map<String, dynamic> userMap = json.decode(userJson);
      return Users.fromJson(userMap);
    }

    return null;
  }

  static Future<bool> deactivateUser(String userId) async {
    final response = await _postRequest({
      "action": "deactivateUser",
      "user_id": userId,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ BRANCH İŞLEMLERİ
  // =========================================================================

  static Future<Branches?> getBranchById(String branchId) async {
    final allBranches = await getBranchesCached();
    try {
      return allBranches.firstWhere((b) => b.branches_id == branchId);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // ✅ SPORTS İŞLEMLERİ
  // =========================================================================

  static Future<Sports?> getSportById(String sportId) async {
    final allSports = await getSportsCached();
    try {
      return allSports.firstWhere((s) => s.sports_id == sportId);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // ✅ GRUP İŞLEMLERİ (CACHE'Lİ)
  // =========================================================================

  static Future<List<Group>> getGroupsByCoachCached(
    String coachId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByBranchCached(
    String branchId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.branches_id == branchId).toList();
  }

  static Future<Group?> getGroupByIdCached(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    try {
      return allGroups.firstWhere((g) => g.groups_id == groupId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<GroupStudent>> getGroupStudentsByGroupIdCached(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final all = await getGroupStudentsCached(forceRefresh: forceRefresh);
    return all.where((gs) => gs.groups_id == groupId).toList();
  }

  static Future<List<Group>> getGroupsByCoachIdCached(
    String coachId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final allGroupRelations = await getGroupStudentsCached(
      forceRefresh: forceRefresh,
    );
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);

    final studentGroupIds = allGroupRelations
        .where((rel) => rel.student_id == studentId && rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    return allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();
  }

  // =========================================================================
  // ✅ GRUP İŞLEMLERİ (CACHE'SİZ)
  // =========================================================================

  static Future<List<Group>> getGroupsByCoach(String coachId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByBranch(String branchId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.branches_id == branchId).toList();
  }

  static Future<Group?> getGroupById(String groupId) async {
    final allGroups = await getGroups();
    try {
      return allGroups.firstWhere((g) => g.groups_id == groupId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<GroupStudent>> getGroupStudentsByGroupId(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final all = await getGroupStudents();
    return all.where((gs) => gs.groups_id == groupId).toList();
  }

  static Future<List<Group>> getGroupsByCoachId(String coachId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByStudentId(String studentId) async {
    final allGroupRelations = await getGroupStudents();
    final allGroups = await getGroups();

    final studentGroupIds = allGroupRelations
        .where((rel) => rel.student_id == studentId && rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    return allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();
  }

  static Future<Users?> getStudentCoach(String studentId) async {
    final studentGroups = await getGroupsByStudentId(studentId);
    if (studentGroups.isEmpty) return null;

    final coachId = studentGroups.first.coach_id;
    final coaches = await getCoachesOnly();
    try {
      final coachUser = coaches.firstWhere((c) => c.app == coachId);
      return coachUser;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateGroup(
    String groupId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _postRequest({
      "action": "updateGroup",
      "group_id": groupId,
      "data": updateData,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ GRUP-ÖĞRENCİ İLİŞKİLERİ (CACHE'Lİ)
  // =========================================================================

  static Future<List<GroupStudent>> getGroupStudentsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final all = await getGroupStudentsCached(forceRefresh: forceRefresh);
    return all.where((gs) => gs.student_id == studentId).toList();
  }

  static Future<List<Group>> getActiveGroupsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final allGroupRelations = await getGroupStudentsByStudentIdCached(
      studentId,
      forceRefresh: forceRefresh,
    );
    final activeGroupIds = allGroupRelations
        .where((rel) => rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups
        .where((g) => activeGroupIds.contains(g.groups_id))
        .toList();
  }

  // =========================================================================
  // ✅ GRUP-ÖĞRENCİ İLİŞKİLERİ (CACHE'SİZ)
  // =========================================================================

  static Future<List<GroupStudent>> getGroupStudentsByStudentId(
    String studentId,
  ) async {
    final all = await getGroupStudents();
    return all.where((gs) => gs.student_id == studentId).toList();
  }

  static Future<List<Group>> getActiveGroupsByStudentId(
    String studentId,
  ) async {
    final allGroupRelations = await getGroupStudentsByStudentId(studentId);
    final activeGroupIds = allGroupRelations
        .where((rel) => rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    final allGroups = await getGroups();
    return allGroups
        .where((g) => activeGroupIds.contains(g.groups_id))
        .toList();
  }

  static Future<bool> assignStudentToGroup(
    String studentId,
    String groupId,
  ) async {
    final response = await _postRequest({
      "action": "assignStudentToGroup",
      "student_id": studentId,
      "group_id": groupId,
      "is_active": "TRUE",
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('group_students');
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  static Future<bool> removeStudentFromGroup(
    String studentId,
    String groupId,
  ) async {
    try {
      final response = await _postRequest({
        "action": "removeStudentFromGroup",
        "student_id": studentId,
        "group_id": groupId,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          // Cache'leri temizle
          invalidateCache('group_students');
          invalidateCache('groups');
        }
        return success;
      }
      return false;
    } catch (e) {
      print("removeStudentFromGroup hatası: $e");
      return false;
    }
  }

  static Future<bool> assignCoachToGroup(String groupId, String coachId) async {
    final response = await _postRequest({
      "action": "assignCoachToGroup",
      "group_id": groupId,
      "coach_id": coachId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ COACH İŞLEMLERİ
  // =========================================================================

  static Future<bool> registerCoach(Coach newCoach) async {
    final coaches = await getCoachesCached();

    int nextId = 1;
    if (coaches.isNotEmpty) {
      final ids = coaches.map((c) => int.tryParse(c.coach_id) ?? 0).toList();
      nextId = ids.reduce((curr, next) => curr > next ? curr : next) + 1;
    }

    final updatedCoachData = newCoach.toJson();
    updatedCoachData['coach_id'] = nextId.toString();

    final success = await insertData("coaches", updatedCoachData);
    if (success) {
      invalidateCache('coaches');
    }
    return success;
  }

  static Future<bool> registerCoachWithAutoId(Coach newCoach) async {
    return await registerCoach(newCoach);
  }

  static Future<bool> addCoachWithAutoId(Map<String, dynamic> coachData) async {
    final allCoaches = await getCoachesCached();

    int nextId = 1;
    if (allCoaches.isNotEmpty) {
      final ids = allCoaches.map((c) => int.tryParse(c.coach_id) ?? 0).toList();
      nextId = ids.reduce((curr, next) => curr > next ? curr : next) + 1;
    }

    coachData['coach_id'] = nextId.toString();
    final success = await insertData("coaches", coachData);
    if (success) {
      invalidateCache('coaches');
    }
    return success;
  }

  // =========================================================================
  // ✅ YOKLAMA İŞLEMLERİ
  // =========================================================================

  static Future<List<Attendance>> getAttendancesByStudent(
    String studentId,
  ) async {
    final all = await getAttendancesCached();
    return all.where((a) => a.student_id == studentId).toList();
  }

  /*
  static Future<bool> saveAttendance(Attendance attendance) async {
    final response = await _postRequest({
      "action": "saveAttendance",
      "sheet": "attendances",
      "data": attendance.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('attendances');
      }
      return success;
    }
    return false;
  }
*/
  static Future<bool> saveAttendance(Attendance attendance) async {
    Map<String, dynamic> dataToSend = attendance.toJson();

    // 🔥 Eğer ID local_ ile başlıyorsa veya boşsa, BOŞ gönder
    if (attendance.attendances_id.isEmpty ||
        attendance.attendances_id.startsWith('local_')) {
      dataToSend['attendances_id'] = '';
      print("📤 YENİ KAYIT: ID boş gönderiliyor");
    } else {
      print("📤 GÜNCELLEME: ID: ${attendance.attendances_id} gönderiliyor");
    }

    final response = await _postRequest({
      "action": "saveAttendance",
      "sheet": "attendances",
      "data": dataToSend,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;

      if (success) {
        invalidateCache('attendances');

        // 🔥🔥🔥 YENİ ID'Yİ AL VE LOCAL'DAKİ KAYDI GÜNCELLE
        if (decoded['data'] != null && decoded['data']['id'] != null) {
          final newId = decoded['data']['id'].toString();
          final isUpdated = decoded['data']['updated'] == true;

          print("📥 Backend'den gelen ID: $newId, Güncellendi mi: $isUpdated");

          // 🔥 Eğer yeni kayıt oluştuysa (updated: false), ID'yi local'e kaydet
          if (!isUpdated) {
            // Local'deki kaydın ID'sini güncelle
            final prefs = await SharedPreferences.getInstance();
            final localAttendancesJson = prefs.getString('attendances');
            if (localAttendancesJson != null) {
              try {
                List<dynamic> decodedList = jsonDecode(localAttendancesJson);
                bool found = false;
                for (var i = 0; i < decodedList.length; i++) {
                  var item = decodedList[i];
                  if (item['student_id'] == attendance.student_id &&
                      item['groups_id'] == attendance.groups_id &&
                      item['attendance_date'] == attendance.attendance_date) {
                    item['attendances_id'] = newId;
                    found = true;
                    print("✅ Local kayıt güncellendi: $newId");
                    break;
                  }
                }
                if (found) {
                  await prefs.setString('attendances', jsonEncode(decodedList));
                }
              } catch (e) {
                print("❌ Local güncelleme hatası: $e");
              }
            }
          }
        }
      }
      return success;
    }
    return false;
  }

  static Future<List<Attendance>> getAttendancesForGroup(String groupId) async {
    final all = await getAttendancesCached();
    return all.where((a) => a.groups_id == groupId).toList();
  }

  static Future<List<Attendance>> getTodayAttendance(String groupId) async {
    final allAttendances = await getAttendancesForGroup(groupId);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return allAttendances
        .where((a) => a.attendance_date.contains(today))
        .toList();
  }

  /*
  static Future<bool> saveBulkAttendance(List<Attendance> attendances) async {
    final response = await _postRequest({
      "action": "saveBulkAttendance",
      "sheet": "attendances",
      "data": attendances.map((a) => a.toJson()).toList(), // liste olarak
    });
    if (response != null && response.statusCode == 200) {
      final ok = jsonDecode(response.body)['success'] == true;
      if (ok) invalidateCache('attendances');
      return ok;
    }
    return false;
  }

  */
  static Future<bool> saveBulkAttendance(List<Attendance> attendances) async {
    try {
      final body = {
        "action": "saveBulkAttendance",
        "sheet": "attendances",
        "data": attendances.map((a) => a.toJson()).toList(),
      };

      // 🔍 LOG: ne gönderiyoruz?
      print(
        "🔍 [POST] saveBulkAttendance çağrıldı. Kayıt: ${attendances.length}",
      );
      print("🔍 [POST] Gönderilen body: ${jsonEncode(body)}");

      final response = await _postRequest(body);

      // 🔍 LOG: ne cevap geldi?
      if (response == null) {
        print("🔍 [POST] response NULL — istek hiç gitmedi/başarısız!");
        return false;
      }
      print("🔍 [POST] statusCode: ${response.statusCode}");
      print("🔍 [POST] body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final ok = decoded['success'] == true;
        print("🔍 [POST] success alanı: ${decoded['success']} | ok: $ok");
        if (ok) invalidateCache('attendances');
        return ok;
      }

      print("🔍 [POST] statusCode 200 değil, false dönüyor.");
      return false;
    } catch (e) {
      print("🔍 [POST] saveBulkAttendance EXCEPTION: $e");
      return false;
    }
  }
  // =========================================================================
  // ✅ ÖDEME İŞLEMLERİ
  // =========================================================================

  static Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    final allPayments = await getPaymentsCached();
    return allPayments.where((p) => p.student_id == studentId).toList();
  }

  static Future<bool> addPayment(Payment payment) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "payments",
      "data": payment.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('payments');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ ÖĞRENCİ NOTLARI İŞLEMLERİ
  // =========================================================================

  static Future<List<StudentNote>> getStudentNotes() async {
    final rawData = await fetchTable("student_notes");
    return rawData.map((item) => StudentNote.fromJson(item)).toList();
  }

  static Future<List<StudentNote>> getStudentNotesByStudent(
    String studentId,
  ) async {
    final all = await getStudentNotes();
    return all.where((n) => n.student_id == studentId).toList();
  }

  static Future<bool> addStudentNote(StudentNote note) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "student_notes",
      "data": note.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('student_notes');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ VELİ-ÖĞRENCİ İLİŞKİLERİ
  // =========================================================================

  static Future<List<ParentStudent>> getParentStudents() async {
    final rawData = await fetchTable("parent_student");
    return rawData.map((item) => ParentStudent.fromJson(item)).toList();
  }

  static Future<List<ParentStudent>> getStudentsByParent(
    String parentId,
  ) async {
    final all = await getParentStudents();
    return all.where((ps) => ps.parent_id == parentId).toList();
  }

  static Future<List<ParentStudent>> getParentsByStudent(
    String studentId,
  ) async {
    final all = await getParentStudents();
    return all.where((ps) => ps.student_id == studentId).toList();
  }

  static Future<bool> addParentStudent(
    String parentId,
    String studentId,
  ) async {
    final success = await insertData("parent_student", {
      "parent_id": parentId,
      "student_id": studentId,
    });
    if (success) {
      invalidateCache('parent_student');
    }
    return success;
  }

  // =========================================================================
  // ✅ GENEL VERİ EKLEME
  // =========================================================================

  static Future<bool> insertData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await _postRequest({
      "action": "insert",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache(tableName);
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ MASTER KAYIT
  // =========================================================================

  static Future<bool> registerEverywhere(Map<String, dynamic> allInfo) async {
    print("📤 registerEverywhere gönderiliyor:");
    print(jsonEncode(allInfo));

    final response = await _postRequest({
      "action": "registerEverywhere",
      "data": allInfo,
    });

    if (response != null) {
      print("📡 registerEverywhere yanıtı:");
      print("   Status: ${response.statusCode}");
      print("   Body: ${response.body}");
    } else {
      print("❌ registerEverywhere: Yanıt NULL!");
    }

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateAllCache();
      }
      print("📡 registerEverywhere success: $success");
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ ÖDEME BİLDİRİMİ GÖNDER
  // =========================================================================

  static Future<bool> sendPaymentReminderToStudent(
    String studentId,
    String studentName,
    double amount,
    String dueDate,
  ) async {
    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": "Admin",
      "recipient_id": studentId,
      "groups_id": "",
      "title": "💰 Ödeme Hatırlatması",
      "message":
          "Sayın $studentName, $dueDate tarihinde sona eren $amount TL aidat ödemeniz bulunmaktadır. Lütfen en kısa sürede ödemenizi gerçekleştiriniz.",
      "type": "payment_reminder",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    return await addNotification(notifData);
  }

  static Future<int> sendPaymentRemindersToAllLateStudents() async {
    try {
      final allPayments = await getPaymentsCached();
      final allStudents = await getStudentsOnlyCached();
      final today = DateTime.now();

      final latePayments = allPayments.where((p) {
        final dueDate = DateTime.tryParse(p.due_date);
        final isLate = dueDate != null && dueDate.isBefore(today);
        final isNotPaid = p.status?.toLowerCase() != 'paid';
        return isLate && isNotPaid;
      }).toList();

      int sentCount = 0;

      for (var payment in latePayments) {
        final student = allStudents.firstWhere(
          (s) => s.app.toString() == payment.student_id,
          orElse: () => Users(
            app: "",
            branches_id: "",
            first_name: "Öğrenci",
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
          ),
        );

        final success = await sendPaymentReminderToStudent(
          payment.student_id,
          "${student.first_name} ${student.last_name}",
          double.tryParse(payment.amount) ?? 0,
          payment.due_date,
        );

        if (success) sentCount++;
      }

      return sentCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> sendAnnouncementToStudent(
    String studentId,
    String title,
    String message,
  ) async {
    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": "Admin",
      "recipient_id": studentId,
      "groups_id": "",
      "title": title,
      "message": message,
      "type": "announcement",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    return await addNotification(notifData);
  }

  // =========================================================================
  // ✅ YARDIMCI METODLAR
  // =========================================================================

  Future<String> loadJsonAsset(String fileName) async {
    return await rootBundle.loadString('assets/data/$fileName.json');
  }

  static Future<Users?> getUserById(String userId) async {
    final allUsers = await getUsersCached();
    try {
      return allUsers.firstWhere((u) => u.app == userId);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // ✅ FCM TOKEN İŞLEMLERİ
  // =========================================================================

  static Future<bool> saveUserToken(String userId, String token) async {
    try {
      final response = await _postRequest({
        "action": "saveUserToken",
        "user_id": userId,
        "fcm_token": token,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getUserToken(String userId) async {
    try {
      final response = await _postRequest({
        "action": "getUserToken",
        "user_id": userId,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> getGroupUserTokens(String groupId) async {
    try {
      final response = await _postRequest({
        "action": "getGroupUserTokens",
        "group_id": groupId,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return List<String>.from(decoded['tokens'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // GoogleSheetService içinde
  static Future<bool> updateFcmToken(String userId, String fcmToken) async {
    final response = await _postRequest({
      'action': 'updateFcmToken',
      'user_id': userId,
      'fcm_token': fcmToken,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  static Future<bool> sendPushNotification(
    String title,
    String body,
    List<String> tokens, {
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return false;

    try {
      final response = await _postRequest({
        "action": "sendPushNotifications",
        "tokens": tokens,
        "title": title,
        "body": body,
        "data": data ?? {},
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // ✅ OFFLİNE DESTEK
  // =========================================================================

  static Future<List<dynamic>> getDataWithOffline({
    required String sheetName,
    required String idField,
  }) async {
    final offlineData = await LocalDatabaseService().getAll(sheetName);

    if (offlineData.isNotEmpty) {
      return offlineData;
    }

    final freshData = await fetchTable(sheetName);
    for (var item in freshData) {
      final id =
          item[idField]?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await LocalDatabaseService().insertOrUpdate(sheetName, id, item);
    }

    return freshData;
  }

  static Future<bool> saveDataWithOffline({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    final tempId =
        data['${tableName}_id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await LocalDatabaseService().insertOrUpdate(tableName, tempId, data);

    await LocalDatabaseService().addPendingOperation(
      operation: 'insert',
      tableName: tableName,
      data: data,
    );

    return true;
  }

  // =========================================================================
  // ✅ GENEL GÜNCELLEME / SİLME
  // =========================================================================

  static Future<bool> updateData(
    String tableName,
    Map<String, dynamic> data,
    Map<String, String?> updateData,
  ) async {
    final response = await _postRequest({
      "action": "update",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  static Future<bool> deleteData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await _postRequest({
      "action": "delete",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  static Future<bool> updatePassword(
    String userId,
    String hashedPassword,
  ) async {
    final response = await _postRequest({
      "action": "updatePassword",
      "user_id": userId,
      "password_hash": hashedPassword,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ FOTOĞRAF YÜKLEME
  // =========================================================================
  /*
  static Future<String?> uploadImageToDrive(
    File imageFile,
    String fileName,
    String folderName, {
    String? targetUserId,
    String? targetField,
  }) async {
    try {
      print("📸 uploadImageToDrive BAŞLADI");
      print("   fileName: $fileName");
      print("   folderName: $folderName");

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      print("   Base64 uzunluk: ${base64Image.length}");

      final requestBody = {
        "action": "uploadImage",
        "file_name": fileName,
        "file_data": base64Image,
        "folder": folderName,
      };

      if (targetUserId != null && targetField != null) {
        requestBody["targetUserId"] = targetUserId;
        requestBody["targetField"] = targetField;
      }

      print("📤 uploadImage requestBody gönderiliyor...");
      final response = await _postRequest(requestBody);

      if (response != null) {
        print("📥 uploadImage response status: ${response.statusCode}");

        // 🔥 302 durumunda redirect'i takip et
        if (response.statusCode == 302) {
          String? redirectUrl = response.headers['location'];
          if (redirectUrl == null && response.body.contains('HREF="')) {
            final start = response.body.indexOf('HREF="') + 6;
            final end = response.body.indexOf('"', start);
            redirectUrl = response.body
                .substring(start, end)
                .replaceAll('&amp;', '&');
          }
          if (redirectUrl != null) {
            print("🌐 Redirect: $redirectUrl");
            final redirectResponse = await http.get(Uri.parse(redirectUrl));
            print("🌐 Redirect yanıtı: ${redirectResponse.statusCode}");

            if (redirectResponse.statusCode == 200) {
              final decoded = jsonDecode(redirectResponse.body);
              print("📥 uploadImage decoded: $decoded");
              if (decoded['success'] == true) {
                final fileId = decoded['data']?['fileId'];
                print("✅ uploadImage başarılı! fileId: $fileId");
                return fileId;
              } else {
                print("❌ uploadImage başarısız: ${decoded['error']}");
              }
            }
          }
        } else if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          print("📥 uploadImage decoded: $decoded");
          if (decoded['success'] == true) {
            final fileId = decoded['data']?['fileId'];
            print("✅ uploadImage başarılı! fileId: $fileId");
            return fileId;
          } else {
            print("❌ uploadImage başarısız: ${decoded['error']}");
          }
        }
      }
      return null;
    } catch (e) {
      print("❌ uploadImageToDrive hatası: $e");
      return null;
    }
  }
*/
  static Future<String?> uploadImageToDrive(
    File imageFile,
    String fileName,
    String folderName, {
    String? targetUserId,
    String? targetField,
  }) async {
    try {
      print("📸 uploadImageToDrive BAŞLADI");

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final requestBody = {
        "action": "uploadImage",
        "file_name": fileName,
        "file_data": base64Image,
        "folder": folderName,
      };

      print("📤 uploadImage requestBody gönderiliyor...");
      var response = await _postRequest(requestBody);

      if (response != null) {
        String finalResponseBody = response.body;

        // 🔥 302 DURUMUNDA REDIRECT'İ TAKİP ET VE YANITI DOĞRU DEĞİŞKENE AT
        if (response.statusCode == 302) {
          String? redirectUrl = response.headers['location'];
          if (redirectUrl == null && response.body.contains('HREF="')) {
            final start = response.body.indexOf('HREF="') + 6;
            final end = response.body.indexOf('"', start);
            redirectUrl = response.body
                .substring(start, end)
                .replaceAll('&amp;', '&');
          }
          if (redirectUrl != null) {
            print("🌐 Redirect Takip Ediliyor: $redirectUrl");
            final redirectResponse = await http.get(Uri.parse(redirectUrl));
            print("🌐 Redirect yanıt statüsü: ${redirectResponse.statusCode}");

            if (redirectResponse.statusCode == 200) {
              finalResponseBody = redirectResponse
                  .body; // <-- Kritik hamle: Asıl veriyi buradan aldık!
            }
          }
        }

        // 🎯 ARTIK ELİMİZDEKİ DOĞRU BODY'Yİ DECODE EDİYORUZ
        final decoded = jsonDecode(finalResponseBody);
        print("📥 uploadImage Çözümlenen Yanıt: $decoded");

        if (decoded['success'] == true) {
          final fileId = decoded['data']?['fileId'];
          print("✅ uploadImage Başarılı! Gelen Değer: $fileId");
          return fileId; // Buradan dönen tertemiz uc?export=view linki olacak
        } else {
          print("❌ uploadImage Başarısız Oldu: ${decoded['error']}");
        }
      }
      return null;
    } catch (e) {
      print("❌ uploadImageToDrive Hatası: $e");
      return null;
    }
  }

  static Future<String?> getImageUrlFromDrive(
    String fileName,
    String folderName,
  ) async {
    if (fileName.isEmpty) return null;

    try {
      final response = await _postRequest({
        "action": "getImageUrl",
        "file_name": fileName,
        "folder": folderName,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded['data']['url'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateUser(Map<String, dynamic> userData) async {
    final response = await _postRequest({
      "action": "updateUser",
      "data": userData,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  static Future<bool> updateGroupStatus(
    String groupId,
    String newStatus,
  ) async {
    try {
      final response = await _postRequest({
        "action": "updateGroupStatus",
        "group_id": groupId,
        "is_active": newStatus,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          invalidateCache('groups');
        }
        return success;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateUserAmount(String userId, double newAmount) async {
    try {
      final response = await _postRequest({
        "action": "updateUserAmount",
        "user_id": userId,
        "amount": newAmount.toString(),
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          invalidateCache('users');
        }
        return success;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateGroupSchedule(
    String groupId,
    String newSchedule,
  ) async {
    final response = await _postRequest({
      "action": "updateGroupSchedule",
      "group_id": groupId,
      "schedule": newSchedule,
    });

    print("📡 Response status: ${response?.statusCode}");
    print("📡 Response body: ${response?.body}"); // ← BU SATIRI EKLE

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  static Future<bool> transferStudentToGroup(
    String studentId,
    String newGroupId,
  ) async {
    try {
      final response = await _postRequest({
        'action': 'transferStudentToGroup',
        'student_id': studentId,
        'new_group_id': newGroupId,
      });

      if (response == null || response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      final isSuccess = decoded['success'] == true;

      if (isSuccess) {
        invalidateCache('group_students');
        invalidateCache('groups');
      }

      return isSuccess;
    } catch (e) {
      print("Transfer hatası: $e");
      return false;
    }
  }

  // Ödeme silme
  static Future<bool> deletePayment(String paymentId) async {
    final response = await _postRequest({
      "action": "deletePayment",
      "payments_id": paymentId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('payments');
      }
      return success;
    }
    return false;
  }

  // Ödeme güncelleme
  static Future<bool> updatePayment(
    String paymentId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _postRequest({
      "action": "updatePayment",
      "payments_id": paymentId,
      "data": updateData,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('payments');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // 🔥 YARDIMCI ANTRENÖR YÖNETİMİ
  // =========================================================================
  // NOT: Yardımcı antrenörlerin "coaches" sayfasında kendi satırı YOKTUR.
  // Bağlantı bilgisi, ANA HOCANIN coaches satırındaki supervisor_coach_id
  // sütununda (virgülle ayrılmış user_id listesi) tutulur.
  // Bu yüzden bu üç metod backend'in (Code.gs) zaten desteklediği
  // transferAssistant / removeAssistant / getAssistantsForCoach
  // action'larını kullanır; genel "update" action'ı YOKTUR ve kullanılmamalı.

  /// Bir yardımcı antrenörü bir ana hocaya bağlar (veya başka bir hocadan
  /// bu hocaya taşır). oldMasterUserId boş ise sadece yeni hocaya eklenir.
  static Future<bool> transferAssistant({
    required String assistantUserId,
    String? oldMasterUserId,
    required String newMasterUserId,
  }) async {
    final response = await _postRequest({
      "action": "transferAssistant",
      "assistant_user_id": assistantUserId,
      "old_master_user_id": oldMasterUserId ?? "",
      "new_master_user_id": newMasterUserId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('coaches');
      }
      return success;
    }
    return false;
  }

  /// Bir yardımcı antrenörü belirli bir hocadan (veya masterUserId boşsa
  /// TÜM hocalardan) kaldırır.
  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR BAĞLA
  // ============================================================

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR BAĞLA
  // ============================================================

  static Future<bool> assignAssistant({
    required String assistantUserId,
    required String masterUserId,
  }) async {
    try {
      final response = await _postRequest({
        'action': 'assignAssistantToMaster',
        'assistant_user_id': assistantUserId,
        'master_user_id': masterUserId,
      });

      if (response == null) {
        print('❌ assignAssistant: response null');
        return false;
      }

      // 🔥 DÜZELTİLDİ: response bir http.Response, önce body'yi decode et
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          print('✅ Yardımcı başarıyla bağlandı!');
          invalidateCache('coaches');
        } else {
          print('❌ Bağlama başarısız: ${decoded['error']}');
        }
        return success;
      }
      return false;
    } catch (e) {
      print('❌ assignAssistant hatası: $e');
      return false;
    }
  }

  // ============================================================
  // 🔥 YARDIMCI ANTRENÖR ÇIKAR
  // ============================================================

  static Future<bool> removeAssistant({
    required String assistantUserId,
    required String masterUserId,
  }) async {
    try {
      final response = await _postRequest({
        'action': 'removeAssistantFromMaster',
        'assistant_user_id': assistantUserId,
        'master_user_id': masterUserId,
      });

      if (response == null) {
        print('❌ removeAssistant: response null');
        return false;
      }

      // 🔥 DÜZELTİLDİ: response bir http.Response, önce body'yi decode et
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          print('✅ Yardımcı başarıyla çıkarıldı!');
          invalidateCache('coaches');
        } else {
          print('❌ Çıkarma başarısız: ${decoded['error']}');
        }
        return success;
      }
      return false;
    } catch (e) {
      print('❌ removeAssistant hatası: $e');
      return false;
    }
  }

  /// Bir ana hocaya bağlı yardımcı antrenörlerin user_id listesini getirir.
  static Future<List<String>> getAssistantsForCoach(String masterUserId) async {
    final response = await _postRequest({
      "action": "getAssistantsForCoach",
      "master_user_id": masterUserId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded['success'] == true && decoded['data'] != null) {
        final assistants = decoded['data']['assistants'];
        if (assistants is List) {
          return assistants.map((e) => e.toString()).toList();
        }
      }
    }
    return [];
  }

  static Future<bool> addAssistantCoach({
    required String userId,
    required String supervisorIds,
    required String branchId,
  }) async {
    try {
      print("🔥 addAssistantCoach çağrıldı!");
      print("   userId: $userId");
      print("   supervisorIds: $supervisorIds");
      print("   branchId: $branchId");

      // 🔥 BURASI DÜZELTİLDİ! Body oluşturuluyor
      Map<String, dynamic> body = {
        "action": "addAssistantCoach",
        "user_id": userId,
        "supervisor_coach_id": supervisorIds,
        "branches_id": branchId,
      };

      // 🔥 BURASI EKSİKTİ! _postRequest çağrılmalı!
      final response = await _postRequest(body);

      if (response == null) {
        print('❌ addAssistantCoach: response null');
        return false;
      }

      // 🔥 BURASI DÜZELTİLDİ! response bir http.Response
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          print('✅ Yardımcı başarıyla eklendi!');
          invalidateCache('coaches');
        } else {
          print('❌ Ekleme başarısız: ${decoded['error']}');
        }
        return success;
      }
      return false;
    } catch (e) {
      print("❌ addAssistantCoach hatası: $e");
      return false;
    }
  }

  static Future<bool> addCoach({
    required String userId,
    required String branchId,
  }) async {
    try {
      print("🔥 addCoach çağrıldı!");
      print("   userId: $userId");
      print("   branchId: $branchId");

      Map<String, dynamic> body = {
        "action": "addCoach",
        "user_id": userId,
        "branches_id": branchId,
      };

      final response = await _postRequest(body);

      if (response == null) {
        print('❌ addCoach: response null');
        return false;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          print('✅ Coach başarıyla eklendi!');
          invalidateCache('coaches');
        } else {
          print('❌ Coach ekleme başarısız: ${decoded['error']}');
        }
        return success;
      }
      return false;
    } catch (e) {
      print("❌ addCoach hatası: $e");
      return false;
    }
  }

  static String convertToDirectImageUrl(String url) {
    if (url.isEmpty) return url;

    // Eğer zaten doğrudan resim URL'siyse
    if (url.contains('uc?export=view&id=')) return url;

    // File ID'yi çıkar
    final regex = RegExp(r'/file/d/([^/]+)/');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1);
      return "https://drive.google.com/uc?export=view&id=$fileId";
    }

    return url;
  }
  // fetch_data_page.dart

  static Future<Map<String, dynamic>> getVersionReport() async {
    try {
      final response = await _postRequest({"action": "getVersionReport"});

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded['data'];
        }
      }
      return {};
    } catch (e) {
      print("❌ Rapor hatası: $e");
      return {};
    }
  }
  // fetch_data_page.dart

  static Future<bool> sendUpdateNotification({
    required String userId,
    required String version,
    required String releaseNotes,
  }) async {
    try {
      final response = await _postRequest({
        "action": "sendUpdateNotification",
        "user_id": userId,
        "version": version,
        "release_notes": releaseNotes,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print("❌ Güncelleme bildirimi hatası: $e");
      return false;
    }
  }

  /*
  static Future<Map<String, dynamic>> getAllDataBulk() async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          body: jsonEncode({"action": "getAllDataBulk"}),
        )deleteExtraData
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    if (decoded['success'] == true) {
      return decoded['data']; // { users: [...], groups: [...], payments: [...], ... }
    } else {
      throw Exception(decoded['error']);
    }
  }
  */
  static Future<Map<String, dynamic>> getAllDataBulk() async {
    try {
      print(
        "📦 getAllDataBulk tetiklendi, merkezi _postRequest kullanılıyor...",
      );

      // 🎯 ÇÖZÜM: Direkt http.post atmak yerine, yönlendirmeleri ve
      // doğru URL'yi yöneten merkezi _postRequest metodumuzu çağırıyoruz.
      final response = await _postRequest({"action": "getAllDataBulk"});

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded; // { success: true, data: { users: [...], groups: [...] } }
        }
      }

      print("❌ getAllDataBulk: Yanıt başarısız veya boş döndü.");
      return {"success": false, "error": "Boş veya hatalı sunucu yanıtı"};
    } catch (e) {
      print("❌ getAllDataBulk Flutter Hatası: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  /// 🔥 DELTA SYNC: Sadece son senkrondan sonra değişen verileri çeker.
  /// last_sync null ise (ilk açılış) sunucu tüm veriyi döner.
  /// Dönüş: { success: true, data: { users:[...], attendances:[...], _server_time: "..." } }
  static Future<Map<String, dynamic>> getUpdatedData({String? lastSync}) async {
    try {
      print("📦 getUpdatedData tetiklendi (last_sync: ${lastSync ?? 'YOK'})");

      final body = {
        "action": "getUpdatedData",
        if (lastSync != null) "last_sync": lastSync,
      };

      final response = await _postRequest(body);

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body); // ✅ response.body kullanıldı
        return decoded as Map<String, dynamic>;
      }

      return {"success": false, "error": "Sunucudan geçerli yanıt alınamadı"};
    } catch (e) {
      print("❌ getUpdatedData hatası: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  // =========================================================================
  // 🔥 EK TABLOLAR: student_data (öğrenci toplama) + expense_management (gider)
  // =========================================================================

  // --- OKUMA (cache'li) ---
  static Future<List<Map<String, dynamic>>> getStudentDataCached({
    bool forceRefresh = false,
  }) async {
    final raw = await fetchTableCached(
      'student_data',
      forceRefresh: forceRefresh,
    );
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getExpensesCached({
    bool forceRefresh = false,
  }) async {
    final raw = await fetchTableCached(
      'expense_management',
      forceRefresh: forceRefresh,
    );
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // --- YAZMA: ÖĞRENCİ TOPLAMA ---
  static Future<bool> addStudentData({
    required String firstName,
    required String lastName,
    required String phone,
    required String bDate,
    required String branches,
    String createdAt = '',
  }) async {
    final response = await _postRequest({
      "action": "insertExtra",
      "table": "student_data",
      "data": {
        "id": "",
        "first_name": firstName,
        "last_name": lastName,
        "phone": phone,
        "b_date": bDate,
        "branches": branches,
        "created_at": createdAt.isEmpty
            ? DateTime.now().toIso8601String()
            : createdAt,
      },
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) invalidateCache('student_data');
      return success;
    }
    return false;
  }

  // --- YAZMA: GİDER ---
  static Future<bool> addExpense({
    required String title, // açıklama -> note
    required String amount, // tutar   -> money
    required String paidDate, // tarih  -> paid_date
    String montMoney = '',
    String firstName = '',
    String lastName = '',
  }) async {
    final response = await _postRequest({
      "action": "insertExtra",
      "table": "expense_management",
      "data": {
        "id": "",
        "first_name": firstName,
        "last_name": lastName,
        "money": amount,
        "mont_money": montMoney,
        "paid_date": paidDate,
        "note": title,
      },
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) invalidateCache('expense_management');
      return success;
    }
    return false;
  }

  static Future<bool> deleteExtraData({
    required String tableName,
    required String id,
  }) async {
    final response = await _postRequest({
      "action": "deleteExtra",
      "table": tableName,
      "id": id.toString(),
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache(tableName); // Cache'i uçuruyoruz
      }
      return success;
    }
    return false;
  }

  // --- STUDENT DATA SİL ---
  static Future<bool> deleteStudentData(String id) async {
    final response = await _postRequest({
      "action": "deleteExtra",
      "table": "student_data",
      "id": id,
    });
    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) invalidateCache('student_data');
      return success;
    }
    return false;
  }

  // --- EXPENSE SİL ---
  static Future<bool> deleteExpense(String id) async {
    final response = await _postRequest({
      "action": "deleteExtra",
      "table": "expense_management",
      "id": id,
    });
    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) invalidateCache('expense_management');
      return success;
    }
    return false;
  }
}

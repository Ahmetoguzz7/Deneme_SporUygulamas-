/*
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File; // 🔥 SADECE Platform ve File

import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/internet/internet_check.dart';
import 'package:EVOM_SPOR/internet/internt_close.dart';
import 'package:EVOM_SPOR/internet/network_aware_wrapper.dart';
import 'package:EVOM_SPOR/local/hive_adapter.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 YENİ: Gerçek indirme + otomatik kurulum için gerekli paketler
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// Firebase paketleri
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Sayfalar
import 'package:EVOM_SPOR/unifiedLoginPage.dart';

// ============================================================
// GLOBAL TANIMLAR
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "EVOM_SPOR";
const String _baseUrl =
    "https://script.google.com/macros/s/AKfycbzLDgE0zIxZQcnHDQCp4udgOopUSWmbq3sHe8JNbqxpb9VxIfF9wtSVhVu1ZE4RgxrUtA/exec";

const String backgroundUpdateTask = "updateCheckTask";
const String backgroundNotificationTask = "notificationCheckTask";
const String backgroundAttendanceSyncTask = "attendanceSyncTask";

// ============================================================
// 🔥 FIREBASE ARKA PLAN HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification?.title ?? 'Bildirim',
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'app_notifications',
          'Uygulama Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND TASK CALLBACK
// ============================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundUpdateTask) {
      await checkForUpdateBackground();
    } else if (taskName == backgroundNotificationTask) {
      await checkForNewNotificationsBackground();
    } else if (taskName == backgroundAttendanceSyncTask) {
      await syncAttendancesInBackground();
    }
    return Future.value(true);
  });
}

// ============================================================
// MAIN - İNTERNET KONTROLLÜ
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe locale
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    Intl.defaultLocale = 'tr_TR';
  }

  // Önce internet kontrolü yap
  final hasInternet = await _checkInternetOnStart();

  // UI başlat
  runApp(MyApp(initialHasInternet: hasInternet));

  // Arka plan işlemleri (UI bloklanmasın)
  unawaited(_initializeAppInBackground());
}

// 🔥 BAŞLANGIÇTA İNTERNET KONTROLÜ
Future<bool> _checkInternetOnStart() async {
  try {
    final results = await Connectivity().checkConnectivity();
    // 🔥 Sadece cihazın hiç bağlantısı yoksa "internet yok" say.
    // Zayıf/yavaş bağlantıda sunucu ping'i ile hemen "yok" deme.
    return results != ConnectivityResult.none;
  } catch (e) {
    return false;
  }
}

Future<void> syncAttendancesInBackground() async {
  try {
    final service = OfflineAttendanceService();
    await service.init();
    await service.processQueueNow();
  } catch (e) {
    // Sessiz geç
  }
}

// Arka planda başlatılacak tüm işlemler
Future<void> _initializeAppInBackground() async {
  // Internet checker dinleyicisi
  final internetChecker = InternetChecker();
  internetChecker.startListening();

  // Firebase başlat
  await Firebase.initializeApp();

  // Arka plan handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // İzinler
  unawaited(requestPermissions());

  // Bildirim servisi
  unawaited(initNotifications());

  // Firebase topic
  _subscribeToTopicWithTimeout();

  // Token işlemleri
  _setupFirebaseTokenHandling();

  // Arka plan görevleri
  unawaited(initBackgroundTask());

  // Güncelleme kontrolü
  _scheduleUpdateCheck();

  if (Platform.isIOS) {
    _startIOSPeriodicCheck();
  }
}

// ============================================================
// TOPIC SUBSCRIBE
// ============================================================

void _subscribeToTopicWithTimeout() {
  Future.delayed(Duration.zero, () {
    FirebaseMessaging.instance
        .subscribeToTopic("all_users")
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint("⚠️ Topic subscribe timeout - skipping");
            return;
          },
        )
        .catchError((e) {
          debugPrint("⚠️ Topic subscribe error: $e");
        });
  });
}

// ============================================================
// FIREBASE TOKEN HANDLING
// ============================================================

void _setupFirebaseTokenHandling() async {
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToServer(token);
      }
    } catch (e) {
      debugPrint("⚠️ Token alınamadı: $e");
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    _saveTokenToServer(newToken);
  });
}

// ============================================================
// FCM TOKEN KAYDET
// ============================================================
Future<void> _saveTokenToServer(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null) return;

    await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'updateFcmToken',
            'user_id': userId,
            'fcm_token': token,
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // Sessizce başarısız ol
  }
}

// ============================================================
// GÜNCELLEME KONTROL ZAMANLAMA
// ============================================================

void _scheduleUpdateCheck() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 3), () async {
      await checkForUpdateWithNotification();
    });
  });
}

Future<void> _trackAppVersion() async {
  try {
    // 1️⃣ Kullanıcı bilgilerini al
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');

    if (userJson == null) {
      print("📌 Kullanıcı oturum açmamış, sürüm takibi atlandı");
      return;
    }

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString() ?? '';
    final email = userMap['email']?.toString() ?? '';
    String deviceInfo = Platform.operatingSystem; // "android" veya "ios"
    if (userId.isEmpty) {
      print("📌 Kullanıcı ID boş, sürüm takibi atlandı");
      return;
    }

    // 2️⃣ Uygulama sürümünü al
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;

    // 3️⃣ Cihaz bilgisini al
    // final deviceInfo = await _getDeviceInfo();

    print("📱 Sürüm takibi gönderiliyor:");
    print("   User ID: $userId");
    print("   Email: $email");
    print("   Sürüm: $appVersion");
    //print("   Cihaz: $deviceInfo");

    // 4️⃣ Apps Script'e gönder
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'trackAppVersion',
            'user_id': userId,
            'email': email,
            'app_version': appVersion,

            /// 'device_info': deviceInfo,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        print("✅ Sürüm takibi başarıyla kaydedildi!");
      } else {
        print("❌ Sürüm takibi başarısız: ${decoded['error']}");
      }
    } else {
      print("❌ HTTP hatası: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Sürüm takibi hatası: $e");
  }
}

// 🔥 CİHAZ BİLGİSİ AL
// 🔥 CİHAZ BİLGİSİ AL - PAKETSİZ
// 📱 CİHAZ BİLGİSİ - BASİT VE GÜVENLİ

// iOS versiyonunu almak için
Future<String> _getIOSVersion() async {
  try {
    // iOS'te sistem versiyonunu almanın basit yolu
    // UIDevice.current.systemVersion'a erişemiyoruz,
    // ama device_info_plus olmadan tam bilgi zor
    return "iOS";
  } catch (e) {
    return "iOS";
  }
}
// ============================================================
// GÜNCELLEME KONTROLÜ - ANA
// ============================================================

Future<void> checkForUpdateWithNotification() async {
  // 1️⃣ İNTERNET KONTROLÜ
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    print("📌 İnternet yok, güncelleme kontrolü atlandı");
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  // 2️⃣ TELEFONDAKİ GERÇEK KURULU SÜRÜM
  final currentVersion = await getCurrentVersion();
  print("📱 Telefondaki GERÇEK kurulu sürüm: $currentVersion");

  // 3️⃣ GITHUB'DAN EN SON SÜRÜMÜ AL
  final latestData = await getLatestReleaseFromGitHub();
  if (latestData == null) {
    print("📌 GitHub'dan sürüm bilgisi alınamadı");
    return;
  }

  final latestVersion = latestData['version'] ?? '';
  print("📌 GitHub'daki en son sürüm: $latestVersion");

  // 4️⃣ GÜNCEL Mİ?
  if (currentVersion == latestVersion ||
      !isNewerVersion(currentVersion, latestVersion)) {
    print(
      "✅ Uygulama zaten güncel! (Telefon: $currentVersion, GitHub: $latestVersion)",
    );
    await prefs.remove('last_notified_for_version');
    return;
  }

  // 5️⃣ BU SÜRÜM İÇİN ZATEN GÖSTERİLDİ Mİ?
  final lastNotified = prefs.getString('last_notified_for_version');
  if (lastNotified == latestVersion) {
    print("📌 $latestVersion için ekran zaten gösterildi");
    return;
  }

  await prefs.setString('last_notified_for_version', latestVersion);

  print("🔄 Yeni sürüm bulundu! $currentVersion -> $latestVersion");

  // 6️⃣ KULLANICIYA GÖSTER
  if (navigatorKey.currentState?.context != null) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ForceUpdateScreen(updateData: latestData),
      ),
      (route) => false,
    );
  }
}

// ============================================================
// iOS PERİYODİK KONTROL
// ============================================================

Timer? _iosPeriodicTimer;

void _startIOSPeriodicCheck() {
  _iosPeriodicTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
    await checkForNewNotificationsBackground();
  });
}

// ============================================================
// İZİN YÖNETİMİ
// ============================================================

Future<void> requestPermissions() async {
  try {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// BİLDİRİM SERVİSİ
// ============================================================

Future<void> initNotifications() async {
  try {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'open_notifications') {
          navigatorKey.currentState?.pushNamed('/notifications');
        } else if (response.payload != null &&
            response.payload!.startsWith('http')) {
          downloadAndInstallApk(response.payload!);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'update_channel',
          'Güncelleme Bildirimleri',
          description: 'Uygulama güncellemeleri',
          importance: Importance.high,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'app_notifications',
          'Uygulama Bildirimleri',
          description: 'Duyurular, ödemeler, yoklama bildirimleri',
          importance: Importance.high,
        ),
      );
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// GÜNCELLEME KONTROL FONKSİYONLARI
// ============================================================

Future<void> checkForUpdateBackground() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final prefs = await SharedPreferences.getInstance();

  final currentVersion = await getCurrentVersion();
  print("📱 [Arka plan] Telefon sürümü: $currentVersion");

  final latestData = await getLatestReleaseFromGitHub();
  if (latestData == null) return;

  final latestVersion = latestData['version'] ?? '';
  print("📌 [Arka plan] GitHub sürümü: $latestVersion");

  if (currentVersion == latestVersion ||
      !isNewerVersion(currentVersion, latestVersion)) {
    print("✅ [Arka plan] Zaten güncel");
    await prefs.remove('last_notified_for_version_bg');
    return;
  }

  final lastNotifiedBg = prefs.getString('last_notified_for_version_bg');
  if (lastNotifiedBg == latestVersion) {
    print("📌 [Arka plan] Bu sürüm için zaten bildirim gönderildi");
    return;
  }

  await prefs.setString('last_notified_for_version_bg', latestVersion);

  await flutterLocalNotificationsPlugin.show(
    id: 0,
    title: "🎉 Yeni Güncelleme Mevcut!",
    body: "v$latestVersion sürümü yayınlandı. Dokunun ve güncelleyin!",
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'update_channel',
        'Güncelleme Bildirimleri',
        importance: Importance.max,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: latestData['downloadUrl'],
  );
}

Future<void> checkForNewNotificationsBackground() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null || userId.isEmpty) return;

    final lastCheckStr = prefs.getString('last_notification_check');
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr) ??
              DateTime.now().subtract(const Duration(hours: 1))
        : DateTime.now().subtract(const Duration(hours: 1));

    final response = await http
        .get(Uri.parse("$_baseUrl?sheet=notifications"))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return;

    final decoded = json.decode(response.body);
    if (decoded['success'] != true) return;

    final List<dynamic> allNotifications = decoded['data'] ?? [];
    final String userIdStr = userId.trim();

    final newNotifications = allNotifications.where((item) {
      final recipientId = item['recipient_id']?.toString().trim() ?? '';
      final isRead = item['is_read']?.toString().toUpperCase() ?? 'FALSE';
      final sentAtStr = item['sent_at']?.toString() ?? '';

      final isForUser = recipientId == 'all' || recipientId == userIdStr;
      if (!isForUser) return false;
      if (isRead == 'TRUE') return false;

      final sentAt = _parseDateTime(sentAtStr);
      return sentAt.isAfter(lastCheck);
    }).toList();

    if (newNotifications.isNotEmpty) {
      if (newNotifications.length == 1) {
        final notif = newNotifications.first;
        await showAppNotification(
          id: 10,
          title: notif['title']?.toString() ?? 'Yeni Bildirim',
          body: notif['message']?.toString() ?? '',
        );
      } else {
        await showAppNotification(
          id: 10,
          title: '${newNotifications.length} Yeni Bildirim',
          body: 'Okumadığınız bildirimleriniz var.',
        );
      }
    }

    await prefs.setString(
      'last_notification_check',
      DateTime.now().toIso8601String(),
    );
  } catch (e) {
    // Sessiz geç
  }
}

DateTime _parseDateTime(String dateTimeStr) {
  try {
    if (dateTimeStr.contains('T')) return DateTime.parse(dateTimeStr);
    if (dateTimeStr.contains(' '))
      return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
    return DateTime(2000);
  } catch (_) {
    return DateTime(2000);
  }
}

Future<void> showAppNotification({
  required int id,
  required String title,
  required String body,
  String payload = 'open_notifications',
}) async {
  try {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'app_notifications',
      'Uygulama Bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  } catch (e) {
    // Sessiz geç
  }
}

Future<String> getCurrentVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    print("📱 Mevcut sürüm: $version");
    return version;
  } catch (_) {
    return "1.0.0";
  }
}

Future<Map<String, dynamic>?> getLatestReleaseFromGitHub() async {
  try {
    final url = Uri.parse(
      "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases/latest",
    );
    final response = await http
        .get(url, headers: {'Accept': 'application/vnd.github.v3+json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final assets = data['assets'] as List;
      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset != null) {
        String version = data['tag_name'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        print("📌 GitHub'daki en son sürüm: $version");
        return {
          'version': version,
          'downloadUrl': apkAsset['browser_download_url'],
          'releaseNotes': data['body'] ?? 'Yeni sürüm mevcut.',
        };
      }
    }
  } catch (e) {
    print("❌ GitHub kontrol hatası: $e");
  }
  return null;
}

bool isNewerVersion(String current, String latest) {
  if (current.isEmpty || latest.isEmpty) return false;

  final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');
  final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');

  if (cleanCurrent.isEmpty || cleanLatest.isEmpty) return false;

  List<int> parse(String v) {
    return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  final v1 = parse(cleanCurrent);
  final v2 = parse(cleanLatest);

  final maxLength = v1.length > v2.length ? v1.length : v2.length;

  for (var i = 0; i < maxLength; i++) {
    final v1Part = i < v1.length ? v1[i] : 0;
    final v2Part = i < v2.length ? v2[i] : 0;

    if (v2Part > v1Part) return true;
    if (v2Part < v1Part) return false;
  }

  return false;
}

// ============================================================
// APK İNDİR + KURULUM
// ============================================================

Future<void> downloadAndInstallApk(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  try {
    // Kurulum izni kontrolü
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          print("❌ Kurulum izni verilmedi, indirme durduruldu.");
          return;
        }
      }
    }

    final dir = await getTemporaryDirectory();
    final savePath = "${dir.path}/evom_spor_update.apk";

    final oldFile = File(savePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    print("⬇️ APK indiriliyor: $url");

    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;
          print("⬇️ İndirme: ${(progress * 100).toStringAsFixed(0)}%");
          onProgress?.call(progress);
        }
      },
    );

    print("✅ İndirme tamamlandı: $savePath");

    final downloadedFile = File(savePath);
    final fileSize = await downloadedFile.length();
    if (fileSize < 1024 * 1024) {
      print("❌ İndirilen dosya çok küçük ($fileSize byte), bozuk olabilir!");
      return;
    }

    final result = await OpenFilex.open(savePath);
    print("📦 Kurulum ekranı açıldı: ${result.message}");
  } catch (e) {
    print("❌ downloadAndInstallApk hatası: $e");
  }
}

Future<void> initBackgroundTask() async {
  if (!Platform.isAndroid) return;

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerPeriodicTask(
      "updateCheckPeriodic",
      backgroundUpdateTask,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );

    await Workmanager().registerPeriodicTask(
      "notificationCheckPeriodic",
      backgroundNotificationTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      "attendanceSyncPeriodic",
      backgroundAttendanceSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// FORCE UPDATE SCREEN
// ============================================================

class ForceUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> updateData;
  const ForceUpdateScreen({super.key, required this.updateData});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final updateData = widget.updateData;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Yeni Güncelleme Mevcut!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "v${updateData['version']} sürümü yayınlandı.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  updateData['releaseNotes'] ??
                      'Yeni özellikler ve hata düzeltmeleri',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.orange),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _progress > 0
                      ? "İndiriliyor... %${(_progress * 100).toStringAsFixed(0)}"
                      : "İndirme başlıyor...",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = updateData['downloadUrl'];
                      if (url == null) return;

                      setState(() {
                        _isDownloading = true;
                        _progress = 0.0;
                      });

                      await downloadAndInstallApk(
                        url,
                        onProgress: (p) {
                          if (mounted) {
                            setState(() => _progress = p);
                          }
                        },
                      );

                      if (mounted) {
                        setState(() => _isDownloading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Güncelle",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              if (!_isDownloading)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Daha Sonra",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MY APP
// ============================================================

class MyApp extends StatefulWidget {
  final bool initialHasInternet;
  const MyApp({super.key, required this.initialHasInternet});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _hasInternet;
  late InternetChecker _internetChecker;

  @override
  void initState() {
    super.initState();
    _hasInternet = widget.initialHasInternet;
    _internetChecker = InternetChecker();
    _internetChecker.startListening();

    _internetChecker.onInternetGained(() {
      if (mounted) {
        setState(() {
          _hasInternet = true;
        });
        _onInternetGained();
      }
    });

    _internetChecker.onInternetLost(() {
      if (mounted) {
        setState(() {
          _hasInternet = false;
        });
      }
    });
  }

  void _onInternetGained() {
    print("🌐 İnternet bağlantısı sağlandı, otomatik yenileme yapılıyor...");
  }

  void _onRetry() {
    setState(() {
      _hasInternet = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EVOM SPOR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _hasInternet
          ? const NetworkAwareWrapper(child: UnifiedLoginPage())
          : NoInternetScreen(onRetry: _onRetry, hasInternet: _hasInternet),
      routes: {'/notifications': (context) => const NotificationsPage()},
    );
  }
}

// ============================================================
// NO INTERNET SCREEN
// ============================================================

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final bool hasInternet;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
    required this.hasInternet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 72,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "İnternet Bağlantısı Yok",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "Tekrar Dene",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOTIFICATIONS PAGE
// ============================================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirimler"),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Henüz bildirim yok",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              "Yeni bildirimler geldiğinde burada görünecek.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
*/
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File; // 🔥 SADECE Platform ve File

import 'package:EVOM_SPOR/connectivity_banner.dart';
import 'package:EVOM_SPOR/connectivity_service.dart';
import 'package:EVOM_SPOR/core/db/local_db.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/internet/internet_check.dart';
import 'package:EVOM_SPOR/internet/internt_close.dart';
import 'package:EVOM_SPOR/internet/network_aware_wrapper.dart';
import 'package:EVOM_SPOR/local/hive_adapter.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 YENİ: Gerçek indirme + otomatik kurulum için gerekli paketler
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// Firebase paketleri
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Sayfalar
import 'package:EVOM_SPOR/unifiedLoginPage.dart';

// 🔥 Tek backend URL kaynağı
import 'package:EVOM_SPOR/config.dart';

// ============================================================
// GLOBAL TANIMLAR
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "EVOM_SPOR";
const String _baseUrl = kBackendUrl; // 🔥 DEĞİŞTİ: config.dart'tan

const String backgroundUpdateTask = "updateCheckTask";
const String backgroundNotificationTask = "notificationCheckTask";
const String backgroundAttendanceSyncTask = "attendanceSyncTask";

// ============================================================
// 🔥 FIREBASE ARKA PLAN HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification?.title ?? 'Bildirim',
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'app_notifications',
          'Uygulama Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND TASK CALLBACK
// ============================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundUpdateTask) {
      await checkForUpdateBackground();
    } else if (taskName == backgroundNotificationTask) {
      await checkForNewNotificationsBackground();
    } else if (taskName == backgroundAttendanceSyncTask) {
      await syncAttendancesInBackground();
    }
    return Future.value(true);
  });
}

// ============================================================
// MAIN - İNTERNET KONTROLLÜ
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService().startMonitoring();
  // Türkçe locale
  await LocalDb.I.db.then((d) => d.delete('outbox'));
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    Intl.defaultLocale = 'tr_TR';
  }

  // Önce internet kontrolü yap
  final hasInternet = await _checkInternetOnStart();

  // UI başlat
  runApp(MyApp(initialHasInternet: hasInternet));

  // Arka plan işlemleri (UI bloklanmasın)
  unawaited(_initializeAppInBackground());
}

// 🔥 BAŞLANGIÇTA İNTERNET KONTROLÜ
Future<bool> _checkInternetOnStart() async {
  try {
    final results = await Connectivity().checkConnectivity();
    // 🔥 Sadece cihazın hiç bağlantısı yoksa "internet yok" say.
    // Zayıf/yavaş bağlantıda sunucu ping'i ile hemen "yok" deme.
    return results != ConnectivityResult.none;
  } catch (e) {
    return false;
  }
}

Future<void> syncAttendancesInBackground() async {
  try {
    final service = OfflineAttendanceService();
    await service.init();
    await service.processQueueNow();
  } catch (e) {
    // Sessiz geç
  }
}

// Arka planda başlatılacak tüm işlemler
Future<void> _initializeAppInBackground() async {
  // Internet checker dinleyicisi
  final internetChecker = InternetChecker();
  internetChecker.startListening();

  // Firebase başlat
  await Firebase.initializeApp();

  // Arka plan handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // İzinler
  unawaited(requestPermissions());

  // Bildirim servisi
  unawaited(initNotifications());

  // Firebase topic
  _subscribeToTopicWithTimeout();

  // Token işlemleri
  _setupFirebaseTokenHandling();

  // Arka plan görevleri
  unawaited(initBackgroundTask());

  // Güncelleme kontrolü
  _scheduleUpdateCheck();

  if (Platform.isIOS) {
    _startIOSPeriodicCheck();
  }
}

// ============================================================
// TOPIC SUBSCRIBE
// ============================================================

void _subscribeToTopicWithTimeout() {
  Future.delayed(Duration.zero, () {
    FirebaseMessaging.instance
        .subscribeToTopic("all_users")
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint("⚠️ Topic subscribe timeout - skipping");
            return;
          },
        )
        .catchError((e) {
          debugPrint("⚠️ Topic subscribe error: $e");
        });
  });
}

// ============================================================
// FIREBASE TOKEN HANDLING
// ============================================================

void _setupFirebaseTokenHandling() async {
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToServer(token);
      }
    } catch (e) {
      debugPrint("⚠️ Token alınamadı: $e");
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    _saveTokenToServer(newToken);
  });
}

// ============================================================
// FCM TOKEN KAYDET
// ============================================================
Future<void> _saveTokenToServer(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null) return;

    await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'updateFcmToken',
            'user_id': userId,
            'fcm_token': token,
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // Sessizce başarısız ol
  }
}

// ============================================================
// GÜNCELLEME KONTROL ZAMANLAMA
// ============================================================

void _scheduleUpdateCheck() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 3), () async {
      await checkForUpdateWithNotification();
    });
  });
}

Future<void> _trackAppVersion() async {
  try {
    // 1️⃣ Kullanıcı bilgilerini al
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');

    if (userJson == null) {
      print("📌 Kullanıcı oturum açmamış, sürüm takibi atlandı");
      return;
    }

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString() ?? '';
    final email = userMap['email']?.toString() ?? '';
    String deviceInfo = Platform.operatingSystem; // "android" veya "ios"
    if (userId.isEmpty) {
      print("📌 Kullanıcı ID boş, sürüm takibi atlandı");
      return;
    }

    // 2️⃣ Uygulama sürümünü al
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;

    // 3️⃣ Cihaz bilgisini al
    // final deviceInfo = await _getDeviceInfo();

    print("📱 Sürüm takibi gönderiliyor:");
    print("   User ID: $userId");
    print("   Email: $email");
    print("   Sürüm: $appVersion");
    //print("   Cihaz: $deviceInfo");

    // 4️⃣ Apps Script'e gönder
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'trackAppVersion',
            'user_id': userId,
            'email': email,
            'app_version': appVersion,

            /// 'device_info': deviceInfo,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        print("✅ Sürüm takibi başarıyla kaydedildi!");
      } else {
        print("❌ Sürüm takibi başarısız: ${decoded['error']}");
      }
    } else {
      print("❌ HTTP hatası: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Sürüm takibi hatası: $e");
  }
}

// 🔥 CİHAZ BİLGİSİ AL
// 🔥 CİHAZ BİLGİSİ AL - PAKETSİZ
// 📱 CİHAZ BİLGİSİ - BASİT VE GÜVENLİ

// iOS versiyonunu almak için
Future<String> _getIOSVersion() async {
  try {
    // iOS'te sistem versiyonunu almanın basit yolu
    // UIDevice.current.systemVersion'a erişemiyoruz,
    // ama device_info_plus olmadan tam bilgi zor
    return "iOS";
  } catch (e) {
    return "iOS";
  }
}
// ============================================================
// GÜNCELLEME KONTROLÜ - ANA
// ============================================================

Future<void> checkForUpdateWithNotification() async {
  // 1️⃣ İNTERNET KONTROLÜ
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    print("📌 İnternet yok, güncelleme kontrolü atlandı");
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  // 2️⃣ TELEFONDAKİ GERÇEK KURULU SÜRÜM
  final currentVersion = await getCurrentVersion();
  print("📱 Telefondaki GERÇEK kurulu sürüm: $currentVersion");

  // 3️⃣ GITHUB'DAN EN SON SÜRÜMÜ AL
  final latestData = await getLatestReleaseFromGitHub();
  if (latestData == null) {
    print("📌 GitHub'dan sürüm bilgisi alınamadı");
    return;
  }

  final latestVersion = latestData['version'] ?? '';
  print("📌 GitHub'daki en son sürüm: $latestVersion");

  // 4️⃣ GÜNCEL Mİ?
  if (currentVersion == latestVersion ||
      !isNewerVersion(currentVersion, latestVersion)) {
    print(
      "✅ Uygulama zaten güncel! (Telefon: $currentVersion, GitHub: $latestVersion)",
    );
    await prefs.remove('last_notified_for_version');
    return;
  }

  // 5️⃣ BU SÜRÜM İÇİN ZATEN GÖSTERİLDİ Mİ?
  final lastNotified = prefs.getString('last_notified_for_version');
  if (lastNotified == latestVersion) {
    print("📌 $latestVersion için ekran zaten gösterildi");
    return;
  }

  await prefs.setString('last_notified_for_version', latestVersion);

  print("🔄 Yeni sürüm bulundu! $currentVersion -> $latestVersion");

  // 6️⃣ KULLANICIYA GÖSTER
  if (navigatorKey.currentState?.context != null) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ForceUpdateScreen(updateData: latestData),
      ),
      (route) => false,
    );
  }
}

// ============================================================
// iOS PERİYODİK KONTROL
// ============================================================

Timer? _iosPeriodicTimer;

void _startIOSPeriodicCheck() {
  _iosPeriodicTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
    await checkForNewNotificationsBackground();
  });
}

// ============================================================
// İZİN YÖNETİMİ
// ============================================================

Future<void> requestPermissions() async {
  try {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// BİLDİRİM SERVİSİ
// ============================================================

Future<void> initNotifications() async {
  try {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'open_notifications') {
          navigatorKey.currentState?.pushNamed('/notifications');
        } else if (response.payload != null &&
            response.payload!.startsWith('http')) {
          downloadAndInstallApk(response.payload!);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'update_channel',
          'Güncelleme Bildirimleri',
          description: 'Uygulama güncellemeleri',
          importance: Importance.high,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'app_notifications',
          'Uygulama Bildirimleri',
          description: 'Duyurular, ödemeler, yoklama bildirimleri',
          importance: Importance.high,
        ),
      );
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// GÜNCELLEME KONTROL FONKSİYONLARI
// ============================================================

Future<void> checkForUpdateBackground() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final prefs = await SharedPreferences.getInstance();

  final currentVersion = await getCurrentVersion();
  print("📱 [Arka plan] Telefon sürümü: $currentVersion");

  final latestData = await getLatestReleaseFromGitHub();
  if (latestData == null) return;

  final latestVersion = latestData['version'] ?? '';
  print("📌 [Arka plan] GitHub sürümü: $latestVersion");

  if (currentVersion == latestVersion ||
      !isNewerVersion(currentVersion, latestVersion)) {
    print("✅ [Arka plan] Zaten güncel");
    await prefs.remove('last_notified_for_version_bg');
    return;
  }

  final lastNotifiedBg = prefs.getString('last_notified_for_version_bg');
  if (lastNotifiedBg == latestVersion) {
    print("📌 [Arka plan] Bu sürüm için zaten bildirim gönderildi");
    return;
  }

  await prefs.setString('last_notified_for_version_bg', latestVersion);

  await flutterLocalNotificationsPlugin.show(
    id: 0,
    title: "🎉 Yeni Güncelleme Mevcut!",
    body: "v$latestVersion sürümü yayınlandı. Dokunun ve güncelleyin!",
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'update_channel',
        'Güncelleme Bildirimleri',
        importance: Importance.max,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: latestData['downloadUrl'],
  );
}

Future<void> checkForNewNotificationsBackground() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null || userId.isEmpty) return;

    final lastCheckStr = prefs.getString('last_notification_check');
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr) ??
              DateTime.now().subtract(const Duration(hours: 1))
        : DateTime.now().subtract(const Duration(hours: 1));

    final response = await http
        .get(Uri.parse("$_baseUrl?sheet=notifications"))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return;

    final decoded = json.decode(response.body);
    if (decoded['success'] != true) return;

    final List<dynamic> allNotifications = decoded['data'] ?? [];
    final String userIdStr = userId.trim();

    final newNotifications = allNotifications.where((item) {
      final recipientId = item['recipient_id']?.toString().trim() ?? '';
      final isRead = item['is_read']?.toString().toUpperCase() ?? 'FALSE';
      final sentAtStr = item['sent_at']?.toString() ?? '';

      final isForUser = recipientId == 'all' || recipientId == userIdStr;
      if (!isForUser) return false;
      if (isRead == 'TRUE') return false;

      final sentAt = _parseDateTime(sentAtStr);
      return sentAt.isAfter(lastCheck);
    }).toList();

    if (newNotifications.isNotEmpty) {
      if (newNotifications.length == 1) {
        final notif = newNotifications.first;
        await showAppNotification(
          id: 10,
          title: notif['title']?.toString() ?? 'Yeni Bildirim',
          body: notif['message']?.toString() ?? '',
        );
      } else {
        await showAppNotification(
          id: 10,
          title: '${newNotifications.length} Yeni Bildirim',
          body: 'Okumadığınız bildirimleriniz var.',
        );
      }
    }

    await prefs.setString(
      'last_notification_check',
      DateTime.now().toIso8601String(),
    );
  } catch (e) {
    // Sessiz geç
  }
}

DateTime _parseDateTime(String dateTimeStr) {
  try {
    if (dateTimeStr.contains('T')) return DateTime.parse(dateTimeStr);
    if (dateTimeStr.contains(' '))
      return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
    return DateTime(2000);
  } catch (_) {
    return DateTime(2000);
  }
}

Future<void> showAppNotification({
  required int id,
  required String title,
  required String body,
  String payload = 'open_notifications',
}) async {
  try {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'app_notifications',
      'Uygulama Bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  } catch (e) {
    // Sessiz geç
  }
}

Future<String> getCurrentVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    print("📱 Mevcut sürüm: $version");
    return version;
  } catch (_) {
    return "1.0.0";
  }
}

Future<Map<String, dynamic>?> getLatestReleaseFromGitHub() async {
  try {
    final url = Uri.parse(
      "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases/latest",
    );
    final response = await http
        .get(url, headers: {'Accept': 'application/vnd.github.v3+json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final assets = data['assets'] as List;
      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset != null) {
        String version = data['tag_name'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        print("📌 GitHub'daki en son sürüm: $version");
        return {
          'version': version,
          'downloadUrl': apkAsset['browser_download_url'],
          'releaseNotes': data['body'] ?? 'Yeni sürüm mevcut.',
        };
      }
    }
  } catch (e) {
    print("❌ GitHub kontrol hatası: $e");
  }
  return null;
}

bool isNewerVersion(String current, String latest) {
  if (current.isEmpty || latest.isEmpty) return false;

  final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');
  final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');

  if (cleanCurrent.isEmpty || cleanLatest.isEmpty) return false;

  List<int> parse(String v) {
    return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  final v1 = parse(cleanCurrent);
  final v2 = parse(cleanLatest);

  final maxLength = v1.length > v2.length ? v1.length : v2.length;

  for (var i = 0; i < maxLength; i++) {
    final v1Part = i < v1.length ? v1[i] : 0;
    final v2Part = i < v2.length ? v2[i] : 0;

    if (v2Part > v1Part) return true;
    if (v2Part < v1Part) return false;
  }

  return false;
}

// ============================================================
// APK İNDİR + KURULUM
// ============================================================

Future<void> downloadAndInstallApk(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  try {
    // Kurulum izni kontrolü
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          print("❌ Kurulum izni verilmedi, indirme durduruldu.");
          return;
        }
      }
    }

    final dir = await getTemporaryDirectory();
    final savePath = "${dir.path}/evom_spor_update.apk";

    final oldFile = File(savePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    print("⬇️ APK indiriliyor: $url");

    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;
          print("⬇️ İndirme: ${(progress * 100).toStringAsFixed(0)}%");
          onProgress?.call(progress);
        }
      },
    );

    print("✅ İndirme tamamlandı: $savePath");

    final downloadedFile = File(savePath);
    final fileSize = await downloadedFile.length();
    if (fileSize < 1024 * 1024) {
      print("❌ İndirilen dosya çok küçük ($fileSize byte), bozuk olabilir!");
      return;
    }

    final result = await OpenFilex.open(savePath);
    print("📦 Kurulum ekranı açıldı: ${result.message}");
  } catch (e) {
    print("❌ downloadAndInstallApk hatası: $e");
  }
}

Future<void> initBackgroundTask() async {
  if (!Platform.isAndroid) return;

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerPeriodicTask(
      "updateCheckPeriodic",
      backgroundUpdateTask,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );

    await Workmanager().registerPeriodicTask(
      "notificationCheckPeriodic",
      backgroundNotificationTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      "attendanceSyncPeriodic",
      backgroundAttendanceSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// FORCE UPDATE SCREEN
// ============================================================

class ForceUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> updateData;
  const ForceUpdateScreen({super.key, required this.updateData});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final updateData = widget.updateData;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Yeni Güncelleme Mevcut!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "v${updateData['version']} sürümü yayınlandı.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  updateData['releaseNotes'] ??
                      'Yeni özellikler ve hata düzeltmeleri',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.orange),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _progress > 0
                      ? "İndiriliyor... %${(_progress * 100).toStringAsFixed(0)}"
                      : "İndirme başlıyor...",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = updateData['downloadUrl'];
                      if (url == null) return;

                      setState(() {
                        _isDownloading = true;
                        _progress = 0.0;
                      });

                      await downloadAndInstallApk(
                        url,
                        onProgress: (p) {
                          if (mounted) {
                            setState(() => _progress = p);
                          }
                        },
                      );

                      if (mounted) {
                        setState(() => _isDownloading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Güncelle",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              if (!_isDownloading)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Daha Sonra",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MY APP
// ============================================================

class MyApp extends StatefulWidget {
  final bool initialHasInternet;
  const MyApp({super.key, required this.initialHasInternet});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _hasInternet;
  late InternetChecker _internetChecker;

  @override
  void initState() {
    super.initState();
    _hasInternet = widget.initialHasInternet;
    _internetChecker = InternetChecker();
    _internetChecker.startListening();

    _internetChecker.onInternetGained(() {
      if (mounted) {
        setState(() {
          _hasInternet = true;
        });
        _onInternetGained();
      }
    });

    _internetChecker.onInternetLost(() {
      if (mounted) {
        setState(() {
          _hasInternet = false;
        });
      }
    });
  }

  void _onInternetGained() {
    print("🌐 İnternet bağlantısı sağlandı, otomatik yenileme yapılıyor...");
  }

  void _onRetry() {
    setState(() {
      _hasInternet = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EVOM SPOR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return ConnectivityBanner(child: child ?? const SizedBox.shrink());
      },
      // 🔽 BURAYI EKLEmelisin:
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      locale: const Locale('tr', 'TR'),
      // -------------------
      home: _hasInternet
          ? const NetworkAwareWrapper(child: UnifiedLoginPage())
          : NoInternetScreen(onRetry: _onRetry, hasInternet: _hasInternet),
      routes: {'/notifications': (context) => const NotificationsPage()},
    );
  }
}

// ============================================================
// NO INTERNET SCREEN
// ============================================================

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final bool hasInternet;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
    required this.hasInternet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 72,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "İnternet Bağlantısı Yok",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "Tekrar Dene",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOTIFICATIONS PAGE
// ============================================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirimler"),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Henüz bildirim yok",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              "Yeni bildirimler geldiğinde burada görünecek.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

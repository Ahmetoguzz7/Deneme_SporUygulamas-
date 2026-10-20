/*
  LocalNotificationService.dart - Mobil platformlarda yerel bildirimler için servis sınıfı
  - Sadece Android ve iOS'ta çalışır, web ve masaüstünde devre dışı bırakılır
  - Doğum günü, özel gün ve duyuru bildirimleri için hazır fonksiyonlar içerir
  - Her platformda çalışacak şekilde SnackBar desteği sağlar
*/
/*
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Sadece mobil platformlarda çalış
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);
    _isInitialized = true;

    // print Bildirim servisi başlatıldı");
  }

  // 🔥 BASİT BİLDİRİM GÖSTER
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidDetails = AndroidNotificationDetails(
      'sport_channel',
      'Spor Uygulaması',
      channelDescription: 'Spor uygulaması bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
    // print Bildirim gönderildi: $title");
  }

  // 🔥 DOĞUM GÜNÜ BİLDİRİMİ
  Future<void> showBirthdayNotification(String studentName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "🎂 Doğum Günü!",
      body: "$studentName bugün doğum gününü kutluyor! Onu tebrik edelim.",
    );
  }

  // 🔥 ÖZEL GÜN BİLDİRİMİ
  Future<void> showSpecialDayNotification(
    String eventName,
    String message,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "📅 $eventName",
      body: message,
    );
  }

  // 🔥 YENİ DUYURU BİLDİRİMİ
  Future<void> showAnnouncementNotification(
    String title,
    String message,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "📢 Yeni Duyuru: $title",
      body: message.length > 100 ? message.substring(0, 100) + "..." : message,
    );
  }

  // 🔥 SNAcKBAR (HER PLATFORMDA ÇALIŞIR)
  void showSnackBar({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
*/ // services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Set<String> _sentNotificationIds = {};

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'duyurular_channel',
      'Duyurular',
      description: 'Yeni duyurular için bildirimler',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _loadSentNotifications();
  }

  // 🔥 PAYLOAD'LU showNotification
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    String? type,
    String? payload, // 🚀 PAYLOAD EKLENDİ
  }) async {
    if (_sentNotificationIds.contains(id)) {
      // print Bildirim daha önce gönderildi: $id");
      return;
    }

    try {
      final int notificationId = id.hashCode;

      final styleInformation = type == 'urgent'
          ? BigTextStyleInformation(body, htmlFormatBigText: true)
          : const BigTextStyleInformation('');

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'duyurular_channel',
            'Duyurular',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: styleInformation,
            autoCancel: true,
            enableVibration: true,
            playSound: true,
            channelShowBadge: true,
          );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      // 🔥 payload ile gönder
      await _notifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload, // payload burada kullanılıyor
      );

      await _saveSentNotification(id);
      // print Bildirim gönderildi: $title (payload: $payload)");
    } catch (e) {
      // print Bildirim hatası: $e");
    }
  }

  // Basit bildirim (payload'suz)
  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'duyurular_channel',
            'Duyurular',
            importance: Importance.high,
            priority: Priority.high,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      // print Basit bildirim hatası: $e");
    }
  }

  Future<void> _loadSentNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final sentList = prefs.getStringList('sent_notifications') ?? [];
    _sentNotificationIds = sentList.toSet();
  }

  Future<void> _saveSentNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _sentNotificationIds.add(id);
    await prefs.setStringList(
      'sent_notifications',
      _sentNotificationIds.toList(),
    );
  }

  Future<void> requestPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> clearAllNotifications() async {
    await _notifications.cancelAll();
  }
}

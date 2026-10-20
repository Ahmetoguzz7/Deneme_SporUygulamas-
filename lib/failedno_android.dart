import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class CompatibilityHelper {
  // 🔥 ANDROİD SÜRÜMÜNÜ KONTROL ET (DÜZELTİLMİŞ)
  static bool isAndroidVersionBelow(int version) {
    if (!Platform.isAndroid) return false;

    try {
      final versionStr = Platform.version;
      if (versionStr.isEmpty) return false;

      final parts = versionStr.split('.');
      if (parts.isEmpty) return false;

      final sdkVersion = int.tryParse(parts[0]) ?? 0;
      return sdkVersion < version;
    } catch (e) {
      return false;
    }
  }

  // 🔥 NOTFİCATİON İZNİ KONTROLÜ (Android 13+)
  static Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    final androidVersion = await _getAndroidVersion();
    if (androidVersion < 33) return true; // Android 13 öncesi izin gerekmez

    // Android 13+ için izin kontrolü
    final permission = Permission.notification;
    final status = await permission.status;

    if (status.isDenied) {
      final result = await permission.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  // 🔥 ANDROİD VERSİYONU AL (SDK)
  static Future<int> _getAndroidVersion() async {
    try {
      // Platform.version zaten SDK versiyonunu veriyor
      final versionStr = Platform.version;
      if (versionStr.isEmpty) return 0;

      final parts = versionStr.split('.');
      if (parts.isEmpty) return 0;

      return int.tryParse(parts[0]) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // 🔥 ANDROİD SDK VERSİYONUNU AL (Alternatif - daha güvenli)
  static Future<int> getAndroidSdkVersion() async {
    return await _getAndroidVersion();
  }

  // 🔥 BİLDİRİM KANALI OLUŞTUR (ESKİ ANDROİDLER İÇİN)
  static Future<void> createNotificationChannel(
    String channelId,
    String channelName,
  ) async {
    if (!Platform.isAndroid) return;

    final androidVersion = await _getAndroidVersion();
    if (androidVersion >= 26) {
      // Android 8+
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              channelId,
              channelName,
              importance: Importance.high,
            ),
          );
    }
  }

  // 🔥 IMAGE CACHE DESTEĞİ (ESKİ ANDROİDLER İÇİN)
  static void clearImageCache() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      // Eski Android'lerde hata olursa sessiz geç
      debugPrint("Image cache temizlenemedi: $e");
    }
  }

  // 🔥 SCHEDULE EXACT ALARM KONTROLÜ (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    final androidVersion = await _getAndroidVersion();
    if (androidVersion < 31) return true; // Android 12 öncesi sorun yok

    final alarmPermission = await Permission.scheduleExactAlarm.status;
    if (alarmPermission.isDenied) {
      await Permission.scheduleExactAlarm.request();
      return await Permission.scheduleExactAlarm.isGranted;
    }
    return alarmPermission.isGranted;
  }

  // 🔥 INTERNET DURUMU (ESKİ ANDROİDLERDE DAHA GÜVENLİ)
  static Future<bool> isInternetAvailable() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 🔥 CİHAZ BİLGİLERİNİ AL
  static Map<String, dynamic> getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.version,
      'isAndroid': Platform.isAndroid,
      'isIOS': Platform.isIOS,
    };
  }
}

/*
  Bu sınıf, özel günler için bildirimleri zamanlamak ve göndermekle sorumludur.
  Uygulama her açıldığında ve her gün saat 09:00'da özel günleri kontrol eder.
  Eğer o gün doğum günü, tatil veya Sevgililer Günü varsa, ilgili bildirimler gönderilir.
*/
/*
import 'dart:async';
import 'special_day_service.dart';

class NotificationScheduler {
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  Timer? _timer;

  void start() {
    // Her gün saat 09:00'da kontrol et
    _scheduleDailyCheck();

    // Uygulama her açıldığında da kontrol et
    _checkNow();
  }

  void _scheduleDailyCheck() {
    final now = DateTime.now();
    final nextCheck = DateTime(now.year, now.month, now.day, 9, 0);

    final delay = nextCheck.isAfter(now)
        ? nextCheck.difference(now)
        : Duration(days: 1) - now.difference(nextCheck);

    _timer = Timer(delay, () {
      _checkNow();
      // Her 24 saatte bir tekrar kontrol et
      Timer.periodic(const Duration(hours: 24), (_) => _checkNow());
    });
  }

  Future<void> _checkNow() async {
    print("🔍 Özel gün kontrolü yapılıyor...");

    final service = SpecialDayService();
    await service.initialize();
    await service.checkBirthdays();
    await service.checkHolidays();
    await service.checkValentinesDay();

    print("✅ Özel gün kontrolü tamamlandı");
  }

  void dispose() {
    _timer?.cancel();
  }
}
*/

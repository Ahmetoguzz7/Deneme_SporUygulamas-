/*
  Bu dosya, özel günler için bildirimleri yönetir. Doğum günleri, bayramlar ve diğer önemli günler için bildirimler gönderir.
  Kullanıcıların doğum günlerini Google Sheets'ten çekerek her yıl tekrarlayan bildirimler oluşturur.
  Ayrıca, Ramazan Bayramı, Kurban Bayramı, Yılbaşı gibi önemli günlerde genel bildirimler gösterir.
*/
/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class SpecialDayService {
  static final SpecialDayService _instance = SpecialDayService._internal();
  factory SpecialDayService() => _instance;
  SpecialDayService._internal();

  final LocalNotificationService _notification = LocalNotificationService();

  // Tüm kullanıcıları tut
  List<Users> _allUsers = [];

  // Daha önce bildirimi gönderilenleri tut
  Set<String> _sentNotifications = {};

  Future<void> initialize() async {
    await _notification.initialize();
    await _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    _allUsers = await GoogleSheetService.getUsers();
  }

  // 🔥 DOĞUM GÜNÜ KONTROLÜ
  Future<void> checkBirthdays() async {
    final today = DateTime.now();

    for (var user in _allUsers) {
      if (user.b_date.isEmpty) continue;

      try {
        final birthDate = DateTime.parse(user.b_date);

        // Bugün doğum günü mü?
        if (birthDate.month == today.month && birthDate.day == today.day) {
          final notificationKey = "birthday_${user.app}_${today.year}";

          // Bu yıl için bildirim gönderilmediyse
          if (!_sentNotifications.contains(notificationKey)) {
            final fullName = "${user.first_name} ${user.last_name}".trim();
            await _notification.showBirthdayNotification(fullName);
            _sentNotifications.add(notificationKey);

            // print Doğum günü bildirimi gönderildi: $fullName");
          }
        }
      } catch (e) {
        // printoğum günü kontrol hatası: $e");
      }
    }
  }

  // 🔥 BAYRAM KONTROLÜ
  Future<void> checkHolidays() async {
    final today = DateTime.now();

    // RAMAZAN BAYRAMI (2026 için örnek tarih)
    if (today.month == 3 && today.day == 30) {
      await _notification.showSpecialDayNotification(
        "Ramazan Bayramı",
        "Ramazan Bayramınız mübarek olsun! Sevgi ve huzur dolu nice bayramlara.",
      );
    }

    // KURBAN BAYRAMI (2026 için örnek tarih)
    if (today.month == 6 && today.day == 6) {
      await _notification.showSpecialDayNotification(
        "Kurban Bayramı",
        "Kurban Bayramınız mübarek olsun! Sağlık, mutluluk ve huzur dolu nice bayramlara.",
      );
    }

    // YILBAŞI
    if (today.month == 1 && today.day == 1) {
      await _notification.showSpecialDayNotification(
        "Yılbaşı",
        "Yeni yılınız kutlu olsun! 2026'da birlikte nice başarılara.",
      );
    }

    // 23 NİSAN
    if (today.month == 4 && today.day == 23) {
      await _notification.showSpecialDayNotification(
        "23 Nisan Ulusal Egemenlik ve Çocuk Bayramı",
        "Egemenlik kayıtsız şartsız milletindir! 23 Nisan kutlu olsun.",
      );
    }

    // 19 MAYIS
    if (today.month == 5 && today.day == 19) {
      await _notification.showSpecialDayNotification(
        "19 Mayıs Atatürk'ü Anma, Gençlik ve Spor Bayramı",
        "Gençler! Spor yapın, sağlıklı kalın! 19 Mayıs kutlu olsun.",
      );
    }

    // 30 AĞUSTOS
    if (today.month == 8 && today.day == 30) {
      await _notification.showSpecialDayNotification(
        "30 Ağustos Zafer Bayramı",
        "Zafer Bayramımız kutlu olsun! Türk milletinin bağımsızlık mücadelesinin simgesi.",
      );
    }

    // 29 EKİM
    if (today.month == 10 && today.day == 29) {
      await _notification.showSpecialDayNotification(
        "29 Ekim Cumhuriyet Bayramı",
        "Cumhuriyet Bayramımız kutlu olsun! Türkiye yüzyılında nice yüzyıllara.",
      );
    }

    // ANNELER GÜNÜ (Mayıs ayının 2. Pazarı)
    if (today.month == 5 && today.weekday == DateTime.sunday) {
      final secondSunday = (today.day >= 8 && today.day <= 14);
      if (secondSunday) {
        await _notification.showSpecialDayNotification(
          "Anneler Günü",
          "Anneler Gününüz kutlu olsun! Annelerimize sevgi ve saygıyla.",
        );
      }
    }

    // BABALAR GÜNÜ (Haziran ayının 3. Pazarı)
    if (today.month == 6 && today.weekday == DateTime.sunday) {
      final thirdSunday = (today.day >= 15 && today.day <= 21);
      if (thirdSunday) {
        await _notification.showSpecialDayNotification(
          "Babalar Günü",
          "Babalar Gününüz kutlu olsun! Babalarımıza sevgi ve saygıyla.",
        );
      }
    }
  }

  // 🔥 SEVGİLİLER GÜNÜ
  Future<void> checkValentinesDay() async {
    final today = DateTime.now();
    if (today.month == 2 && today.day == 14) {
      await _notification.showSpecialDayNotification(
        "Sevgililer Günü",
        "Sevgililer Gününüz kutlu olsun! ❤️",
      );
    }
  }
}
*/

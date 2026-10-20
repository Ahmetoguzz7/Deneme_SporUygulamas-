// lib/core/background_sync_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';

class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  final List<VoidCallback> _onSyncCallbacks = [];

  // 🔥 AppRepository referansı (callback ile güncelleme yapılacak)
  Function(
    List<Users>,
    List<Group>,
    List<GroupStudent>,
    List<Payment>,
    List<Attendance>,
    List<Coach>,
    List<Notifications>,
  )?
  _onDataUpdated;

  static const Duration _syncInterval = Duration(minutes: 15);

  void startPeriodicSync() {
    print(
      "🔄 Periyodik senkronizasyon başlatıldı (${_syncInterval.inMinutes} dakikada bir)",
    );

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      /*AppRepository()
          .syncDelta();*/ // artık tüm veriyi değil, sadece yeniyi çeker
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print("⏹️ Periyodik senkronizasyon durduruldu");
  }

  /// 🔥 YENİ: AppRepository'den güncelleme callback'i al
  void setOnDataUpdatedCallback(
    Function(
      List<Users>,
      List<Group>,
      List<GroupStudent>,
      List<Payment>,
      List<Attendance>,
      List<Coach>,
      List<Notifications>,
    )
    callback,
  ) {
    _onDataUpdated = callback;
    print("✅ AppRepository callback'i eklendi");
  }

  Future<void> syncNow({bool force = false}) async {
    if (_isSyncing && !force) {
      print("⚠️ Senkronizasyon zaten devam ediyor, atlanıyor...");
      return;
    }
    await _syncInBackground(force: force);
  }

  Future<void> _syncInBackground({bool force = false}) async {
    if (_isSyncing) return;

    _isSyncing = true;
    print("🔄 Arka plan senkronizasyonu başladı...");

    try {
      final localStorage = LocalStorageService();

      // Internet'ten en güncel verileri çek
      final results = await Future.wait([
        GoogleSheetService.getUsersCached(forceRefresh: true),
        GoogleSheetService.getGroupsCached(forceRefresh: true),
        GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
        GoogleSheetService.getPaymentsCached(forceRefresh: true),
        GoogleSheetService.getAttendancesCached(forceRefresh: true),
        GoogleSheetService.getCoachesCached(forceRefresh: true),
        GoogleSheetService.getNotifications(userId: "all", forceRefresh: true),
      ]);

      final users = results[0] as List<Users>;
      final groups = results[1] as List<Group>;
      final groupStudents = results[2] as List<GroupStudent>;
      final payments = results[3] as List<Payment>;
      final attendances = results[4] as List<Attendance>;
      final coaches = results[5] as List<Coach>;
      final notifications = results[6] as List<Notifications>;

      // Lokale kaydet
      await localStorage.saveAllData(
        users: users,
        groups: groups,
        groupStudents: groupStudents,
        payments: payments,
        attendances: attendances,
        coaches: coaches,
        notifications: notifications,
      );

      // 🔥 KRİTİK: AppRepository'deki RAM verilerini güncelle
      if (_onDataUpdated != null) {
        _onDataUpdated!(
          users,
          groups,
          groupStudents,
          payments,
          attendances,
          coaches,
          notifications,
        );
        print("✅ AppRepository RAM verileri güncellendi!");
      }

      print("✅ Arka plan senkronizasyonu tamamlandı!");

      for (var callback in _onSyncCallbacks) {
        callback();
      }
    } catch (e) {
      print("❌ Arka plan senkronizasyon hatası: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void addSyncListener(VoidCallback callback) {
    _onSyncCallbacks.add(callback);
  }

  void removeSyncListener(VoidCallback callback) {
    _onSyncCallbacks.remove(callback);
  }

  void dispose() {
    stopPeriodicSync();
  }
}

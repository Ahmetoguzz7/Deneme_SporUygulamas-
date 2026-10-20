import 'dart:async';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

class OfflinePaymentService {
  static final OfflinePaymentService _instance =
      OfflinePaymentService._internal();
  factory OfflinePaymentService() => _instance;
  OfflinePaymentService._internal();

  late final LocalStorageService _localStorage;
  late Box _queueBox;
  final List<QueuedPayment> _paymentQueue = [];
  final StreamController<void> _paymentSyncController =
      StreamController.broadcast();
  Stream<void> get onPaymentSynced => _paymentSyncController.stream;

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _localStorage = LocalStorageService();
    await _localStorage.init();
    _queueBox = await Hive.openBox('payment_queue_box');
    await _loadQueueFromStorage();
    _startPeriodicSync();
    _isInitialized = true;
    print(
      "✅ OfflinePaymentService başlatıldı, kuyrukta ${_paymentQueue.length} işlem",
    );
  }

  Future<bool> savePayment(Payment payment) async {
    if (_isDisposed) return false;

    try {
      final localPayments = _localStorage.getPayments();
      final newPayment = Payment(
        payments_id: _generateLocalId(),
        student_id: payment.student_id,
        groups_id: payment.groups_id,
        recorded_by: payment.recorded_by,
        amount: payment.amount,
        due_date: payment.due_date,
        paid_date: payment.paid_date,
        status: payment.status,
        payment_method: payment.payment_method,
        note: payment.note,
      );

      localPayments.add(newPayment);
      await _localStorage.savePayments(localPayments);

      _paymentQueue.add(
        QueuedPayment(
          localId: newPayment.payments_id,
          payment: newPayment,
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      _paymentSyncController.add(null);
      unawaited(_processQueue());

      print("✅ Ödeme LOKAL'e kaydedildi: ${payment.amount} TL");
      return true;
    } catch (e) {
      print("❌ Lokal kayıt hatası: $e");
      return false;
    }
  }

  /// 🔥 TOPLU ÖDEME KAYDET
  Future<bool> savePaymentsBatch(List<Payment> payments) async {
    if (_isDisposed) return false;

    try {
      final localPayments = _localStorage.getPayments();

      for (var payment in payments) {
        final newPayment = Payment(
          payments_id: _generateLocalId(),
          student_id: payment.student_id,
          groups_id: payment.groups_id,
          recorded_by: payment.recorded_by,
          amount: payment.amount,
          due_date: payment.due_date,
          paid_date: payment.paid_date,
          status: payment.status,
          payment_method: payment.payment_method,
          note: payment.note,
        );

        localPayments.add(newPayment);

        _paymentQueue.add(
          QueuedPayment(
            localId: newPayment.payments_id,
            payment: newPayment,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _localStorage.savePayments(localPayments);
      await _saveQueueToStorage();

      _paymentSyncController.add(null);
      unawaited(_processQueue());

      print("✅ ${payments.length} ödeme LOKAL'e kaydedildi");
      return true;
    } catch (e) {
      print("❌ Toplu kayıt hatası: $e");
      return false;
    }
  }

  Timer? _quickRetryTimer;

  /// Ücret güncellemeleri (fee_update / fee_override) kuyrukta ÖNCE gider.
  bool _isFeeItem(QueuedPayment q) =>
      q.payment.status == 'fee_update' || q.payment.status == 'fee_override';

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (_isDisposed) return;

    _isProcessing = true;
    bool hadFailure = false;

    // 🔥 try/finally: hata olsa bile _isProcessing asla takılı kalmaz
    //    (eskiden checkConnectivity vb. hata atarsa kuyruk bir daha işlenmezdi).
    try {
      final attempted = <QueuedPayment>{};
      int rounds = 0;

      // 🔥 İşlem sırasında kuyruğa yeni öğe eklenirse 2 dk periyodik timer'ı
      //    BEKLEMEDEN aynı turda onu da gönder (eski gecikmenin ana sebebi).
      while (rounds < 5 && !_isDisposed) {
        rounds++;

        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity == ConnectivityResult.none) {
          print(
            "⚠️ İnternet yok, sync bekletiliyor... (${_paymentQueue.length} işlem)",
          );
          break;
        }

        final pending = _paymentQueue
            .where((q) => !attempted.contains(q))
            .toList();
        if (pending.isEmpty) break;

        // Ücret güncellemeleri öne al
        final queueSnapshot = <QueuedPayment>[
          ...pending.where(_isFeeItem),
          ...pending.where((q) => !_isFeeItem(q)),
        ];
        final List<QueuedPayment> succeeded = [];

        for (var queued in queueSnapshot) {
          attempted.add(queued);
          try {
            final success = await GoogleSheetService.addPayment(
              queued.payment,
            ).timeout(const Duration(seconds: 10));

            if (success) {
              succeeded.add(queued);
              print("  ✅ Ödeme senkronize edildi: ${queued.payment.amount} TL");
            } else {
              hadFailure = true;
              print(
                "  ❌ Ödeme senkronize EDİLEMEDİ: ${queued.payment.amount} TL",
              );
            }
          } catch (e) {
            hadFailure = true;
            print("  ❌ Sync hatası: $e");
          }
        }

        // 🔥 Başarılı olanları kuyruktan çıkar
        if (succeeded.isNotEmpty) {
          _paymentQueue.removeWhere((q) => succeeded.contains(q));
          await _saveQueueToStorage();
          GoogleSheetService.invalidateCache('payments');
          print(
            "✅ ${succeeded.length} ödeme temizlendi, ${_paymentQueue.length} işlem kaldı",
          );
        } else {
          print("⚠️ Bu turda hiçbir ödeme temizlenemedi!");
        }
      }
    } catch (e) {
      hadFailure = true;
      print("❌ Kuyruk işleme hatası: $e");
    } finally {
      _isProcessing = false;
    }

    // Başarısız öğe kaldıysa 2 dk beklemeden kısa süre sonra tekrar dene.
    if (hadFailure && _paymentQueue.isNotEmpty && !_isDisposed) {
      _quickRetryTimer?.cancel();
      _quickRetryTimer = Timer(const Duration(seconds: 15), () {
        if (!_isDisposed) _processQueue();
      });
    }
  }

  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_isDisposed)
        timer.cancel();
      else
        _processQueue();
    });
  }

  Future<void> _saveQueueToStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _paymentQueue
          .map(
            (q) => {
              'localId': q.localId,
              'payment': q.payment.toJson(),
              'createdAt': q.createdAt.toIso8601String(),
            },
          )
          .toList();
      await _queueBox.put('queue', queueJson);
      print("💾 Ödeme kuyruğu kaydedildi: ${_paymentQueue.length} öğe");
    } catch (e) {
      print("❌ Kuyruk kaydetme hatası: $e");
    }
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _queueBox.get('queue');
      if (queueJson != null && queueJson is List) {
        for (var item in queueJson) {
          try {
            Map<String, dynamic> typedItem;
            if (item is Map<String, dynamic>) {
              typedItem = item;
            } else if (item is Map<dynamic, dynamic>) {
              typedItem = Map<String, dynamic>.from(item);
            } else {
              continue;
            }

            Map<String, dynamic> paymentMap;
            final paymentData = typedItem['payment'];
            if (paymentData is Map<String, dynamic>) {
              paymentMap = paymentData;
            } else if (paymentData is Map<dynamic, dynamic>) {
              paymentMap = Map<String, dynamic>.from(paymentData);
            } else {
              continue;
            }

            _paymentQueue.add(
              QueuedPayment(
                localId: typedItem['localId'] as String,
                payment: Payment.fromJson(paymentMap),
                createdAt: DateTime.parse(typedItem['createdAt'] as String),
              ),
            );
          } catch (e) {
            print("❌ Queue item yüklenirken hata: $e");
          }
        }
        print("📦 Ödeme kuyruğundan ${_paymentQueue.length} öğe yüklendi");
      }
    } catch (e) {
      print("❌ Kuyruk yükleme hatası: $e");
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _generateLocalId() {
    return "local_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}";
  }

  int get pendingSyncCount => _paymentQueue.length;

  void dispose() {
    _isDisposed = true;
    _paymentSyncController.close();
    _queueBox.close();
  }
}

class QueuedPayment {
  final String localId;
  final Payment payment;
  final DateTime createdAt;

  QueuedPayment({
    required this.localId,
    required this.payment,
    required this.createdAt,
  });
}

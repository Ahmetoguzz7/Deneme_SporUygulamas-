// lib/core/connectivity_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  bool _isChecking = false;
  Timer? _periodicTimer;

  // Gerçekten tamamen kopuk olduğunu anlamak için daha katı bir eşik
  int _failCount = 0;
  static const int _requiredFailures =
      4; // Arka arkaya 4 kez (40 saniye) tamamen başarısız olmalı

  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;

  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _checkNow();
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => _checkNow());
  }

  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _checkNow() async {
    if (_isChecking) return;
    _isChecking = true;

    // Instagram / WhatsApp mantığı: Çok hafif ve hızlı bir nokta
    const testUrl = 'https://www.google.com/generate_204';

    try {
      // Süreyi 3 saniyeye düşürdük. İnternet zayıf olsa bile 3 saniyede 204 döner.
      final resp = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 3));

      final online = resp.statusCode == 204 || resp.statusCode == 200;

      if (online) {
        _failCount =
            0; // İnternet geldiği an sayacı sıfırla, kullanıcıya asla hissettirme
        _updateStatus(true);
      } else {
        _registerFailure();
      }
    } catch (_) {
      // Bağlantı zayıfsa veya paket kaybı varsa buraya düşer
      _registerFailure();
    } finally {
      _isChecking = false;
    }
  }

  void _registerFailure() {
    _failCount++;
    // Sadece arka arkaya 4 kez yani uzun süre (örn: 40 saniye boyunca hiç internet gidemediğinde) kopuk de
    if (_failCount >= _requiredFailures) {
      _updateStatus(false);
    }
  }

  Future<bool> retry() async {
    _isChecking = true;
    notifyListeners();

    const testUrl = 'https://www.google.com/generate_204';
    bool online = false;
    try {
      final resp = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 3));
      online = resp.statusCode == 204 || resp.statusCode == 200;
    } catch (_) {
      online = false;
    }

    if (online) {
      _failCount = 0;
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }

    _isChecking = false;
    notifyListeners();
    return online;
  }

  void _updateStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }
}

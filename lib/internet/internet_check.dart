import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetChecker {
  static final InternetChecker _instance = InternetChecker._internal();
  factory InternetChecker() => _instance;
  InternetChecker._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final List<VoidCallback> _onInternetGainedCallbacks = [];
  final List<VoidCallback> _onInternetLostCallbacks = [];

  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  void startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasInternet = results != ConnectivityResult.none;

      if (hasInternet != _hasInternet) {
        _hasInternet = hasInternet;

        if (hasInternet) {
          print("🌐 İnternet bağlantısı sağlandı!");
          for (var callback in _onInternetGainedCallbacks) {
            callback();
          }
        } else {
          print("⚠️ İnternet bağlantısı kesildi!");
          for (var callback in _onInternetLostCallbacks) {
            callback();
          }
        }
      }
    });
  }

  void onInternetGained(VoidCallback callback) {
    _onInternetGainedCallbacks.add(callback);
  }

  void onInternetLost(VoidCallback callback) {
    _onInternetLostCallbacks.add(callback);
  }

  Future<bool> checkInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results != ConnectivityResult.none;
  }

  void dispose() {
    _subscription?.cancel();
  }
}

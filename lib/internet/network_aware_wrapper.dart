import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkAwareWrapper extends StatefulWidget {
  final Widget child;

  const NetworkAwareWrapper({super.key, required this.child});

  @override
  State<NetworkAwareWrapper> createState() => _NetworkAwareWrapperState();
}

class _NetworkAwareWrapperState extends State<NetworkAwareWrapper> {
  bool _hasInternet = true;
  bool _isDialogShowing = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    // 🔥 HEMEN KONTROL ET, SONRA TEKRAR KONTROL ET
    _checkInternetImmediately();
    _startListening();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  // 🔥 HEMEN İNTERNET KONTROLÜ
  Future<void> _checkInternetImmediately() async {
    print("🌐 NetworkAwareWrapper: İnternet kontrolü başlıyor...");

    final hasInternet = await _checkInternet();
    print("🌐 NetworkAwareWrapper: İnternet durumu = $hasInternet");

    if (mounted && !hasInternet) {
      setState(() => _hasInternet = false);
      _showNoInternetDialog();
    } else if (mounted && hasInternet) {
      setState(() => _hasInternet = true);
    }
  }

  void _startListening() {
    Connectivity().onConnectivityChanged.listen((results) async {
      print("🌐 Bağlantı durumu değişti: $results");

      final hasInternet = results != ConnectivityResult.none;

      // Gerçek internet kontrolü için ek ping
      bool realInternet = false;
      if (hasInternet) {
        realInternet = await _checkRealInternet();
      }

      final finalHasInternet = hasInternet && realInternet;

      if (finalHasInternet != _hasInternet) {
        setState(() => _hasInternet = finalHasInternet);

        if (!finalHasInternet && mounted) {
          _showNoInternetDialog();
        } else if (finalHasInternet && mounted && _isDialogShowing) {
          // İnternet geldi, dialog'u kapat
          Navigator.pop(context);
          _isDialogShowing = false;
        }
      }
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results == ConnectivityResult.none) return false;

      // Gerçek internet kontrolü
      return await _checkRealInternet();
    } catch (e) {
      print("İnternet kontrol hatası: $e");
      return false;
    }
  }

  Future<bool> _checkRealInternet() async {
    try {
      // Google DNS'e ping at
      final result = await InternetAddress.lookup(
        '8.8.8.8',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showNoInternetDialog() {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    print("🌐 İnternet yok, dialog gösteriliyor...");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text("İnternet Bağlantısı Yok"),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("İnternet bağlantınız bulunmuyor veya kesildi."),
              SizedBox(height: 12),
              Text(
                "Lütfen Wi-Fi veya mobil verinizi kontrol edin.\nBağlantı sağlandığında otomatik olarak devam edecektir.",
                style: TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("UYGULAMAYI KAPAT"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _isDialogShowing = false;
                // Tekrar kontrol et
                await _checkInternetImmediately();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("TEKRAR DENE"),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

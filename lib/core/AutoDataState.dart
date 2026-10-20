import 'dart:async';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

mixin AutoDataState<T extends StatefulWidget> on State<T> {
  // Sayfa ilk açıldığında arka planda veri çekiliyor mu bayrağı
  bool isBackgroundFetching = false;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _setupDataPipeline();
  }

  void _setupDataPipeline() {
    // 1. Canlı güncellemeleri dinle (Arka planda veri değişirse ekranı anında tazele)
    _updateSubscription = AppRepository().onDataUpdated.listen((_) {
      if (mounted) {
        print(
          "🔄 [AutoData] Arka planda yeni veri alındı, ekran güncelleniyor...",
        );
        onDataRefreshed();
      }
    });

    // 2. Eğer RAM tamamen boşsa, kullanıcıya çaktırmadan arka planda ilk yüklemeyi tetikle
    if (AppRepository().isLoaded == false && AppRepository().allUsers.isEmpty) {
      _fetchInBackground();
    }
  }

  Future<void> _fetchInBackground() async {
    if (isBackgroundFetching) return;
    isBackgroundFetching = true;
    try {
      print("🔍 [AutoData] RAM boş, veriler arka planda çekiliyor...");
      await AppRepository().loadAllData();
      if (mounted) {
        onDataRefreshed();
      }
    } catch (e) {
      print("❌ [AutoData] Arka plan veri çekme hatası: $e");
    } finally {
      isBackgroundFetching = false;
    }
  }

  // Sayfaların veriler güncellendiğinde ekranı yenilemek için kullanacağı metod
  void onDataRefreshed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }
}

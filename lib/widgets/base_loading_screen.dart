import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/widgets/loading_overlay.dart';

/// 🔥 TEMEL LOADING SCREEN
/// Tüm loading screen'ler bu sınıftan miras alır
abstract class BaseLoadingScreen extends StatefulWidget {
  final Users user;
  const BaseLoadingScreen({super.key, required this.user});

  @override
  State<BaseLoadingScreen> createState() => _BaseLoadingScreenState();

  // Alt sınıfların implement edeceği metodlar
  Future<void> onDataLoaded(AppRepository repo, BuildContext context);
  String getLoadingMessage(double progress);
}

class _BaseLoadingScreenState extends State<BaseLoadingScreen> {
  final AppRepository _repo = AppRepository();
  double _progress = 0.0;
  String _message = "Veriler hazırlanıyor...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _repo.loadCriticalData(
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p;
            _message = widget.getLoadingMessage(p);
          });
        }
      },
    );

    _repo.preloadProfilePhotosAsync(context);
    await widget.onDataLoaded(_repo, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: LoadingOverlay(
        message: _message,
        progress: _progress,
        subMessage: "Sporla kalın, sağlıklı kalın! 💪",
      ),
    );
  }
}

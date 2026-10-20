import 'package:EVOM_SPOR/accountant/accountant_interface.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/widgets/Sportsfactticker.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class AccountantLoadingScreen extends StatefulWidget {
  final Users user;
  final String currentUserRole;

  const AccountantLoadingScreen({
    super.key,
    required this.user,
    required this.currentUserRole,
  });

  @override
  State<AccountantLoadingScreen> createState() =>
      _AccountantLoadingScreenState();
}

class _AccountantLoadingScreenState extends State<AccountantLoadingScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  double _progress = 0.0;
  String _currentStep = "Başlatılıyor";
  String _detailMessage = "Sistem kontrol ediliyor...";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _retryCount = 0;
  static const int MAX_RETRY = 3;

  // Adımlar gerçek akışla uyumlu (fotoğraf ön-yükleme kaldırıldı).
  final List<MapEntry<String, String>> _loadingSteps = [
    const MapEntry(
      "🔐 Hesap Doğrulanıyor",
      "Kullanıcı bilgileriniz kontrol ediliyor...",
    ),
    const MapEntry(
      "📦 Veriler Yükleniyor",
      "Öğrenci ve grup bilgileri geliyor...",
    ),
    const MapEntry("💰 Ödeme Kayıtları", "Finansal veriler hazırlanıyor..."),
    const MapEntry("✅ Hazır!", "Muhasebeci paneline yönlendiriliyorsunuz..."),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateLoadingStep(double progress) {
    int stepIndex = (progress * _loadingSteps.length).floor();
    if (stepIndex >= _loadingSteps.length) stepIndex = _loadingSteps.length - 1;
    if (stepIndex < 0) stepIndex = 0;
    setState(() {
      _currentStep = _loadingSteps[stepIndex].key;
      _detailMessage = _loadingSteps[stepIndex].value;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "GÜNAYDIN";
    if (hour < 18) return "TÜNAYDIN";
    return "İYİ AKŞAMLAR";
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _progress = 0.15;
        _updateLoadingStep(0.15);
      });

      // 1) Kritik veriler (offline-first, hızlı, paralel).
      if (!_repo.isLoaded) {
        await _repo.loadAllData().timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception("Bağlantı zaman aşımına uğradı"),
        );
      }

      if (!mounted) return;
      setState(() {
        _progress = 0.6;
        _updateLoadingStep(0.6);
      });

      // 2) SADECE cache boşsa (ilk açılış) ödemeleri bekle ki gelir 0 gelmesin.
      //    Cache doluysa hiç ağ beklenmez -> anında geçer, arkada tazelenir.
      if (_repo.allPayments.isEmpty) {
        try {
          await _repo
              .refreshTable('payments', 'payments')
              .timeout(const Duration(seconds: 15), onTimeout: () {});
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _updateLoadingStep(1.0);
      });

      // NOT: preloadProfilePhotosAsync KALDIRILDI — %85'te takılmanın sebebi buydu.
      //      Fotoğraflar gerektiğinde (lazily) yüklenir.

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AccountantInterface(
            currentUserRole: widget.currentUserRole,
            currentUser: widget.user,
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Muhasebe veri yükleme hatası: $e");
      _retryCount++;

      if (_retryCount < MAX_RETRY) {
        if (!mounted) return;
        setState(() {
          _detailMessage =
              "Bağlantı sorunu, tekrar deneniyor... ($_retryCount/$MAX_RETRY)";
          _progress = 0.0;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadData();
        });
      } else {
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text("Bağlantı Hatası"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Veriler birden fazla kez denenmesine rağmen yüklenemedi.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "İnternet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın.",
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Sorun devam ederse:\n• İnternet bağlantınızı kontrol edin\n• Uygulamayı tamamen kapatıp açın\n• Daha sonra tekrar deneyin",
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            onPressed: () {
              Navigator.pop(context);
              _retryCount = 0;
              _progress = 0.0;
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("TEKRAR DENE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.calculate,
                              color: Colors.white,
                              size: 65,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${widget.user.first_name} ${widget.user.last_name}",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: Colors.blue.shade400,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${(_progress * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                            ),
                            Text(
                              "Adım ${((_progress * _loadingSteps.length).toInt() + 1).clamp(1, _loadingSteps.length)}/${_loadingSteps.length}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentStep,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: Text(
                            _detailMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(0.2),
                          Colors.green.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: SportsFactRotatingText()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

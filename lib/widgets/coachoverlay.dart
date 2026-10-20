import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/userInterfacepage/userinterface.dart';
import 'package:EVOM_SPOR/widgets/coachoverlay.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/widgets/Sportsfactticker.dart';
import 'dart:io';

class CoachLoadingScreen extends StatefulWidget {
  final Users user;
  const CoachLoadingScreen({super.key, required this.user});

  @override
  State<CoachLoadingScreen> createState() => _CoachLoadingScreenState();
}

class _CoachLoadingScreenState extends State<CoachLoadingScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  double _progress = 0.0;
  String _currentStep = "Başlatılıyor";
  String _detailMessage = "Sistem kontrol ediliyor...";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _coachName = "";
  String _sportName = "";
  int _retryCount = 0;
  static const int MAX_RETRY = 2;

  bool _isAssistant = false; // 🔥 EKLENDİ

  final List<MapEntry<String, String>> _loadingSteps = [
    const MapEntry(
      "🔐 Hesap Doğrulanıyor",
      "Kullanıcı bilgileriniz kontrol ediliyor...",
    ),
    const MapEntry(
      "📦 Veriler Yükleniyor",
      "Antrenör ve grup bilgileri geliyor...",
    ),
    const MapEntry("👥 Öğrenci Listesi", "Öğrenci kayıtları taranıyor..."),
    const MapEntry("✅ Hazır!", "Antrenör paneline yönlendiriliyorsunuz..."),
  ];

  final List<String> _tips = [
    "💡 İpucu: Öğrencilerinizin gelişimini düzenli takip edin!",
    "💡 İpucu: Antrenman programlarını haftalık güncelleyin!",
    "💡 İpucu: Öğrencilerinizle düzenli iletişimde kalın!",
    "💡 İpucu: Başarıları kutlamak motivasyonu artırır!",
    "💡 İpucu: Her öğrenci farklıdır, bireysel ilgi gösterin!",
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
    setState(() {
      _currentStep = _loadingSteps[stepIndex].key;
      _detailMessage = _loadingSteps[stepIndex].value;
    });
  }

  String _getRandomTip() {
    return _tips[DateTime.now().millisecondsSinceEpoch % _tips.length];
  }

  Future<void> _loadData() async {
    try {
      //   await _loadWithTimeout();

      setState(() {
        _progress = 0.15;
        _updateLoadingStep(0.15);
      });

      // 🔥 Verileri offline-first yükle (coach/spor bulma için ŞART).
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

      final coaches = _repo.allCoaches;
      final sports = _repo.allSports;

      // 1. Önce kullanıcının kendi coach kaydını bul
      var userCoach = coaches.firstWhere(
        (c) => c.user_id == widget.user.app,
        orElse: () => Coach(
          coach_id: "",
          user_id: widget.user.app,
          branches_id: "",
          sports_id: "",
          bio: "",
          certificate_info: "",
          monthly_salary: "",
          hired_at: "",
          supervisor_coach_id: "",
        ),
      );

      Coach targetCoach = userCoach;

      // 🔥 YARDIMCI ANTRENÖR KONTROLÜ
      _isAssistant =
          widget.user.role.toLowerCase() == 'assistant_coach' ||
          widget.user.role.toLowerCase() == 'yardımcı_antrenör';

      if (_isAssistant) {
        // Sadece üst hocayı bul (görüntüleme için)
        Coach? masterCoach;
        for (var coach in coaches) {
          if (coach.supervisor_coach_id.isNotEmpty) {
            List<String> supervisorIds = [];
            if (coach.supervisor_coach_id.contains(',')) {
              supervisorIds = coach.supervisor_coach_id
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            } else if (coach.supervisor_coach_id.contains('.')) {
              supervisorIds = coach.supervisor_coach_id
                  .split('.')
                  .map((s) => s.trim())
                  .toList();
            } else {
              supervisorIds = [coach.supervisor_coach_id.trim()];
            }

            if (supervisorIds.contains(widget.user.app)) {
              masterCoach = coach;
              print(
                "✅ Yardımcı antrenör! Üst hoca bulundu: coach_id=${masterCoach.coach_id}, user_id=${masterCoach.user_id}",
              );
              break;
            }
          }
        }

        // 🔥🔥🔥 ÖNEMLİ: PersonalTrainer'a KENDİ coach_id'ni gönder, üst hocayı DEĞİL!
        if (userCoach.coach_id.isNotEmpty) {
          targetCoach = userCoach; // ✅ KENDİ COACH KAYDINI GÖNDER
          print(
            "✅ Yardımcı antrenörün kendi coach_id'si: ${targetCoach.coach_id}",
          );
        } else {
          targetCoach = userCoach;
        }
      }

      // 2. Spor bilgisini bul
      final sportData = targetCoach.sports_id.isNotEmpty
          ? sports.firstWhere(
              (s) => s.sports_id == targetCoach.sports_id,
              orElse: () =>
                  Sports(sports_id: "", name: "Spor", description: ""),
            )
          : Sports(sports_id: "", name: "Fitness", description: "");
      _sportName = sportData.name;
      _coachName = "${widget.user.first_name} ${widget.user.last_name}";

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _updateLoadingStep(1.0);
      });

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PersonalTrainer(
              users: widget.user,
              sport: sportData,
              coachData: targetCoach, // ✅ KENDİ COACH KAYDI
              isAssistant: _isAssistant,
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      _retryCount++;

      if (_retryCount < MAX_RETRY) {
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

  /*
  Future<void> _loadWithTimeout() async {
    await _repo
        .loadCoachData(
          widget.user.app,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _progress = p;
                _updateLoadingStep(p);
              });
            }
          },
          onMessage: (msg) {
            if (mounted) setState(() => _detailMessage = msg);
          },
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception("Bağlantı zaman aşımına uğradı"),
        );
  }
*/
  void _showErrorDialog() {
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
              backgroundColor: Colors.orange,
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
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sports,
                              color: Colors.white,
                              size: 70,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "HOŞ GELDİN,",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 3,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _coachName.isEmpty
                        ? "${widget.user.first_name} ${widget.user.last_name}"
                        : _coachName,
                    style: const TextStyle(
                      fontSize: 32,
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
                            color: Colors.orange.shade400,
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
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${(_progress * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade300,
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
                                color: Colors.orange.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentStep,
                                style: TextStyle(
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
                          Colors.indigo.withOpacity(0.2),
                          Colors.purple.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: const SportsFactRotatingText()),
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

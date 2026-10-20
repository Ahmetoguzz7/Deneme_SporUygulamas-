import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// 🔥 ULTRA PREMIUM LOADING OVERLAY
/// Spor temalı, orbital enerji halkası animasyonu, sinematik tasarım
class LoadingOverlay extends StatefulWidget {
  final String message;
  final double progress;
  final String? subMessage;

  const LoadingOverlay({
    super.key,
    required this.message,
    this.progress = 0.0,
    this.subMessage,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  // Orbital ring animasyonları
  late AnimationController _outerRingController;
  late AnimationController _innerRingController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _factFadeController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;

  late Animation<double> _outerRingAnim;
  late Animation<double> _innerRingAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _factFadeAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _particleAnim;

  // Renk paleti
  static const Color _deepSpace = Color(0xFF060912);
  static const Color _navyCard = Color(0xFF0D1424);
  static const Color _navyBorder = Color(0xFF1A2744);
  static const Color _emberOrange = Color(0xFFFF4D00);
  static const Color _amber = Color(0xFFFFB347);
  static const Color _softWhite = Color(0xFFF0F4FF);
  static const Color _dimWhite = Color(0xFF8899BB);

  final List<Map<String, String>> _sportFacts = [
    {"icon": "⚡", "fact": "Usain Bolt, 100m'de saniyede 12.4 metre koştu."},
    {
      "icon": "🏀",
      "fact": "Michael Jordan lise takımından kesilmişti — sonra efsane oldu.",
    },
    {
      "icon": "⚽",
      "fact": "Messi, 11 yaşında büyüme hormonu eksikliği teşhisi aldı.",
    },
    {
      "icon": "🏊",
      "fact": "Phelps, Olimpiyat tarihinin en çok madalyalı sporcusu: 28.",
    },
    {
      "icon": "🎾",
      "fact": "Serena Williams, Open Era'da 23 Grand Slam şampiyonu.",
    },
    {
      "icon": "🥊",
      "fact": "Ali, Foreman'ı 'Rope-a-Dope' stratejisiyle yenerek efsaneleşti.",
    },
    {
      "icon": "🏆",
      "fact": "Türkiye, 2002 Dünya Kupası'nda 3. oldu — tarihî rekor.",
    },
    {
      "icon": "🚴",
      "fact": "Tour de France pedalcıları günde 7.000 kalori yakar.",
    },
    {
      "icon": "🏋️",
      "fact": "İnsan vücudu, maksimal eforda 3 saniye zirve güç üretebilir.",
    },
    {
      "icon": "🎯",
      "fact": "100m sprintte altın-gümüş farkı çoğunlukla 0.01 saniye.",
    },
    {"icon": "🏒", "fact": "Hokeyde puck saatte 160 km'ye ulaşabilir."},
    {
      "icon": "⛷️",
      "fact": "Kayak atlama sporcuları havada 140 km/s'ye ulaşır.",
    },
    {"icon": "🤽", "fact": "Su topu oyuncuları maçta 3 km'den fazla yüzer."},
    {
      "icon": "🥋",
      "fact": "Karate'de bir yumruk 0.14 saniyede 700 Newton kuvvet üretir.",
    },
    {
      "icon": "🏹",
      "fact": "Okçular 70 metreyi 10 cm'lik hedef merkezine isabetlendiriyor.",
    },
    {
      "icon": "🤸",
      "fact": "Cimnastikçiler salt kasıyla 3G'ye kadar ivme deneyimler.",
    },
    {
      "icon": "🏄",
      "fact":
          "Büyük dalga sörfçüleri 30 metre yüksekliğindeki dalgalara biner.",
    },
    {
      "icon": "🎿",
      "fact":
          "Biathlon sporcuları koşunun ardından kalp atışını 30 sn'de sakinleştirir.",
    },
    {
      "icon": "🚣",
      "fact": "Kürek çekme, vücudun %86 kas grubunu aktive eden nadir spordur.",
    },
    {
      "icon": "🏇",
      "fact": "At yarışında jokey + at hız dengesi saatte 70 km'yi aşar.",
    },
  ];

  int _currentFactIndex = 0;
  Timer? _factTimer;
  double _animatedProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _animatedProgress = widget.progress;

    // Dış ring — yavaş saat yönünde
    _outerRingController = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    )..repeat();
    _outerRingAnim = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_outerRingController);

    // İç ring — hızlı ters yön
    _innerRingController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _innerRingAnim = Tween<double>(
      begin: 2 * pi,
      end: 0,
    ).animate(_innerRingController);

    // Nabız (pulse) efekti
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer efekti
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Parçacık hareketi
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _particleAnim = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_particleController);

    // Bilgi kartı fade
    _factFadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _factFadeAnim = CurvedAnimation(
      parent: _factFadeController,
      curve: Curves.easeInOut,
    );

    // Progress animasyonu
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Bilgi kartı döngüsü
    _factTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _factFadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentFactIndex = (_currentFactIndex + 1) % _sportFacts.length;
            });
            _factFadeController.forward();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      setState(() => _animatedProgress = widget.progress);
    }
  }

  @override
  void dispose() {
    _outerRingController.dispose();
    _innerRingController.dispose();
    _pulseController.dispose();
    _factFadeController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    _factTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFact = _sportFacts[_currentFactIndex];
    final progressPercent = (_animatedProgress * 100).toInt();
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: _deepSpace),
      child: Stack(
        children: [
          // Arka plan parçacıkları
          ..._buildBackgroundParticles(size),

          // Üst gradient ışık huzmesi
          Positioned(
            top: -size.height * 0.15,
            left: size.width * 0.5 - 200,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Opacity(
                  opacity: 0.15 + _pulseController.value * 0.1,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _emberOrange.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Ana içerik
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Orbital logo + progress ring sistemi
                    _buildOrbitalSystem(progressPercent),
                    const SizedBox(height: 40),

                    // Ana mesaj ve progress
                    _buildMessageSection(progressPercent),
                    const SizedBox(height: 32),

                    // Spor bilgisi kartı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _buildFactCard(currentFact),
                    ),
                    const SizedBox(height: 28),

                    // Pulse dots
                    _buildPulseDots(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Arka plan parçacıkları ────────────────────────────────────────────────

  List<Widget> _buildBackgroundParticles(Size size) {
    final particles = <Widget>[];
    final random = Random(42);

    for (int i = 0; i < 18; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2.0 + 0.5;
      final phase = random.nextDouble() * 2 * pi;

      particles.add(
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) {
            final drift = sin(_particleAnim.value + phase) * 12;
            return Positioned(
              left: x + drift,
              top: y + cos(_particleAnim.value * 0.7 + phase) * 8,
              child: Opacity(
                opacity: (0.2 + sin(_particleAnim.value + phase) * 0.15).clamp(
                  0.05,
                  0.4,
                ),
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    color: i % 3 == 0 ? _emberOrange : _amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return particles;
  }

  // ─── Orbital sistem ───────────────────────────────────────────────────────

  Widget _buildOrbitalSystem(int percent) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış halka gölgesi
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _emberOrange.withOpacity(
                        0.12 + _pulseController.value * 0.1,
                      ),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),

          // Dış arka plan halkası (track)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _navyBorder.withOpacity(0.6), width: 2),
            ),
          ),

          // Dış ilerleme halkası (CustomPaint)
          SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: _outerRingController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ArcProgressPainter(
                    progress: _animatedProgress,
                    sweepAngle: _outerRingAnim.value,
                    strokeWidth: 4.0,
                    primaryColor: _emberOrange,
                    secondaryColor: _amber,
                    trailOpacity: 0.15,
                  ),
                );
              },
            ),
          ),

          // İç arka plan halkası (track)
          Container(
            width: 158,
            height: 158,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _navyBorder.withOpacity(0.4),
                width: 1.5,
              ),
            ),
          ),

          // İç hızlı dönen dekoratif halka
          SizedBox(
            width: 158,
            height: 158,
            child: AnimatedBuilder(
              animation: _innerRingController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SpinnerArcPainter(
                    angle: _innerRingAnim.value,
                    color: _amber.withOpacity(0.5),
                    strokeWidth: 2.0,
                    arcLength: pi * 0.6,
                  ),
                );
              },
            ),
          ),

          // Merkez kart
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF1A2744), Color(0xFF0D1424)],
                      center: Alignment(0, -0.3),
                    ),
                    border: Border.all(
                      color: _emberOrange.withOpacity(0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _emberOrange.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Büyük yüzde rakamı — signature element
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [_amber, _emberOrange],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: Text(
                            '$percent',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '%',
                          style: TextStyle(
                            color: _dimWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Orbital top (dönen ışık noktası — dış halkada)
          AnimatedBuilder(
            animation: _outerRingController,
            builder: (context, _) {
              final angle = _outerRingAnim.value;
              const r = 100.0;
              final x = cos(angle - pi / 2) * r;
              final y = sin(angle - pi / 2) * r;
              return Transform.translate(
                offset: Offset(x, y),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _emberOrange.withOpacity(0.9),
                        blurRadius: 14,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // İç halkada küçük amber nokta
          AnimatedBuilder(
            animation: _innerRingController,
            builder: (context, _) {
              final angle = _innerRingAnim.value;
              const r = 79.0;
              final x = cos(angle - pi / 2) * r;
              final y = sin(angle - pi / 2) * r;
              return Transform.translate(
                offset: Offset(x, y),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _amber,
                    boxShadow: [
                      BoxShadow(
                        color: _amber.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Mesaj bölümü ─────────────────────────────────────────────────────────

  Widget _buildMessageSection(int percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Ana başlık
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_softWhite, _dimWhite],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (widget.subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subMessage!,
              style: const TextStyle(
                color: _dimWhite,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Segmented progress bar
          _buildSegmentedProgressBar(percent),
        ],
      ),
    );
  }

  Widget _buildSegmentedProgressBar(int percent) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _navyBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: 6,
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _animatedProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_emberOrange, _amber],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Shimmer sweep
                  if (_animatedProgress > 0.05)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _animatedProgress.clamp(0.0, 1.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            alignment: Alignment.centerLeft,
                            child: Transform.translate(
                              offset: Offset(_shimmerAnim.value * 200 - 80, 0),
                              child: Container(
                                width: 60,
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.55),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Yüzde etiketi sağa dayalı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YÜKLENIYOR',
              style: TextStyle(
                color: _dimWhite,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                color: _amber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Bilgi kartı ──────────────────────────────────────────────────────────

  Widget _buildFactCard(Map<String, String> fact) {
    return FadeTransition(
      opacity: _factFadeAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _navyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _navyBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // İkon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _navyBorder,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  fact["icon"] ?? "🏆",
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Metin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BİLİYOR MUYDUN?',
                    style: TextStyle(
                      color: _emberOrange,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fact["fact"] ?? "Spor yapmak hayattır!",
                    style: const TextStyle(
                      color: _softWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pulse dots ───────────────────────────────────────────────────────────

  Widget _buildPulseDots() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = i / 3.0;
            final v = ((_pulseController.value + phase) % 1.0);
            final scale = 0.7 + v * 0.6;
            final opacity = 0.3 + v * 0.7;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 1 ? _emberOrange : _amber,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── CustomPainter: İlerleme halka ────────────────────────────────────────────

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final double sweepAngle;
  final double strokeWidth;
  final Color primaryColor;
  final Color secondaryColor;
  final double trailOpacity;

  _ArcProgressPainter({
    required this.progress,
    required this.sweepAngle,
    required this.strokeWidth,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trailOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (iz)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = primaryColor.withOpacity(0.12);
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi,
        colors: [primaryColor.withOpacity(0.1), primaryColor, secondaryColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress || old.sweepAngle != sweepAngle;
}

// ─── CustomPainter: Dönen dekoratif yay ──────────────────────────────────────

class _SpinnerArcPainter extends CustomPainter {
  final double angle;
  final Color color;
  final double strokeWidth;
  final double arcLength;

  _SpinnerArcPainter({
    required this.angle,
    required this.color,
    required this.strokeWidth,
    required this.arcLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, angle, arcLength, false, paint);
  }

  @override
  bool shouldRepaint(_SpinnerArcPainter old) => old.angle != angle;
}

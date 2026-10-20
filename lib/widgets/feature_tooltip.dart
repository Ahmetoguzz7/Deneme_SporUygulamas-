// lib/widgets/feature_tooltip.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureTooltip extends StatefulWidget {
  final Widget child;
  final String tooltipKey; // Benzersiz anahtar (ör: "dashboard_tooltip")
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onSkip;
  final AlignmentGeometry alignment;
  final Color backgroundColor;

  const FeatureTooltip({
    super.key,
    required this.child,
    required this.tooltipKey,
    required this.title,
    required this.description,
    this.buttonText,
    this.onSkip,
    this.alignment = Alignment.bottomCenter,
    this.backgroundColor = const Color(0xFF1E293B),
  });

  @override
  State<FeatureTooltip> createState() => _FeatureTooltipState();
}

class _FeatureTooltipState extends State<FeatureTooltip> {
  bool _isVisible = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final bool shown = prefs.getBool(widget.tooltipKey) ?? false;

    if (mounted) {
      setState(() {
        _isVisible = !shown;
        _isInitialized = true;
      });
    }
  }

  Future<void> _dismissTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.tooltipKey, true);

    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_isVisible) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // 🔥 Yarı saydam overlay
        Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tooltip kartı
                  Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Başlık
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.lightbulb_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.onSkip != null)
                              TextButton(
                                onPressed: () {
                                  widget.onSkip!();
                                  _dismissTooltip();
                                },
                                child: const Text(
                                  "Şimdi değil",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _dismissTooltip,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                widget.buttonText ?? "Anladım",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

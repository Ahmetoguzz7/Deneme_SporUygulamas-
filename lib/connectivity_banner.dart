// lib/core/connectivity_banner.dart
import 'package:flutter/material.dart';
import 'connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final _service = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            // 🔥 Tamamen soldan/sağdan kaymak yerine üstten aşağıya doğru inmesi mobil uygulamalarda daha şık durur
            offset: _service.isOnline ? const Offset(0, -1.5) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _service.isOnline ? 0 : 1,
              child: _buildBanner(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFDC2626), // kırmızı
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "İnternet bağlantısı kesildi",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Bağlantı gelene kadar çevrimdışı moddasınız.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RetryButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService();
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        if (service.isChecking) {
          return const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          );
        }
        return InkWell(
          onTap: () => service.retry(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Tekrar Dene",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

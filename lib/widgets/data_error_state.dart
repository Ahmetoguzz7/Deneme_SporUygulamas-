// lib/widgets/data_error_state.dart
import 'package:flutter/material.dart';

/// 🔥 ORTAK "VERİLER YÜKLENEMEDİ" EKRANI
/// AppRepository.hasError true olduğunda (bulk veri çekme başarısız olduğunda)
/// bunu tüm ekranlarda tutarlı biçimde göstermek için kullanılır.
///
/// Kullanım:
/// ```dart
/// hasError
///     ? DataErrorState(
///         message: _repo.lastErrorMessage,
///         onRetry: () async {
///           await _repo.loadAllData(forceRefresh: true);
///           // ardından ekranın kendi state'ini yenile
///         },
///       )
///     : ...normal içerik...
/// ```
class DataErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final Color accentColor;

  const DataErrorState({
    super.key,
    this.message,
    required this.onRetry,
    this.accentColor = const Color(0xFF0EA5E9),
  });

  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Veriler Yüklenemedi",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? "İnternet bağlantınızı kontrol edip tekrar deneyin.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Tekrar Dene"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

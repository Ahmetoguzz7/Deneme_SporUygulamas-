import 'dart:async';
import 'package:EVOM_SPOR/password_hashing/email_service.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _isTimedOut = false;
  String _generatedCode = "";
  String _foundUserId = "";
  String _foundUserName = "";
  String _foundUserEmail = "";
  int _remainingSeconds = 180; // 3 dakika = 180 saniye
  Timer? _countdownTimer;

  String _generateCode() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  void _startCountdown() {
    _remainingSeconds = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isTimedOut = true;
            _codeSent = false;
          });
          _showSnackBar(
            "⏰ Kodun süresi doldu! Lütfen yeniden kod isteyin.",
            isError: true,
          );
          _clearResetData();
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      }
    });
  }

  void _clearResetData() {
    _codeController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _generatedCode = "";
    _foundUserId = "";
    _foundUserName = "";
    _foundUserEmail = "";
    _isTimedOut = false;
  }

  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Lütfen e-posta adresinizi girin!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final allUsers = await GoogleSheetService.getUsers();
      final user = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => Users(
          app: "",
          branches_id: "",
          first_name: "",
          last_name: "",
          email: "",
          phone: "",
          password_hash: "",
          role: "",
          profile_photo_url: "",
          amount: "",
          b_date: "",
          created_at: "",
          last_login: "",
          is_active: "",
        ),
      );

      if (user.app.isEmpty) {
        _showSnackBar(
          "❌ Bu e-posta adresine kayıtlı kullanıcı bulunamadı!",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      _generatedCode = _generateCode();
      _foundUserId = user.app;
      _foundUserName = "${user.first_name} ${user.last_name}";
      _foundUserEmail = user.email;

      // Kodu kaydet (3 dakika geçerli - 180000 ms)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reset_code_${user.app}', _generatedCode);
      await prefs.setInt(
        'reset_code_expiry_${user.app}',
        DateTime.now().millisecondsSinceEpoch + (3 * 60 * 1000), // 3 dakika
      );

      // 📧 EMAIL GÖNDER
      final emailSent = await EmailService.sendPasswordResetCode(
        _foundUserEmail,
        _generatedCode,
        _foundUserName,
      );

      if (emailSent) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
          _isTimedOut = false;
        });
        _startCountdown();
        _showSnackBar(
          "✅ Şifre sıfırlama kodu e-posta adresinize gönderildi! 3 dakikanız var.",
        );
      } else {
        _showSnackBar(
          "❌ E-posta gönderilemedi! Lütfen daha sonra tekrar deneyin.",
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Bir hata oluştu: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _verifyCode() async {
    final enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      _showSnackBar("Lütfen e-postanıza gelen kodu girin!", isError: true);
      return false;
    }

    if (_isTimedOut) {
      _showSnackBar(
        "⏰ Kodun süresi doldu! Lütfen yeniden kod isteyin.",
        isError: true,
      );
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('reset_code_$_foundUserId');
    final expiry = prefs.getInt('reset_code_expiry_$_foundUserId') ?? 0;

    if (savedCode == null) {
      _showSnackBar("Kod bulunamadı! Lütfen yeni kod isteyin.", isError: true);
      return false;
    }

    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      _showSnackBar(
        "⏰ Kodun süresi doldu! Lütfen yeni kod isteyin.",
        isError: true,
      );
      return false;
    }

    if (enteredCode != savedCode) {
      _showSnackBar("❌ Hatalı kod! Tekrar deneyin.", isError: true);
      return false;
    }

    return true;
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("Lütfen yeni şifrenizi girin!", isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar("Şifre en az 6 karakter olmalıdır!", isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar("Şifreler eşleşmiyor!", isError: true);
      return;
    }

    final isValid = await _verifyCode();
    if (!isValid) return;

    setState(() => _isLoading = true);

    // Yeni şifreyi hash'le
    final hashedPassword = _hashPassword(newPassword);
    final success = await GoogleSheetService.updatePassword(
      _foundUserId,
      hashedPassword,
    );

    setState(() => _isLoading = false);

    if (success) {
      _countdownTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('reset_code_$_foundUserId');
      await prefs.remove('reset_code_expiry_$_foundUserId');

      _showSnackBar("✅ Şifreniz başarıyla değiştirildi!");

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      _showSnackBar("❌ Şifre değiştirilemedi! Tekrar deneyin.", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Şifremi Unuttum",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              "Şifrenizi mi unuttunuz?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "E-posta adresinize göndereceğimiz güvenlik kodu ile şifrenizi sıfırlayabilirsiniz.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Email - SADECE KOD GÖNDERİLMEDİYSE GÖRÜNSÜN
            if (!_codeSent)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "E-posta Adresi",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            if (!_codeSent) const SizedBox(height: 20),

            if (!_codeSent)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Kod Gönder",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

            if (_codeSent) ...[
              // ✅ KOD GÖNDERİLDİ BİLGİSİ - KOD EKRANDA YOK!
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade900],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.mark_email_read,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Kod Gönderildi!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _foundUserEmail,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "E-posta adresinize gönderilen 6 haneli kodu giriniz.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    // ⏰ GERİ SAYIM SAYACI
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Kalan Süre: ${_formatRemainingTime()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _sendCode,
                      child: const Text(
                        "Kod almadınız? Tekrar gönder",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: "6 Haneli Kod",
                  hintText: "••••••",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre (min. 6 karakter)",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre (Tekrar)",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isTimedOut)
                      ? null
                      : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Şifreyi Sıfırla",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              if (_isTimedOut)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "⏰ Kodun süresi doldu. Lütfen yeniden kod isteyin.",
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

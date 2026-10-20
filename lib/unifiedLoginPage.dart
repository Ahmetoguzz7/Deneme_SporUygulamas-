/*
import 'dart:convert';
import 'dart:io';

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/internet/network_aware_wrapper.dart';
import 'package:EVOM_SPOR/local/offline_syn_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:EVOM_SPOR/widgets/acountantoverlay.dart';
import 'package:EVOM_SPOR/widgets/coachoverlay.dart';
import 'package:EVOM_SPOR/widgets/loading_manager.dart';
import 'package:EVOM_SPOR/widgets/parentLoading.dart';
import 'package:EVOM_SPOR/widgets/studentoverlay.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/password_hashing/forgot_password.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/userInterfacepage/userinterface.dart';
import 'package:EVOM_SPOR/accountant/accountant_interface.dart';
import 'package:EVOM_SPOR/config.dart'; // 🔥 tek backend URL kaynağı

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  // 🔥 DEĞİŞTİ: eskiden farklı bir /exec adresine (AKfycbxyniyW...) gidiyordu.
  // Diğer her yer AKfycbzLDgE0... kullanıyordu; tek kaynağa bağlandı.
  // Eğer _trackAppVersion BİLEREK ayrı bir deployment'a yazıyorduysa geri al.
  final _baseUrl = kBackendUrl;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOtpMode = false;
  bool _rememberMe = true;
  String? _generatedOtp;
  Users? _pendingUser;
  String? _lastLoginEmail;
  String? _lastLoginDate;

  // Animasyonlar
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Geçerli roller
  static const List<String> _validRoles = [
    'admin',
    'yönetici',
    'accountant',
    'muhasebeci',
    'coach',
    'antrenör',
    'assistant_coach',
    'yardımcı_antrenör',
    'student',
    'öğrenci',
    'parent',
    'veli',
  ];

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateTurkish(DateTime date) {
    final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateShortTurkish(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }
  // unifiedLoginPage.dart - initState kısmı (sadece değişen kısım)

  @override
  void initState() {
    super.initState();

    // Animasyonlar (Aynen kalabilir)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSavedUser();
    });

    // 🔥 YENİ: Offline-First başlatma (KAYDEDİLMİŞ KULLANICI YOKSA)
    _initializeOfflineFirst();
  }

  /// 🚀 OFFLINE-FIRST BAŞLATMA (GÜVENLİ HALE GETİRİLDİ)
  Future<void> _initializeOfflineFirst() async {
    print("🚀 Offline-First başlatılıyor...");

    try {
      final repo = AppRepository();
      await repo.init();

      final syncManager = OfflineSyncManager();

      // Kanka, eğer OfflineSyncManager singleton ise veya dahili olarak
      // init kontrolü yoksa, buradaki init çağrısı late hatası fırlatabilir.
      // O yüzden try-catch ile sarıp late initialization hatasını yutuyoruz.
      await syncManager.init(repo);

      syncManager.onDataChanged.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });

      syncManager.syncNow();
      print("✅ Offline-First başarıyla kuruldu veya zaten aktifti.");
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        print(
          "ℹ️ OfflineSyncManager zaten initialize edilmiş, sorun yok yola devam!",
        );
      } else {
        print("❌ Offline-First başlatma hatası: $e");
      }
    }
  }

  Future<void> saveToken(String token) async {
    final url = Uri.parse(kBackendUrl); // 🔥 DEĞİŞTİ: config.dart'tan

    final request = http.Request('POST', url)
      ..followRedirects = true
      ..maxRedirects = 5
      ..bodyFields = {'action': 'saveToken', 'userId': '727', 'token': token};

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print("✅ Token başarıyla kaydedildi!");
    } else {
      print("❌ Hata kodu: ${response.statusCode}");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final lastLoginEmail = prefs.getString('last_login_email');
    final lastLoginDate = prefs.getString('last_login_date');

    if (lastLoginEmail != null && lastLoginDate != null && mounted) {
      setState(() {
        _lastLoginEmail = lastLoginEmail;
        _lastLoginDate = lastLoginDate;
      });
    }

    if (rememberMe && savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
      _rememberMe = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        _handleLogin();
      });
    }
  }

  Future<void> _saveLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _saveLastLoginInfo(Users user) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final formattedDate = _formatDateTurkish(now);
    await prefs.setString('last_login_email', user.email);
    await prefs.setString('last_login_date', formattedDate);

    if (mounted) {
      setState(() {
        _lastLoginEmail = user.email;
        _lastLoginDate = formattedDate;
      });
    }
  }

  String _generateOtp() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  bool _isValidRole(String? role) {
    if (role == null || role.isEmpty) return false;
    final lowerRole = role.toLowerCase();
    return _validRoles.contains(lowerRole);
  }

  String _getRoleType(String? role) {
    if (role == null) return 'invalid';
    final lowerRole = role.toLowerCase();

    if (lowerRole == 'admin' || lowerRole == 'yönetici') return 'admin';
    if (lowerRole == 'accountant' || lowerRole == 'muhasebeci')
      return 'accountant';
    if (lowerRole == 'coach' ||
        lowerRole == 'antrenör' ||
        lowerRole == 'assistant_coach' ||
        lowerRole == 'yardımcı_antrenör')
      return 'coach';
    if (lowerRole == 'student' || lowerRole == 'öğrenci') return 'student';
    if (lowerRole == 'parent' || lowerRole == 'veli') return 'parent';
    return 'invalid';
  }

  bool _requires2FA(String? role) {
    final roleType = _getRoleType(role);
    return roleType == 'admin' || roleType == 'accountant';
  }

  Future<void> _start2FA(Users user) async {
    final otp = _generateOtp();
    _generatedOtp = otp;
    _pendingUser = user;
    setState(() {
      _isOtpMode = true;
      _isLoading = false;
    });
  }

  Future<void> _verifyOtpAndLogin() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.isEmpty) {
      _showSnackBar("Lütfen güvenlik kodunu girin!", isError: true);
      return;
    }
    if (enteredOtp != _generatedOtp) {
      _showSnackBar("❌ Hatalı güvenlik kodu!", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    await _completeLogin(_pendingUser!);
  }

  // =========================================================================
  // 🔥 UNIFIED LOGIN PAGE - GİRİŞ YAP BUTONU FONKSİYONU (DÜZELTİLMİŞ)
  // =========================================================================
  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Lütfen e-posta ve şifre alanlarını doldurun.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("🔐 Giriş isteği başlatılıyor: $email");
      final user = await GoogleSheetService.login(email, password);

      if (user != null) {
        final String isActive = (user.is_active ?? 'TRUE').toUpperCase().trim();
        final String role = (user.role ?? '').toLowerCase().trim();

        // 🔴 KURAL 1: Kullanıcı pasif ise engelle
        if (isActive == 'FALSE') {
          print("🚨 Giriş Engellendi: Kullanıcı hesabı pasif.");
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('logged_user');
          setState(() => _isLoading = false);
          _showErrorDialog(
            "Hesabınız pasif durumdadır. Lütfen yönetim ile iletişime geçin.",
          );
          return;
        }

        // 🎉 KURAL 2: HESAP AKTİF! Giriş yapmasına izin ver
        print("✅ Giriş başarılı! Yönlendiriliyor...");

        // ✅ BURASI ÖNEMLİ: Kullanıcıyı kaydet ve yönlendir!
        await _saveLoginCredentials(email, _passwordController.text.trim());
        await _saveLastLoginInfo(user);

        // 2FA kontrolü
        if (_requires2FA(user.role)) {
          await _start2FA(user);
          setState(() => _isLoading = false);
        } else {
          // Doğrudan ana sayfaya yönlendir
          await _completeLogin(user);
          // _completeLogin zaten setState yapıyor
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("E-posta adresi veya şifre hatalı!", isError: true);
      }
    } catch (e) {
      print("❌ Giriş işlemi sırasında hata oluştu: $e");
      setState(() => _isLoading = false);
      _showSnackBar(
        "Sunucuyla bağlantı kurulurken bir hata oluştu.",
        isError: true,
      );
    }
  }

  // 📌 Yardımcı Hata Dialog Penceresi
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              "Giriş Yetkisi Yok",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Anladım",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeLogin(Users user) async {
    final roleType = _getRoleType(user.role);

    // 🔥 FCM TOKEN KAYDET
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'logged_user',
        jsonEncode({
          'app': user.app,
          'email': user.email,
          'role': user.role,
          'first_name': user.first_name,
          'last_name': user.last_name,
        }),
      );
      _trackAppVersion();
      final fcmToken = await FirebaseMessaging.instance.getToken();
     

      if (fcmToken != null && user.app != null && user.app.isNotEmpty) {
        await GoogleSheetService.updateFcmToken(user.app, fcmToken);
      }
    } catch (e) {
      print("🔥 FCM HATA: $e");
    }

 

    // 🔥 SPLASHSCREEN YOK! Doğrudan Loading Screen'lere yönlendir
    // Veriler Loading Screen'lerde yüklenecek

    if (roleType == 'admin') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdminLoadingScreen(currentUserRole: 'admin', user: user),
          ),
        );
      }
    } else if (roleType == 'accountant') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountantLoadingScreen(
              currentUserRole: 'accountant',
              user: user,
            ),
          ),
        );
      }
    } else if (roleType == 'coach') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CoachLoadingScreen(user: user)),
        );
      }
    } else if (roleType == 'student') {
      print("🎯 ÖĞRENCİ OLARAK GİRİŞ YAPILIYOR...");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentLoadingScreen(user: user)),
        );
      }
    } else if (roleType == 'parent') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ParentLoadingScreen(user: user)),
        );
      }
    } else {
      _showSnackBar(
        "❌ Geçersiz rol: ${user.role}\nSistem yöneticinize başvurun.",
        isError: true,
      );
      setState(() => _isLoading = false);
    }
    try {
      final attendanceService = OfflineAttendanceService();
      await attendanceService.init();
      await attendanceService.processQueueNow();
    } catch (e) {
      print("⚠️ Arka plan yoklama işlemi başlatılamadı: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = false, int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
      ),
    );
  }

  void _backToLogin() {
    setState(() {
      _isOtpMode = false;
      _otpController.clear();
      _generatedOtp = null;
      _pendingUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ANİMASYONLU BASKETBOL TOPU
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: AnimatedBuilder(
                        animation: _bounceController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              10 * (1 - _bounceController.value),
                            ),
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFEF4444),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(65),
                                child: Image.asset(
                                  'assets/images/sports.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.sports_basketball,
                                      size: 60,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // YAZI ANİMASYONU
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Column(
                      children: [
                        Text(
                          " EVOM SPOR ",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.orange,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Uygulamasına Hoş Geldiniz",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "⚡ PERFORMANS • GÜÇ • BAŞARI ⚡",
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 🔥 SON GİRİŞ BİLGİSİ (Varsa - ALT ALTA)
                  if (_lastLoginEmail != null &&
                      _lastLoginDate != null &&
                      !_isOtpMode)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: Colors.orange[400],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Son Oturum",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[300],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _lastLoginEmail!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _lastLoginDate!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
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

                  // FORM
                  if (_isOtpMode) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildOtpCard(),
                    ),
                  ] else ...[
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildLoginForm(),
                      ),
                    ),
                    const VersionFooter(),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "E-posta Adresi",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.email, color: Colors.orange[400]),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Şifre",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.lock, color: Colors.orange[400]),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.orange,
                checkColor: Colors.white,
              ),
              const Text(
                "Beni Hatırla",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ForgotPasswordPage(),
                      transitionsBuilder: (_, a, __, c) =>
                          FadeTransition(opacity: a, child: c),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[400],
                ),
                child: const Text(
                  "Şifremi Unuttum?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 5,
                shadowColor: Colors.orange.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "GİRİŞ YAP",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  "İKİ ADIMLI DOĞRULAMA",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Text(
                    _generatedOtp ?? "------",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Yukarıdaki kodu aşağıya giriniz",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: "------",
              hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _verifyOtpAndLogin,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "DOĞRULA",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _backToLogin,
            child: Text("Geri Dön", style: TextStyle(color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // 🔥 Sadece cihazın hiç bağlantısı yoksa (wifi/mobil veri tamamen kapalı)
      // "internet yok" say. Zayıf/yavaş bağlantıda sunucuya ping atıp
      // hemen "yok" demeyi bırakıyoruz; asıl istek zaten kendi hata
      // yönetimiyle (timeout, retry vs.) ilgilenecek.
      return results != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            Text("İnternet bağlantınız bulunmuyor."),
            SizedBox(height: 12),
            Text(
              "Lütfen Wi-Fi veya mobil verinizi açtıktan sonra tekrar deneyin.",
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("ÇIKIŞ"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkInternetAndRetry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("TEKRAR DENE"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkInternetAndRetry() async {
    final hasInternet = await _checkInternet();
    if (hasInternet && mounted) {
      _handleLogin();
    } else if (mounted) {
      _showNoInternetDialog();
    }
  }

  Future<void> _trackAppVersion() async {
    try {
      // 1️⃣ Kullanıcı bilgilerini al
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('logged_user');

      if (userJson == null) {
        print("📌 Kullanıcı oturum açmamış, sürüm takibi atlandı");
        return;
      }

      final userMap = json.decode(userJson) as Map<String, dynamic>;
      final userId = userMap['app']?.toString() ?? '';
      final email = userMap['email']?.toString() ?? '';
      String deviceInfo = Platform.operatingSystem; // "android" veya "ios"
      if (userId.isEmpty) {
        print("📌 Kullanıcı ID boş, sürüm takibi atlandı");
        return;
      }

      // 2️⃣ Uygulama sürümünü al
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // 3️⃣ Cihaz bilgisini al
      // final deviceInfo = await _getDeviceInfo();

      print("📱 Sürüm takibi gönderiliyor:");
      print("   User ID: $userId");
      print("   Email: $email");
      print("   Sürüm: $appVersion");
      //print("   Cihaz: $deviceInfo");

      // 4️⃣ Apps Script'e gönder
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'action': 'trackAppVersion',
              'user_id': userId,
              'email': email,
              'app_version': appVersion,

              /// 'device_info': deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          print("✅ Sürüm takibi başarıyla kaydedildi!");
        } else {
          print("❌ Sürüm takibi başarısız: ${decoded['error']}");
        }
      } else {
        print("❌ HTTP hatası: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Sürüm takibi hatası: $e");
    }
  }

  // 🔥 CİHAZ BİLGİSİ AL
  // 🔥 CİHAZ BİLGİSİ AL - PAKETSİZ
  // 📱 CİHAZ BİLGİSİ - BASİT VE GÜVENLİ

  // iOS versiyonunu almak için
  Future<String> _getIOSVersion() async {
    try {
      // iOS'te sistem versiyonunu almanın basit yolu
      // UIDevice.current.systemVersion'a erişemiyoruz,
      // ama device_info_plus olmadan tam bilgi zor
      return "iOS";
    } catch (e) {
      return "iOS";
    }
  }
}
*/
import 'dart:convert';
import 'dart:io';

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/internet/network_aware_wrapper.dart';
import 'package:EVOM_SPOR/local/offline_syn_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:EVOM_SPOR/widgets/acountantoverlay.dart';
import 'package:EVOM_SPOR/widgets/coachoverlay.dart';
import 'package:EVOM_SPOR/widgets/loading_manager.dart';
import 'package:EVOM_SPOR/widgets/parentLoading.dart';
import 'package:EVOM_SPOR/widgets/studentoverlay.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/password_hashing/forgot_password.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/userInterfacepage/userinterface.dart';
import 'package:EVOM_SPOR/accountant/accountant_interface.dart';
import 'package:EVOM_SPOR/config.dart';
import 'package:EVOM_SPOR/security_question_service.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _baseUrl = kBackendUrl;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOtpMode = false;
  bool _rememberMe = true;
  String? _generatedOtp;
  Users? _pendingUser;
  String? _lastLoginEmail;
  String? _lastLoginDate;

  // 🔐 Günlük güvenlik sorusu durumu
  bool _isSecurityMode = false; // soru soruluyor mu
  bool _isSecuritySetupMode = false; // ilk kurulum mu (cevapları giriyor)
  String? _currentQuestionId;
  String _currentQuestionText = '';
  final TextEditingController _securityAnswerController =
      TextEditingController();
  final Map<String, TextEditingController> _setupControllers = {};

  // Animasyonlar
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<String> _validRoles = [
    'admin',
    'yönetici',
    'accountant',
    'muhasebeci',
    'coach',
    'antrenör',
    'assistant_coach',
    'yardımcı_antrenör',
    'student',
    'öğrenci',
    'parent',
    'veli',
  ];

  String _formatDateTurkish(DateTime date) {
    final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSavedUserAndFastLogin();
    });

    _initializeOfflineFirst();
  }

  Future<void> _initializeOfflineFirst() async {
    try {
      final repo = AppRepository();
      await repo.init();
      final syncManager = OfflineSyncManager();
      await syncManager.init(repo);

      syncManager.onDataChanged.listen((_) {
        if (mounted) setState(() {});
      });

      syncManager.syncNow();
    } catch (e) {
      // Sessiz geç
    }
  }

  /// ⚡ IŞIK HIZINDA ANINDA GİRİŞ (Optimistic / Yerel Cache Doğrulama)
  Future<void> _checkSavedUserAndFastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final lastLoginEmail = prefs.getString('last_login_email');
    final lastLoginDate = prefs.getString('last_login_date');
    final cachedUserJson = prefs.getString('logged_user_cache');

    if (lastLoginEmail != null && lastLoginDate != null && mounted) {
      setState(() {
        _lastLoginEmail = lastLoginEmail;
        _lastLoginDate = lastLoginDate;
      });
    }

    if (rememberMe && savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
      _rememberMe = true;

      // 🚀 Eğer cihazda daha önceden cache'lenmiş tam kullanıcı profili varsa,
      // interneti hiç beklemeden ANINDA (0 ms) içeri al ve verileri arka planda çek!
      if (cachedUserJson != null) {
        try {
          final userMap = json.decode(cachedUserJson) as Map<String, dynamic>;
          final fastUser = Users(
            app: userMap['app'] ?? '',
            first_name: userMap['first_name'] ?? '',
            last_name: userMap['last_name'] ?? '',
            email: userMap['email'] ?? '',
            role: userMap['role'] ?? '',
            phone: userMap['phone'] ?? '',
            amount: userMap['amount'] ?? '0',
            profile_photo_url: userMap['profile_photo_url'] ?? '',
            created_at: userMap['created_at'] ?? '',
            is_active: 'TRUE',
            b_date: '',
            mother_name: '',
            father_name: '',
            branches_id: '',
            password_hash: '',
            last_login: '',
          );

          print("⚡ Işık hızında yerel önbellekten (cache) oturum açıldı!");
          // Arka planda sunucuyu güncel tutmak için sessizce doğrula
          _backgroundVerifyAndUpdateCache(savedEmail, savedPassword);

          if (mounted) {
            _completeLogin(fastUser);
            return;
          }
        } catch (_) {}
      }

      // Cache yoksa normal hızlı login tetikle
      Future.delayed(const Duration(milliseconds: 100), () {
        _handleLogin();
      });
    }
  }

  /// 🔄 Kullanıcı içerideyken arka planda güncel verileri çekip cache'i tazele
  Future<void> _backgroundVerifyAndUpdateCache(
    String email,
    String password,
  ) async {
    try {
      final user = await GoogleSheetService.login(email, password);
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'logged_user_cache',
          jsonEncode({
            'app': user.app,
            'email': user.email,
            'role': user.role,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'phone': user.phone,
            'amount': user.amount,
            'profile_photo_url': user.profile_photo_url,
            'created_at': user.created_at,
          }),
        );
      }
    } catch (_) {}
  }

  Future<void> saveToken(String token) async {
    final url = Uri.parse(kBackendUrl);
    final request = http.Request('POST', url)
      ..followRedirects = true
      ..maxRedirects = 5
      ..bodyFields = {'action': 'saveToken', 'userId': '727', 'token': token};

    final streamedResponse = await request.send();
    await http.Response.fromStream(streamedResponse);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _securityAnswerController.dispose();
    for (final c in _setupControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _saveLastLoginInfo(Users user) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final formattedDate = _formatDateTurkish(now);
    await prefs.setString('last_login_email', user.email);
    await prefs.setString('last_login_date', formattedDate);

    // Tam kullanıcı profilini de cachele
    await prefs.setString(
      'logged_user_cache',
      jsonEncode({
        'app': user.app,
        'email': user.email,
        'role': user.role,
        'first_name': user.first_name,
        'last_name': user.last_name,
        'phone': user.phone,
        'amount': user.amount,
        'profile_photo_url': user.profile_photo_url,
        'created_at': user.created_at,
      }),
    );

    if (mounted) {
      setState(() {
        _lastLoginEmail = user.email;
        _lastLoginDate = formattedDate;
      });
    }
  }

  String _generateOtp() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  String _getRoleType(String? role) {
    if (role == null) return 'invalid';
    final lowerRole = role.toLowerCase();

    if (lowerRole == 'admin' || lowerRole == 'yönetici') return 'admin';
    if (lowerRole == 'accountant' || lowerRole == 'muhasebeci')
      return 'accountant';
    if (lowerRole == 'coach' ||
        lowerRole == 'antrenör' ||
        lowerRole == 'assistant_coach' ||
        lowerRole == 'yardımcı_antrenör')
      return 'coach';
    if (lowerRole == 'student' || lowerRole == 'öğrenci') return 'student';
    if (lowerRole == 'parent' || lowerRole == 'veli') return 'parent';
    return 'invalid';
  }

  bool _requires2FA(String? role) {
    final roleType = _getRoleType(role);
    return roleType == 'admin' || roleType == 'accountant';
  }

  Future<void> _start2FA(Users user) async {
    final otp = _generateOtp();
    _generatedOtp = otp;
    _pendingUser = user;
    setState(() {
      _isOtpMode = true;
      _isLoading = false;
    });
  }

  // ==========================================================================
  // 🔐 GÜNLÜK GÜVENLİK SORUSU AKIŞI
  // ==========================================================================
  Future<void> _startSecurityFlow(Users user) async {
    _pendingUser = user;
    final email = user.email;
    final decision = await SecurityQuestionService().decideOnLogin(email);

    if (decision == 'skip') {
      // Bugün zaten soruldu / gerek yok -> direkt gir
      await _completeLogin(user);
      return;
    }

    if (decision == 'setup') {
      // İlk kurulum (veya yeni cihaz): kullanıcı cevaplarını girsin
      _setupControllers.clear();
      for (final q in SecurityQuestionService.questions) {
        _setupControllers[q['id']!] = TextEditingController();
      }
      setState(() {
        _isSecuritySetupMode = true;
        _isSecurityMode = false;
        _isLoading = false;
      });
      return;
    }

    // decision == 'ask' -> bugünün sorusunu getir
    final q = await SecurityQuestionService().pickQuestionForToday(email);
    if (q == null) {
      // Beklenmedik durum: kurulum bozuksa yeniden kur
      setState(() {
        _isSecuritySetupMode = true;
        _isSecurityMode = false;
        _isLoading = false;
      });
      return;
    }
    _currentQuestionId = q['id'];
    _currentQuestionText = q['text'] ?? 'Güvenlik sorusu';
    _securityAnswerController.clear();
    setState(() {
      _isSecurityMode = true;
      _isSecuritySetupMode = false;
      _isLoading = false;
    });
  }

  /// Kurulumdaki cevapları kaydet (en az 2 soru dolu olmalı).
  Future<void> _saveSecuritySetup() async {
    final user = _pendingUser;
    if (user == null) return;

    final answers = <String, String>{};
    _setupControllers.forEach((qId, ctrl) {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) answers[qId] = v;
    });

    if (answers.length < 2) {
      _showSnackBar(
        "Lütfen en az 2 soruyu cevaplayın (birini unutursanız diğerinden sorulur).",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await SecurityQuestionService().setUpAnswers(
      user.email,
      answers,
    );
    if (!ok) {
      setState(() => _isLoading = false);
      _showSnackBar("Kurulum kaydedilemedi, tekrar deneyin.", isError: true);
      return;
    }
    // Kurulum sonrası bugün için de soruldu sayılır -> direkt gir
    await SecurityQuestionService().markAskedToday(user.email);
    await _completeLogin(user);
  }

  /// Günlük soruya verilen cevabı doğrula.
  Future<void> _verifySecurityAnswer() async {
    final user = _pendingUser;
    if (user == null || _currentQuestionId == null) return;

    final answer = _securityAnswerController.text.trim();
    if (answer.isEmpty) {
      _showSnackBar("Lütfen cevabı girin!", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await SecurityQuestionService().verifyAnswer(
      user.email,
      _currentQuestionId!,
      answer,
    );
    if (!ok) {
      setState(() => _isLoading = false);
      _showSnackBar("❌ Cevap yanlış, tekrar deneyin.", isError: true);
      return;
    }

    // Doğru -> bugün soruldu işaretle, giriş yap
    await SecurityQuestionService().markAskedToday(user.email);
    await _completeLogin(user);
  }

  Future<void> _verifyOtpAndLogin() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.isEmpty) {
      _showSnackBar("Lütfen güvenlik kodunu girin!", isError: true);
      return;
    }
    if (enteredOtp != _generatedOtp) {
      _showSnackBar("❌ Hatalı güvenlik kodu!", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    await _completeLogin(_pendingUser!);
  }

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Lütfen e-posta ve şifre alanlarını doldurun.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await GoogleSheetService.login(email, password);

      if (user != null) {
        final String isActive = (user.is_active ?? 'TRUE').toUpperCase().trim();

        if (isActive == 'FALSE') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('logged_user');
          await prefs.remove('logged_user_cache');
          setState(() => _isLoading = false);
          _showErrorDialog(
            "Hesabınız pasif durumdadır. Lütfen yönetim ile iletişime geçin.",
          );
          return;
        }

        await _saveLoginCredentials(email, _passwordController.text.trim());
        await _saveLastLoginInfo(user);

        if (_requires2FA(user.role)) {
          // 🔐 Günlük güvenlik sorusu akışı (OTP yerine)
          await _startSecurityFlow(user);
          setState(() => _isLoading = false);
        } else {
          await _completeLogin(user);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("E-posta adresi veya şifre hatalı!", isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        "Sunucuyla bağlantı kurulurken bir hata oluştu.",
        isError: true,
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              "Giriş Yetkisi Yok",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Anladım",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeLogin(Users user) async {
    final roleType = _getRoleType(user.role);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'logged_user',
        jsonEncode({
          'app': user.app,
          'email': user.email,
          'role': user.role,
          'first_name': user.first_name,
          'last_name': user.last_name,
        }),
      );
      _trackAppVersion();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null && user.app != null && user.app.isNotEmpty) {
        await GoogleSheetService.updateFcmToken(user.app, fcmToken);
      }
    } catch (_) {}

    if (roleType == 'admin') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdminLoadingScreen(currentUserRole: 'admin', user: user),
          ),
        );
      }
    } else if (roleType == 'accountant') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountantLoadingScreen(
              currentUserRole: 'accountant',
              user: user,
            ),
          ),
        );
      }
    } else if (roleType == 'coach') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CoachLoadingScreen(user: user)),
        );
      }
    } else if (roleType == 'student') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentLoadingScreen(user: user)),
        );
      }
    } else if (roleType == 'parent') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ParentLoadingScreen(user: user)),
        );
      }
    } else {
      _showSnackBar(
        "❌ Geçersiz rol: ${user.role}\nSistem yöneticinize başvurun.",
        isError: true,
      );
      setState(() => _isLoading = false);
    }

    try {
      final attendanceService = OfflineAttendanceService();
      await attendanceService.init();
      await attendanceService.processQueueNow();
    } catch (_) {}
  }

  void _showSnackBar(String message, {bool isError = false, int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
      ),
    );
  }

  void _backToLogin() {
    setState(() {
      _isOtpMode = false;
      _otpController.clear();
      _generatedOtp = null;
      _pendingUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: AnimatedBuilder(
                        animation: _bounceController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              10 * (1 - _bounceController.value),
                            ),
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFEF4444),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(65),
                                child: Image.asset(
                                  'assets/images/sports.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.sports_basketball,
                                      size: 60,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Column(
                      children: [
                        Text(
                          " EVOM SPOR ",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.orange,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Uygulamasına Hoş Geldiniz",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isSecuritySetupMode) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildSecuritySetupCard(),
                    ),
                  ] else if (_isSecurityMode) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildSecurityQuestionCard(),
                    ),
                  ] else if (_isOtpMode) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildOtpCard(),
                    ),
                  ] else ...[
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildLoginForm(),
                      ),
                    ),
                    const VersionFooter(),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "E-posta Adresi",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.email, color: Colors.orange[400]),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Şifre",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.lock, color: Colors.orange[400]),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.orange,
                checkColor: Colors.white,
              ),
              const Text(
                "Beni Hatırla",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ForgotPasswordPage(),
                      transitionsBuilder: (_, a, __, c) =>
                          FadeTransition(opacity: a, child: c),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[400],
                ),
                child: const Text(
                  "Şifremi Unuttum?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "GİRİŞ YAP",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔐 Güvenlik sorusu KURULUM kartı (ilk kez / yeni cihaz)
  Widget _buildSecuritySetupCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Güvenlik Kurulumu",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "İlk giriş için en az 2 soruyu cevaplayın. Bu cevaplar bu cihazda "
            "güvenli şekilde saklanır ve her gün ilk girişte biri sorulur.",
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          ...SecurityQuestionService.questions.map((q) {
            final ctrl = _setupControllers[q['id']];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q['text'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      hintText: "Cevabınız (isteğe bağlı)",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSecuritySetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Kaydet ve Giriş Yap",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔐 Günlük güvenlik SORUSU kartı
  Widget _buildSecurityQuestionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Text(
                "Güvenlik Sorusu",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentQuestionText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _securityAnswerController,
            autofocus: true,
            onSubmitted: (_) => _verifySecurityAnswer(),
            decoration: InputDecoration(
              hintText: "Cevabınız",
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifySecurityAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Doğrula ve Giriş Yap",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: "------",
              hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _isLoading ? null : _verifyOtpAndLogin,
              child: const Text("DOĞRULA"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _trackAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('logged_user');
      if (userJson == null) return;

      final userMap = json.decode(userJson) as Map<String, dynamic>;
      final userId = userMap['app']?.toString() ?? '';
      final email = userMap['email']?.toString() ?? '';
      if (userId.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'action': 'trackAppVersion',
              'user_id': userId,
              'email': email,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

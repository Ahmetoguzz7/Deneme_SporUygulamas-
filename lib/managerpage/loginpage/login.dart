/*import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';

class AdvancedSignUpPage extends StatefulWidget {
  const AdvancedSignUpPage({super.key});

  @override
  State<AdvancedSignUpPage> createState() => _AdvancedSignUpPageState();
}

class _AdvancedSignUpPageState extends State<AdvancedSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyParent = GlobalKey<FormState>();
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();

  String _mode = "register";
  Users? _selectedUser;
  List<Users> _searchResults = [];
  String _searchQuery = "";
  bool _isSearching = false;
  Timer? _searchDebounce;
  String _selectedGroupFilter = "";
  List<Group> _allGroups = [];
  Map<String, List<String>> _userGroups = {};

  // 🔥 YENİ: Çoklu hoca desteği için liste
  List<String> _selectedSupervisorCoachIds = [];
  String _tempSupervisorCoachId = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _createdDateController = TextEditingController();
  final TextEditingController _healthProblemsController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentSurnameController =
      TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherPhoneController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherPhoneController = TextEditingController();

  String _selectedRole = 'student';
  String _selectedBranchId = '';
  String _selectedSportId = '';
  String _selectedGroupId = '';
  bool _hasParent = false;
  File? _profileImage;
  String _existingPhotoUrl = "";
  bool _isLoading = false;
  bool _isBackgroundProcessing = false;

  List<Branches> _branches = [];
  List<Sports> _sports = [];
  List<Group> _groups = [];
  List<Users> _existingUsers = [];

  // =========================================================================
  // VALIDASYON FONKSİYONLARI
  // =========================================================================

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Telefon numarası zorunlu";
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 11)
      return "Telefon numarası tam olarak 11 haneli olmalıdır";
    if (!cleaned.startsWith('05'))
      return "Telefon numarası 05 ile başlamalıdır (Örn: 05xxxxxxxxx)";
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "E-posta adresi zorunlu";
    final validDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@yahoo.com',
      '@outlook.com',
      '@icloud.com',
      '@yandex.com',
      '@protonmail.com',
      '@evom.com.tr',
    ];
    final email = value.trim().toLowerCase();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email))
      return "Geçerli bir e-posta adresi formatı giriniz";
    bool hasValidDomain = false;
    for (var domain in validDomains) {
      if (email.endsWith(domain)) {
        hasValidDomain = true;
        break;
      }
    }
    if (!hasValidDomain)
      return "Sadece izin verilen domainler desteklenir (gmail, hotmail, evom.com.tr vb.)";
    return null;
  }

  String? _validatePassword(String? value) {
    if (_mode == "register") {
      if (value == null || value.isEmpty) return "Şifre zorunlu";
      if (value.length < 6) return "Şifre en az 6 karakter olmalıdır";
    }
    if (_mode == "update" && value != null && value.isNotEmpty) {
      if (value.length < 6) return "Yeni şifre en az 6 karakter olmalıdır";
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (_selectedRole == 'student' || _selectedRole == 'öğrenci') {
      if (value == null || value.isEmpty) return "Aylık ücret zorunlu";
      final amount = double.tryParse(value);
      if (amount == null || amount < 0) return "Geçerli bir ücret giriniz";
    }
    return null;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // =========================================================================
  // TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // =========================================================================
  // LIFE CYCLE
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _mode = "update";
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _createdDateController.dispose();
    _healthProblemsController.dispose();
    _amountController.dispose();
    _parentNameController.dispose();
    _parentSurnameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _motherNameController.dispose();
    _motherPhoneController.dispose();
    _fatherNameController.dispose();
    _fatherPhoneController.dispose();
    super.dispose();
  }

  // =========================================================================
  // VERİ YÜKLEME
  // =========================================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _branches = _repo.allBranches;
      _sports = _repo.allSports;
      _groups = _repo.allGroups;
      _allGroups = _repo.allGroups;
      _existingUsers = _repo.allUsers;

      _userGroups.clear();
      for (var rel in _repo.allGroupStudents) {
        if (rel.is_active.toString().toUpperCase() == "TRUE") {
          if (!_userGroups.containsKey(rel.student_id)) {
            _userGroups[rel.student_id] = [];
          }
          _userGroups[rel.student_id]!.add(rel.groups_id);
        }
      }

      if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branches_id;
      if (_sports.isNotEmpty) _selectedSportId = _sports.first.sports_id;
      if (_groups.isNotEmpty) _selectedGroupId = _groups.first.groups_id;
    } catch (e) {
      print("Lokal veri yükleme hatası: $e");
    }
    if (mounted) setState(() => _isLoading = false);
    unawaited(_refreshDataInBackground());
  }

  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
    setState(() => _isBackgroundProcessing = true);
    try {
      await _repo.loadAllData();
      _branches = _repo.allBranches;
      _sports = _repo.allSports;
      _groups = _repo.allGroups;
      _allGroups = _repo.allGroups;
      _existingUsers = _repo.allUsers;
      if (_branches.isNotEmpty && _selectedBranchId.isEmpty) {
        _selectedBranchId = _branches.first.branches_id;
      }
      if (_sports.isNotEmpty && _selectedSportId.isEmpty) {
        _selectedSportId = _sports.first.sports_id;
      }
    } catch (e) {
      print("Arka plan veri yenileme hatası: $e");
    } finally {
      if (mounted) setState(() => _isBackgroundProcessing = false);
    }
  }

  // =========================================================================
  // BİLDİRİM FONKSİYONLARI
  // =========================================================================

  void _showSuccessNotification(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =========================================================================
  // ARAMA FONKSİYONLARI
  // =========================================================================

  void _searchUserWithGroup(String query, String groupId) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        if (query.isEmpty && groupId.isEmpty) {
          _searchResults = [];
          return;
        }
        final searchLower = query.toLowerCase().trim();
        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "assistant_coach" ||
              role == "yardımcı_antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";
          if (!isAllowedRole) return false;
          if (groupId.isNotEmpty) {
            final userGroupIds = _userGroups[user.app] ?? [];
            if (!userGroupIds.contains(groupId)) return false;
          }
          if (query.isNotEmpty) {
            final fullName = "${user.first_name} ${user.last_name}"
                .toLowerCase();
            return fullName.contains(searchLower) ||
                user.email.toLowerCase().contains(searchLower);
          }
          return true;
        }).toList();
        if (_searchResults.length > 50)
          _searchResults = _searchResults.sublist(0, 50);
      });
    });
  }

  void _searchUser(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _searchResults = [];
          return;
        }
        final searchLower = query.toLowerCase().trim();
        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "assistant_coach" ||
              role == "yardımcı_antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";
          if (!isAllowedRole) return false;
          final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
          return fullName.contains(searchLower) ||
              user.email.toLowerCase().contains(searchLower);
        }).toList();
        if (_searchResults.length > 50)
          _searchResults = _searchResults.sublist(0, 50);
      });
    });
  }

  // =========================================================================
  // FOTOĞRAF FONKSİYONLARI
  // =========================================================================

  void _showFullScreenPhoto(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            panEnabled: true,
            maxScale: 4.0,
            minScale: 0.8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: MediaQuery.of(context).size.width * 0.95,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 300,
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          "Fotoğraf yüklenemedi",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  // =========================================================================
  // KULLANICI İŞLEMLERİ
  // =========================================================================

  void _loadUserToForm(Users user) {
    print(
      "🔥🔥🔥 _loadUserToForm ÇAĞRILDI! Kullanıcı: ${user.first_name} ${user.last_name}",
    );
    print("🔥🔥🔥 Kullanıcı rolü: ${user.role}");
    print("🔥🔥🔥 Kullanıcı supervisor_coach_id: ${user.supervisor_coach_id}");
    print(
      "🔍 _loadUserToForm - Kullanıcı: ${user.first_name} ${user.last_name}",
    );
    print("🔍 _loadUserToForm - profile_photo_url: ${user.profile_photo_url}");

    setState(() {
      _selectedUser = user;
      _nameController.text = user.first_name;
      _surnameController.text = user.last_name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _passwordController.text = "";
      _amountController.text = user.amount;

      String birthDate = user.b_date;
      if (birthDate.contains('T')) birthDate = birthDate.split('T')[0];
      _birthDateController.text = birthDate;

      String createdDate = user.created_at;
      if (createdDate.contains('T')) createdDate = createdDate.split('T')[0];
      _createdDateController.text = createdDate;

      final branchExists = _branches.any(
        (b) => b.branches_id == user.branches_id,
      );
      _selectedBranchId = branchExists
          ? user.branches_id
          : (_branches.isNotEmpty ? _branches.first.branches_id : '');

      // ============================================================
      // 🔥🔥🔥 1. ÖNCE ROLÜ ATA
      // ============================================================
      final validRoles = [
        'student',
        'parent',
        'coach',
        'admin',
        'accountant',
        'assistant_coach',
      ];
      _selectedRole = validRoles.contains(user.role.toLowerCase())
          ? user.role.toLowerCase()
          : 'student';

      print("🔥🔥🔥 Seçilen rol: $_selectedRole");

      // ============================================================
      // 🔥🔥🔥 2. SONRA SUPERVISOR LİSTESİNİ DOLDUR
      // ============================================================
      _selectedSupervisorCoachIds = [];

      if (_selectedRole == 'assistant_coach' ||
          _selectedRole == 'yardımcı_antrenör') {
        print(
          "🔥🔥🔥 Yardımcı antrenör tespit edildi! Supervisor bilgisi kontrol ediliyor...",
        );

        if (user.supervisor_coach_id != null &&
            user.supervisor_coach_id!.isNotEmpty) {
          // 🔥 TEMİZLE! Sadece rakamları al
          String raw = user.supervisor_coach_id!;
          // Nokta, virgül, boşluk hepsini temizle
          raw = raw.replaceAll(RegExp(r'[^0-9,]'), '');
          // Birden fazla virgülü tek yap
          raw = raw.replaceAll(RegExp(r',+'), ',');
          // Baştaki ve sondaki virgülleri temizle
          raw = raw.replaceAll(RegExp(r'^,|,$'), '');

          print("🔥🔥🔥 Temizlenmiş supervisor_coach_id: $raw");

          if (raw.isNotEmpty) {
            _selectedSupervisorCoachIds = raw
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            print(
              "🔥🔥🔥 Doldurulan Supervisor ID'ler: $_selectedSupervisorCoachIds",
            );
          }
        } else {
          print("🔥🔥🔥 Supervisor bilgisi BOŞ!");
        }
      }

      _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
      _healthProblemsController.text = "";
      _existingPhotoUrl = GoogleSheetService.convertToDirectImageUrl(
        user.profile_photo_url,
      );
      _profileImage = null;
      _searchQuery = "";
      _searchResults = [];
      _isSearching = false;
      _motherNameController.text = user.mother_name;
      _motherPhoneController.text = user.mother_phone;
      _fatherNameController.text = user.father_name;
      _fatherPhoneController.text = user.father_phone;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _surnameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _birthDateController.clear();
    _createdDateController.clear();
    _healthProblemsController.clear();
    _amountController.clear();
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branches_id : "";
    _selectedSportId = _sports.isNotEmpty ? _sports.first.sports_id : "";
    _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
    _profileImage = null;
    _existingPhotoUrl = "";
    _motherNameController.clear();
    _motherPhoneController.clear();
    _fatherNameController.clear();
    _fatherPhoneController.clear();
    _selectedSupervisorCoachIds = [];
    _tempSupervisorCoachId = '';
  }

  // =========================================================================
  // YARDIMCI ANTRENÖR HOCA İŞLEMLERİ
  // =========================================================================

  void _addSupervisorCoach() {
    print("🔥 _addSupervisorCoach çağrıldı!");
    print("🔥 _tempSupervisorCoachId: $_tempSupervisorCoachId");
    print("🔥 _selectedSupervisorCoachIds: $_selectedSupervisorCoachIds");

    if (_tempSupervisorCoachId.isEmpty) {
      _showSnackBar("Lütfen bir antrenör seçin!", isError: true);
      return;
    }
    if (_selectedSupervisorCoachIds.contains(_tempSupervisorCoachId)) {
      _showSnackBar("Bu antrenör zaten eklenmiş!", isError: true);
      return;
    }

    // 🔥 Seçilen hocanın user bilgisini bul ve göster
    final coach = _existingUsers.firstWhere(
      (u) => u.app == _tempSupervisorCoachId,
      orElse: () => Users(
        app: '',
        first_name: 'Bilinmeyen',
        last_name: '',
        email: '',
        phone: '',
        b_date: '',
        role: '',
        profile_photo_url: '',
        mother_name: '',
        father_name: '',
        is_active: '',
        branches_id: '',
        password_hash: '',
        amount: '',
        created_at: '',
        last_login: '',
      ),
    );

    print(
      "✅ Hoca eklendi: ${coach.first_name} ${coach.last_name} (app: ${coach.app})",
    );

    setState(() {
      _selectedSupervisorCoachIds.add(_tempSupervisorCoachId);
      _tempSupervisorCoachId = '';
      print(
        "🔥 Güncel _selectedSupervisorCoachIds: $_selectedSupervisorCoachIds",
      );
    });
  }

  void _removeSupervisorCoach(String coachId) {
    setState(() {
      _selectedSupervisorCoachIds.remove(coachId);
    });
  }

  String _getSupervisorName(String userId) {
    final user = _existingUsers.firstWhere(
      (u) => u.app == userId,
      orElse: () => Users(
        app: '',
        first_name: 'Bilinmeyen',
        last_name: '',
        email: '',
        phone: '',
        b_date: '',
        role: '',
        profile_photo_url: '',
        mother_name: '',
        father_name: '',
        is_active: '',
        branches_id: '',
        password_hash: '',
        amount: '',
        created_at: '',
        last_login: '',
      ),
    );
    return "${user.first_name} ${user.last_name}".trim();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() => _birthDateController.text = _formatDateForDB(picked));
    }
  }

  Future<void> _selectCreatedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Kayıt Tarihi Seç (Gelecek tarih seçebilirsiniz)',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() => _createdDateController.text = _formatDateForDB(picked));
    }
  }

  Future<bool> _checkEmailExists(String email, {String? excludeUserId}) async {
    if (email.isEmpty) return false;
    return _existingUsers.any(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() &&
          u.app != excludeUserId,
    );
  }

  // =========================================================================
  // GÜNCELLEME İŞLEMİ
  // =========================================================================
  Future<void> _updateUser() async {
    if (_selectedUser == null) {
      _showSnackBar("Lütfen önce bir kullanıcı seçin!", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final emailExists = await _checkEmailExists(
      email,
      excludeUserId: _selectedUser!.app,
    );
    if (emailExists) {
      _showSnackBar(
        "❌ Bu e-posta adresi başka bir kullanıcıya ait!",
        isError: true,
      );
      return;
    }

    // ============================================================
    // 🔥🔥🔥 1. ÖNCE FOTOĞRAFI DRIVE'A YÜKLE (EĞER SEÇİLDİYSE)
    // ============================================================
    print("🔍 _profileImage: $_profileImage");
    print("🔍 _existingPhotoUrl: $_existingPhotoUrl");

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor...");
        final fileName = "${email}.jpg";
        // 🔥 targetUserId kaldırıldı! Sadece resmi yükleyip linki alıyoruz.
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("❌ Fotoğraf güncelleme hatası: $e");
      }
    }

    print("📦 Kullanıcı profile_photo_url: $photoUrl");

    // ============================================================
    // 🔥🔥🔥 2. SUPERVISOR ID'LERİNİ AL
    // ============================================================
    String supervisorIds = '';
    if (_selectedRole == 'assistant_coach' ||
        _selectedRole == 'yardımcı_antrenör') {
      final cleanIds = _selectedSupervisorCoachIds
          .map((id) => id.trim().replaceAll(RegExp(r'[^0-9]'), ''))
          .where((id) => id.isNotEmpty)
          .toList();
      supervisorIds = cleanIds.join(',');
      print("🔗 Güncelleme - Supervisor ID'ler (app ID'leri): $supervisorIds");
    }

    // ============================================================
    // 🔥🔥🔥 3. USERS NESNESİNİ OLUŞTUR
    // ============================================================
    final updatedStudent = Users(
      app: _selectedUser!.app,
      branches_id: _selectedBranchId,
      first_name: _nameController.text.trim(),
      last_name: _surnameController.text.trim(),
      email: email,
      phone: _phoneController.text.trim(),
      password_hash: _passwordController.text.isNotEmpty
          ? _hashPassword(_passwordController.text.trim())
          : _selectedUser!.password_hash,
      role: _selectedRole,
      profile_photo_url: photoUrl ?? "",
      amount: _amountController.text.trim(),
      b_date: _birthDateController.text.trim(),
      created_at: _createdDateController.text.trim(),
      last_login: _selectedUser!.last_login,
      is_active: _selectedUser!.is_active,
      mother_name: _motherNameController.text.trim(),
      mother_phone: _motherPhoneController.text.trim(),
      father_name: _fatherNameController.text.trim(),
      father_phone: _fatherPhoneController.text.trim(),
      supervisor_coach_id: supervisorIds,
    );

    print(
      "📦 Oluşturulan Users nesnesi profile_photo_url: ${updatedStudent.profile_photo_url}",
    );
    print(
      "📦 Oluşturulan Users nesnesi supervisor_coach_id: ${updatedStudent.supervisor_coach_id}",
    );

    // ============================================================
    // 🔥🔥🔥 4. RAM VE CACHE'İ GÜNCELLE
    // ============================================================
    final idx = _repo.allUsers.indexWhere((u) => u.app == _selectedUser!.app);
    if (idx != -1) {
      _repo.allUsers[idx] = updatedStudent;
    }
    await _localStorage.saveUsers(_repo.allUsers);
    await _repo.refreshSingleTable('users');

    _showSuccessNotification(
      "✅ Güncelleme Başarılı",
      "${_nameController.text.trim()} ${_surnameController.text.trim()} bilgileri güncellendi.",
    );
    _clearForm();

    if (mounted) {
      setState(() {
        _selectedUser = null;
        _existingPhotoUrl = "";
        _profileImage = null;
      });
      Navigator.of(context).pop();
    }

    // ============================================================
    // 🔥🔥🔥 5. ARKA PLANDA HOCA BAĞLAMA
    // ============================================================
    // unawaited(_executeBackgroundUpdate(updatedStudent, email));
  }

  // =========================================================================
  // ARKA PLAN GÜNCELLEME
  // =========================================================================

  Future<void> _executeBackgroundUpdate(Users student, String email) async {
    try {
      String photoUrl = student.profile_photo_url ?? "";

      print("🔍 _executeBackgroundUpdate - photoUrl: $photoUrl");

      if (photoUrl.isEmpty || photoUrl.startsWith('/data/')) {
        print("⚠️ Fotoğraf URL'si geçersiz veya yerel: $photoUrl");
      } else {
        print("✅ Fotoğraf URL'si geçerli: $photoUrl");
      }

      // ============================================================
      // 🔥🔥🔥 supervisorIds'yi AL
      // ============================================================
      String supervisorIds = student.supervisor_coach_id ?? '';

      supervisorIds = supervisorIds
          .replaceAll(RegExp(r'[^0-9,]'), '')
          .replaceAll(RegExp(r',+'), ',')
          .replaceAll(RegExp(r'^,|,$'), '')
          .trim();

      if (supervisorIds.isEmpty && _selectedSupervisorCoachIds.isNotEmpty) {
        final cleanIds = _selectedSupervisorCoachIds
            .map((id) => id.trim().replaceAll(RegExp(r'[^0-9]'), ''))
            .where((id) => id.isNotEmpty)
            .toList();
        supervisorIds = cleanIds.join(',');
      }

      print("🔗 Arka plan güncelleme - Supervisor ID'ler: $supervisorIds");

      // ============================================================
      // 🔥🔥🔥 KULLANICIYI GÜNCELLE
      // ============================================================
      Map<String, dynamic> updatedData = {
        "app": student.app,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "email": student.email,
        "phone": student.phone,
        "role": student.role,
        "branches_id": student.branches_id,
        "b_date": student.b_date,
        "created_at": student.created_at,
        "amount": student.amount,
        "profile_photo_url": photoUrl,
        "mother_name": student.mother_name,
        "mother_phone": student.mother_phone,
        "father_name": student.father_name,
        "father_phone": student.father_phone,
        "supervisor_coach_id": supervisorIds,
      };

      print("📤 Güncellenen veri: ${jsonEncode(updatedData)}");
      await GoogleSheetService.updateUser(updatedData);

      // ============================================================
      // 🔥🔥🔥 YARDIMCI ANTRENÖR BAĞLAMA
      // ============================================================
      if ((student.role == 'assistant_coach' ||
              student.role == 'yardımcı_antrenör') &&
          supervisorIds.isNotEmpty) {
        print("🔥 Coach tablosu işlemleri başlıyor...");
        print("🔥 Yardımcı ID (app): ${student.app}");
        print("🔥 Bağlanacağı hocalar (app ID'leri): $supervisorIds");

        final coachIds = supervisorIds.split(',');
        for (var coachId in coachIds) {
          if (coachId.trim().isNotEmpty) {
            final assignResult = await GoogleSheetService.assignAssistant(
              assistantUserId: student.app,
              masterUserId: coachId.trim(),
            );
            print(
              "✅ Yardımcı ${student.app} -> ${coachId.trim()} hocasına bağlandı: $assignResult",
            );
          }
        }
      }

      await _repo.refreshSingleTable('users');
      await _repo.refreshSingleTable('coaches');
      print("✅ _executeBackgroundUpdate TAMAMLANDI");
    } catch (e) {
      print("❌ Arka plan güncelleme hatası: $e");
      print("❌ Hata detayı: ${e.toString()}");
    }
  }

  // =========================================================================
  // KAYIT İŞLEMİ
  // =========================================================================

  Future<void> _handleRegister() async {
    print("🚀 _handleRegister BAŞLADI");

    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    print("📧 Email: $email");

    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      _showSnackBar("❌ Bu e-posta adresi zaten kayıtlı!", isError: true);
      return;
    }

    if (_hasParent && !_formKeyParent.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen veli bilgilerindeki hataları düzeltiniz!",
        isError: true,
      );
      return;
    }
    // _handleRegister() içinde, setState(() => _isLoading = true);'den SONRA EKLE

    String? photoUrl = "";
    print("🔍 _profileImage: $_profileImage");

    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor (kayıt)...");
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    print("📦 Kullanıcı profile_photo_url: $photoUrl");
    // 🔥 FORM VERİLERİNİ AL
    final firstName = _nameController.text.trim();
    final lastName = _surnameController.text.trim();
    final phone = _phoneController.text.trim();
    final amount = _amountController.text.trim().isEmpty
        ? "0"
        : _amountController.text.trim();
    final birthDate = _birthDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _birthDateController.text.trim();
    final createdDate = _createdDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _createdDateController.text.trim();
    final motherName = _motherNameController.text.trim();
    final motherPhone = _motherPhoneController.text.trim();
    final fatherName = _fatherNameController.text.trim();
    final fatherPhone = _fatherPhoneController.text.trim();
    final healthProblems = _healthProblemsController.text.trim();
    final hasParent = _hasParent;
    final parentName = _parentNameController.text.trim();
    final parentSurname = _parentSurnameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final parentEmail = _parentEmailController.text.trim();

    // 🔥🔥🔥 ÇOKLU HOCA ID'LERİNİ AL (BURASI ÖNEMLİ!)
    String supervisorIds = '';
    if (_selectedRole == 'assistant_coach' ||
        _selectedRole == 'yardımcı_antrenör') {
      supervisorIds = _selectedSupervisorCoachIds.join(',');
      print("🔗 SEÇİLEN SUPERVISOR ID'LERİ: $supervisorIds");
    }

    // 🔥 EĞER YARDIMCI ANTRENÖRSE VE HİÇ HOCA SEÇİLMEDİYSE UYARI VER
    if ((_selectedRole == 'assistant_coach' ||
            _selectedRole == 'yardımcı_antrenör') &&
        supervisorIds.isEmpty) {
      _showSnackBar("❌ Lütfen en az bir antrenör seçin!", isError: true);
      return;
    }

    final hashedPassword = _hashPassword(_passwordController.text.trim());

    print("📝 FORM VERİLERİ:");
    print("   Ad: $firstName");
    print("   Soyad: $lastName");
    print("   Email: $email");
    print("   Telefon: $phone");
    print("   Rol: $_selectedRole");
    print("   Supervisor ID'ler: $supervisorIds");
    print("   Amount: $amount");

    // ✅ ARKA PLAN İŞLEMİNİ BAŞLAT
    unawaited(
      _executeBackgroundRegisterWithData(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        hashedPassword: hashedPassword,
        role: _selectedRole,
        branchId: _selectedBranchId,
        sportId: _selectedSportId,
        groupId: _selectedGroupId,
        supervisorIds: supervisorIds,
        amount: amount,
        birthDate: birthDate,
        createdDate: createdDate,
        motherName: motherName,
        motherPhone: motherPhone,
        fatherName: fatherName,
        fatherPhone: fatherPhone,
        healthProblems: healthProblems,
        hasParent: hasParent,
        parentName: parentName,
        parentSurname: parentSurname,
        parentPhone: parentPhone,
        parentEmail: parentEmail,
        profileImage: _profileImage,
      ),
    );

    final studentName = "$firstName $lastName";
    _showSuccessNotification(
      "🎉 Kayıt Başarılı!",
      "$studentName başarıyla kaydedildi.",
    );

    _clearForm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _executeBackgroundRegisterWithData({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String hashedPassword,
    required String role,
    required String branchId,
    required String sportId,
    required String groupId,
    required String supervisorIds,
    required String amount,
    required String birthDate,
    required String createdDate,
    required String motherName,
    required String motherPhone,
    required String fatherName,
    required String fatherPhone,
    required String healthProblems,
    required bool hasParent,
    required String parentName,
    required String parentSurname,
    required String parentPhone,
    required String parentEmail,
    File? profileImage,
  }) async {
    print("🔄 _executeBackgroundRegisterWithData BAŞLADI");
    print("   Ad: $firstName");
    print("   Soyad: $lastName");
    print("   Email: $email");
    print("   Supervisor IDs: $supervisorIds");

    try {
      String? photoUrl = "";
      if (profileImage != null) {
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          profileImage,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("🖼️ Fotoğraf yüklendi: $photoUrl");
      }

      Map<String, dynamic> userInfo = {
        "app": "",
        "branches_id": branchId,
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "phone": phone,
        "password_hash": hashedPassword,
        "role": role,
        "profile_photo_url": photoUrl ?? "",
        "amount": amount,
        "b_date": birthDate,
        "created_at": createdDate,
        "last_login": "",
        "is_active": "TRUE",
        "mother_name": motherName,
        "mother_phone": motherPhone,
        "father_name": fatherName,
        "father_phone": fatherPhone,
      };

      // 🔥 Yardımcı antrenörse supervisor_id'leri ekle
      if (role == 'assistant_coach' || role == 'yardımcı_antrenör') {
        if (supervisorIds.isNotEmpty) {
          userInfo["supervisor_coach_id"] = supervisorIds;
          print("🔗 Supervisor ID'ler eklendi: $supervisorIds");
        }
      }

      print("📤 Gönderilen userInfo:");
      print(jsonEncode(userInfo));

      Map<String, dynamic> allData = {
        "user_info": userInfo,
        "sports_id": sportId,
      };

      if (healthProblems.isNotEmpty) {
        allData["health_problems"] = healthProblems;
      }

      if (hasParent) {
        allData["parent_info"] = {
          "first_name": parentName,
          "last_name": parentSurname,
          "phone": parentPhone,
          "email": parentEmail,
        };
        print("👨‍👩‍👧 Veli bilgileri eklendi");
      }

      final selectedGroupIdForSave = groupId.isNotEmpty && groupId != "none"
          ? groupId
          : "";
      if (selectedGroupIdForSave.isNotEmpty) {
        allData["group_id"] = selectedGroupIdForSave;
        print("📚 Grup ID eklendi: $selectedGroupIdForSave");
      }

      print("📦 Gönderilen Tüm Veri:");
      print(jsonEncode(allData));

      bool result = await GoogleSheetService.registerEverywhere(allData);
      print("📡 registerEverywhere SONUCU: $result");

      if (result) {
        // 🔥🔥🔥 YENİ KULLANICI ID'SİNİ AL
        final allUsers = await GoogleSheetService.getUsersCached(
          forceRefresh: true,
        );
        final newUser = allUsers.firstWhere(
          (u) => u.email.toLowerCase() == email,
          orElse: () => Users(
            app: '',
            branches_id: '',
            first_name: '',
            last_name: '',
            email: '',
            phone: '',
            password_hash: '',
            role: '',
            profile_photo_url: '',
            amount: '',
            b_date: '',
            created_at: '',
            last_login: '',
            is_active: '',
            mother_name: '',
            father_name: '',
          ),
        );

        if (newUser.app.isNotEmpty) {
          // ============================================================
          // 🔥🔥🔥 YARDIMCI ANTRENÖRSE VE HOCA SEÇİLDİYSE BAĞLA
          // ============================================================
          // BU KISIM unassigned_assistants.dart'daki _assignAssistant ile AYNI MANTIK!
          // ============================================================
          if ((role == 'assistant_coach' || role == 'yardımcı_antrenör') &&
              supervisorIds.isNotEmpty) {
            final coachIds = supervisorIds.split(',');
            for (var coachId in coachIds) {
              if (coachId.trim().isNotEmpty) {
                // 🔥 AYNI unassigned_assistants.dart'daki gibi!
                final assignResult = await GoogleSheetService.assignAssistant(
                  assistantUserId: newUser.app,
                  masterUserId: coachId.trim(),
                );
                print(
                  "✅ Yardımcı ${newUser.app} -> ${coachId.trim()} hocasına bağlandı: $assignResult",
                );
              }
            }
          }

          // Gruba ata
          if (selectedGroupIdForSave.isNotEmpty) {
            await GoogleSheetService.assignStudentToGroup(
              newUser.app,
              selectedGroupIdForSave,
            );
            print(
              "✅ Öğrenci gruba atandı: ${newUser.app} -> $selectedGroupIdForSave",
            );
          }
        }
      }

      await _repo.refreshSingleTable('users');
      await _repo.refreshSingleTable('coaches');
      print("✅ _executeBackgroundRegisterWithData TAMAMLANDI");
    } catch (e) {
      print("❌ Arka plan kayıt hatası: $e");
      print("❌ Hata detayı: ${e.toString()}");
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
      case 'öğrenci':
        return 'Öğrenci';
      case 'parent':
      case 'veli':
        return 'Veli';
      case 'coach':
      case 'antrenör':
        return 'Antrenör';
      case 'assistant_coach':
      case 'yardımcı_antrenör':
        return 'Yardımcı Antrenör';
      case 'admin':
      case 'yönetici':
        return 'Admin';
      case 'accountant':
      case 'muhasebeci':
        return 'Muhasebeci';
      default:
        return role;
    }
  }

  // =========================================================================
  // BUILD - ANA SAYFA
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_isBackgroundProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E293B)),
                  SizedBox(height: 16),
                  Text("Veriler yükleniyor..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 20),

                  if (_mode == "update") ...[
                    _buildSearchSection(),
                    const SizedBox(height: 20),
                    if (_selectedUser != null) ...[
                      _buildSelectedUserBanner(),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildPhotoSection(),
                            const SizedBox(height: 20),
                            _buildPersonalInfoSection(),
                            const SizedBox(height: 20),
                            _buildSelectionSection(),
                            const SizedBox(height: 20),
                            _buildParentSection(),
                            const SizedBox(height: 20),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ] else
                      _buildSelectUserHint(),
                  ],

                  if (_mode == "register")
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildPhotoSection(),
                          const SizedBox(height: 20),
                          _buildPersonalInfoSection(),
                          const SizedBox(height: 20),
                          _buildSelectionSection(),
                          const SizedBox(height: 20),
                          if (_selectedRole == 'student' ||
                              _selectedRole == 'öğrenci') ...[
                            _buildHealthSection(),
                            const SizedBox(height: 20),
                            _buildParentSection(),
                            const SizedBox(height: 20),
                          ],
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // ARAYÜZ BİLEŞENLERİ
  // =========================================================================

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = "update";
                  _selectedUser = null;
                  _clearForm();
                  _isSearching = true;
                  _selectedGroupFilter = "";
                  _searchQuery = "";
                  _searchResults = [];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == "update"
                      ? const Color(0xFF1E293B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: _mode == "update" ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Arama",
                      style: TextStyle(
                        color: _mode == "update" ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = "register";
                  _selectedUser = null;
                  _clearForm();
                  _isSearching = false;
                  _selectedGroupFilter = "";
                  _searchQuery = "";
                  _searchResults = [];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == "register"
                      ? const Color(0xFF1E293B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 20,
                      color: _mode == "register" ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Yeni Kayıt",
                      style: TextStyle(
                        color: _mode == "register" ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectUserHint() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.person_search, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Güncellemek istediğiniz kullanıcıyı yukarıdaki arama kutusundan bulun ve seçin.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUserBanner() {
    if (_selectedUser == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal.shade100,
            backgroundImage: _selectedUser!.profile_photo_url.isNotEmpty
                ? NetworkImage(
                        GoogleSheetService.convertToDirectImageUrl(
                          _selectedUser!.profile_photo_url,
                        ),
                      )
                      as ImageProvider
                : null,
            child: _selectedUser!.profile_photo_url.isEmpty
                ? Text(
                    _selectedUser!.first_name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_selectedUser!.first_name} ${_selectedUser!.last_name}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedUser!.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.teal),
            onPressed: () {
              setState(() {
                _selectedUser = null;
                _clearForm();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    if (_existingUsers.isEmpty && _allGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text("Veriler yükleniyor, lütfen bekleyin..."),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kullanıcı Ara ve Güncelle",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_allGroups.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value:
                          (_selectedGroupFilter.isNotEmpty &&
                              _allGroups.any(
                                (g) => g.groups_id == _selectedGroupFilter,
                              ))
                          ? _selectedGroupFilter
                          : null,
                      hint: const Text("Tüm Gruplar"),
                      decoration: InputDecoration(
                        labelText: "Gruba Göre Filtrele",
                        prefixIcon: const Icon(
                          Icons.group,
                          color: Color(0xFF1E293B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: "",
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.all_inclusive, size: 18),
                              SizedBox(width: 8),
                              Text("Tüm Gruplar"),
                            ],
                          ),
                        ),
                        ..._allGroups.map(
                          (group) => DropdownMenuItem<String>(
                            value: group.groups_id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  group.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedGroupFilter = value ?? "");
                        _searchUserWithGroup(
                          _searchQuery,
                          _selectedGroupFilter,
                        );
                      },
                    ),
                  ),
                TextField(
                  onChanged: (value) {
                    if (_selectedGroupFilter.isEmpty) {
                      _searchUser(value);
                    } else {
                      _searchUserWithGroup(value, _selectedGroupFilter);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "İsim, soyisim veya e-posta ile ara...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              if (_selectedGroupFilter.isEmpty) {
                                _searchUser("");
                              } else {
                                _searchUserWithGroup("", _selectedGroupFilter);
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: user.profile_photo_url.isNotEmpty
                                ? NetworkImage(
                                        GoogleSheetService.convertToDirectImageUrl(
                                          user.profile_photo_url,
                                        ),
                                      )
                                      as ImageProvider
                                : null,
                            child: user.profile_photo_url.isEmpty
                                ? Text(
                                    user.first_name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            "${user.first_name} ${user.last_name}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${user.email} • ${_getRoleText(user.role)}",
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.teal,
                          ),
                          onTap: () => _loadUserToForm(user),
                        );
                      },
                    ),
                  ),
                if (_searchQuery.isNotEmpty && _searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "'$_searchQuery' ile eşleşen kullanıcı bulunamadı",
                              style: TextStyle(color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    print("🔍 _buildPhotoSection - _profileImage: $_profileImage");
    print("🔍 _buildPhotoSection - _existingPhotoUrl: $_existingPhotoUrl");
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_profileImage != null) {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: InteractiveViewer(
                        panEnabled: true,
                        maxScale: 4.0,
                        minScale: 0.8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _profileImage!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else if (_existingPhotoUrl.isNotEmpty) {
                _showFullScreenPhoto(_existingPhotoUrl);
              } else {
                _pickImage();
              }
            },
            onLongPress: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(
                      color: const Color(0xFF1E293B),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: _profileImage != null
                        ? DecorationImage(
                            image: FileImage(_profileImage!),
                            fit: BoxFit.cover,
                          )
                        : (_existingPhotoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_existingPhotoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null),
                  ),
                  child: (_profileImage == null && _existingPhotoUrl.isEmpty)
                      ? const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Color(0xFF1E293B),
                        )
                      : null,
                ),
                if (_profileImage != null || _existingPhotoUrl.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library, size: 18),
            label: Text(
              _existingPhotoUrl.isNotEmpty || _profileImage != null
                  ? "Fotoğrafı Değiştir"
                  : "Profil Fotoğrafı Seç",
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Kişisel Bilgiler", Icons.person),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(_nameController, "Ad", Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(
                  _surnameController,
                  "Soyad",
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _emailController,
                  "E-posta",
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _phoneController,
                  "Telefon (05xx)",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _passwordController,
                  "Şifre",
                  Icons.lock_outline,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                if (_selectedRole == 'student' || _selectedRole == 'öğrenci')
                  _buildTextField(
                    _amountController,
                    "Aylık Ücret (TL)",
                    Icons.money,
                    keyboardType: TextInputType.number,
                    validator: _validateAmount,
                  ),
                const SizedBox(height: 12),
                _buildDateField(),
                const SizedBox(height: 12),
                _buildCreatedDateField(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E293B)),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _birthDateController.text.isEmpty
                    ? "Doğum Tarihi Seçin"
                    : _formatDisplayDate(_birthDateController.text),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedDateField() {
    return InkWell(
      onTap: _selectCreatedDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.create, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _createdDateController.text.isEmpty
                    ? "Kayıt Tarihi Seçin"
                    : _formatDisplayDate(_createdDateController.text),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEÇİM BÖLÜMÜ (Yardımcı Antrenör Çoklu Hoca Desteği)
  // =========================================================================

  Widget _buildSelectionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Kayıt Bilgileri", Icons.settings),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRoleSelection(),
                const SizedBox(height: 16),

                // 🔥🔥🔥 YARDIMCI ANTRENÖR İSE ÇOKLU HOCA SEÇİMİ 🔥🔥🔥
                if (_selectedRole == 'assistant_coach' ||
                    _selectedRole == 'yardımcı_antrenör') ...[
                  _buildMultiSupervisorSection(),
                  const SizedBox(height: 12),
                ] else ...[
                  if (_branches.isNotEmpty)
                    _buildDropdown(
                      label: "Şube Seç",
                      value: _selectedBranchId,
                      items: _branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.branches_id,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBranchId = v!),
                    ),
                  const SizedBox(height: 12),
                  if (_sports.isNotEmpty)
                    _buildDropdown(
                      label: "Spor Dalı",
                      value: _selectedSportId,
                      items: _sports
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.sports_id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSportId = v!),
                    ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: "Bağlı Grup",
                    value: _selectedGroupId.isEmpty ? "none" : _selectedGroupId,
                    items: [
                      const DropdownMenuItem(
                        value: "none",
                        child: Text("-- Grup Seçilmedi --"),
                      ),
                      ..._groups.map(
                        (g) => DropdownMenuItem(
                          value: g.groups_id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _selectedGroupId = v == "none" ? "" : v!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥🔥🔥 YENİ: ÇOKLU HOCA SEÇİM BÖLÜMÜ (OVERFLOW FIX)
  // 🔥🔥🔥 YENİ: ÇOKLU HOCA SEÇİM BÖLÜMÜ (OVERFLOW FIX - DÜZELTİLMİŞ)
  Widget _buildMultiSupervisorSection() {
    // 🔥 Sadece 'coach' rolüne sahip kullanıcıları al
    final coaches = _existingUsers
        .where((u) => u.role.toLowerCase() == 'coach')
        .toList();

    // 🔥 Zaten seçili olanları filtrele
    final availableCoaches = coaches.where((coach) {
      return !_selectedSupervisorCoachIds.contains(coach.app);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Row(
          children: [
            Icon(
              Icons.supervised_user_circle,
              color: Colors.teal.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              "Bağlı Olacağı Hocalar",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E), // Colors.teal.shade700
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                "${_selectedSupervisorCoachIds.length} hoca",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Eklenen hocalar listesi
        if (_selectedSupervisorCoachIds.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSupervisorCoachIds.map((coachId) {
                final coachName = _getSupervisorName(coachId);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 12,
                    child: Text(
                      coachName.isNotEmpty ? coachName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  label: Text(coachName, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeSupervisorCoach(coachId),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Hoca ekleme dropdown + buton (TAŞMA PROBLEMİNİN ÇÖZÜLDÜĞÜ YER - DÜZELTİLDİ)
        if (availableCoaches.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔥 FIX: Expanded yerine Flexible kullanıldı
              // 🔥 FIX: mainAxisSize: MainAxisSize.min eklendi
              Flexible(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _tempSupervisorCoachId.isEmpty
                      ? null
                      : _tempSupervisorCoachId,
                  hint: const Text("Hoca Seç", style: TextStyle(fontSize: 13)),
                  decoration: InputDecoration(
                    labelText: "Bağlanılacak Antrenör",
                    labelStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF1E293B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                  ),
                  items: availableCoaches.map((coach) {
                    return DropdownMenuItem<String>(
                      value: coach.app,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: coach.profile_photo_url.isNotEmpty
                                ? NetworkImage(coach.profile_photo_url)
                                : null,
                            child: coach.profile_photo_url.isEmpty
                                ? Text(
                                    coach.first_name.isNotEmpty
                                        ? coach.first_name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "${coach.first_name} ${coach.last_name}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _tempSupervisorCoachId = value ?? '');
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onPressed: _addSupervisorCoach,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      "Ekle",
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        // Hoca bulunamadı uyarısı
        if (coaches.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sistemde kayıtlı ana antrenör bulunamadı! Lütfen önce bir antrenör kaydedin.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // 🔥 Validasyon mesajı (Eğer yardımcı antrenör seçiliyse)
        if (_selectedRole == 'assistant_coach' &&
            _selectedSupervisorCoachIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "⚠️ En az bir antrenör seçmelisiniz!",
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // ROL SEÇİMİ
  // =========================================================================

  Widget _buildRoleSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile(
            title: "Öğrenci / Sporcu",
            subtitle: "Gelişim takibi ve programlar için",
            value: 'student',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Veli",
            subtitle: "Sporcu ödemeleri ve yoklama takibi için",
            value: 'parent',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Antrenör / Koç",
            subtitle: "Sporcu yönetimi ve ders takibi için",
            value: 'coach',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Yardımcı Antrenör",
            subtitle: "Antrenöre bağlı çalışır (Birden fazla seçilebilir)",
            value: 'assistant_coach',
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _selectedRole,
      activeColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: (val) {
        setState(() {
          _selectedRole = val.toString();
          if (_selectedRole != 'assistant_coach' &&
              _selectedRole != 'yardımcı_antrenör') {
            _selectedSupervisorCoachIds = [];
          }
        });
      },
    );
  }

  // =========================================================================
  // DİĞER BİLEŞENLER
  // =========================================================================

  Widget _buildHealthSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Sağlık Bilgileri", Icons.health_and_safety),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _healthProblemsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "Varsa sağlık problemlerini belirtin (alerji, astım vb.)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.family_restroom, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Aile Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.pink.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.female,
                              color: Colors.pink.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Anne Bilgileri",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTextField(
                          _motherNameController,
                          "Anne Adı",
                          Icons.person_outline,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: _buildTextField(
                          _motherPhoneController,
                          "Anne Telefon",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                          isRequired: false,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cleaned = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (cleaned.length != 11)
                                return "Telefon 11 haneli olmalı";
                              if (!cleaned.startsWith('05'))
                                return "05 ile başlamalı";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.male,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Baba Bilgileri",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTextField(
                          _fatherNameController,
                          "Baba Adı",
                          Icons.person_outline,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: _buildTextField(
                          _fatherPhoneController,
                          "Baba Telefon",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                          isRequired: false,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cleaned = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (cleaned.length != 11)
                                return "Telefon 11 haneli olmalı";
                              if (!cleaned.startsWith('05'))
                                return "05 ile başlamalı";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isLoading
            ? null
            : (_mode == "register" ? _handleRegister : _updateUser),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _mode == "register" ? "HESAP OLUŞTUR" : "BİLGİLERİ GÜNCELLE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator:
          validator ??
          (isRequired
              ? (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null
              : null),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    final bool hasValidValue = items.any((item) => item.value == value);
    return DropdownButtonFormField<String>(
      value: hasValidValue ? value : null,
      hint: Text(label),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle,
          color: Color(0xFF1E293B),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
*/
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvancedSignUpPage extends StatefulWidget {
  const AdvancedSignUpPage({super.key});

  @override
  State<AdvancedSignUpPage> createState() => _AdvancedSignUpPageState();
}

class _AdvancedSignUpPageState extends State<AdvancedSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyParent = GlobalKey<FormState>();
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();

  String _mode = "register";
  Users? _selectedUser;
  List<Users> _searchResults = [];
  String _searchQuery = "";
  bool _isSearching = false;
  Timer? _searchDebounce;
  String _selectedGroupFilter = "";
  List<Group> _allGroups = [];
  Map<String, List<String>> _userGroups = {};

  // 🔥 YENİ: Çoklu hoca desteği için liste (SADECE KAYIT İÇİN)
  List<String> _selectedSupervisorCoachIds = [];
  String _tempSupervisorCoachId = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _createdDateController = TextEditingController();
  final TextEditingController _healthProblemsController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentSurnameController =
      TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherPhoneController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherPhoneController = TextEditingController();

  String _selectedRole = 'student';
  String _selectedBranchId = '';
  String _selectedSportId = '';
  String _selectedGroupId = '';
  bool _hasParent = false;
  File? _profileImage;
  String _existingPhotoUrl = "";
  bool _isLoading = false;
  bool _isBackgroundProcessing = false;

  List<Branches> _branches = [];
  List<Sports> _sports = [];
  List<Group> _groups = [];
  List<Users> _existingUsers = [];

  // =========================================================================
  // VALIDASYON FONKSİYONLARI
  // =========================================================================

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Telefon numarası zorunlu";
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 11)
      return "Telefon numarası tam olarak 11 haneli olmalıdır";
    if (!cleaned.startsWith('05'))
      return "Telefon numarası 05 ile başlamalıdır (Örn: 05xxxxxxxxx)";
    return null;
  }

  // 🔥 YENİ: Telefonu temizle ve başına 0 ekle
  // 🔥 Telefon numarasını temizle ve başına 0 ekle (EĞER YOKSA)
  String _cleanPhoneNumber(String phone) {
    // Sadece rakamları al
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Boşsa boş döndür
    if (cleaned.isEmpty) return '';

    // Eğer 10 haneli ise başına 0 ekle (Türk numarası formatı)
    if (cleaned.length == 10) {
      cleaned = '0' + cleaned;
    }

    // Eğer 11 haneli ve 0 ile başlamıyorsa başına 0 ekle
    if (cleaned.length == 11 && !cleaned.startsWith('0')) {
      cleaned = '0' + cleaned;
    }

    // Eğer 12 haneli ve 00 ile başlıyorsa bir 0'ı kaldır
    if (cleaned.length == 12 && cleaned.startsWith('00')) {
      cleaned = cleaned.substring(1);
    }

    // Eğer 12 haneli ve 0 ile başlamıyorsa başına 0 ekle
    if (cleaned.length == 12 && !cleaned.startsWith('0')) {
      cleaned = '0' + cleaned;
    }

    // 🔥 SON GÜVENLİK: Eğer hala 0 ile başlamıyorsa ve 10-11 haneliyse başına 0 ekle
    if (!cleaned.startsWith('0') &&
        (cleaned.length == 10 || cleaned.length == 11)) {
      cleaned = '0' + cleaned;
    }

    return cleaned;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "E-posta adresi zorunlu";
    final validDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@yahoo.com',
      '@outlook.com',
      '@icloud.com',
      '@yandex.com',
      '@protonmail.com',
      '@evom.com.tr',
    ];
    final email = value.trim().toLowerCase();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email))
      return "Geçerli bir e-posta adresi formatı giriniz";
    bool hasValidDomain = false;
    for (var domain in validDomains) {
      if (email.endsWith(domain)) {
        hasValidDomain = true;
        break;
      }
    }
    if (!hasValidDomain)
      return "Sadece izin verilen domainler desteklenir (gmail, hotmail, evom.com.tr vb.)";
    return null;
  }

  String? _validatePassword(String? value) {
    if (_mode == "register") {
      if (value == null || value.isEmpty) return "Şifre zorunlu";
      if (value.length < 6) return "Şifre en az 6 karakter olmalıdır";
    }
    if (_mode == "update" && value != null && value.isNotEmpty) {
      if (value.length < 6) return "Yeni şifre en az 6 karakter olmalıdır";
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (_selectedRole == 'student' || _selectedRole == 'öğrenci') {
      if (value == null || value.isEmpty) return "Aylık ücret zorunlu";
      final amount = double.tryParse(value);
      if (amount == null || amount < 0) return "Geçerli bir ücret giriniz";
    }
    return null;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // =========================================================================
  // TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // =========================================================================
  // LIFE CYCLE
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _mode = "update";
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _createdDateController.dispose();
    _healthProblemsController.dispose();
    _amountController.dispose();
    _parentNameController.dispose();
    _parentSurnameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _motherNameController.dispose();
    _motherPhoneController.dispose();
    _fatherNameController.dispose();
    _fatherPhoneController.dispose();
    super.dispose();
  }

  // =========================================================================
  // VERİ YÜKLEME
  // =========================================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _branches = _repo.allBranches;
      _sports = _repo.allSports;
      _groups = _repo.allGroups;
      _allGroups = _repo.allGroups;
      _existingUsers = _repo.allUsers;

      _userGroups.clear();
      for (var rel in _repo.allGroupStudents) {
        if (rel.is_active.toString().toUpperCase() == "TRUE") {
          if (!_userGroups.containsKey(rel.student_id)) {
            _userGroups[rel.student_id] = [];
          }
          _userGroups[rel.student_id]!.add(rel.groups_id);
        }
      }

      if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branches_id;
      if (_sports.isNotEmpty) _selectedSportId = _sports.first.sports_id;
      if (_groups.isNotEmpty) _selectedGroupId = _groups.first.groups_id;
    } catch (e) {
      print("Lokal veri yükleme hatası: $e");
    }
    if (mounted) setState(() => _isLoading = false);
    unawaited(_refreshDataInBackground());
  }

  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
    setState(() => _isBackgroundProcessing = true);
    try {
      await _repo.loadAllData();
      _branches = _repo.allBranches;
      _sports = _repo.allSports;
      _groups = _repo.allGroups;
      _allGroups = _repo.allGroups;
      _existingUsers = _repo.allUsers;
      if (_branches.isNotEmpty && _selectedBranchId.isEmpty) {
        _selectedBranchId = _branches.first.branches_id;
      }
      if (_sports.isNotEmpty && _selectedSportId.isEmpty) {
        _selectedSportId = _sports.first.sports_id;
      }
    } catch (e) {
      print("Arka plan veri yenileme hatası: $e");
    } finally {
      if (mounted) setState(() => _isBackgroundProcessing = false);
    }
  }

  // =========================================================================
  // BİLDİRİM FONKSİYONLARI
  // =========================================================================

  void _showSuccessNotification(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =========================================================================
  // ARAMA FONKSİYONLARI
  // =========================================================================
  void _searchUserWithGroup(String query, String groupId) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        if (query.isEmpty && groupId.isEmpty) {
          _searchResults = [];
          return;
        }
        // 🔥 Türkçe karakter ve küçük/büyük harf duyarlılığını kaldıran normalize fonksiyonu
        final searchLower = _normalizeText(query);

        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "assistant_coach" ||
              role == "yardımcı_antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";
          if (!isAllowedRole) return false;
          if (groupId.isNotEmpty) {
            final userGroupIds = _userGroups[user.app] ?? [];
            if (!userGroupIds.contains(groupId)) return false;
          }
          if (query.isNotEmpty) {
            final fullName = _normalizeText(
              "${user.first_name} ${user.last_name}",
            );
            final emailNormalized = _normalizeText(user.email);
            final phoneClean = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
            final searchClean = searchLower.replaceAll(RegExp(r'[^0-9]'), '');

            bool matchesText =
                fullName.contains(searchLower) ||
                emailNormalized.contains(searchLower);
            bool matchesPhone =
                searchClean.isNotEmpty && phoneClean.contains(searchClean);

            return matchesText || matchesPhone;
          }
          return true;
        }).toList();
        if (_searchResults.length > 50)
          _searchResults = _searchResults.sublist(0, 50);
      });
    });
  }

  void _searchUser(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _searchResults = [];
          return;
        }
        final searchLower = _normalizeText(query);

        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "assistant_coach" ||
              role == "yardımcı_antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";
          if (!isAllowedRole) return false;

          final fullName = _normalizeText(
            "${user.first_name} ${user.last_name}",
          );
          final emailNormalized = _normalizeText(user.email);
          final phoneClean = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
          final searchClean = searchLower.replaceAll(RegExp(r'[^0-9]'), '');

          bool matchesText =
              fullName.contains(searchLower) ||
              emailNormalized.contains(searchLower);
          bool matchesPhone =
              searchClean.isNotEmpty && phoneClean.contains(searchClean);

          return matchesText || matchesPhone;
        }).toList();
        if (_searchResults.length > 50)
          _searchResults = _searchResults.sublist(0, 50);
      });
    });
  }

  // 🔥 Türkçe karakterleri normalize eden yardımcı fonksiyon (İ -> i, Ş -> s vb.)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleaned);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        print("Arama URI'si açılamadı: $launchUri");
      }
    } catch (e) {
      print("Arama başlatılamadı: $e");
    }
  }
  // =========================================================================
  // FOTOĞRAF FONKSİYONLARI
  // =========================================================================

  void _showFullScreenPhoto(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            panEnabled: true,
            maxScale: 4.0,
            minScale: 0.8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: MediaQuery.of(context).size.width * 0.95,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 300,
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          "Fotoğraf yüklenemedi",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  // =========================================================================
  // KULLANICI İŞLEMLERİ
  // =========================================================================

  void _loadUserToForm(Users user) {
    print(
      "🔥🔥🔥 _loadUserToForm ÇAĞRILDI! Kullanıcı: ${user.first_name} ${user.last_name}",
    );
    print("🔥🔥🔥 Kullanıcı rolü: ${user.role}");
    print("🔥🔥🔥 Kullanıcı supervisor_coach_id: ${user.supervisor_coach_id}");

    setState(() {
      _selectedUser = user;
      _nameController.text = user.first_name;
      _surnameController.text = user.last_name;
      _emailController.text = user.email;

      // 🔥 Telefonu temizle ve başına 0 ekle
      _phoneController.text = _cleanPhoneNumber(user.phone);

      _passwordController.text = "";
      _amountController.text = user.amount;

      String birthDate = user.b_date;
      if (birthDate.contains('T')) birthDate = birthDate.split('T')[0];
      _birthDateController.text = birthDate;

      String createdDate = user.created_at;
      if (createdDate.contains('T')) createdDate = createdDate.split('T')[0];
      _createdDateController.text = createdDate;

      final branchExists = _branches.any(
        (b) => b.branches_id == user.branches_id,
      );
      _selectedBranchId = branchExists
          ? user.branches_id
          : (_branches.isNotEmpty ? _branches.first.branches_id : '');

      final validRoles = [
        'student',
        'parent',
        'coach',
        'admin',
        'accountant',
        'assistant_coach',
      ];
      _selectedRole = validRoles.contains(user.role.toLowerCase())
          ? user.role.toLowerCase()
          : 'student';

      // 🔥 GÜNCELLEMEDE HOCA LİSTESİNİ TEMİZLE (SADECE KAYIT İÇİN)
      _selectedSupervisorCoachIds = [];
      _tempSupervisorCoachId = '';

      _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
      _healthProblemsController.text = "";
      _existingPhotoUrl = GoogleSheetService.convertToDirectImageUrl(
        user.profile_photo_url,
      );
      _profileImage = null;
      _searchQuery = "";
      _searchResults = [];
      _isSearching = false;

      _motherNameController.text = user.mother_name;
      _motherPhoneController.text = _cleanPhoneNumber(
        user.mother_phone,
      ); // <-- EKLE
      _fatherNameController.text = user.father_name;
      _fatherPhoneController.text = _cleanPhoneNumber(
        user.father_phone,
      ); // <-- E
    });
  }

  void _clearForm() {
    _nameController.clear();
    _surnameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _birthDateController.clear();
    _createdDateController.clear();
    _healthProblemsController.clear();
    _amountController.clear();
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branches_id : "";
    _selectedSportId = _sports.isNotEmpty ? _sports.first.sports_id : "";
    _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
    _profileImage = null;
    _existingPhotoUrl = "";
    _motherNameController.clear();
    _motherPhoneController.clear();
    _fatherNameController.clear();
    _fatherPhoneController.clear();
    _selectedSupervisorCoachIds = [];
    _tempSupervisorCoachId = '';
  }

  // =========================================================================
  // YARDIMCI ANTRENÖR HOCA İŞLEMLERİ (SADECE KAYIT İÇİN)
  // =========================================================================

  void _addSupervisorCoach() {
    print("🔥 _addSupervisorCoach çağrıldı!");
    print("🔥 _tempSupervisorCoachId: $_tempSupervisorCoachId");
    print("🔥 _selectedSupervisorCoachIds: $_selectedSupervisorCoachIds");

    if (_tempSupervisorCoachId.isEmpty) {
      _showSnackBar("Lütfen bir antrenör seçin!", isError: true);
      return;
    }
    if (_selectedSupervisorCoachIds.contains(_tempSupervisorCoachId)) {
      _showSnackBar("Bu antrenör zaten eklenmiş!", isError: true);
      return;
    }

    final coach = _existingUsers.firstWhere(
      (u) => u.app == _tempSupervisorCoachId,
      orElse: () => Users(
        app: '',
        first_name: 'Bilinmeyen',
        last_name: '',
        email: '',
        phone: '',
        b_date: '',
        role: '',
        profile_photo_url: '',
        mother_name: '',
        father_name: '',
        is_active: '',
        branches_id: '',
        password_hash: '',
        amount: '',
        created_at: '',
        last_login: '',
      ),
    );

    print(
      "✅ Hoca eklendi: ${coach.first_name} ${coach.last_name} (app: ${coach.app})",
    );

    setState(() {
      _selectedSupervisorCoachIds.add(_tempSupervisorCoachId);
      _tempSupervisorCoachId = '';
      print(
        "🔥 Güncel _selectedSupervisorCoachIds: $_selectedSupervisorCoachIds",
      );
    });
  }

  void _removeSupervisorCoach(String coachId) {
    setState(() {
      _selectedSupervisorCoachIds.remove(coachId);
    });
  }

  String _getSupervisorName(String userId) {
    final user = _existingUsers.firstWhere(
      (u) => u.app == userId,
      orElse: () => Users(
        app: '',
        first_name: 'Bilinmeyen',
        last_name: '',
        email: '',
        phone: '',
        b_date: '',
        role: '',
        profile_photo_url: '',
        mother_name: '',
        father_name: '',
        is_active: '',
        branches_id: '',
        password_hash: '',
        amount: '',
        created_at: '',
        last_login: '',
      ),
    );
    return "${user.first_name} ${user.last_name}".trim();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() => _birthDateController.text = _formatDateForDB(picked));
    }
  }

  Future<void> _selectCreatedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Kayıt Tarihi Seç (Gelecek tarih seçebilirsiniz)',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() => _createdDateController.text = _formatDateForDB(picked));
    }
  }

  Future<bool> _checkEmailExists(String email, {String? excludeUserId}) async {
    if (email.isEmpty) return false;
    return _existingUsers.any(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() &&
          u.app != excludeUserId,
    );
  }

  // =========================================================================
  // GÜNCELLEME İŞLEMİ
  // =========================================================================
  /*
  Future<void> _updateUser() async {
    if (_selectedUser == null) {
      _showSnackBar("Lütfen önce bir kullanıcı seçin!", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final emailExists = await _checkEmailExists(
      email,
      excludeUserId: _selectedUser!.app,
    );
    if (emailExists) {
      _showSnackBar(
        "❌ Bu e-posta adresi başka bir kullanıcıya ait!",
        isError: true,
      );
      return;
    }

    // 🔥 Telefonu temizle ve başına 0 ekle
    final phone = _cleanPhoneNumber(_phoneController.text.trim());

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor...");
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("❌ Fotoğraf güncelleme hatası: $e");
      }
    }

    // 🔥 GÜNCELLEMEDE SUPERVISOR ID'LERİ GÖNDERME (KULLANICININ MEVCUT DEĞERİNİ KORU)
    String supervisorIds = _selectedUser!.supervisor_coach_id ?? '';

    final updatedStudent = Users(
      app: _selectedUser!.app,
      branches_id: _selectedBranchId,
      first_name: _nameController.text.trim(),
      last_name: _surnameController.text.trim(),
      email: email,
      phone: phone, // 🔥 Düzeltilmiş telefon
      password_hash: _passwordController.text.isNotEmpty
          ? _hashPassword(_passwordController.text.trim())
          : _selectedUser!.password_hash,
      role: _selectedRole,
      profile_photo_url: photoUrl ?? "",
      amount: _amountController.text.trim(),
      b_date: _birthDateController.text.trim(),
      created_at: _createdDateController.text.trim(),
      last_login: _selectedUser!.last_login,
      is_active: _selectedUser!.is_active,
      mother_name: _motherNameController.text.trim(),
      mother_phone: _cleanPhoneNumber(_motherPhoneController.text.trim()),
      father_name: _fatherNameController.text.trim(),
      father_phone: _cleanPhoneNumber(_fatherPhoneController.text.trim()),
      supervisor_coach_id: supervisorIds, // 🔥 MEVCUT DEĞERİ KORU
    );

    final idx = _repo.allUsers.indexWhere((u) => u.app == _selectedUser!.app);
    if (idx != -1) {
      _repo.allUsers[idx] = updatedStudent;
    }
    await _localStorage.saveUsers(_repo.allUsers);
    await _repo.refreshSingleTable('users');

    _showSuccessNotification(
      "✅ Güncelleme Başarılı",
      "${_nameController.text.trim()} ${_surnameController.text.trim()} bilgileri güncellendi.",
    );
    _clearForm();

    if (mounted) {
      setState(() {
        _selectedUser = null;
        _existingPhotoUrl = "";
        _profileImage = null;
      });
      Navigator.of(context).pop();
    }
  }
*/
  Future<void> _updateUser() async {
    if (_selectedUser == null) {
      _showSnackBar("Lütfen önce bir kullanıcı seçin!", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true); // 🔥 YÜKLENİYOR BAŞLAT

    final email = _emailController.text.trim().toLowerCase();
    final emailExists = await _checkEmailExists(
      email,
      excludeUserId: _selectedUser!.app,
    );
    if (emailExists) {
      setState(() => _isLoading = false);
      _showSnackBar(
        "❌ Bu e-posta adresi başka bir kullanıcıya ait!",
        isError: true,
      );
      return;
    }

    // 🔥 Telefonu temizle ve başına 0 ekle
    final phone = _cleanPhoneNumber(_phoneController.text.trim());

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor...");
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("❌ Fotoğraf güncelleme hatası: $e");
      }
    }

    // 🔥 GÜNCELLEMEDE ROL DEĞİŞTİRME - YENİ ROLÜ KULLAN
    final String newRole = _selectedRole;

    // 🔥 GÜNCELLEMEDE SUPERVISOR ID'LERİ KORU (değiştirme)
    String supervisorIds = _selectedUser!.supervisor_coach_id ?? '';

    final updatedStudent = Users(
      app: _selectedUser!.app,
      branches_id: _selectedBranchId,
      first_name: _nameController.text.trim(),
      last_name: _surnameController.text.trim(),
      email: email,
      phone: phone,
      password_hash: _passwordController.text.isNotEmpty
          ? _hashPassword(_passwordController.text.trim())
          : _selectedUser!.password_hash,
      role: newRole, // 🔥 YENİ ROL
      profile_photo_url: photoUrl ?? "",
      amount: _amountController.text.trim(),
      b_date: _birthDateController.text.trim(),
      created_at: _createdDateController.text.trim(),
      last_login: _selectedUser!.last_login,
      is_active: _selectedUser!.is_active,
      mother_name: _motherNameController.text.trim(),
      mother_phone: _cleanPhoneNumber(_motherPhoneController.text.trim()),
      father_name: _fatherNameController.text.trim(),
      father_phone: _cleanPhoneNumber(_fatherPhoneController.text.trim()),
      supervisor_coach_id: supervisorIds,
    );

    // RAM GÜNCELLE
    final idx = _repo.allUsers.indexWhere((u) => u.app == _selectedUser!.app);
    if (idx != -1) {
      _repo.allUsers[idx] = updatedStudent;
    }
    await _localStorage.saveUsers(_repo.allUsers);

    // 🔥 ARKA PLANDA BULUTA GÖNDER
    unawaited(() async {
      try {
        Map<String, dynamic> updateData = {
          "app": updatedStudent.app,
          "first_name": updatedStudent.first_name,
          "last_name": updatedStudent.last_name,
          "email": updatedStudent.email,
          "phone": updatedStudent.phone,
          "role": updatedStudent.role, // 🔥 ROL GÜNCELLENDİ
          "branches_id": updatedStudent.branches_id,
          "b_date": updatedStudent.b_date,
          "created_at": updatedStudent.created_at,
          "amount": updatedStudent.amount,
          "profile_photo_url": updatedStudent.profile_photo_url,
          "mother_name": updatedStudent.mother_name,
          "mother_phone": updatedStudent.mother_phone,
          "father_name": updatedStudent.father_name,
          "father_phone": updatedStudent.father_phone,
          "supervisor_coach_id": updatedStudent.supervisor_coach_id ?? '',
        };
        await GoogleSheetService.updateUser(updateData);
        await _repo.refreshSingleTable('users');
      } catch (e) {
        print("❌ Arka plan güncelleme hatası: $e");
      }
    }());

    await _repo.refreshSingleTable('users');

    _showSuccessNotification(
      "✅ Güncelleme Başarılı",
      "${_nameController.text.trim()} ${_surnameController.text.trim()} bilgileri güncellendi.",
    );

    _clearForm();
    setState(() => _isLoading = false); // 🔥 YÜKLENİYOR BİTİR

    if (mounted) {
      setState(() {
        _selectedUser = null;
        _existingPhotoUrl = "";
        _profileImage = null;
      });
      Navigator.of(context).pop();
    }
  }

  // =========================================================================
  // KAYIT İŞLEMİ
  // =========================================================================
  /*
  Future<void> _handleRegister() async {
    print("🚀 _handleRegister BAŞLADI");

    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    print("📧 Email: $email");

    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      _showSnackBar("❌ Bu e-posta adresi zaten kayıtlı!", isError: true);
      return;
    }

    if (_hasParent && !_formKeyParent.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen veli bilgilerindeki hataları düzeltiniz!",
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);

    String? photoUrl = "";
    print("🔍 _profileImage: $_profileImage");

    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor (kayıt)...");
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    print("📦 Kullanıcı profile_photo_url: $photoUrl");

    final firstName = _nameController.text.trim();
    final lastName = _surnameController.text.trim();
    // 🔥 Telefonu temizle ve başına 0 ekle
    final phone = _cleanPhoneNumber(_phoneController.text.trim());
    final amount = _amountController.text.trim().isEmpty
        ? "0"
        : _amountController.text.trim();
    final birthDate = _birthDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _birthDateController.text.trim();
    final createdDate = _createdDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _createdDateController.text.trim();
    final motherName = _motherNameController.text.trim();
    final motherPhone = _cleanPhoneNumber(_motherPhoneController.text.trim());
    final fatherPhone = _cleanPhoneNumber(_fatherPhoneController.text.trim());
    final fatherName = _fatherNameController.text.trim();

    final healthProblems = _healthProblemsController.text.trim();
    final hasParent = _hasParent;
    final parentName = _parentNameController.text.trim();
    final parentSurname = _parentSurnameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final parentEmail = _parentEmailController.text.trim();

    // 🔥🔥🔥 ÇOKLU HOCA ID'LERİNİ AL (SADECE KAYIT İÇİN)
    String supervisorIds = '';
    if (_selectedRole == 'assistant_coach' ||
        _selectedRole == 'yardımcı_antrenör') {
      supervisorIds = _selectedSupervisorCoachIds.join(',');
      print("🔗 SEÇİLEN SUPERVISOR ID'LERİ: $supervisorIds");
    }

    if ((_selectedRole == 'assistant_coach' ||
            _selectedRole == 'yardımcı_antrenör') &&
        supervisorIds.isEmpty) {
      setState(() => _isLoading = false);
      _showSnackBar("❌ Lütfen en az bir antrenör seçin!", isError: true);
      return;
    }

    final hashedPassword = _hashPassword(_passwordController.text.trim());
    /*
    print("📝 FORM VERİLERİ:");
    print("   Ad: $firstName");
    print("   Soyad: $lastName");
    print("   Email: $email");
    print("   Telefon: $phone");
    print("   Rol: $_selectedRole");
    print("   Supervisor ID'ler: $supervisorIds");
    print("   Amount: $amount");
*/
    unawaited(
      _executeBackgroundRegisterWithData(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        hashedPassword: hashedPassword,
        role: _selectedRole,
        branchId: _selectedBranchId,
        sportId: _selectedSportId,
        groupId: _selectedGroupId,
        supervisorIds: supervisorIds,
        amount: amount,
        birthDate: birthDate,
        createdDate: createdDate,
        motherName: motherName,
        motherPhone: motherPhone,
        fatherName: fatherName,
        fatherPhone: fatherPhone,
        healthProblems: healthProblems,
        hasParent: hasParent,
        parentName: parentName,
        parentSurname: parentSurname,
        parentPhone: parentPhone,
        parentEmail: parentEmail,
        profileImage: _profileImage,
      ),
    );

    final studentName = "$firstName $lastName";
    _showSuccessNotification(
      "🎉 Kayıt Başarılı!",
      "$studentName başarıyla kaydedildi.",
    );

    _clearForm();
    if (mounted) Navigator.of(context).pop();
  }
  */
  Future<void> _handleRegister() async {
    print("🚀 _handleRegister BAŞLADI");

    if (_isLoading) return;

    // 🔥 VALİDASYON KONTROLLERİ
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    print("📧 Email: $email");

    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      _showSnackBar("❌ Bu e-posta adresi zaten kayıtlı!", isError: true);
      return;
    }

    if (_hasParent && !_formKeyParent.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen veli bilgilerindeki hataları düzeltiniz!",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true); // 🔥 YÜKLENİYOR BAŞLAT

    String? photoUrl = "";
    print("🔍 _profileImage: $_profileImage");

    if (_profileImage != null) {
      try {
        print("🖼️ Fotoğraf Drive'a yükleniyor (kayıt)...");
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("📤 uploadImageToDrive sonucu: $photoUrl");
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    print("📦 Kullanıcı profile_photo_url: $photoUrl");

    final firstName = _nameController.text.trim();
    final lastName = _surnameController.text.trim();
    // 🔥 Telefonu temizle ve başına 0 ekle
    final phone = _cleanPhoneNumber(_phoneController.text.trim());
    final amount = _amountController.text.trim().isEmpty
        ? "0"
        : _amountController.text.trim();
    final birthDate = _birthDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _birthDateController.text.trim();
    final createdDate = _createdDateController.text.trim().isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _createdDateController.text.trim();
    final motherName = _motherNameController.text.trim();
    final motherPhone = _cleanPhoneNumber(_motherPhoneController.text.trim());
    final fatherPhone = _cleanPhoneNumber(_fatherPhoneController.text.trim());
    final fatherName = _fatherNameController.text.trim();

    final healthProblems = _healthProblemsController.text.trim();
    final hasParent = _hasParent;
    final parentName = _parentNameController.text.trim();
    final parentSurname = _parentSurnameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final parentEmail = _parentEmailController.text.trim();

    // 🔥🔥🔥 ÇOKLU HOCA ID'LERİNİ AL (SADECE KAYIT İÇİN)
    String supervisorIds = '';
    if (_selectedRole == 'assistant_coach' ||
        _selectedRole == 'yardımcı_antrenör') {
      supervisorIds = _selectedSupervisorCoachIds.join(',');
      print("🔗 SEÇİLEN SUPERVISOR ID'LERİ: $supervisorIds");
    }

    if ((_selectedRole == 'assistant_coach' ||
            _selectedRole == 'yardımcı_antrenör') &&
        supervisorIds.isEmpty) {
      setState(() => _isLoading = false);
      _showSnackBar("❌ Lütfen en az bir antrenör seçin!", isError: true);
      return;
    }

    final hashedPassword = _hashPassword(_passwordController.text.trim());

    print("📝 FORM VERİLERİ:");
    print("   Ad: $firstName");
    print("   Soyad: $lastName");
    print("   Email: $email");
    print("   Telefon: $phone");
    print("   Rol: $_selectedRole");
    print("   Supervisor ID'ler: $supervisorIds");
    print("   Amount: $amount");

    // 🔥 KAYIT İŞLEMİNİ ARKA PLANA AT
    unawaited(
      _executeBackgroundRegisterWithData(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        hashedPassword: hashedPassword,
        role: _selectedRole,
        branchId: _selectedBranchId,
        sportId: _selectedSportId,
        groupId: _selectedGroupId,
        supervisorIds: supervisorIds,
        amount: amount,
        birthDate: birthDate,
        createdDate: createdDate,
        motherName: motherName,
        motherPhone: motherPhone,
        fatherName: fatherName,
        fatherPhone: fatherPhone,
        healthProblems: healthProblems,
        hasParent: hasParent,
        parentName: parentName,
        parentSurname: parentSurname,
        parentPhone: parentPhone,
        parentEmail: parentEmail,
        profileImage: _profileImage,
      ),
    );

    final studentName = "$firstName $lastName";
    _showSuccessNotification(
      "🎉 Kayıt Başarılı!",
      "$studentName başarıyla kaydedildi.",
    );

    _clearForm();

    setState(() => _isLoading = false); // 🔥 YÜKLENİYOR BİTİR

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _executeBackgroundRegisterWithData({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String hashedPassword,
    required String role,
    required String branchId,
    required String sportId,
    required String groupId,
    required String supervisorIds,
    required String amount,
    required String birthDate,
    required String createdDate,
    required String motherName,
    required String motherPhone,
    required String fatherName,
    required String fatherPhone,
    required String healthProblems,
    required bool hasParent,
    required String parentName,
    required String parentSurname,
    required String parentPhone,
    required String parentEmail,
    File? profileImage,
  }) async {
    print("🔄 _executeBackgroundRegisterWithData BAŞLADI");
    print("   Ad: $firstName");
    print("   Soyad: $lastName");
    print("   Email: $email");
    print("   Supervisor IDs: $supervisorIds");

    try {
      String? photoUrl = "";
      if (profileImage != null) {
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          profileImage,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
        print("🖼️ Fotoğraf yüklendi: $photoUrl");
      }

      Map<String, dynamic> userInfo = {
        "app": "",
        "branches_id": branchId,
        "first_name": firstName,
        "last_name": lastName,
        "email": email,
        "phone": phone,
        "password_hash": hashedPassword,
        "role": role,
        "profile_photo_url": photoUrl ?? "",
        "amount": amount,
        "b_date": birthDate,
        "created_at": createdDate,
        "last_login": "",
        "is_active": "TRUE",
        "mother_name": motherName,
        "mother_phone": motherPhone,
        "father_name": fatherName,
        "father_phone": fatherPhone,
      };

      if (role == 'assistant_coach' || role == 'yardımcı_antrenör') {
        if (supervisorIds.isNotEmpty) {
          userInfo["supervisor_coach_id"] = supervisorIds;
          print("🔗 Supervisor ID'ler eklendi: $supervisorIds");
        }
      }

      print("📤 Gönderilen userInfo:");
      print(jsonEncode(userInfo));

      Map<String, dynamic> allData = {
        "user_info": userInfo,
        "sports_id": sportId,
      };

      if (healthProblems.isNotEmpty) {
        allData["health_problems"] = healthProblems;
      }

      if (hasParent) {
        allData["parent_info"] = {
          "first_name": parentName,
          "last_name": parentSurname,
          "phone": parentPhone,
          "email": parentEmail,
        };
        print("👨‍👩‍👧 Veli bilgileri eklendi");
      }

      final selectedGroupIdForSave = groupId.isNotEmpty && groupId != "none"
          ? groupId
          : "";
      print("🔥🔥🔥 SEÇİLEN GRUP ID: '$selectedGroupIdForSave'"); // DEBUG

      if (selectedGroupIdForSave.isNotEmpty) {
        allData["group_id"] = selectedGroupIdForSave;
        print("📚 Grup ID eklendi: $selectedGroupIdForSave");
      }

      print("📦 Gönderilen Tüm Veri:");
      print(jsonEncode(allData));

      bool result = await GoogleSheetService.registerEverywhere(allData);
      print("📡 registerEverywhere SONUCU: $result");

      if (result) {
        final allUsers = await GoogleSheetService.getUsersCached(
          forceRefresh: true,
        );
        final newUser = allUsers.firstWhere(
          (u) => u.email.toLowerCase() == email,
          orElse: () => Users(
            app: '',
            branches_id: '',
            first_name: '',
            last_name: '',
            email: '',
            phone: '',
            password_hash: '',
            role: '',
            profile_photo_url: '',
            amount: '',
            b_date: '',
            created_at: '',
            last_login: '',
            is_active: '',
            mother_name: '',
            father_name: '',
          ),
        );

        if (newUser.app.isNotEmpty) {
          if ((role == 'assistant_coach' || role == 'yardımcı_antrenör') &&
              supervisorIds.isNotEmpty) {
            final coachIds = supervisorIds.split(',');
            for (var coachId in coachIds) {
              if (coachId.trim().isNotEmpty) {
                final assignResult = await GoogleSheetService.assignAssistant(
                  assistantUserId: newUser.app,
                  masterUserId: coachId.trim(),
                );
                print(
                  "✅ Yardımcı ${newUser.app} -> ${coachId.trim()} hocasına bağlandı: $assignResult",
                );
              }
            }
          }

          // o tertemiz grup ID'si artık boş kalmadığı için bu if bloğu tetiklenecek!
          if (selectedGroupIdForSave.isNotEmpty) {
            print(
              "🚀 Öğrenci gruba atanıyor... ID: ${newUser.app} -> Grup: $selectedGroupIdForSave",
            );
            await GoogleSheetService.assignStudentToGroup(
              newUser.app,
              selectedGroupIdForSave,
            );
            // İlişki tablosu cache'ini de zorla tazele ki atama anında yansısın
            await GoogleSheetService.fetchTableCached(
              'group_students',
              forceRefresh: true,
            );
          }
        }
      }

      await _repo.refreshSingleTable('users');
      await _repo.refreshSingleTable('coaches');
      print("✅ _executeBackgroundRegisterWithData TAMAMLANDI");
    } catch (e) {
      print("❌ Arka plan kayıt hatası: $e");
      print("❌ Hata detayı: ${e.toString()}");
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
      case 'öğrenci':
        return 'Öğrenci';
      case 'parent':
      case 'veli':
        return 'Veli';
      case 'coach':
      case 'antrenör':
        return 'Antrenör';
      case 'assistant_coach':
      case 'yardımcı_antrenör':
        return 'Yardımcı Antrenör';
      case 'admin':
      case 'yönetici':
        return 'Admin';
      case 'accountant':
      case 'muhasebeci':
        return 'Muhasebeci';
      default:
        return role;
    }
  }

  // =========================================================================
  // BUILD - ANA SAYFA
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_isBackgroundProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E293B)),
                  SizedBox(height: 16),
                  Text("Veriler yükleniyor..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 20),

                  if (_mode == "update") ...[
                    _buildSearchSection(),
                    const SizedBox(height: 20),
                    if (_selectedUser != null) ...[
                      _buildSelectedUserBanner(),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildPhotoSection(),
                            const SizedBox(height: 20),
                            _buildPersonalInfoSection(),
                            const SizedBox(height: 20),
                            _buildSelectionSection(
                              showSupervisor: false,
                            ), // 🔥 false gönder
                            const SizedBox(height: 20),
                            _buildParentSection(),
                            const SizedBox(height: 20),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ] else
                      _buildSelectUserHint(),
                  ],

                  if (_mode == "register")
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildPhotoSection(),
                          const SizedBox(height: 20),
                          _buildPersonalInfoSection(),
                          const SizedBox(height: 20),
                          _buildSelectionSection(
                            showSupervisor: true,
                          ), // 🔥 true gönder
                          const SizedBox(height: 20),
                          if (_selectedRole == 'student' ||
                              _selectedRole == 'öğrenci') ...[
                            _buildHealthSection(),
                            const SizedBox(height: 20),
                            _buildParentSection(),
                            const SizedBox(height: 20),
                          ],
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // ARAYÜZ BİLEŞENLERİ
  // =========================================================================

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = "update";
                  _selectedUser = null;
                  _clearForm();
                  _isSearching = true;
                  _selectedGroupFilter = "";
                  _searchQuery = "";
                  _searchResults = [];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == "update"
                      ? const Color(0xFF1E293B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: _mode == "update" ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Arama",
                      style: TextStyle(
                        color: _mode == "update" ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = "register";
                  _selectedUser = null;
                  _clearForm();
                  _isSearching = false;
                  _selectedGroupFilter = "";
                  _searchQuery = "";
                  _searchResults = [];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _mode == "register"
                      ? const Color(0xFF1E293B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 20,
                      color: _mode == "register" ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Yeni Kayıt",
                      style: TextStyle(
                        color: _mode == "register" ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectUserHint() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.person_search, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Güncellemek istediğiniz kullanıcıyı yukarıdaki arama kutusundan bulun ve seçin.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUserBanner() {
    if (_selectedUser == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal.shade100,
            backgroundImage: _selectedUser!.profile_photo_url.isNotEmpty
                ? NetworkImage(
                        GoogleSheetService.convertToDirectImageUrl(
                          _selectedUser!.profile_photo_url,
                        ),
                      )
                      as ImageProvider
                : null,
            child: _selectedUser!.profile_photo_url.isEmpty
                ? Text(
                    _selectedUser!.first_name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_selectedUser!.first_name} ${_selectedUser!.last_name}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedUser!.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.teal),
            onPressed: () {
              setState(() {
                _selectedUser = null;
                _clearForm();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    if (_existingUsers.isEmpty && _allGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text("Veriler yükleniyor, lütfen bekleyin..."),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kullanıcı Ara ve Güncelle",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_allGroups.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value:
                          (_selectedGroupFilter.isNotEmpty &&
                              _allGroups.any(
                                (g) => g.groups_id == _selectedGroupFilter,
                              ))
                          ? _selectedGroupFilter
                          : null,
                      hint: const Text("Tüm Gruplar"),
                      decoration: InputDecoration(
                        labelText: "Gruba Göre Filtrele",
                        prefixIcon: const Icon(
                          Icons.group,
                          color: Color(0xFF1E293B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: "",
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.all_inclusive, size: 18),
                              SizedBox(width: 8),
                              Text("Tüm Gruplar"),
                            ],
                          ),
                        ),
                        ..._allGroups.map(
                          (group) => DropdownMenuItem<String>(
                            value: group.groups_id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  group.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedGroupFilter = value ?? "");
                        _searchUserWithGroup(
                          _searchQuery,
                          _selectedGroupFilter,
                        );
                      },
                    ),
                  ),
                TextField(
                  onChanged: (value) {
                    if (_selectedGroupFilter.isEmpty) {
                      _searchUser(value);
                    } else {
                      _searchUserWithGroup(value, _selectedGroupFilter);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "İsim, soyisim veya e-posta ile ara...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              if (_selectedGroupFilter.isEmpty) {
                                _searchUser("");
                              } else {
                                _searchUserWithGroup("", _selectedGroupFilter);
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: user.profile_photo_url.isNotEmpty
                                ? NetworkImage(
                                        GoogleSheetService.convertToDirectImageUrl(
                                          user.profile_photo_url,
                                        ),
                                      )
                                      as ImageProvider
                                : null,
                            child: user.profile_photo_url.isEmpty
                                ? Text(
                                    user.first_name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            "${user.first_name} ${user.last_name}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${user.email} • ${_getRoleText(user.role)}\nTel: ${user.phone.isEmpty ? 'Belirtilmemiş' : user.phone}",
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🔥 ARAMA (TELEFON) BUTONU
                              if (user.phone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.phone,
                                    color: Colors.green,
                                  ),
                                  tooltip: "Ara",
                                  onPressed: () {
                                    _makePhoneCall(user.phone);
                                  },
                                ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.teal,
                              ),
                            ],
                          ),
                          onTap: () => _loadUserToForm(user),
                        );
                      },
                    ),
                  ),
                if (_searchQuery.isNotEmpty && _searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "'$_searchQuery' ile eşleşen kullanıcı bulunamadı",
                              style: TextStyle(color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    print("🔍 _buildPhotoSection - _profileImage: $_profileImage");
    print("🔍 _buildPhotoSection - _existingPhotoUrl: $_existingPhotoUrl");
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_profileImage != null) {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: InteractiveViewer(
                        panEnabled: true,
                        maxScale: 4.0,
                        minScale: 0.8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _profileImage!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else if (_existingPhotoUrl.isNotEmpty) {
                _showFullScreenPhoto(_existingPhotoUrl);
              } else {
                _pickImage();
              }
            },
            onLongPress: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(
                      color: const Color(0xFF1E293B),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: _profileImage != null
                        ? DecorationImage(
                            image: FileImage(_profileImage!),
                            fit: BoxFit.cover,
                          )
                        : (_existingPhotoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_existingPhotoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null),
                  ),
                  child: (_profileImage == null && _existingPhotoUrl.isEmpty)
                      ? const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Color(0xFF1E293B),
                        )
                      : null,
                ),
                if (_profileImage != null || _existingPhotoUrl.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library, size: 18),
            label: Text(
              _existingPhotoUrl.isNotEmpty || _profileImage != null
                  ? "Fotoğrafı Değiştir"
                  : "Profil Fotoğrafı Seç",
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Kişisel Bilgiler", Icons.person),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(_nameController, "Ad", Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(
                  _surnameController,
                  "Soyad",
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _emailController,
                  "E-posta",
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _phoneController,
                  "Telefon (05xx)",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  showPhoneCallButton: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _passwordController,
                  "Şifre",
                  Icons.lock_outline,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                if (_selectedRole == 'student' || _selectedRole == 'öğrenci')
                  _buildTextField(
                    _amountController,
                    "Aylık Ücret (TL)",
                    Icons.money,
                    keyboardType: TextInputType.number,
                    validator: _validateAmount,
                  ),
                const SizedBox(height: 12),
                _buildDateField(),
                const SizedBox(height: 12),
                _buildCreatedDateField(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E293B)),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _birthDateController.text.isEmpty
                    ? "Doğum Tarihi Seçin"
                    : _formatDisplayDate(_birthDateController.text),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedDateField() {
    return InkWell(
      onTap: _selectCreatedDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.create, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _createdDateController.text.isEmpty
                    ? "Kayıt Tarihi Seçin"
                    : _formatDisplayDate(_createdDateController.text),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEÇİM BÖLÜMÜ (showSupervisor parametresi eklendi)
  // =========================================================================
  Widget _buildSelectionSection({required bool showSupervisor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Kayıt Bilgileri", Icons.settings),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 🔥 ROL SEÇİMİ - HEM KAYIT HEM GÜNCELLEMEDE GÖSTER
                _buildRoleSelection(),
                const SizedBox(height: 16),

                // 🔥 SADECE KAYIT MODUNDA VE YARDIMCI ANTRENÖRSE GÖSTER
                if (showSupervisor &&
                    (_selectedRole == 'assistant_coach' ||
                        _selectedRole == 'yardımcı_antrenör')) ...[
                  _buildMultiSupervisorSection(),
                  const SizedBox(height: 12),
                ] else ...[
                  if (_branches.isNotEmpty)
                    _buildDropdown(
                      label: "Şube Seç",
                      value: _selectedBranchId,
                      items: _branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.branches_id,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBranchId = v!),
                    ),
                  const SizedBox(height: 12),
                  if (_sports.isNotEmpty)
                    _buildDropdown(
                      label: "Spor Dalı",
                      value: _selectedSportId,
                      items: _sports
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.sports_id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSportId = v!),
                    ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: "Bağlı Grup",
                    value: _selectedGroupId.isEmpty ? "none" : _selectedGroupId,
                    items: [
                      const DropdownMenuItem(
                        value: "none",
                        child: Text("-- Grup Seçilmedi --"),
                      ),
                      ..._groups.map(
                        (g) => DropdownMenuItem(
                          value: g.groups_id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _selectedGroupId = v == "none" ? "" : v!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  // =========================================================================
  // YENİ: ÇOKLU HOCA SEÇİM BÖLÜMÜ (SADECE KAYIT İÇİN)
  // =========================================================================

  Widget _buildMultiSupervisorSection() {
    final coaches = _existingUsers
        .where((u) => u.role.toLowerCase() == 'coach')
        .toList();

    final availableCoaches = coaches.where((coach) {
      return !_selectedSupervisorCoachIds.contains(coach.app);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.supervised_user_circle,
              color: Colors.teal.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              "Bağlı Olacağı Hocalar",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                "${_selectedSupervisorCoachIds.length} hoca",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_selectedSupervisorCoachIds.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSupervisorCoachIds.map((coachId) {
                final coachName = _getSupervisorName(coachId);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 12,
                    child: Text(
                      coachName.isNotEmpty ? coachName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  label: Text(coachName, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeSupervisorCoach(coachId),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (availableCoaches.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _tempSupervisorCoachId.isEmpty
                      ? null
                      : _tempSupervisorCoachId,
                  hint: const Text("Hoca Seç", style: TextStyle(fontSize: 13)),
                  decoration: InputDecoration(
                    labelText: "Bağlanılacak Antrenör",
                    labelStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF1E293B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                  ),
                  items: availableCoaches.map((coach) {
                    return DropdownMenuItem<String>(
                      value: coach.app,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: coach.profile_photo_url.isNotEmpty
                                ? NetworkImage(coach.profile_photo_url)
                                : null,
                            child: coach.profile_photo_url.isEmpty
                                ? Text(
                                    coach.first_name.isNotEmpty
                                        ? coach.first_name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "${coach.first_name} ${coach.last_name}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _tempSupervisorCoachId = value ?? '');
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onPressed: _addSupervisorCoach,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      "Ekle",
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        if (coaches.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sistemde kayıtlı ana antrenör bulunamadı! Lütfen önce bir antrenör kaydedin.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        if (_selectedRole == 'assistant_coach' &&
            _selectedSupervisorCoachIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "⚠️ En az bir antrenör seçmelisiniz!",
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // ROL SEÇİMİ
  // =========================================================================
  Widget _buildRoleSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile(
            title: "Öğrenci / Sporcu",
            subtitle: "Gelişim takibi ve programlar için",
            value: 'student',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Veli",
            subtitle: "Sporcu ödemeleri ve yoklama takibi için",
            value: 'parent',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Antrenör / Koç",
            subtitle: "Sporcu yönetimi ve ders takibi için",
            value: 'coach',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Yardımcı Antrenör",
            subtitle: "Antrenöre bağlı çalışır (Birden fazla seçilebilir)",
            value: 'assistant_coach',
          ),
          const Divider(height: 1), // 🔥 AYIRICI
          _buildRadioTile(
            title: "Muhasebeci / Accountant",
            subtitle: "Ödeme takibi ve finans yönetimi için",
            value: 'accountant', // 🔥 EKLENDİ
          ),
          const Divider(height: 1), // 🔥 AYIRICI
          _buildRadioTile(
            title: "Admin / Yönetici",
            subtitle: "Tüm yetkilere sahiptir",
            value: 'admin', // 🔥 EKLENDİ
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _selectedRole,
      activeColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: (val) {
        setState(() {
          _selectedRole = val.toString();
          if (_selectedRole != 'assistant_coach' &&
              _selectedRole != 'yardımcı_antrenör') {
            _selectedSupervisorCoachIds = [];
          }
        });
      },
    );
  }

  // =========================================================================
  // DİĞER BİLEŞENLER
  // =========================================================================

  Widget _buildHealthSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader("Sağlık Bilgileri", Icons.health_and_safety),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _healthProblemsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "Varsa sağlık problemlerini belirtin (alerji, astım vb.)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.family_restroom, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Aile Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.pink.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.female,
                              color: Colors.pink.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Anne Bilgileri",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTextField(
                          _motherNameController,
                          "Anne Adı",
                          Icons.person_outline,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: _buildTextField(
                          _motherPhoneController,
                          "Anne Telefon",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                          isRequired: false,
                          showPhoneCallButton: true,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cleaned = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (cleaned.length != 11)
                                return "Telefon 11 haneli olmalı";
                              if (!cleaned.startsWith('05'))
                                return "05 ile başlamalı";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.male,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Baba Bilgileri",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTextField(
                          _fatherNameController,
                          "Baba Adı",
                          Icons.person_outline,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: _buildTextField(
                          _fatherPhoneController,
                          "Baba Telefon",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                          isRequired: false,
                          showPhoneCallButton: true,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cleaned = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (cleaned.length != 11)
                                return "Telefon 11 haneli olmalı";
                              if (!cleaned.startsWith('05'))
                                return "05 ile başlamalı";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isLoading
            ? null
            : (_mode == "register" ? _handleRegister : _updateUser),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _mode == "register"
                        ? "KAYDEDİLİYOR..."
                        : "GÜNCELLENİYOR...",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                _mode == "register" ? "HESAP OLUŞTUR" : "BİLGİLERİ GÜNCELLE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool showPhoneCallButton =
        false, // 🔥 Yeni parametre: True olursa sağda arama ikonu çıkar
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
        // 🔥 Eğer telefon alanıysa ve arama butonu istenmişse sağ tarafa arama butonu koyuyoruz
        suffixIcon: showPhoneCallButton
            ? IconButton(
                icon: const Icon(Icons.phone_forwarded, color: Colors.green),
                tooltip: "Bu Numarayı Ara",
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _makePhoneCall(controller.text);
                  } else {
                    _showSnackBar(
                      "Önce bir telefon numarası girin!",
                      isError: true,
                    );
                  }
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator:
          validator ??
          (isRequired
              ? (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null
              : null),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    final bool hasValidValue = items.any((item) => item.value == value);
    return DropdownButtonFormField<String>(
      value: hasValidValue ? value : null,
      hint: Text(label),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle,
          color: Color(0xFF1E293B),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

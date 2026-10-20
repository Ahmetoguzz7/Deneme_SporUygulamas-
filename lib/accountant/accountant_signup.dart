import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class AccountantSignupPage extends StatefulWidget {
  const AccountantSignupPage({super.key});

  @override
  State<AccountantSignupPage> createState() => _AccountantSignupPageState();
}

class _AccountantSignupPageState extends State<AccountantSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyParent = GlobalKey<FormState>();

  String _mode = "register";
  Users? _selectedUser;
  List<Users> _searchResults = [];
  String _searchQuery = "";
  bool _isSearching = false;
  Timer? _searchDebounce;
  String _selectedGroupFilter = "";
  List<Group> _allGroups = [];
  Map<String, List<String>> _userGroups = {};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _createdDateController = TextEditingController();
  final TextEditingController _healthProblemsController =
      TextEditingController();

  // 🔥 YENİ: Ücret Controller
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Telefon numarası zorunlu";
    }
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 11) {
      return "Telefon numarası tam olarak 11 haneli olmalıdır";
    }
    if (!cleaned.startsWith('05')) {
      return "Telefon numarası 05 ile başlamalıdır (Örn: 05xxxxxxxxx)";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "E-posta adresi zorunlu";
    }

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
    if (!emailRegex.hasMatch(email)) {
      return "Geçerli bir e-posta adresi formatı giriniz";
    }

    bool hasValidDomain = false;
    for (var domain in validDomains) {
      if (email.endsWith(domain)) {
        hasValidDomain = true;
        break;
      }
    }

    if (!hasValidDomain) {
      return "Sadece izin verilen domainler desteklenir (gmail, hotmail, evom.com.tr vb.)";
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (_mode == "register") {
      if (value == null || value.isEmpty) {
        return "Şifre zorunlu";
      }
      if (value.length < 6) {
        return "Şifre en az 6 karakter olmalıdır";
      }
    }
    if (_mode == "update" && value != null && value.isNotEmpty) {
      if (value.length < 6) {
        return "Yeni şifre en az 6 karakter olmalıdır";
      }
    }
    return null;
  }

  /// 🔥 YENİ: Ücret validasyonu
  String? _validateAmount(String? value) {
    if (_selectedRole == 'student' || _selectedRole == 'öğrenci') {
      if (value == null || value.isEmpty) {
        return "Aylık ücret zorunlu";
      }
      final amount = double.tryParse(value);
      if (amount == null || amount < 0) {
        return "Geçerli bir ücret giriniz";
      }
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
    _amountController.dispose(); // 🔥 EKLENDİ
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
      final results = await Future.wait([
        GoogleSheetService.getBranchesCached(),
        GoogleSheetService.getSportsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
      ]);

      _branches = results[0] as List<Branches>;
      _sports = results[1] as List<Sports>;
      _groups = results[2] as List<Group>;
      _allGroups = results[2] as List<Group>;
      _existingUsers = results[3] as List<Users>;

      try {
        final groupStudents = await GoogleSheetService.getGroupStudentsCached();
        _userGroups.clear();
        for (var rel in groupStudents) {
          if (rel.is_active.toString().toUpperCase() == "TRUE") {
            if (!_userGroups.containsKey(rel.student_id)) {
              _userGroups[rel.student_id] = [];
            }
            _userGroups[rel.student_id]!.add(rel.groups_id);
          }
        }
      } catch (e) {
        print("Grup-öğrenci ilişkileri yüklenemedi: $e");
      }

      if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branches_id;
      if (_sports.isNotEmpty) _selectedSportId = _sports.first.sports_id;
      if (_groups.isNotEmpty) _selectedGroupId = _groups.first.groups_id;
    } catch (e) {
      print("Veri yükleme hatası: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
    setState(() => _isBackgroundProcessing = true);

    try {
      final results = await Future.wait([
        GoogleSheetService.getBranchesCached(forceRefresh: true),
        GoogleSheetService.getSportsCached(forceRefresh: true),
        GoogleSheetService.getGroupsCached(forceRefresh: true),
        GoogleSheetService.getUsersCached(forceRefresh: true),
      ]);

      _branches = results[0] as List<Branches>;
      _sports = results[1] as List<Sports>;
      _groups = results[2] as List<Group>;
      _allGroups = results[2] as List<Group>;
      _existingUsers = results[3] as List<Users>;

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

        if (_searchResults.length > 50) {
          _searchResults = _searchResults.sublist(0, 50);
        }
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
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";
          if (!isAllowedRole) return false;

          final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
          return fullName.contains(searchLower) ||
              user.email.toLowerCase().contains(searchLower);
        }).toList();

        if (_searchResults.length > 50) {
          _searchResults = _searchResults.sublist(0, 50);
        }
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
    setState(() {
      _selectedUser = user;
      _nameController.text = user.first_name;
      _surnameController.text = user.last_name;
      _emailController.text = user.email;
      _phoneController.text = _cleanPhoneNumber(user.phone);
      _passwordController.text = "";
      _amountController.text = user.amount; // 🔥 Ücreti de yükle

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

      final validRoles = ['student', 'parent', 'coach', 'admin', 'accountant'];
      _selectedRole = validRoles.contains(user.role.toLowerCase())
          ? user.role.toLowerCase()
          : 'student';

      _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
      _healthProblemsController.text = "";
      _existingPhotoUrl = user.profile_photo_url;
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
      ); // <-- EKLE
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
    _amountController.clear(); // 🔥 EKLENDİ
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branches_id : "";
    _selectedSportId = _sports.isNotEmpty ? _sports.first.sports_id : "";
    _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
    _profileImage = null;
    _existingPhotoUrl = "";
    _motherNameController.clear();
    _motherPhoneController.clear();
    _fatherNameController.clear();
    _fatherPhoneController.clear();
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
  // GÜNCELLEME İŞLEMİ (Ücret desteği ile)
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

    setState(() => _isLoading = true);

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
          targetUserId: _selectedUser!.app,
        );
      } catch (e) {
        print("Fotoğraf güncelleme hatası: $e");
      }
    }

    Map<String, dynamic> updatedData = {
      "app": _selectedUser!.app,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": email,
      "phone": _phoneController.text.trim(),
      "role": _selectedRole,
      "branches_id": _selectedBranchId,
      "b_date": _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim(),
      "amount": _amountController.text.trim(), // 🔥 Ücret eklendi
      "profile_photo_url": photoUrl ?? "",
      "mother_name": _motherNameController.text.trim(),
      "mother_phone": _motherPhoneController.text.trim(),
      "father_name": _fatherNameController.text.trim(),
      "father_phone": _fatherPhoneController.text.trim(),
    };

    bool success = await GoogleSheetService.updateUser(updatedData);

    if (success) {
      await _refreshDataInBackground();
      _showSuccessNotification(
        "✅ Güncelleme Başarılı",
        "${_nameController.text.trim()} ${_surnameController.text.trim()} bilgileri güncellendi.",
      );
      _clearForm();
      if (mounted) {
        setState(() {
          _selectedUser = null;
          _existingPhotoUrl = "";
          _isLoading = false;
        });
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar("❌ Güncelleme başarısız!", isError: true);
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

    // 🔥 TÜM TELEFONLARI TEMİZLE
    final phone = _cleanPhoneNumber(_phoneController.text.trim());
    final motherPhone = _cleanPhoneNumber(_motherPhoneController.text.trim());
    final fatherPhone = _cleanPhoneNumber(_fatherPhoneController.text.trim());

    setState(() => _isLoading = true);

    try {
      String? photoUrl = _existingPhotoUrl;
      if (_profileImage != null) {
        try {
          final fileName = "${email}.jpg";
          photoUrl = await GoogleSheetService.uploadImageToDrive(
            _profileImage!,
            fileName,
            "Öğrenci Bilgileri_Images",
            targetUserId: _selectedUser!.app,
          );
        } catch (e) {
          print("Fotoğraf güncelleme hatası: $e");
        }
      }

      Map<String, dynamic> updatedData = {
        "app": _selectedUser!.app,
        "first_name": _nameController.text.trim(),
        "last_name": _surnameController.text.trim(),
        "email": email,
        "phone": phone, // ✅ Temizlendi!
        "role": _selectedRole,
        "branches_id": _selectedBranchId,
        "b_date": _birthDateController.text.trim(),
        "created_at": _createdDateController.text.trim(),
        "amount": _amountController.text.trim(),
        "profile_photo_url": photoUrl ?? "",
        "mother_name": _motherNameController.text.trim(),
        "mother_phone": motherPhone, // ✅ Temizlendi!
        "father_name": _fatherNameController.text.trim(),
        "father_phone": fatherPhone, // ✅ Temizlendi!
      };

      bool success = await GoogleSheetService.updateUser(updatedData);

      if (mounted) setState(() => _isLoading = false);

      if (success && mounted) {
        await _refreshDataInBackground();
        _showSuccessNotification(
          "✅ Güncelleme Başarılı",
          "${_nameController.text.trim()} ${_surnameController.text.trim()} bilgileri güncellendi.",
        );
        _clearForm();
        setState(() {
          _selectedUser = null;
          _existingPhotoUrl = "";
        });

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop(true);
      } else if (mounted) {
        _showSnackBar("❌ Güncelleme başarısız!", isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("❌ Güncelleme hatası: $e");
      _showSnackBar("❌ Güncelleme sırasında bir hata oluştu!", isError: true);
    }
  }

  // =========================================================================
  // KAYIT İŞLEMİ (Ücret desteği ile)
  // =========================================================================
  /*
  Future<void> _handleRegister() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
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
    if (_profileImage != null) {
      try {
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    final hashedPassword = _hashPassword(_passwordController.text.trim());

    Map<String, dynamic> userInfo = {
      "app": "",
      "branches_id": _selectedBranchId,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": email,
      "phone": _phoneController.text.trim(),
      "password_hash": hashedPassword,
      "role": _selectedRole,
      "profile_photo_url": photoUrl,
      "amount": _amountController.text.trim().isEmpty
          ? "0"
          : _amountController.text.trim(), // 🔥 Ücret eklendi
      "b_date": _birthDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _createdDateController.text.trim(),
      "last_login": "",
      "is_active": "TRUE",
      "mother_name": _motherNameController.text.trim(),
      "mother_phone": _motherPhoneController.text.trim(),
      "father_name": _fatherNameController.text.trim(),
      "father_phone": _fatherPhoneController.text.trim(),
    };

    Map<String, dynamic> allData = {
      "user_info": userInfo,
      "sports_id": _selectedSportId,
    };

    if (_healthProblemsController.text.trim().isNotEmpty) {
      allData["health_problems"] = _healthProblemsController.text.trim();
    }

    if (_hasParent) {
      allData["parent_info"] = {
        "first_name": _parentNameController.text.trim(),
        "last_name": _parentSurnameController.text.trim(),
        "phone": _parentPhoneController.text.trim(),
        "email": _parentEmailController.text.trim(),
      };
    }

    final selectedGroupIdForSave =
        _selectedGroupId.isNotEmpty && _selectedGroupId != "none"
        ? _selectedGroupId
        : "";

    if (selectedGroupIdForSave.isNotEmpty) {
      allData["group_id"] = selectedGroupIdForSave;
    }

    bool result = await GoogleSheetService.registerEverywhere(allData);

    if (result && selectedGroupIdForSave.isNotEmpty) {
      final allUsers = await GoogleSheetService.getUsersCached(
        forceRefresh: true,
      );
      final newUser = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email,
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

      if (newUser.app.isNotEmpty) {
        await GoogleSheetService.assignStudentToGroup(
          newUser.app,
          selectedGroupIdForSave,
        );
      }
    }

    await _refreshDataInBackground();

    if (mounted) setState(() => _isLoading = false);

    if (result && mounted) {
      final studentName =
          "${_nameController.text.trim()} ${_surnameController.text.trim()}";
      _showSuccessNotification(
        "🎉 Kayıt Başarılı!",
        "$studentName başarıyla kaydedildi.",
      );
      _clearForm();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      _showSnackBar("❌ Kayıt başarısız!", isError: true);
    }
  }
*/
  Future<void> _handleRegister() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        "❌ Lütfen formdaki hatalı alanları düzeltiniz!",
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
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

    // 🔥 TÜM TELEFONLARI TEMİZLE
    final phone = _cleanPhoneNumber(_phoneController.text.trim());
    final motherPhone = _cleanPhoneNumber(_motherPhoneController.text.trim());
    final fatherPhone = _cleanPhoneNumber(_fatherPhoneController.text.trim());

    String? photoUrl = "";
    if (_profileImage != null) {
      try {
        final fileName = "${email}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "Öğrenci Bilgileri_Images",
        );
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    final hashedPassword = _hashPassword(_passwordController.text.trim());

    Map<String, dynamic> userInfo = {
      "app": "",
      "branches_id": _selectedBranchId,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": email,
      "phone": phone, // ✅ Temizlendi!
      "password_hash": hashedPassword,
      "role": _selectedRole,
      "profile_photo_url": photoUrl,
      "amount": _amountController.text.trim().isEmpty
          ? "0"
          : _amountController.text.trim(),
      "b_date": _birthDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _createdDateController.text.trim(),
      "last_login": "",
      "is_active": "TRUE",
      "mother_name": _motherNameController.text.trim(),
      "mother_phone": motherPhone, // ✅ Temizlendi!
      "father_name": _fatherNameController.text.trim(),
      "father_phone": fatherPhone, // ✅ Temizlendi!
    };

    Map<String, dynamic> allData = {
      "user_info": userInfo,
      "sports_id": _selectedSportId,
    };

    if (_healthProblemsController.text.trim().isNotEmpty) {
      allData["health_problems"] = _healthProblemsController.text.trim();
    }

    if (_hasParent) {
      allData["parent_info"] = {
        "first_name": _parentNameController.text.trim(),
        "last_name": _parentSurnameController.text.trim(),
        "phone": _parentPhoneController.text.trim(),
        "email": _parentEmailController.text.trim(),
      };
    }

    final selectedGroupIdForSave =
        _selectedGroupId.isNotEmpty && _selectedGroupId != "none"
        ? _selectedGroupId
        : "";

    if (selectedGroupIdForSave.isNotEmpty) {
      allData["group_id"] = selectedGroupIdForSave;
    }

    bool result = await GoogleSheetService.registerEverywhere(allData);

    if (result && selectedGroupIdForSave.isNotEmpty) {
      final allUsers = await GoogleSheetService.getUsersCached(
        forceRefresh: true,
      );
      final newUser = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email,
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

      if (newUser.app.isNotEmpty) {
        await GoogleSheetService.assignStudentToGroup(
          newUser.app,
          selectedGroupIdForSave,
        );
      }
    }

    // 🔥🔥🔥 ARKA PLANDA VERİ YENİLE (BEKLEME)
    // _refreshDataInBackground() yerine doğrudan _repo.loadAllData() çağır
    await _refreshDataInBackground();

    if (mounted) setState(() => _isLoading = false);

    if (result && mounted) {
      final studentName =
          "${_nameController.text.trim()} ${_surnameController.text.trim()}";
      _showSuccessNotification(
        "🎉 Kayıt Başarılı!",
        "$studentName başarıyla kaydedildi.",
      );
      _clearForm();

      // 🔥 2 saniye bekle (Snackbar görünsün diye)
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      _showSnackBar("❌ Kayıt başarısız!", isError: true);
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
  // VALIDASYON FONKSİYONLARI
  // =========================================================================

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
                ? NetworkImage(_selectedUser!.profile_photo_url)
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
                                const Icon(Icons.group, size: 18),
                                const SizedBox(width: 8),
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
                                ? NetworkImage(user.profile_photo_url)
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

                // 🔥 YENİ: Ücret Alanı (Sadece öğrenci rolü için göster)
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
                  onChanged: (v) =>
                      setState(() => _selectedGroupId = v == "none" ? "" : v!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      onChanged: (val) => setState(() => _selectedRole = val.toString()),
    );
  }

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
                // ANNE BİLGİLERİ
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
                // BABA BİLGİLERİ
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

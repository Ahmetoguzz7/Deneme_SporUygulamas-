import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class KisiselBilgilerPage extends StatefulWidget {
  final Users user;

  const KisiselBilgilerPage({super.key, required this.user});

  @override
  State<KisiselBilgilerPage> createState() => _KisiselBilgilerPageState();
}

class _KisiselBilgilerPageState extends State<KisiselBilgilerPage> {
  final AppRepository _repo = AppRepository();

  bool _isUploading = false;
  late Users _currentUser;
  Branches? _branch;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_repo.isLoaded) {
      await _repo.loadCriticalData();
    }

    setState(() {
      _branch = _repo.getBranchById(_currentUser.branches_id);
      _isLoading = false;
    });
  }

  Future<void> _changeProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Profil Fotoğrafını Değiştir",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
                ),
                title: const Text(
                  "Kamerayla Çek",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF22C55E),
                  ),
                ),
                title: const Text(
                  "Galeriden Seç",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        final File imageFile = File(pickedFile.path);
        final fileName =
            "user_${_currentUser.app}_${DateTime.now().millisecondsSinceEpoch}.jpg";

        final imageUrl = await GoogleSheetService.uploadImageToDrive(
          imageFile,
          fileName,
          "profile_photos",
          targetUserId: _currentUser.app,
          targetField: "profile_photo_url",
        );

        if (imageUrl != null && mounted) {
          setState(() {
            _currentUser = Users(
              app: _currentUser.app,
              first_name: _currentUser.first_name,
              last_name: _currentUser.last_name,
              email: _currentUser.email,
              phone: _currentUser.phone,
              b_date: _currentUser.b_date,
              role: _currentUser.role,
              branches_id: _currentUser.branches_id,
              created_at: _currentUser.created_at,
              is_active: _currentUser.is_active,
              profile_photo_url: imageUrl,
              password_hash: '',
              amount: '',
              last_login: '',
            );
          });

          await _updateSavedUser(imageUrl);
          _repo.refreshTable('users', 'users');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Profil fotoğrafı güncellendi"),
              backgroundColor: const Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception("Fotoğraf yüklenemedi");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Fotoğraf yüklenirken hata: $e"),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  Future<void> _updateSavedUser(String newPhotoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('logged_user');
      if (savedUserJson != null) {
        Map<String, dynamic> userMap = jsonDecode(savedUserJson);
        userMap['profile_photo_url'] = newPhotoUrl;
        await prefs.setString('logged_user', jsonEncode(userMap));
      }
    } catch (e) {
      print("Local kullanıcı güncelleme hatası: $e");
    }
  }

  String _formatDateLongTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getAgeTurkish(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return "?";
    try {
      final date = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day))
        age--;
      return "$age yaşında";
    } catch (e) {
      return "?";
    }
  }

  String _getAgeNumber(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return "?";
    try {
      final date = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day))
        age--;
      return "$age";
    } catch (e) {
      return "?";
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'coach':
        return 'Antrenör';
      case 'parent':
        return 'Veli';
      case 'admin':
        return 'Admin';
      case 'accountant':
        return 'Muhasebeci';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return Icons.school_rounded;
      case 'coach':
        return Icons.sports_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'accountant':
        return Icons.calculate_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getStatusText(String isActive) {
    return isActive.toLowerCase() == "true" ? "Aktif" : "Pasif";
  }

  Color _getStatusColor(String isActive) {
    return isActive.toLowerCase() == "true"
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
  }

  String _getBranchName(Branches? branch) {
    if (branch == null)
      return _currentUser.branches_id.isNotEmpty
          ? _currentUser.branches_id
          : "Belirtilmemiş";
    return branch.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Profilim",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _repo.refreshTable('branches', 'branches');
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoCard(
                          "Kişisel Bilgiler",
                          Icons.person_outline_rounded,
                          const Color(0xFF3B82F6),
                          [
                            _infoRow(
                              "Ad Soyad",
                              "${_currentUser.first_name} ${_currentUser.last_name}",
                              Icons.person_rounded,
                            ),
                            _infoRow(
                              "Doğum Tarihi",
                              _formatDateLongTurkish(_currentUser.b_date),
                              Icons.cake_rounded,
                            ),
                            _infoRow(
                              "Yaş",
                              _getAgeTurkish(_currentUser.b_date),
                              Icons.timeline_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          "İletişim Bilgileri",
                          Icons.contact_phone_rounded,
                          const Color(0xFF22C55E),
                          [
                            _infoRow(
                              "E-posta",
                              _currentUser.email,
                              Icons.email_rounded,
                            ),
                            _infoRow(
                              "Telefon",
                              _currentUser.phone.isEmpty
                                  ? "Belirtilmemiş"
                                  : _currentUser.phone,
                              Icons.phone_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          "Hesap Bilgileri",
                          Icons.account_circle_rounded,
                          const Color(0xFF8B5CF6),
                          [
                            _infoRow(
                              "Sistem ID",
                              _currentUser.app,
                              Icons.fingerprint_rounded,
                            ),
                            _infoRow(
                              "Şube",
                              _getBranchName(_branch),
                              Icons.business_rounded,
                            ),
                            _infoRow(
                              "Kayıt Tarihi",
                              _formatDateLongTurkish(_currentUser.created_at),
                              Icons.calendar_today_rounded,
                            ),
                            _infoRow(
                              "Hesap Durumu",
                              _getStatusText(_currentUser.is_active),
                              Icons.verified_user_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isUploading ? null : _changeProfilePhoto,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.transparent,
                      backgroundImage: _currentUser.profile_photo_url.isNotEmpty
                          ? NetworkImage(_currentUser.profile_photo_url)
                          : null,
                      child: _currentUser.profile_photo_url.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 56,
                              color: Colors.white.withOpacity(0.8),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "${_currentUser.first_name} ${_currentUser.last_name}",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRoleIcon(_currentUser.role),
                    size: 16,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getRoleText(_currentUser.role),
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatCard(
                    "Yaş",
                    _getAgeNumber(_currentUser.b_date),
                    Icons.cake_rounded,
                    const Color(0xFFEC4899),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    "Durum",
                    _getStatusText(_currentUser.is_active),
                    Icons.verified_rounded,
                    _getStatusColor(_currentUser.is_active),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    "Şube",
                    _getBranchName(_branch).length > 15
                        ? "${_getBranchName(_branch).substring(0, 12)}..."
                        : _getBranchName(_branch),
                    Icons.location_on_rounded,
                    const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0EA5E9)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "Belirtilmemiş" : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

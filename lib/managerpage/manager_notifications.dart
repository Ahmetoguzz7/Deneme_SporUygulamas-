// lib/managerpage/manager_notifications.dart
import 'dart:async';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'dart:core';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/core/app_repository.dart'; // 🔥 RAM HAFIZA ODASI ENTEGRASYONU

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationsScreen extends StatefulWidget {
  final Users? currentUser;

  const NotificationsScreen({super.key, this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  // 🔥 MİMARİ BAĞLANTI: Sayfa doğrudan yerel RAM'i dinleyecek
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchUserController = TextEditingController();

  String _selectedType = "Genel";
  String _selectedTargetType = "Tümü";
  String? _selectedGroupId;
  String? _selectedUserId;
  String _searchQuery = "";

  List<Group> _allGroups = [];
  List<Users> _allUsers = [];
  List<Users> _filteredUsers = [];
  List<Notifications> _cachedNotifications = []; // 🔥 Hafızadaki bildirimler

  bool _isSending = false;
  bool _sendLocalNotification = true;
  bool _isLoading = false;
  Timer? _searchDebounce; // 🔥 Klavye kasmalarını önleyen zamanlayıcı

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // RAM'deki verileri sıfır gecikmeyle yükle
    _loadDataFromRAM();

    // 🔥 SESSİZ ARKA PLAN DİNLEYİCİSİ:
    // Periyodik servis arkada bildirimleri güncellerse, ekran kasmadan listeyi yeniler.
    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        print(
          "⚡ Bildirim Sayfası: Arka planda veriler tazeledi, liste sessizce güncelleniyor...",
        );
        _loadDataFromRAM();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _searchUserController.dispose();
    _searchDebounce?.cancel();
    _repoSubscription?.cancel();
    super.dispose();
  }

  /// 🧠 RAM BELLEKTEN VERİ OKUMA (0ms Gecikme - İnternet İstemez)
  void _loadDataFromRAM() {
    if (!mounted) return;

    _allGroups = _repo.allGroups;
    _allUsers = _repo.allUsers.where((u) {
      final role = u.role.toLowerCase();
      return role == "student" ||
          role == "coach" ||
          role == "accountant" ||
          role == "admin";
    }).toList();

    // Giriş yapmış kullanıcının kendi ID'sini alıyoruz
    final myId = widget.currentUser?.app?.toString() ?? "all";

    // RAM'den bu kullanıcıya ait olan ham bildirim listesini çekiyoruz
    final rawNotifications = _repo.getNotificationsByRecipient(myId);

    // 🔥 ADMİN FİLTRESİ: Gönderen admine, "all" (Tümü) olmadığı sürece kendi attığı özel/grup bildirimleri geri dönmesin
    _cachedNotifications = rawNotifications.where((notif) {
      // Eğer bildirimi gönderen kişi benimle aynıysa (Ben gönderdiysem)
      if (notif.sender_id == myId) {
        // Sadece alıcı 'all' (Tümü - Genel Duyuru) ise listeye ekle, değilse gizle
        return notif.recipient_id.toLowerCase() == 'all';
      }
      return true; // Başkasından gelen her şeyi normal şekilde göster
    }).toList();

    // Tarihe göre sırala
    _cachedNotifications.sort((a, b) => b.sent_at.compareTo(a.sent_at));

    setState(() {});
  }

  // =========================================================================
  // ⚡ DEBOUNCE ARAMA SİSTEMİ (KLAVYENİN KASMASINI KÖKTEN ÇÖZER)
  // =========================================================================
  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (_selectedUserId != null && !query.contains("(")) {
      _selectedUserId = null;
    }

    // Kullanıcı harf yazarken bekler, yazmayı durdurunca 250ms sonra tek bir kez filtreler
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (query.trim().isEmpty) {
        setState(() {
          _filteredUsers = [];
          _searchQuery = "";
        });
        return;
      }

      final lowerQuery = query.trim().toLowerCase();
      final tempResults = _allUsers.where((user) {
        final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
        return fullName.contains(lowerQuery) || user.phone.contains(lowerQuery);
      }).toList();

      setState(() {
        _searchQuery = query;
        _filteredUsers = tempResults;
      });
    });
  }

  void _selectUser(Users user) {
    setState(() {
      _selectedUserId = user.app;
      _searchUserController.text =
          "${user.first_name} ${user.last_name} (${_getRoleText(user.role)})";
      _filteredUsers = [];
      _searchQuery = "";
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUserId = null;
      _searchUserController.clear();
      _filteredUsers = [];
      _searchQuery = "";
    });
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return "Öğrenci";
      case 'coach':
        return "Antrenör";
      case 'accountant':
        return "Muhasebeci";
      case 'admin':
        return "Admin";
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return Icons.school;
      case 'coach':
        return Icons.sports;
      case 'accountant':
        return Icons.calculate;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return _success;
      case 'coach':
        return _warning;
      case 'accountant':
        return _info;
      case 'admin':
        return _purple;
      default:
        return _textSecondary;
    }
  }

  void _refreshData() async {
    setState(() => _isLoading = true);
    // İnternetten sadece bildirimler tablosunu sessizce indirir, RAM'e yazar
    await _repo.refreshSingleTable('notifications');
    _loadDataFromRAM();
    setState(() => _isLoading = false);
  }

  // =========================================================================
  // ☁️ SESSİZ BİLDİRİM GÖNDERİMİ (UI ASLA KİLİTLENMEZ)
  // =========================================================================
  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      _showSnackBar("Başlık ve mesaj boş olamaz!", isError: true);
      return;
    }

    setState(() => _isSending = true);

    String dbType = _convertTypeToEnglish(_selectedType);
    String recipientId = _selectedTargetType == "Tümü"
        ? "all"
        : (_selectedTargetType == "Grup" ? "group" : (_selectedUserId ?? ""));
    String groupsId = _selectedTargetType == "Grup"
        ? (_selectedGroupId ?? "")
        : "";
    String currentUserId = widget.currentUser?.app?.toString() ?? "Admin";

    // 🔥 KENDİNE BİLDİRİM KONTROLÜ
    if (recipientId == currentUserId ||
        (_selectedTargetType == "Kullanıcı" &&
            _selectedUserId == currentUserId)) {
      _showSnackBar("❌ Kendinize bildirim gönderemezsiniz!", isError: true);
      setState(() => _isSending = false);
      return;
    }

    final localNotifId = "local_ntf_${DateTime.now().millisecondsSinceEpoch}";

    // 🎯 ANA BİLDİRİM (Öğrenciye / Gruba / Tümüne)
    final newNotif = Notifications(
      notifications_id: localNotifId,
      sender_id: currentUserId,
      recipient_id: recipientId,
      groups_id: groupsId,
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      type: dbType,
      is_read: "FALSE",
      sent_at: DateTime.now().toIso8601String(),
    );

    // ========================================================================
    // 🔥🔥🔥 VELİLERE DE BİLDİRİM GÖNDER (EĞER HEDEF ÖĞRENCİ İSE)
    // ========================================================================

    List<Notifications> parentNotifications = [];

    if (_selectedTargetType == "Kullanıcı" && _selectedUserId != null) {
      // Seçili öğrencinin velilerini bul
      final parentIds = _getParentIdsByStudentId(_selectedUserId!);
      print("🔍 Öğrenci $_selectedUserId için veli ID'leri: $parentIds");

      for (String parentId in parentIds) {
        final parentNotif = Notifications(
          notifications_id: "parent_${localNotifId}_$parentId",
          sender_id: currentUserId,
          recipient_id: parentId, // Veli ID'si
          groups_id: "",
          title: "👨‍👩‍👧 Öğrenci Bildirimi: ${_titleController.text.trim()}",
          message:
              "${_getStudentName(_selectedUserId!)} öğrenciniz için yeni bir duyuru var:\n\n${_messageController.text.trim()}",
          type: dbType,
          is_read: "FALSE",
          sent_at: DateTime.now().toIso8601String(),
        );
        parentNotifications.add(parentNotif);
      }
    }

    // ========================================================================
    // 💾 TÜM BİLDİRİMLERİ RAM'E KAYDET (Ana + Veli)
    // ========================================================================

    // Ana bildirimi RAM'e ekle
    _repo.allNotifications.add(newNotif);

    // Veli bildirimlerini RAM'e ekle
    for (var pNotif in parentNotifications) {
      _repo.allNotifications.add(pNotif);
    }

    // UI'ı güncelle
    _loadDataFromRAM();

    // Form paketini hazırla (Ana bildirim için)
    final notifMap = {
      "notifications_id": localNotifId,
      "sender_id": currentUserId,
      "recipient_id": recipientId,
      "groups_id": groupsId,
      "title": _titleController.text.trim(),
      "message": _messageController.text.trim(),
      "type": dbType,
      "is_read": "FALSE",
      "sent_at": newNotif.sent_at,
    };

    // ========================================================================
    // ☁️ GOOGLE SHEETS'E KAYDET (Ana + Veli)
    // ========================================================================

    // Ana bildirimi Google Sheets'e gönder
    bool dbSuccess = await GoogleSheetService.addNotification(notifMap);

    // Veli bildirimlerini Google Sheets'e gönder
    for (var pNotif in parentNotifications) {
      final parentNotifMap = {
        "notifications_id": pNotif.notifications_id,
        "sender_id": pNotif.sender_id,
        "recipient_id": pNotif.recipient_id,
        "groups_id": pNotif.groups_id,
        "title": pNotif.title,
        "message": pNotif.message,
        "type": pNotif.type,
        "is_read": pNotif.is_read,
        "sent_at": pNotif.sent_at,
      };
      await GoogleSheetService.addNotification(parentNotifMap);
    }

    setState(() => _isSending = false);

    if (dbSuccess) {
      final parentCount = parentNotifications.length;
      final message = parentCount > 0
          ? "✅ Duyuru başarıyla gönderildi! ($parentCount veliye de iletildi)"
          : "✅ Duyuru başarıyla gönderildi!";
      _showSnackBar(message);
      _titleController.clear();
      _messageController.clear();
      _clearSelectedUser();
      if (_sendLocalNotification) {
        _showLocalNotification(newNotif.title, newNotif.message);
      }
    } else {
      _showSnackBar(
        "❌ Duyuru buluta gönderilirken bir hata oluştu!",
        isError: true,
      );
    }
  }

  String _convertTypeToEnglish(String turkishType) {
    switch (turkishType) {
      case "Ödeme Hatırlatması":
        return "payment_reminder";
      case "Antrenman İptali":
        return "attendance_alert";
      case "Maç Duyurusu":
        return "announcement";
      case "Acil":
        return "urgent";
      default:
        return "announcement";
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case "payment_reminder":
        return _warning;
      case "attendance_alert":
        return _purple;
      case "announcement":
        return _info;
      case "urgent":
        return _danger;
      default:
        return _info;
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case "payment_reminder":
        return '💰';
      case "attendance_alert":
        return '❌';
      case "announcement":
        return '📢';
      case "urgent":
        return '⚠️';
      default:
        return '📢';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showLocalNotification(String title, String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'manager_notifications_channel',
          'Yönetici Duyuruları',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 1,
      //time: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: message,
      notificationDetails: platformChannelSpecifics,
    );
  }

  String _formatDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  List<String> _getParentIdsByStudentId(String studentId) {
    final parentRelations = _repo.allParentStudents
        .where((ps) => ps.student_id == studentId)
        .toList();

    return parentRelations.map((ps) => ps.parent_id).toList();
  }

  /// Öğrenci adını döndürür
  String _getStudentName(String studentId) {
    final student = _repo.allUsers.firstWhere(
      (u) => u.app == studentId,
      orElse: () => Users(
        app: "",
        first_name: "Bilinmeyen",
        last_name: "Öğrenci",
        email: "",
        phone: "",
        b_date: "",
        role: "student",
        branches_id: "",
        created_at: "",
        is_active: "",
        profile_photo_url: "",
        password_hash: '',
        amount: '',
        last_login: '',
      ),
    );
    return "${student.first_name} ${student.last_name}";
  }

  // =========================================================================
  // 🖼️ RENDER BÖLÜMÜ
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboard(currentUserRole: ''),
            ),
          ),
        ),
        title: const Text(
          "Duyuru & Bildirim",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: "Yeni Duyuru", icon: Icon(Icons.send_rounded, size: 18)),
            Tab(
              text: "Bildirimlerim",
              icon: Icon(Icons.notifications_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendNotificationTab(), _buildNotificationsListTab()],
      ),
    );
  }

  Widget _buildSendNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Telefona Bildirim Gönder Switch Kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Telefona Bildirim Gönder",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Açıkken bildirim cihaz ekranına düşer",
                          style: TextStyle(color: _textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _sendLocalNotification,
                  onChanged: (val) =>
                      setState(() => _sendLocalNotification = val),
                  activeColor: _accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Hedef Seçimi Kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Hedef Seçimi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildTargetButton(
                      "Tümü",
                      Icons.public_rounded,
                      "Tümü",
                      _accent,
                    ),
                    const SizedBox(width: 10),
                    _buildTargetButton(
                      "Grup",
                      Icons.group_rounded,
                      "Grup",
                      _purple,
                    ),
                    const SizedBox(width: 10),
                    _buildTargetButton(
                      "Kullanıcı",
                      Icons.person_rounded,
                      "Kullanıcı",
                      _info,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_selectedTargetType == "Grup")
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedGroupId,
                dropdownColor: _surface,
                decoration: InputDecoration(
                  hintText: "Grup seçin",
                  hintStyle: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: _allGroups.map((g) {
                  return DropdownMenuItem(
                    value: g.groups_id,
                    child: Text(
                      g.name,
                      style: const TextStyle(fontSize: 14, color: _textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedGroupId = val),
              ),
            ),

          if (_selectedTargetType == "Kullanıcı")
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchUserController,
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "İsim veya tel yazın...",
                      hintStyle: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _textSecondary,
                      ),
                      suffixIcon: _searchUserController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: _textSecondary,
                              ),
                              onPressed: _clearSelectedUser,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (_filteredUsers.isNotEmpty && _selectedUserId == null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return ListTile(
                            leading: Icon(
                              _getRoleIcon(user.role),
                              color: _getRoleColor(user.role),
                              size: 18,
                            ),
                            title: Text(
                              "${user.first_name} ${user.last_name}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              user.phone,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                            onTap: () => _selectUser(user),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Duyuru Tipi Kartı
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Duyuru Tipi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTypeButton("Genel", Icons.info_rounded, _info),
                    _buildTypeButton("Acil", Icons.warning_rounded, _danger),
                    _buildTypeButton(
                      "Ödeme Hatırlatması",
                      Icons.money_rounded,
                      _warning,
                    ),
                    _buildTypeButton(
                      "Antrenman İptali",
                      Icons.sports_rounded,
                      _purple,
                    ),
                    _buildTypeButton(
                      "Maç Duyurusu",
                      Icons.emoji_events_rounded,
                      _accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // İçerik Formu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Başlık",
                    hintStyle: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Mesajınızı yazın...",
                    hintStyle: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isSending ? null : _sendNotification,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Duyuruyu Yayınla",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const VersionFooter(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // 🔥 DEĞİŞTİ: Ağır FutureBuilder kaldırıldı, RAM listesi jilet hızında listeleniyor
  Widget _buildNotificationsListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_cachedNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              "Henüz bir bildirim bulunmuyor.",
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics:
            const AlwaysScrollableScrollPhysics(), // Kaydırma pürüzsüzlüğü kilidi
        itemCount: _cachedNotifications.length,
        itemBuilder: (context, index) {
          final notif = _cachedNotifications[index];
          final color = _getTypeColor(notif.type);
          final icon = _getTypeIcon(notif.type);
          final isRead = notif.is_read.toUpperCase() == 'TRUE';
          final currentUserId = widget.currentUser?.app?.toString() ?? "Admin";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead ? _border : color.withOpacity(0.4),
                width: isRead ? 1 : 1.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showNotificationDetail({
                'title': notif.title,
                'message': notif.message,
                'type': notif.type,
                'sent_at': notif.sent_at,
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Text(icon, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    fontSize: 14,
                                    color: _textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (notif.sender_id == currentUserId)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Siz",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.message,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTurkish(notif.sent_at),
                            style: const TextStyle(
                              color: _textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTargetButton(
    String type,
    IconData icon,
    String label,
    Color targetColor,
  ) {
    bool isSelected = _selectedTargetType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedTargetType = type;
          if (type != "Kullanıcı") _clearSelectedUser();
          if (type != "Grup") _selectedGroupId = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? targetColor.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? targetColor : _border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? targetColor : _textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? targetColor : _textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon, Color typeColor) {
    bool isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? typeColor.withOpacity(0.1) : _surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? typeColor : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? typeColor : _textSecondary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? typeColor : _textPrimary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    final color = _getTypeColor(notif['type'] ?? '');
    final icon = _getTypeIcon(notif['type'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTurkish(notif['sent_at'] ?? ''),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      notif['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: _accent.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Kapat",
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

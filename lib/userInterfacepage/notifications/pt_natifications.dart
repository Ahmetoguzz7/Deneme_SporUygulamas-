// lib/parent/pt_notifications.dart
/*
import 'dart:async';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/core/app_repository.dart'; // 🔥 Eklendi
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class DuyurularPage extends StatefulWidget {
  final Users currentUser;
  final Coach? currentCoach;

  const DuyurularPage({
    super.key,
    required this.currentUser,
    this.currentCoach,
  });

  @override
  State<DuyurularPage> createState() => _DuyurularPageState();
}

class _DuyurularPageState extends State<DuyurularPage> {
  final AppRepository _repo = AppRepository(); // 🔥 RAM bağlantısı
  StreamSubscription<bool>? _repoSubscription;

  late Future<List<Notifications>> _notificationsFuture;
  String _selectedFilter = "Son 7 gün";
  final List<String> _filterOptions = [
    "Son 7 gün",
    "Son 30 gün",
    "Son 3 ay",
    "Tümü",
  ];

  final NotificationService _notificationService = NotificationService();
  List<Notifications> _previousNotifications = [];

  @override
  void initState() {
    super.initState();
    _initNotifications();

    // 🔥 SESSİZ GÜNCELLEME DİNLEYİCİSİ
    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        _initNotifications();
      }
    });
  }

  @override
  void dispose() {
    _repoSubscription?.cancel();
    super.dispose();
  }

  // 🔥 ARTIK SIFIR GECİKME: RAM listesine anında köprü atar
  void _initNotifications() {
    if (mounted) {
      setState(() {
        _notificationsFuture = _loadNotificationsLocal();
      });
    }
  }

  Future<List<Notifications>> _loadNotificationsLocal() async {
    final myId = widget.currentUser.app.toString();
    final allNotifs = _repo.getNotificationsByRecipient(myId);

    // Tarihe göre sıralama kilidi
    allNotifs.sort((a, b) => b.sent_at.compareTo(a.sent_at));

    final now = DateTime.now();
    if (_selectedFilter == "Son 7 gün") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 7;
      }).toList();
    } else if (_selectedFilter == "Son 30 gün") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 30;
      }).toList();
    } else if (_selectedFilter == "Son 3 ay") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 90;
      }).toList();
    }
    return allNotifs;
  }

  Future<void> _refreshNotifications() async {
    // Sadece bildirimleri sessizce yenile
    await _repo.refreshSingleTable('notifications');
    _initNotifications();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return 'Ödeme Hatırlatması';
      case 'urgent':
        return 'Acil Durum';
      case 'announcement':
        return 'Genel Duyuru';
      case 'attendance_alert':
        return 'Yoklama Uyarısı';
      default:
        return 'Duyuru';
    }
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet;
      case 'urgent':
        return Icons.priority_high;
      case 'announcement':
        return Icons.emoji_events;
      case 'attendance_alert':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Duyuru Merkezi",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Notifications>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshNotifications,
                    child: Stack(children: [ListView(), _buildEmptyState()]),
                  );
                }

                final list = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refreshNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final notif = list[index];
                      final color = _getIconColor(notif.type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(
                              _getIcon(notif.type),
                              color: color,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                notif.message,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getTypeText(notif.type),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(notif.sent_at),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _showDetailsDialog(notif),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final opt = _filterOptions[index];
          final isSel = _selectedFilter == opt;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = opt;
                _initNotifications();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.grey.shade600,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetailsDialog(Notifications notif) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getIconColor(notif.type).withOpacity(0.1),
                  child: Icon(
                    _getIcon(notif.type),
                    color: _getIconColor(notif.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(notif.sent_at),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notif.message,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/

// lib/parent/pt_notifications.dart
import 'dart:async';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class DuyurularPage extends StatefulWidget {
  final Users currentUser;
  final Coach? currentCoach;
  final bool isAssistant; // 🆕

  const DuyurularPage({
    super.key,
    required this.currentUser,
    this.currentCoach,
    this.isAssistant = false,
  });

  @override
  State<DuyurularPage> createState() => _DuyurularPageState();
}

class _DuyurularPageState extends State<DuyurularPage> {
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  late Future<List<Notifications>> _notificationsFuture;
  String _selectedFilter = "Son 7 gün";
  final List<String> _filterOptions = [
    "Son 7 gün",
    "Son 30 gün",
    "Son 3 ay",
    "Tümü",
  ];

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initNotifications();

    _repoSubscription = _repo.onDataUpdated.listen((updated) {
      if (updated && mounted) {
        _initNotifications();
      }
    });
  }

  @override
  void dispose() {
    _repoSubscription?.cancel();
    super.dispose();
  }

  void _initNotifications() {
    if (mounted) {
      setState(() {
        _notificationsFuture = _loadNotificationsLocal();
      });
    }
  }

  Future<List<Notifications>> _loadNotificationsLocal() async {
    final myId = widget.currentUser.app.toString();
    final coachId = widget.currentCoach?.coach_id ?? '';

    // Tüm bildirimleri al
    List<Notifications> allNotifs = List.from(_repo.allNotifications);

    // Yardımcı antrenör için filtrele
    if (widget.isAssistant && widget.currentCoach != null) {
      final assistantCoach = _repo.allCoaches.firstWhere(
        (c) => c.coach_id == coachId,
        orElse: () => widget.currentCoach!,
      );

      final supervisorIds =
          assistantCoach.supervisor_coach_id
              ?.split(',')
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList() ??
          [];

      final supervisorIdsSet = Set.from(supervisorIds);

      allNotifs = allNotifs.where((notif) {
        final recipientId =
            notif.recipient_id?.toString().trim().toLowerCase() ?? '';
        final senderId = notif.sender_id?.toString().trim().toLowerCase() ?? '';
        final groupId = notif.groups_id?.toString().trim() ?? '';

        if (senderId == myId) return false;
        if (recipientId == 'all' || recipientId == 'tümü') return true;
        if (recipientId == myId) return true;
        if (recipientId == coachId || supervisorIdsSet.contains(recipientId))
          return true;

        if (groupId.isNotEmpty) {
          for (var supId in supervisorIds) {
            final groups = _repo.getGroupsByCoachId(supId);
            for (var g in groups) {
              if (g.groups_id == groupId) return true;
            }
          }
        }

        return false;
      }).toList();
    } else if (widget.currentCoach != null) {
      // Normal antrenör
      final coachId = widget.currentCoach!.coach_id;
      final coachGroups = _repo.getGroupsByCoachId(coachId);
      final coachGroupIds = coachGroups.map((g) => g.groups_id).toSet();

      allNotifs = allNotifs.where((notif) {
        final recipientId =
            notif.recipient_id?.toString().trim().toLowerCase() ?? '';
        final senderId = notif.sender_id?.toString().trim().toLowerCase() ?? '';
        final groupId = notif.groups_id?.toString().trim() ?? '';

        if (senderId == myId) return false;
        if (recipientId == 'all' || recipientId == 'tümü') return true;
        if (recipientId == myId) return true;
        if (recipientId == coachId) return true;
        if (groupId.isNotEmpty && coachGroupIds.contains(groupId)) return true;

        return false;
      }).toList();
    } else {
      // Öğrenci/veli
      allNotifs = allNotifs.where((notif) {
        final recipientId =
            notif.recipient_id?.toString().trim().toLowerCase() ?? '';
        final senderId = notif.sender_id?.toString().trim().toLowerCase() ?? '';
        final groupId = notif.groups_id?.toString().trim() ?? '';

        if (senderId == myId) return false;
        if (recipientId == 'all' || recipientId == 'tümü') return true;
        if (recipientId == myId) return true;
        if (groupId.isNotEmpty) {
          final userGroups = _repo.getGroupsByStudentId(myId);
          for (var g in userGroups) {
            if (g.groups_id == groupId) return true;
          }
        }

        return false;
      }).toList();
    }

    // Tarihe göre sıralama
    allNotifs.sort((a, b) => b.sent_at.compareTo(a.sent_at));

    final now = DateTime.now();
    if (_selectedFilter == "Son 7 gün") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 7;
      }).toList();
    } else if (_selectedFilter == "Son 30 gün") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 30;
      }).toList();
    } else if (_selectedFilter == "Son 3 ay") {
      return allNotifs.where((n) {
        final d = DateTime.tryParse(n.sent_at) ?? now;
        return now.difference(d).inDays <= 90;
      }).toList();
    }
    return allNotifs;
  }

  Future<void> _refreshNotifications() async {
    await _repo.refreshSingleTable('notifications');
    _initNotifications();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return 'Ödeme Hatırlatması';
      case 'urgent':
        return 'Acil Durum';
      case 'announcement':
        return 'Genel Duyuru';
      case 'attendance_alert':
        return 'Yoklama Uyarısı';
      default:
        return 'Duyuru';
    }
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet;
      case 'urgent':
        return Icons.priority_high;
      case 'announcement':
        return Icons.emoji_events;
      case 'attendance_alert':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isAssistant ? "Yardımcı Duyuruları" : "Duyuru Merkezi",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: widget.isAssistant ? Colors.teal : Colors.white,
        foregroundColor: widget.isAssistant ? Colors.white : Colors.black,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Notifications>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshNotifications,
                    child: Stack(children: [ListView(), _buildEmptyState()]),
                  );
                }

                final list = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refreshNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final notif = list[index];
                      final color = _getIconColor(notif.type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(
                              _getIcon(notif.type),
                              color: color,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                notif.message,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getTypeText(notif.type),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(notif.sent_at),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _showDetailsDialog(notif),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const VersionFooter(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final opt = _filterOptions[index];
          final isSel = _selectedFilter == opt;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = opt;
                _initNotifications();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.grey.shade600,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetailsDialog(Notifications notif) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getIconColor(notif.type).withOpacity(0.1),
                  child: Icon(
                    _getIcon(notif.type),
                    color: _getIconColor(notif.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(notif.sent_at),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notif.message,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

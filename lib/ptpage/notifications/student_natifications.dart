// lib/student/student_notifications.dart
import 'dart:async';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final AppRepository _repo = AppRepository();
  StreamSubscription<bool>? _repoSubscription;

  late Future<List<Notifications>> _filteredNotificationsFuture;
  final NotificationService _notificationService = NotificationService();
  Set<int> _readNotificationIds = {};

  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = [
    "Tümü",
    "Genel Duyurular",
    "Kişisel Duyurular",
    "Grup Duyuruları",
  ];

  @override
  void initState() {
    super.initState();
    _loadReadNotifications();
    _initNotifications();

    // 🔥 SESSİZ GÜNCELLEME: Arka plan servisi yeni bildirim indirdiğinde
    // ekranda yükleme çemberi çıkarmadan listeyi tık diye yeniler.
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

  // 🔥 ARTIK İNTERNETİ BEKLEMİYOR: Doğrudan RAM'den ve lokal hafızadan jilet gibi besleniyor
  void _initNotifications() {
    if (mounted) {
      setState(() {
        _filteredNotificationsFuture = _loadNotificationsLocal();
      });
    }
  }

  Future<List<Notifications>> _loadNotificationsLocal() async {
    // Giriş yapmış kullanıcının bildirimlerini RAM odasından çekiyoruz
    final myId = widget.currentUser.app.toString();
    final allNotifs = _repo.getNotificationsByRecipient(myId);

    // Tarihe göre yeniden eskiye akıllı sıralama
    allNotifs.sort((a, b) => b.sent_at.compareTo(a.sent_at));

    // Filtreleme mantığını yerel liste üzerinden uyguluyoruz
    if (_selectedFilter == "Tümü") {
      return allNotifs;
    } else if (_selectedFilter == "Genel Duyurular") {
      return allNotifs
          .where((n) => n.recipient_id.toLowerCase() == "all")
          .toList();
    } else if (_selectedFilter == "Kişisel Duyurular") {
      return allNotifs.where((n) => n.recipient_id == myId).toList();
    } else if (_selectedFilter == "Grup Duyuruları") {
      return allNotifs
          .where((n) => n.recipient_id.toLowerCase() == "group")
          .toList();
    }
    return allNotifs;
  }

  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds =
        prefs.getStringList('read_notifications_${widget.currentUser.app}') ??
        [];
    if (mounted) {
      setState(() {
        _readNotificationIds = readIds
            .map((id) => int.tryParse(id) ?? 0)
            .toSet();
      });
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    if (_readNotificationIds.contains(notificationId)) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readNotificationIds.add(notificationId);
    });
    await prefs.setStringList(
      'read_notifications_${widget.currentUser.app}',
      _readNotificationIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _refreshNotifications() async {
    // İnternetten sadece bildirimler tablosunu sessizce tazeler, UI'ı kilitlemez
    await _repo.refreshSingleTable('notifications');
    _initNotifications();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getTypeText(String? type) {
    switch (type?.toLowerCase()) {
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

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
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

  Color _getIconColor(String? type) {
    switch (type?.toLowerCase()) {
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
          Icon(
            Icons.notifications_none_rounded,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
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
          "Duyurular ve Bildirimler",
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
              future: _filteredNotificationsFuture,
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
                      final notifIdInt =
                          int.tryParse(notif.notifications_id) ?? index;
                      final isRead = _readNotificationIds.contains(notifIdInt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead
                                ? Colors.grey.shade100
                                : _getIconColor(notif.type).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: _getIconColor(
                              notif.type,
                            ).withOpacity(0.1),
                            child: Icon(
                              _getIcon(notif.type),
                              color: _getIconColor(notif.type),
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    fontSize: 15,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getIconColor(notif.type),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
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
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getTypeText(notif.type),
                                    style: TextStyle(
                                      color: _getIconColor(notif.type),
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
                          onTap: () {
                            _markAsRead(notifIdInt);
                            _showDetailsDialog(notif);
                          },
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

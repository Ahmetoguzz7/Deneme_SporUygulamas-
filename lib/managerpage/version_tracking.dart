// version_tracking_screen.dart
/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class VersionTrackingScreen extends StatefulWidget {
  @override
  _VersionTrackingScreenState createState() => _VersionTrackingScreenState();
}

class _VersionTrackingScreenState extends State<VersionTrackingScreen> {
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  String _error = '';

  // 🔥 MEVCUT SÜRÜM (Buradan güncelle)
  final String currentVersion = '1.0.24';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final data = await GoogleSheetService.getVersionReport();
      if (data.isNotEmpty) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Veri alınamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Hata: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 Sürüm Takibi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? _buildErrorWidget()
          : _buildReportWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(_error, style: TextStyle(fontSize: 16)),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _loadReport, child: Text('Tekrar Dene')),
        ],
      ),
    );
  }

  Widget _buildReportWidget() {
    final totalActive = _reportData['totalActive'] ?? 0;
    final versionStats = _reportData['versionStats'] as List? ?? [];
    final users = _reportData['users'] as List? ?? [];

    // 🔥 Sürümleri sırala (en yüksekten en düşüğe)
    final sortedStats = List.from(versionStats)
      ..sort((a, b) {
        return _compareVersions(b['version'], a['version']);
      });

    // 🔥 Mevcut sürümü kullanan sayısı
    final currentVersionCount = versionStats
        .where((v) => v['version'] == currentVersion)
        .fold(0, (sum, v) => sum + (v['count'] as int));

    return Column(
      children: [
        // 📊 Özet Kart
        Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.teal.shade700],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Aktif Kullanıcı (Son 7 Gün)',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '$totalActive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🟢 Güncel Sürüm: $currentVersion • $currentVersionCount kullanıcı',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // 📱 Sürüm Dağılımı
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '📱 Sürüm Dağılımı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🟢 Güncel: $currentVersion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Container(
          height: 150,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sortedStats.length,
            itemBuilder: (context, index) {
              final item = sortedStats[index];
              final version = item['version'];
              final count = item['count'] as int;
              final percentage = item['percentage'] as String;

              // 🔥 Sürüm kontrolü
              final isCurrentVersion = version == currentVersion;
              final isNewer = _compareVersions(version, currentVersion) > 0;
              final isOlder = _compareVersions(version, currentVersion) < 0;

              // 🔥 Renkler
              Color bgColor;
              Color textColor;
              String statusIcon;

              if (isCurrentVersion) {
                bgColor = Colors.green.shade100;
                textColor = Colors.green.shade700;
                statusIcon = '✅';
              } else if (isNewer) {
                bgColor = Colors.blue.shade100;
                textColor = Colors.blue.shade700;
                statusIcon = '🔵';
              } else {
                bgColor = Colors.red.shade100;
                textColor = Colors.red.shade700;
                statusIcon = '🔴';
              }

              return Container(
                width: 110,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentVersion
                        ? Colors.green.shade300
                        : isOlder
                        ? Colors.red.shade300
                        : Colors.blue.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$statusIcon $version',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$count kullanıcı',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '%$percentage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (isOlder)
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ESKİ SÜRÜM',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    if (isCurrentVersion)
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'GÜNCEL',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // 📊 Sürüm Özeti
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildLegendItem('🟢', 'Güncel', Colors.green),
              SizedBox(width: 16),
              _buildLegendItem('🔴', 'Eski Sürüm', Colors.red),
              SizedBox(width: 16),
              _buildLegendItem('🔵', 'Gelecek Sürüm', Colors.blue),
            ],
          ),
        ),

        // 👥 Kullanıcı Listesi
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '👥 Kullanıcılar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                '${users.length} kullanıcı',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isActive = user['isActive'] == true;
              final version = user['version'] ?? '?';
              final lastSeen = DateTime.tryParse(user['lastSeen'] ?? '');
              final lastSeenStr = lastSeen != null
                  ? '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}'
                  : 'Bilinmiyor';

              // 🔥 Sürüm kontrolü
              final isCurrentVersion = version == currentVersion;
              final isOlder = _compareVersions(version, currentVersion) < 0;

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOlder
                        ? Colors.red.shade100
                        : isActive
                        ? Colors.green
                        : Colors.grey,
                    child: Icon(
                      isOlder
                          ? Icons.warning
                          : isActive
                          ? Icons.check
                          : Icons.hourglass_empty,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    user['email'] ?? 'Bilinmiyor',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isOlder ? Colors.red.shade700 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Sürüm: $version • Son: $lastSeenStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOlder
                          ? Colors.red.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOlder
                          ? Colors.red.shade100
                          : isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOlder
                          ? '🔴 Eski Sürüm'
                          : isActive
                          ? '✅ Güncel'
                          : '⏳ Bekliyor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOlder
                            ? Colors.red.shade700
                            : isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 🔥 Sürüm karşılaştırma fonksiyonu
  int _compareVersions(String v1, String v2) {
    if (v1 == v2) return 0;

    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }
    return parts1.length.compareTo(parts2.length);
  }

  // 🔥 Legend Widget
  Widget _buildLegendItem(String icon, String text, Color color) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 14)),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

*/
// version_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class VersionTrackingScreen extends StatefulWidget {
  const VersionTrackingScreen({super.key});

  @override
  _VersionTrackingScreenState createState() => _VersionTrackingScreenState();
}

class _VersionTrackingScreenState extends State<VersionTrackingScreen> {
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  String _error = '';

  // 🔥 MEVCUT SÜRÜM (Buradan güncelle)
  final String currentVersion = '1.0.24';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final data = await GoogleSheetService.getVersionReport();
      if (data.isNotEmpty) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Veri alınamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Hata: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern hafif gri arka plan
      appBar: AppBar(
        title: const Text(
          'Sürüm & Kullanıcı Takibi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B), // Kurumsal koyu lacivert
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E293B)),
            )
          : _error.isNotEmpty
          ? _buildErrorWidget()
          : _buildReportWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportWidget() {
    final totalActive = _reportData['totalActive'] ?? 0;
    final versionStats = _reportData['versionStats'] as List? ?? [];
    final users = _reportData['users'] as List? ?? [];

    // 🔥 Sürümleri sırala (en yüksekten en düşüğe)
    final sortedStats = List.from(versionStats)
      ..sort((a, b) {
        return _compareVersions(b['version'], a['version']);
      });

    // 🔥 Mevcut sürümü kullanan sayısı
    final currentVersionCount = versionStats
        .where((v) => v['version'] == currentVersion)
        .fold(0, (sum, v) => sum + (v['count'] as int));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 📊 Özet Kart (Gradient + Şık Gölgelendirme)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'AKTİF KULLANICI (SON 7 GÜN)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalActive',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🟢 Güncel Sürüm: $currentVersion • $currentVersionCount Kullanıcı',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 📱 Sürüm Dağılımı Başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📱 Sürüm Dağılımı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green?.shade50 ?? Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Hedef: $currentVersion',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 📱 Sürüm Dağılım Kartları (Yatay Liste)
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sortedStats.length,
            itemBuilder: (context, index) {
              final item = sortedStats[index];
              final version = item['version'];
              final count = item['count'] as int;
              final percentage = item['percentage'] as String;

              final isCurrentVersion = version == currentVersion;
              final isNewer = _compareVersions(version, currentVersion) > 0;
              final isOlder = _compareVersions(version, currentVersion) < 0;

              Color cardBg;
              Color borderColor;
              Color textColor;
              String badgeText;
              Color badgeBg;

              if (isCurrentVersion) {
                cardBg = Colors.green.shade50;
                borderColor = Colors.green.shade200;
                textColor = Colors.green.shade800;
                badgeText = 'GÜNCEL';
                badgeBg = Colors.green.shade200;
              } else if (isNewer) {
                cardBg = Colors.blue.shade50;
                borderColor = Colors.blue.shade200;
                textColor = Colors.blue.shade800;
                badgeText = 'YENİ';
                badgeBg = Colors.blue.shade200;
              } else {
                cardBg = Colors.red.shade50;
                borderColor = Colors.red.shade200;
                textColor = Colors.red.shade800;
                badgeText = 'ESKİ';
                badgeBg = Colors.red.shade200;
              }

              return Container(
                width: 115,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      version,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count kişi',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '%$percentage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // 📊 Renk Göstergeleri (Legend)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('🟢', 'Güncel Sürüm', Colors.green.shade700),
            const SizedBox(width: 16),
            _buildLegendItem('🔴', 'Eski Sürüm', Colors.red.shade700),
            const SizedBox(width: 16),
            _buildLegendItem('🔵', 'İleri Sürüm', Colors.blue.shade700),
          ],
        ),
        const SizedBox(height: 24),

        // 👥 Kullanıcı Listesi Başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '👥 Kullanıcı Listesi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'Toplam: ${users.length}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 👥 Kullanıcı Listesi (Kart Tasarımı)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isActive = user['isActive'] == true;
            final version = user['version'] ?? '?';
            final lastSeen = DateTime.tryParse(user['lastSeen'] ?? '');
            final lastSeenStr = lastSeen != null
                ? '${lastSeen.day.toString().padLeft(2, '0')}.${lastSeen.month.toString().padLeft(2, '0')}.${lastSeen.year}'
                : 'Bilinmiyor';

            final isOlder = _compareVersions(version, currentVersion) < 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOlder ? Colors.red.shade200 : Colors.grey.shade200,
                  width: isOlder ? 1.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: isOlder
                      ? Colors.red.shade50
                      : isActive
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  child: Icon(
                    isOlder
                        ? Icons.warning_amber_rounded
                        : isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.access_time_rounded,
                    color: isOlder
                        ? Colors.red.shade700
                        : isActive
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                title: Text(
                  user['email'] ?? 'Bilinmiyor',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isOlder
                        ? Colors.red.shade900
                        : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Sürüm: $version • Son Görülme: $lastSeenStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isOlder
                        ? Colors.red.shade100
                        : isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOlder ? 'Eski Sürüm' : (isActive ? 'Aktif' : 'Pasif'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOlder == true /* or standard ternary */
                          ? Colors.red.shade700
                          : isOlder
                          ? Colors.red.shade700
                          : (isActive
                                ? Colors.green.shade700
                                : Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 🔥 Sürüm karşılaştırma fonksiyonu (Hızı koruntu)
  int _compareVersions(String v1, String v2) {
    if (v1 == v2) return 0;

    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }
    return parts1.length.compareTo(parts2.length);
  }

  // 🔥 Şık Legend Widget
  Widget _buildLegendItem(String icon, String text, Color color) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class StudentWeeklyProgram extends StatelessWidget {
  final Users student;

  const StudentWeeklyProgram({super.key, required this.student});

  String _getWeekRange() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
    return "${formatter.format(monday)} - ${formatter.format(sunday)}";
  }

  String _getTodayName() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Haftalık Antrenman Programım",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: _getProgramData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildEmptyState("Veri bulunamadı");
          }

          final data = snapshot.data!;
          if (!data['hasGroup']) {
            return _buildEmptyState(
              "Henüz bir gruba atanmadınız\nAntrenörünüz sizi bir gruba atayınca programınız burada görünecektir",
            );
          }

          final group = data['group'] as Group;
          final schedules = data['schedules'] as List<Map<String, dynamic>>;

          if (schedules.isEmpty) {
            return _buildEmptyState(
              "Antrenman programı henüz eklenmemiş\nGrubunuz için bir program oluşturulduğunda burada görünecektir",
            );
          }

          return RefreshIndicator(
            onRefresh: () async => (context as Element).reassemble(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderCard(group),
                  const SizedBox(height: 20),
                  const Text(
                    "Haftalık Program",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._buildWeekDays(schedules),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getProgramData() async {
    final repo = AppRepository();
    if (!repo.isLoaded) await repo.loadCriticalData();

    final groups = repo.getGroupsByStudentId(student.app);
    if (groups.isEmpty) return {'hasGroup': false};

    final group = groups.first;
    final schedules = _parseSchedule(group.schedule);

    return {'hasGroup': true, 'group': group, 'schedules': schedules};
  }

  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];

    for (var day in days) {
      final pattern = RegExp(
        '$day:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(schedule);
      if (match != null) {
        result.add({
          'day': day,
          'dayIndex': days.indexOf(day),
          'start': match.group(1)!,
          'end': match.group(2)!,
        });
      }
    }
    return result;
  }

  List<Widget> _buildWeekDays(List<Map<String, dynamic>> schedules) {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final today = _getTodayName();

    return days.map((day) {
      final daySchedules = schedules.where((s) => s['day'] == day).toList();
      final isToday = day == today;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? Colors.indigo : Colors.grey.shade200,
            width: isToday ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.indigo.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday ? Icons.today : Icons.calendar_today,
                    size: 18,
                    color: isToday ? Colors.indigo : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.indigo : Colors.grey.shade800,
                    ),
                  ),
                  if (isToday) _buildBadge("Bugün", Colors.indigo),
                  const Spacer(),
                  if (daySchedules.isNotEmpty)
                    _buildBadge(
                      "${daySchedules.length} antrenman",
                      Colors.green,
                    ),
                ],
              ),
            ),
            if (daySchedules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: daySchedules
                      .map((s) => _buildTrainingItem(s))
                      .toList(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "Bu günde antrenman yok 🏠",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTrainingItem(Map<String, dynamic> schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.sports, color: Colors.indigo, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Antrenman",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "${schedule['start']} - ${schedule['end']}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Group group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getWeekRange(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
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
            child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
*/
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class StudentWeeklyProgram extends StatelessWidget {
  final Users student;

  const StudentWeeklyProgram({super.key, required this.student});

  String _getWeekRange() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
    return "${formatter.format(monday)} - ${formatter.format(sunday)}";
  }

  String _getTodayName() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          "${student.first_name} ${student.last_name} - Haftalık Program",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: FutureBuilder(
        future: _getProgramData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildEmptyState("Veri bulunamadı");
          }

          final data = snapshot.data!;

          print("📊 Program Verisi: hasGroup=${data['hasGroup']}");
          if (data['hasGroup'] == true) {
            final group = data['group'] as Group;
            print("📊 Grup: ${group.name}, Schedule: ${group.schedule}");
          }

          if (!data['hasGroup']) {
            return _buildEmptyState(
              "Henüz bir gruba atanmadınız\nAntrenörünüz sizi bir gruba atayınca programınız burada görünecektir",
            );
          }

          final group = data['group'] as Group;
          final schedules = data['schedules'] as List<Map<String, dynamic>>;

          if (schedules.isEmpty) {
            return _buildEmptyState(
              "Antrenman programı henüz eklenmemiş\nGrubunuz için bir program oluşturulduğunda burada görünecektir",
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshData(context),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderCard(group),
                  const SizedBox(height: 20),
                  const Text(
                    "Haftalık Program",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._buildWeekDays(schedules),
                  const VersionFooter(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshData(BuildContext context) async {
    final repo = AppRepository();
    await repo.refreshAllData();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StudentWeeklyProgram(student: student)),
    );
  }

  Future<Map<String, dynamic>> _getProgramData() async {
    final repo = AppRepository();

    if (!repo.isLoaded) {
      await repo.loadAllData();
    } else {
      if (repo.allGroupStudents.isEmpty) {
        // print("⚠️ allGroupStudents boş, yeniden yükleniyor...");
        await repo.loadAllData();
      }
    }
    /*
    print("🔍 ===== REPO VERİLERİ =====");
    print("🔍 allUsers: ${repo.allUsers.length}");
    print("🔍 allGroups: ${repo.allGroups.length}");
    print("🔍 allGroupStudents: ${repo.allGroupStudents.length}");
    print("🔍 Öğrenci ID: ${student.app}");*/

    final groups = repo.getGroupsByStudentId(student.app);
    //print("🔍 getGroupsByStudentId sonucu: ${groups.length} grup");

    if (groups.isEmpty) {
      return {'hasGroup': false};
    }

    final group = groups.first;
    //print("🔍 Seçilen grup: ${group.name} (ID: ${group.groups_id})");
    //print("🔍 Program: ${group.schedule}");

    final schedules = _parseSchedule(group.schedule);
    //print("🔍 Parse edilen günler: ${schedules.map((s) => s['day']).toList()}");

    return {'hasGroup': true, 'group': group, 'schedules': schedules};
  }

  // 🔥 HER TÜRLÜ FORMATI PARSE EDEN GELİŞMİŞ FONKSİYON
  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    if (schedule.isEmpty) return result;

    const List<String> weekDays = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];

    // Türkçe karakterleri normalize etmek için yardımcı fonksiyon
    String normalize(String input) {
      return input
          .trim()
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ç', 'c')
          .replaceAll('ş', 's')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ö', 'o');
    }

    // Gelen string'i ana bölümlere ayır (Virgülle ayrılmış bağımsız gün/saat blokları)
    // Örn: "pazartesi-salı-çarşamba,22:00-23:00,pazar:22:30-23:30"
    // Ancak gün bloklarının ardındaki saatleri korumak için akıllıca split/bölme yapıyoruz.

    // Saat kalıbını yakala: 22:00-23:00
    final timeRegex = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})');

    // String içindeki tüm bağımsız program gruplarını ayıklamak için tarama yapıyoruz
    // Mantık: Gün tanımları ve ardından gelen saat aralığı
    final blockRegex = RegExp(
      r'([a-zA-ZçÇğĞıİöÖşŞüÜ\s-]+)(?::|,)\s*(\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    final matches = blockRegex.allMatches(schedule);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final daysPart = match.group(1)!;
        final timePart = match.group(2)!;

        // Saati böl
        final timeMatch = timeRegex.firstMatch(timePart);
        if (timeMatch == null) continue;
        final start = timeMatch.group(1)!;
        final end = timeMatch.group(2)!;

        // Günleri ayır (pazartesi-salı-çarşamba veya cumartesi-pazar -> tekil gün listesi)
        final rawDays = daysPart.split(RegExp(r'[-.]'));

        for (var rawDay in rawDays) {
          final normalizedRaw = normalize(rawDay);
          if (normalizedRaw.isEmpty) continue;

          for (int i = 0; i < weekDays.length; i++) {
            if (normalize(weekDays[i]) == normalizedRaw) {
              // Eğer bu gün için daha önce aynı saat eklenmediyse listeye ekle
              bool isDuplicate = result.any(
                (element) =>
                    element['dayIndex'] == i &&
                    element['start'] == start &&
                    element['end'] == end,
              );

              if (!isDuplicate) {
                result.add({
                  'day': weekDays[i],
                  'dayIndex': i,
                  'start': start,
                  'end': end,
                });
              }
              break;
            }
          }
        }
      }
    }
    // Eğer üstteki yapısal regex'ten kaçan düzensiz tekil formatlar olursa (Fallback)
    else {
      for (int i = 0; i < weekDays.length; i++) {
        final pattern = RegExp(
          '${weekDays[i]}:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})',
          caseSensitive: false,
        );
        final match = pattern.firstMatch(schedule);
        if (match != null) {
          result.add({
            'day': weekDays[i],
            'dayIndex': i,
            'start': match.group(1)!,
            'end': match.group(2)!,
          });
        }
      }
    }

    // Gün sırasına (Pazartesi -> Pazar) ve ardından başlangıç saatine göre sırala kanka
    result.sort((a, b) {
      int dayCompare = a['dayIndex'].compareTo(b['dayIndex']);
      if (dayCompare != 0) return dayCompare;
      return a['start'].compareTo(b['start']);
    });

    return result;
  }

  List<Widget> _buildWeekDays(List<Map<String, dynamic>> schedules) {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final today = _getTodayName();

    return days.map((day) {
      final daySchedules = schedules.where((s) => s['day'] == day).toList();
      final isToday = day == today;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? Colors.indigo : Colors.grey.shade200,
            width: isToday ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.indigo.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday ? Icons.today : Icons.calendar_today,
                    size: 18,
                    color: isToday ? Colors.indigo : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.indigo : Colors.grey.shade800,
                    ),
                  ),
                  if (isToday) _buildBadge("Bugün", Colors.indigo),
                  const Spacer(),
                  if (daySchedules.isNotEmpty)
                    _buildBadge(
                      "${daySchedules.length} antrenman",
                      Colors.green,
                    ),
                ],
              ),
            ),
            if (daySchedules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: daySchedules
                      .map((s) => _buildTrainingItem(s))
                      .toList(),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTrainingItem(Map<String, dynamic> schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.sports, color: Colors.indigo, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Antrenman",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "${schedule['start']} - ${schedule['end']}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Group group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getWeekRange(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
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
            child: Icon(Icons.sports, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

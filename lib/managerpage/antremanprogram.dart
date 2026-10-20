import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class WeeklyTrainingScreen extends StatefulWidget {
  final List<Group> groups;
  final List<GroupStudent> relations;
  final List<Users> students;
  final List<Coach> coaches;
  final Future<void> Function(String groupId, String newSchedule)?
  onScheduleUpdated;

  const WeeklyTrainingScreen({
    Key? key,
    required this.groups,
    required this.relations,
    required this.students,
    required this.coaches,
    this.onScheduleUpdated,
  }) : super(key: key);

  @override
  State<WeeklyTrainingScreen> createState() => _WeeklyTrainingScreenState();
}

class _WeeklyTrainingScreenState extends State<WeeklyTrainingScreen>
    with SingleTickerProviderStateMixin {
  late List<Group> _groups;
  List<Map<String, dynamic>> _weeklySchedule = [];
  String _selectedDay = "";
  Map<String, List<Map<String, dynamic>>> _groupedSchedule = {};

  final List<String> _days = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar",
  ];

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _accentDark = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _orange = Color(0xFFF97316);
  static const Color _red = Color(0xFFEF4444);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.groups);
    _loadSchedule();
    _selectedDay = _getTodayName();
  }

  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  String _getTodayName() {
    final now = DateTime.now();
    return _days[now.weekday - 1];
  }

  String _getCoachName(String coachId) {
    if (coachId.isEmpty) return "Atanmamış";

    final coach = widget.coaches.firstWhere(
      (c) => c.coach_id == coachId,
      orElse: () => Coach(
        coach_id: "",
        user_id: "",
        branches_id: "",
        sports_id: "",
        bio: "",
        certificate_info: "",
        monthly_salary: "",
        hired_at: "",
      ),
    );

    if (coach.user_id.isEmpty) return "Atanmamış";

    final coachUser = widget.students.firstWhere(
      (u) => u.app == coach.user_id,
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

    if (coachUser.first_name.isEmpty) return "Atanmamış";

    return "${coachUser.first_name} ${coachUser.last_name}".trim();
  }

  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    final dayMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };

    if (schedule.isEmpty) return result;

    // 🔥 1. Önce virgülle ayır
    final parts = schedule.split(',');

    // 🔥 2. Geçici değişkenler
    String? pendingDays;
    String? pendingTime;

    for (var i = 0; i < parts.length; i++) {
      var part = parts[i].trim();
      if (part.isEmpty) continue;

      // 🔥 3. "gün:saat" formatı mı?
      final colonIndex = part.indexOf(':');
      if (colonIndex != -1) {
        // "cuma:08:30-10:00" formatı
        final dayPart = part.substring(0, colonIndex).trim().toLowerCase();
        final timePart = part.substring(colonIndex + 1).trim();

        if (dayMap.containsKey(dayPart)) {
          final timeParts = timePart.split('-');
          if (timeParts.length == 2) {
            final start = timeParts[0].trim();
            final end = timeParts[1].trim();
            if (start.isNotEmpty && end.isNotEmpty) {
              result.add({'day': dayMap[dayPart]!, 'start': start, 'end': end});
            }
          }
        }
        continue;
      }

      // 🔥 4. "pazartesi-salı-çarşamba" gün listesi mi?
      final hasDay = dayMap.keys.any((d) => part.toLowerCase().contains(d));
      if (hasDay) {
        // Gün listesi
        pendingDays = part;

        // 🔥 5. Bir sonraki parça saat mi? (virgülle ayrılmış)
        if (i + 1 < parts.length) {
          final nextPart = parts[i + 1].trim();
          final timeMatch = RegExp(
            r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2})$',
          ).firstMatch(nextPart);
          if (timeMatch != null) {
            // Saat bulundu
            final start = timeMatch.group(1)!;
            final end = timeMatch.group(2)!;
            pendingTime = '$start-$end';
            i++; // Saati atla
          }
        }

        // 🔥 6. Eğer saat varsa, günleri saatle eşleştir
        if (pendingDays != null && pendingTime != null) {
          final days = pendingDays!
              .split('-')
              .map((d) => d.trim().toLowerCase())
              .toList();
          final timeParts = pendingTime!.split('-');
          for (var day in days) {
            if (dayMap.containsKey(day)) {
              result.add({
                'day': dayMap[day]!,
                'start': timeParts[0],
                'end': timeParts[1],
              });
            }
          }
          pendingDays = null;
          pendingTime = null;
        }
      }
    }

    // 🔥 7. Eğer hala bekleyen günler ve saat varsa
    if (pendingDays != null && pendingTime != null) {
      final days = pendingDays!
          .split('-')
          .map((d) => d.trim().toLowerCase())
          .toList();
      final timeParts = pendingTime!.split('-');
      for (var day in days) {
        if (dayMap.containsKey(day)) {
          result.add({
            'day': dayMap[day]!,
            'start': timeParts[0],
            'end': timeParts[1],
          });
        }
      }
    }

    return result;
  }

  void _loadSchedule() {
    _weeklySchedule = [];

    for (var group in _groups) {
      if (group.schedule.isEmpty) continue;

      final schedules = _parseSchedule(group.schedule);
      final coachName = _getCoachName(group.coach_id);

      for (var schedule in schedules) {
        final dayInt = schedule['day'] as int;
        final dayIndex = dayInt - 1;
        if (dayIndex < 0 || dayIndex >= _days.length) continue;
        final dayName = _days[dayIndex];

        _weeklySchedule.add({
          'day': dayName,
          'dayIndex': dayIndex,
          'time': '${schedule['start']} - ${schedule['end']}',
          'start': schedule['start'],
          'end': schedule['end'],
          'groupName': group.name,
          'groupId': group.groups_id,
          'coachName': coachName,
        });
      }
    }

    // Günlere göre grupla
    _groupedSchedule = {};
    for (var item in _weeklySchedule) {
      final day = item['day'] as String;
      if (!_groupedSchedule.containsKey(day)) {
        _groupedSchedule[day] = [];
      }
      _groupedSchedule[day]!.add(item);
    }

    // Her gün içinde saat sıralaması yap
    for (var day in _groupedSchedule.keys) {
      _groupedSchedule[day]!.sort((a, b) {
        return (a['start'] as String).compareTo(b['start'] as String);
      });
    }
  }

  String _buildScheduleString(
    String existingSchedule,
    List<String> selectedDayNames,
    String start,
    String end, {
    String? removeEntry,
  }) {
    final dayTr = {
      'Pazartesi': 'pazartesi',
      'Salı': 'salı',
      'Çarşamba': 'çarşamba',
      'Perşembe': 'perşembe',
      'Cuma': 'cuma',
      'Cumartesi': 'cumartesi',
      'Pazar': 'pazar',
    };

    final dayNumMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };

    // Mevcut programları parse et
    final existing = _parseSchedule(existingSchedule);
    List<Map<String, dynamic>> entries = List.from(existing);

    // 🔥 SİLİNECEK OLANI ÇIKAR
    if (removeEntry != null && removeEntry.isNotEmpty) {
      final parts = removeEntry.split(':');
      if (parts.length == 2) {
        final dayTrKey = dayTr.entries
            .firstWhere(
              (e) => e.key == parts[0],
              orElse: () => const MapEntry('', ''),
            )
            .value;
        final timeParts = parts[1].split('-');
        if (timeParts.length == 2) {
          entries.removeWhere((e) {
            final dayMap = {
              1: 'pazartesi',
              2: 'salı',
              3: 'çarşamba',
              4: 'perşembe',
              5: 'cuma',
              6: 'cumartesi',
              7: 'pazar',
            };
            return dayMap[e['day']] == dayTrKey &&
                e['start'] == timeParts[0] &&
                e['end'] == timeParts[1];
          });
        }
      }
    }

    // 🔥 YENİ PROGRAMLARI EKLE
    for (final dayName in selectedDayNames) {
      final trDay = dayTr[dayName] ?? '';
      if (trDay.isEmpty) continue;

      final alreadyExists = entries.any((e) {
        final dayMap = {
          1: 'pazartesi',
          2: 'salı',
          3: 'çarşamba',
          4: 'perşembe',
          5: 'cuma',
          6: 'cumartesi',
          7: 'pazar',
        };
        return dayMap[e['day']] == trDay &&
            e['start'] == start &&
            e['end'] == end;
      });

      if (!alreadyExists) {
        entries.add({'day': dayNumMap[trDay]!, 'start': start, 'end': end});
      }
    }

    if (entries.isEmpty) return '';

    // 🔥 PROGRAMLARI FORMATLA (GÜN VE SAAT GRUPLAMA)
    final Map<String, List<String>> timeTodays = {};
    final dayNumToTr = {
      1: 'pazartesi',
      2: 'salı',
      3: 'çarşamba',
      4: 'perşembe',
      5: 'cuma',
      6: 'cumartesi',
      7: 'pazar',
    };

    for (final e in entries) {
      final key = '${e['start']}-${e['end']}';
      final dayTrName = dayNumToTr[e['day']] ?? '';
      timeTodays.putIfAbsent(key, () => []);
      if (!timeTodays[key]!.contains(dayTrName)) {
        timeTodays[key]!.add(dayTrName);
      }
    }

    final dayOrder = [
      'pazartesi',
      'salı',
      'çarşamba',
      'perşembe',
      'cuma',
      'cumartesi',
      'pazar',
    ];
    for (final list in timeTodays.values) {
      list.sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));
    }

    final parts = <String>[];
    timeTodays.forEach((timeRange, days) {
      if (days.length == 1) {
        final timeParts = timeRange.split('-');
        parts.add('${days[0]}:${timeParts[0]}-${timeParts[1]}');
      } else {
        final timeParts = timeRange.split('-');
        parts.add('${days.join('-')},${timeParts[0]}-${timeParts[1]}');
      }
    });

    return parts.join(',');
  }

  void _showAddScheduleModal(Group group) {
    final List<String> selectedDays = [];
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String formatTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            Future<void> pickTime({required bool isStart}) async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: isStart ? startTime : endTime,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            Future<void> saveSchedule() async {
              if (selectedDays.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('En az bir gün seçin'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final startStr = formatTime(startTime);
              final endStr = formatTime(endTime);

              if (startTime.hour * 60 + startTime.minute >=
                  endTime.hour * 60 + endTime.minute) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bitiş saati başlangıçtan sonra olmalı'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => isSaving = true);

              final newSchedule = _buildScheduleString(
                group.schedule,
                selectedDays,
                startStr,
                endStr,
              );

              if (widget.onScheduleUpdated != null) {
                await widget.onScheduleUpdated!(group.groups_id, newSchedule);
              }

              // 🔥 GRUBU GÜNCELLE
              setState(() {
                final idx = _groups.indexWhere(
                  (g) => g.groups_id == group.groups_id,
                );
                if (idx != -1) {
                  _groups[idx] = Group(
                    groups_id: group.groups_id,
                    branches_id: group.branches_id,
                    coach_id: group.coach_id,
                    sports_id: group.sports_id,
                    name: group.name,
                    schedule: newSchedule,
                    capacity: group.capacity,
                    monthly_fee: group.monthly_fee,
                    is_active: group.is_active,
                  );
                }
                // 🔥 VERİLERİ YENİDEN YÜKLE
                _loadSchedule();
              });

              if (ctx.mounted) Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Program güncellendi ✓'),
                  backgroundColor: Color(0xFF22C55E),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: _accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Program Ekle',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: _textSecondary,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Günler',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _days.map((day) {
                          final isSelected = selectedDays.contains(day);
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              isSelected
                                  ? selectedDays.remove(day)
                                  : selectedDays.add(day);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? _accent : _border,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : _textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Saat Aralığı',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => pickTime(isStart: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: _accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Başlangıç',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _textTertiary,
                                          ),
                                        ),
                                        Text(
                                          formatTime(startTime),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '→',
                              style: TextStyle(
                                fontSize: 20,
                                color: _textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => pickTime(isStart: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled,
                                      size: 18,
                                      color: _accentDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bitiş',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _textTertiary,
                                          ),
                                        ),
                                        Text(
                                          formatTime(endTime),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Programı Kaydet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteScheduleEntry(Map<String, dynamic> item) async {
    final group = _groups.firstWhere(
      (g) => g.groups_id == item['groupId'],
      orElse: () => _groups.first,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Programı Sil'),
        content: Text(
          '${item['groupName']} grubunun ${item['day']} ${item['time']} programı silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final removeEntry = '${item['day']}:${item['start']}-${item['end']}';

    final newSchedule = _buildScheduleString(
      group.schedule,
      [],
      '',
      '',
      removeEntry: removeEntry,
    );

    if (widget.onScheduleUpdated != null) {
      await widget.onScheduleUpdated!(group.groups_id, newSchedule);
    }

    setState(() {
      final idx = _groups.indexWhere((g) => g.groups_id == group.groups_id);
      if (idx != -1) {
        _groups[idx] = Group(
          groups_id: group.groups_id,
          branches_id: group.branches_id,
          coach_id: group.coach_id,
          sports_id: group.sports_id,
          name: group.name,
          schedule: newSchedule,
          capacity: group.capacity,
          monthly_fee: group.monthly_fee,
          is_active: group.is_active,
        );
      }
      _loadSchedule();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Program silindi'),
        backgroundColor: Color(0xFF64748B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          "Antrenman Programı",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: _textPrimary,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildDaySelector(),
        ),
      ),

      body: _buildWeeklyScheduleTab(),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isToday = day == _getTodayName();
          final hasTraining = _groupedSchedule.containsKey(day);
          final isSelected = _selectedDay == day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.transparent : _border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isToday ? _accent : _textSecondary),
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (hasTraining && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyScheduleTab() {
    final selectedDayItems = _groupedSchedule[_selectedDay] ?? [];
    final isToday = _selectedDay == _getTodayName();
    final todayDate = isToday ? _getTodayDateTurkish() : "";

    return Column(
      children: [
        // HEADER KISMI (AYNI)
        Container(
          padding: const EdgeInsets.all(16),
          color: _surface,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isToday
                      ? _accent.withOpacity(0.1)
                      : _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isToday ? Icons.today : Icons.calendar_today,
                  color: isToday ? _accent : _purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDay,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isToday ? _accent : _textPrimary,
                      ),
                    ),
                    if (isToday && todayDate.isNotEmpty)
                      Text(
                        todayDate,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        "${selectedDayItems.length} antrenman",
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Bugün",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 🔥 LİSTE + PROGRAM EKLE BUTONU
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // MEVCUT PROGRAMLAR
                if (selectedDayItems.isNotEmpty) ...[
                  for (
                    var index = 0;
                    index < selectedDayItems.length;
                    index++
                  ) ...[
                    Dismissible(
                      key: Key(
                        'schedule_${index}_${selectedDayItems[index]['groupId']}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        _deleteScheduleEntry(selectedDayItems[index]);
                        return false;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showGroupScheduleOptions(
                              selectedDayItems[index],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [_accent, _accentDark],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.sports,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedDayItems[index]['groupName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person,
                                              size: 12,
                                              color: _orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              selectedDayItems[index]['coachName'] ??
                                                  "Atanmamış",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: _textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              selectedDayItems[index]['time'],
                                              style: TextStyle(
                                                color: _accent,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      const Icon(
                                        Icons.chevron_right,
                                        color: _accent,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '← sil',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: _textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                // 🔥 PROGRAM EKLE BUTONU (HER ZAMAN GÖSTER)
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showGroupPickerForDay(_selectedDay),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    selectedDayItems.isEmpty
                        ? 'Program Ekle'
                        : 'Başka Grup Ekle',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),

                // 🔥 HİÇ PROGRAM YOKSA BİLGİ MESAJI
                if (selectedDayItems.isEmpty) ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.sports, size: 48, color: _textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          "Bu günde antrenman yok",
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                const VersionFooter(),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGroupScheduleOptions(Map<String, dynamic> item) {
    final group = _groups.firstWhere(
      (g) => g.groups_id == item['groupId'],
      orElse: () => _groups.first,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accentDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.sports, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['groupName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          "Antrenör: ${item['coachName'] ?? 'Atanmamış'}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saat: ${item['time']}',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: _border, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: _accent),
              ),
              title: const Text(
                'Bu gruba program ekle',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text('Yeni gün ve saat ekle'),
              trailing: const Icon(Icons.chevron_right, color: _textTertiary),
              onTap: () {
                Navigator.pop(ctx);
                _showAddScheduleModal(group);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, color: _red),
              ),
              title: const Text(
                'Bu programı sil',
                style: TextStyle(fontWeight: FontWeight.w500, color: _red),
              ),
              subtitle: Text('${item['day']} ${item['time']}'),
              trailing: const Icon(Icons.chevron_right, color: _textTertiary),
              onTap: () {
                Navigator.pop(ctx);
                _deleteScheduleEntry(item);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showGroupPickerForDay(String day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        child: Column(
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
              child: Row(
                children: [
                  const Text(
                    'Hangi gruba program eklensin?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: _border, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (ctx2, i) {
                  final group = _groups[i];
                  final coachName = _getCoachName(group.coach_id);

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sports, color: _accent, size: 20),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Antrenör: $coachName",
                          style: const TextStyle(fontSize: 11, color: _orange),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.schedule.isEmpty
                              ? 'Program yok'
                              : group.schedule,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddScheduleModal(group);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

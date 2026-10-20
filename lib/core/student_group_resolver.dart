import 'package:EVOM_SPOR/core/app_repository.dart';

/// Öğrenci -> grup eşleşmesinin TEK kaynağı.
///
/// Grup Yönetimi sayfası (manager_group.dart) ile birebir aynı yolu kullanır:
///   _repo.allGroups  +  _repo.getGroupStudentsByGroupId(groupId)
///
/// Böylece Grup sayfasında bir öğrenci hangi grubun içinde görünüyorsa,
/// Öğrenci Arama ve Ödeme Hatırlatma sayfalarında da aynı grup görünür.
class StudentGroupResolver {
  static const String noGroup = "Grup Yok";

  /// studentId -> öğrencinin bulunduğu grup adları
  static Map<String, List<String>> buildMap() {
    final repo = AppRepository();
    final map = <String, List<String>>{};

    for (final group in repo.allGroups) {
      if (group.name.isEmpty) continue;

      for (final relation in repo.getGroupStudentsByGroupId(group.groups_id)) {
        final names = map.putIfAbsent(relation.student_id, () => <String>[]);
        if (!names.contains(group.name)) names.add(group.name);
      }
    }
    return map;
  }

  /// Ekranda gösterilecek metin: "A Grubu" / "A Grubu, B Grubu" / "Grup Yok"
  static String label(Map<String, List<String>> map, String studentId) {
    final names = map[studentId];
    if (names == null || names.isEmpty) return noGroup;
    return names.join(", ");
  }

  /// Grup filtresi için: öğrenci bu grupta mı?
  static bool isInGroup(
    Map<String, List<String>> map,
    String studentId,
    String groupName,
  ) {
    return map[studentId]?.contains(groupName) ?? false;
  }
}

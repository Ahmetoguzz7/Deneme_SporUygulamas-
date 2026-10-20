import 'package:EVOM_SPOR/core/student_filter_page.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

/// 🚀 ISOLATE'DE ÇALIŞACAK FONKSİYON
/// Main thread'e dokunmaz, telefonun boşta kalan çekirdeğinde çalışır
StudentFilterResult filterStudentsInIsolate(StudentFilterPackage package) {
  var filtered = List<Users>.from(package.students);

  // Filtre 1: Role = student
  filtered = filtered.where((u) => u.role.toLowerCase() == 'student').toList();

  // Filtre 2: Aktiflik
  if (package.onlyActive) {
    filtered = filtered.where((u) => u.is_active == "TRUE").toList();
  }

  // Filtre 3: Branch
  if (package.selectedBranchId != null &&
      package.selectedBranchId!.isNotEmpty) {
    filtered = filtered
        .where((u) => u.branches_id == package.selectedBranchId)
        .toList();
  }

  // Filtre 4: Arama metni (isim + soyisim + email + telefon)
  if (package.searchText.isNotEmpty) {
    final searchLower = package.searchText.toLowerCase();
    filtered = filtered.where((u) {
      return u.first_name.toLowerCase().contains(searchLower) ||
          u.last_name.toLowerCase().contains(searchLower) ||
          "${u.first_name} ${u.last_name}".toLowerCase().contains(
            searchLower,
          ) ||
          u.email.toLowerCase().contains(searchLower) ||
          u.phone.contains(package.searchText);
    }).toList();
  }

  // Filtre 5: Bakiye aralığı
  if (package.minBalance != null || package.maxBalance != null) {
    filtered = filtered.where((u) {
      final balance = double.tryParse(u.amount) ?? 0;
      if (package.minBalance != null && balance < package.minBalance!) {
        return false;
      }
      if (package.maxBalance != null && balance > package.maxBalance!) {
        return false;
      }
      return true;
    }).toList();
  }

  // Hesaplamalar
  final totalCount = package.students
      .where((u) => u.role.toLowerCase() == 'student')
      .length;

  final filteredCount = filtered.length;

  // Ortalama bakiye hesabı
  final avgBalance = filtered.isEmpty
      ? 0.0
      : filtered
                .map((u) => double.tryParse(u.amount) ?? 0)
                .reduce((a, b) => a + b) /
            filteredCount;

  // 🔥 Sonuç paketini eksiksiz geri döndürüyoruz
  return StudentFilterResult(
    filteredStudents: filtered,
    totalCount: totalCount,
    filteredCount: filteredCount,
    averageBalance: avgBalance,
  );
}

import 'package:EVOM_SPOR/datapage/data_page/data.dart';

/// 📦 Filtre paketi - Isolate'e göndermek için
class StudentFilterPackage {
  final List<Users> students;
  final String searchText;
  final String? selectedBranchId;
  final String? selectedGroupId;
  final bool onlyActive;
  final double? minBalance;
  final double? maxBalance;

  StudentFilterPackage({
    required this.students,
    this.searchText = "",
    this.selectedBranchId,
    this.selectedGroupId,
    this.onlyActive = true,
    this.minBalance,
    this.maxBalance,
  });
}

/// 📦 Sonuç paketi
class StudentFilterResult {
  final List<Users> filteredStudents;
  final int totalCount;
  final int filteredCount;
  final double averageBalance;

  StudentFilterResult({
    required this.filteredStudents,
    required this.totalCount,
    required this.filteredCount,
    required this.averageBalance,
  });
}

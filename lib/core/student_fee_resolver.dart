import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

/// Öğrencinin AYA GÖRE aylık ücretini tek yerden hesaplar.
///
/// Kurallar (sırayla):
///  1. O ay için "fee_override" (geçmişe yönelik düzeltme) varsa o geçerli.
///  2. "fee_update" (geleceğe yönelik zam) kayıtlarından, hedef aydan önce
///     veya hedef ayda başlayan SON kayıt geçerli.
///  3. Hedef ay ilk zamdan önceyse ilk zammın "eski ücreti" geçerli.
///  4. Hiç kayıt yoksa öğrencinin güncel ücreti (users.amount) geçerli.
///
/// Böylece Haziran'da ücret değişince Mayıs ve öncesi ESKİ ücretle kalır.
class StudentFeeResolver {
  StudentFeeResolver._();

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      final d = s.contains('T') ? s.split('T')[0] : s;
      final parts = d.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final dd = int.tryParse(parts[2].substring(0, 2)) ?? 1;
        if (y != null && m != null) return DateTime(y, m, dd);
      }
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  static String _ym(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}";

  /// Payment listesinden zam geçmişini çıkarır.
  /// Aynı ay için birden fazla kayıt varsa EN SON girilen (paid_date) kazanır.
  /// Dönen map: {date, fee, oldFee, ts}
  static List<Map<String, dynamic>> parseUpdates(Iterable<Payment> payments) {
    final list = payments
        .where(
          (p) => p.status == "fee_update" || p.note.contains("FEE_UPDATE:"),
        )
        .toList();
    list.sort((a, b) => a.paid_date.compareTo(b.paid_date));

    final byMonth = <String, Map<String, dynamic>>{};
    for (final p in list) {
      final match = RegExp(r'FEE_UPDATE:\s*(\d+)').firstMatch(p.note);
      if (match == null) continue;
      final fee = double.tryParse(match.group(1)!) ?? 0;
      final oldMatch = RegExp(r'\(Eski:\s*(\d+)\s*TL\)').firstMatch(p.note);
      final oldFee = oldMatch != null
          ? (double.tryParse(oldMatch.group(1)!) ?? fee)
          : fee;
      final date = _parseDate(p.due_date) ?? _parseDate(p.paid_date);
      if (date == null || fee <= 0) continue;
      final ts = _parseDate(p.paid_date)?.millisecondsSinceEpoch ?? 0;
      // paid_date'e göre sıralı geldiği için sonraki kayıt öncekini ezer
      byMonth[_ym(date)] = {
        'date': DateTime(date.year, date.month, 1),
        'fee': fee,
        'oldFee': oldFee,
        'ts': ts,
      };
    }
    final result = byMonth.values.toList()
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }

  /// Payment listesinden ay bazlı düzeltmeleri çıkarır ("yyyy-MM" -> tutar).
  /// Aynı ay için en son girilen kayıt kazanır.
  static Map<String, double> parseOverrides(Iterable<Payment> payments) {
    final list = payments
        .where(
          (p) => p.status == "fee_override" || p.note.contains("OVERRIDE:"),
        )
        .toList();
    list.sort((a, b) => b.paid_date.compareTo(a.paid_date)); // yeni -> eski
    final result = <String, double>{};
    for (final p in list) {
      if (p.due_date.length < 7) continue;
      final key = p.due_date.substring(0, 7);
      final amount = double.tryParse(p.amount) ?? 0;
      if (amount > 0 && !result.containsKey(key)) result[key] = amount;
    }
    return result;
  }

  /// Saf hesaplama: hazır zam/düzeltme listeleriyle o ayın ücretini verir.
  static double feeForMonth({
    required double baseFee,
    required List<Map<String, dynamic>> updates,
    required Map<String, double> overrides,
    required int year,
    required int month,
  }) {
    final key = "$year-${month.toString().padLeft(2, '0')}";
    final ov = overrides[key];
    if (ov != null) return ov;
    if (updates.isEmpty) return baseFee;

    final sorted = List<Map<String, dynamic>>.from(updates)
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    Map<String, dynamic>? applicable;
    for (final u in sorted) {
      final d = u['date'] as DateTime;
      final started = year > d.year || (year == d.year && month >= d.month);
      if (started) {
        applicable = u;
      } else {
        break;
      }
    }
    if (applicable != null) return applicable['fee'] as double;
    return sorted.first['oldFee'] as double;
  }

  /// Repo'daki (RAM) verilerden doğrudan hesaplar. Liste ekranları bunu kullanır.
  static double forStudentMonth(
    AppRepository repo,
    String studentId,
    int year,
    int month,
  ) {
    final user = repo.getUserById(studentId);
    final baseFee = double.tryParse(user?.amount ?? "0") ?? 0;
    final payments = repo.getPaymentsByStudentId(studentId);
    return feeForMonth(
      baseFee: baseFee,
      updates: parseUpdates(payments),
      overrides: parseOverrides(payments),
      year: year,
      month: month,
    );
  }
}

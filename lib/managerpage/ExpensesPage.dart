import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Formda seçilen gider tarihi
  DateTime _selectedDate = DateTime.now();
  // Ekranda görüntülenen ay (özet + liste bu aya göre)
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<ExpenseItem> _expenses = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VERİ ÇEKME
  // ==========================================================================
  Future<void> _loadExpenses({bool force = false}) async {
    if (mounted) setState(() => _loading = true);

    final raw = await GoogleSheetService.getExpensesCached(forceRefresh: force);
    final items = <ExpenseItem>[];

    for (final m in raw) {
      final amount =
          double.tryParse((m['money'] ?? '').toString().replaceAll(',', '.')) ??
          0.0;
      final date = _parseDate((m['paid_date'] ?? '').toString());
      final title = (m['note'] ?? '').toString();
      final id = (m['id'] ?? '').toString(); // 🔥 ID güvenli şekilde alındı

      // Boş/anlamsız satırları atla
      if (amount == 0 && title.trim().isEmpty) continue;

      items.add(
        ExpenseItem(
          id: id,
          title: title.isEmpty ? "Gider" : title,
          amount: amount,
          date: date ?? DateTime.now(),
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _expenses
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      if (s.contains('T')) return DateTime.parse(s);
      final onlyDate = s.split(' ').first;
      final p = onlyDate.split('-');
      if (p.length == 3) {
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  // ==========================================================================
  // HESAPLAMALAR
  // ==========================================================================
  List<ExpenseItem> get _monthExpenses => _expenses
      .where(
        (e) =>
            e.date.year == _viewMonth.year && e.date.month == _viewMonth.month,
      )
      .toList();

  double get _monthTotal =>
      _monthExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get _todayTotal {
    final n = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.date.year == n.year &&
              e.date.month == n.month &&
              e.date.day == n.day,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<MapEntry<String, double>> get _monthBreakdown {
    final map = <String, double>{};
    for (final e in _monthExpenses) {
      map[e.title] = (map[e.title] ?? 0) + e.amount;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // ==========================================================================
  // TARİH BİÇİMLENDİRME
  // ==========================================================================
  String _fmtTr(DateTime d) {
    try {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  String _fmtMonthTr(DateTime d) {
    try {
      return DateFormat('MMMM yyyy', 'tr_TR').format(d);
    } catch (_) {
      return DateFormat('MM/yyyy').format(d);
    }
  }

  // ==========================================================================
  // GİDER EKLE
  // ==========================================================================
  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ??
        0.0;

    setState(() => _saving = true);

    final ok = await GoogleSheetService.addExpense(
      title: title,
      amount: amount.toStringAsFixed(2),
      paidDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    if (ok) {
      _titleController.clear();
      _amountController.clear();
      _viewMonth = DateTime(_selectedDate.year, _selectedDate.month);
      // 🔥 Eklemeden sonra sunucudan güncel listeyi çek ki gerçek ID gelsin
      await _loadExpenses(force: true);
    }

    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? "Gider eklendi!" : "Kaydedilemedi (bağlantı?)"),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  // ==========================================================================
  // GİDER SİL (GÜNCELLENDİ)
  // ==========================================================================
  Future<void> _confirmDeleteExpense(ExpenseItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Gideri Sil"),
        content: Text(
          "\"${item.title}\" (${item.amount.toStringAsFixed(2)} ₺) "
          "giderini silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (item.id.isNotEmpty && item.id != 'local') {
      // Doğrudan GoogleSheetService üzerinden silme isteği atıyoruz
      final success = await GoogleSheetService.deleteExtraData(
        tableName: 'expense_management',
        id: item.id,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sunucudan silinemedi! Bağlantıyı kontrol edin."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Listeden kaldır ve sunucudan tazele
    setState(() => _expenses.remove(item));
    await _loadExpenses(force: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Gider silindi."),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gider ve Harcama Takibi"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadExpenses(force: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadExpenses(force: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // AY SEÇİCİ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                          ),
                          Text(
                            _fmtMonthTr(_viewMonth),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _changeMonth(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ÖZET KARTLARI
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            "Bugün",
                            _todayTotal,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            "Aylık Toplam",
                            _monthTotal,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // GİDER EKLEME FORMU
                    _buildForm(),
                    const SizedBox(height: 24),

                    // NEYE HARCANDI DÖKÜMÜ
                    if (_monthBreakdown.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Neye Harcandı? (Aylık Döküm)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: _monthBreakdown.map((e) {
                            final pct = _monthTotal > 0
                                ? (e.value / _monthTotal * 100)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    "%${pct.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "${e.value.toStringAsFixed(2)} ₺",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // HARCAMA GEÇMİŞİ (seçili ay)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Harcama Geçmişi (${_monthExpenses.length} kayıt)",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _monthExpenses.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                "Bu ay harcama girilmedi.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _monthExpenses.length,
                            itemBuilder: (context, index) {
                              final item = _monthExpenses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade50,
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(_fmtTr(item.date)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${item.amount.toStringAsFixed(2)} ₺",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: "Sil",
                                        onPressed: () =>
                                            _confirmDeleteExpense(item),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryCard(String label, double value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 6),
          Text(
            "${value.toStringAsFixed(2)} ₺",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Gider Açıklaması (Örn: Yol, Yemek, Malzeme)",
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? "Açıklama giriniz" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: "Tutar (TL)",
                prefixIcon: const Icon(Icons.currency_lira),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return "Tutar giriniz";
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return "Geçerri bir sayı girin";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      "Tarih: ${_fmtTr(_selectedDate)}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _addExpense,
                child: _saving
                    ? const SubsectionLoadingIndicator() // veya standart CircularProgressIndicator
                    : const Text(
                        "Gider Ekle",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ufak bir yardımcı widget (Eğer projende yoksa circular indicator döner)
class SubsectionLoadingIndicator extends StatelessWidget {
  const SubsectionLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

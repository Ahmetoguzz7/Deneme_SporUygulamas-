/*
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class StudentCollectionPage extends StatefulWidget {
  const StudentCollectionPage({super.key});

  @override
  State<StudentCollectionPage> createState() => _StudentCollectionPageState();
}

class _StudentCollectionPageState extends State<StudentCollectionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _recordDateController = TextEditingController();

  List<String> _branches = [];
  String? _selectedBranch;

  final List<Map<String, String>> _collectedStudents = [];

  bool _loading = true;
  bool _saving = false;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _recordDateController.text = _fmtInput(DateTime.now());
    _init();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _recordDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _loading = true);
    await Future.wait([_loadBranches(), _loadStudents()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBranches() async {
    try {
      final list = await GoogleSheetService.getBranchesCached();
      final names = <String>[];
      for (final b in list) {
        var active = "TRUE";
        try {
          active = b.is_active.toString().toUpperCase();
        } catch (_) {}
        if (active == "FALSE") continue;

        final name = b.name.toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
      names.sort();
      if (mounted) setState(() => _branches = names);
    } catch (e) {}
  }

  Future<void> _loadStudents({bool force = false}) async {
    if (force && mounted) {
      setState(() => _isRefreshing = true);
    }

    final raw = await GoogleSheetService.getStudentDataCached(
      forceRefresh: force,
    );
    final list = <Map<String, String>>[];
    for (final m in raw) {
      final name = (m['first_name'] ?? '').toString();
      final surname = (m['last_name'] ?? '').toString();
      if (name.trim().isEmpty && surname.trim().isEmpty) continue;

      list.add({
        'id': (m['id'] ?? '').toString(),
        'name': name,
        'surname': surname,
        'phone': (m['phone'] ?? '').toString(),
        'birth_date': (m['b_date'] ?? '').toString(),
        'record_date': (m['created_at'] ?? '').toString(),
        'branch': (m['branches'] ?? '').toString(),
      });
    }
    list.sort(
      (a, b) => (b['record_date'] ?? '').compareTo(a['record_date'] ?? ''),
    );

    if (!mounted) return;
    setState(() {
      _collectedStudents
        ..clear()
        ..addAll(list);
      _isRefreshing = false;
    });
  }

  DateTime? _parseUserDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;

    if (t.contains('T') || (t.length >= 8 && t.startsWith(RegExp(r'\d{4}')))) {
      final iso = DateTime.tryParse(t.replaceAll(' ', 'T'));
      if (iso != null) return iso;
    }

    final parts = t.split(RegExp(r'[./-]'));
    if (parts.length != 3) return null;
    try {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
      }
      final d = DateTime(year, month, day);
      if (d.day != day || d.month != month || d.year != year) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  String _fmtInput(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}."
      "${d.month.toString().padLeft(2, '0')}."
      "${d.year}";

  String? _toBackendDate(String userInput) {
    final d = _parseUserDate(userInput);
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  String _fmtTr(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return "—";
    final d = _parseUserDate(r);
    if (d == null) return raw;
    try {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final existing = _parseUserDate(controller.text);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => controller.text = _fmtInput(picked));
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen bir şube seçin!"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final bDateBackend =
        _toBackendDate(_birthDateController.text) ??
        _birthDateController.text.trim();
    final recordBackend =
        _toBackendDate(_recordDateController.text) ??
        _recordDateController.text.trim();

    final ok = await GoogleSheetService.addStudentData(
      firstName: _nameController.text.trim(),
      lastName: _surnameController.text.trim(),
      phone: _phoneController.text.trim(),
      bDate: bDateBackend,
      branches: _selectedBranch!,
      createdAt: recordBackend,
    );

    if (ok) {
      _collectedStudents.insert(0, {
        "id": "local",
        "name": _nameController.text.trim(),
        "surname": _surnameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "birth_date": bDateBackend,
        "record_date": recordBackend,
        "branch": _selectedBranch!,
      });

      _nameController.clear();
      _surnameController.clear();
      _phoneController.clear();
      _birthDateController.clear();
    }

    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ok ? "Öğrenci başarıyla eklendi!" : "Kaydedilemedi (bağlantı?)",
              ),
            ),
          ],
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final s = _collectedStudents[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text("Kaydı Sil"),
          ],
        ),
        content: Text(
          "${s['name']} ${s['surname']} kaydını silmek istediğinize emin misiniz?",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = s['id'] ?? '';
    if (id.isNotEmpty && id != 'local') {
      await GoogleSheetService.deleteStudentData(id);
    }

    setState(() => _collectedStudents.removeAt(index));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Kayıt silindi."),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ======================== RENK PALETİ ========================
  static const Color _primaryColor = Color(0xFF0F172A);
  static const Color _secondaryColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF3B82F6);
  static const Color _gradientStart = Color(0xFF0F172A);
  static const Color _gradientEnd = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _loading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: () => _loadStudents(force: true),
              color: _accentColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildForm(),
                      const SizedBox(height: 24),
                      _buildStudentListHeader(),
                      const SizedBox(height: 12),
                      _buildStudentList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Saha Öğrenci Toplama",
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: "Yenile",
          onPressed: _isRefreshing ? null : () => _loadStudents(force: true),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, _gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Öğrenci Bilgi Toplama",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Toplam ${_collectedStudents.length} öğrenci kaydı",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_branches.length} Şube",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.people_alt, color: _accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          "Kayıtlı Öğrenciler",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primaryColor,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _secondaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${_collectedStudents.length}",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _secondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    if (_collectedStudents.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _collectedStudents.length,
      itemBuilder: (context, index) {
        final s = _collectedStudents[index];
        return _buildStudentCard(s, index);
      },
    );
  }

  Widget _buildStudentCard(Map<String, String> s, int index) {
    final branchColor = _getBranchColor(s['branch'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (s['name'] ?? '?').isNotEmpty
                          ? s['name']![0].toUpperCase()
                          : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${s['name']} ${s['surname']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: branchColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: branchColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              s['branch'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: branchColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (s['phone']?.isNotEmpty ?? false)
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  s['phone'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.cake,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _fmtTr(s['birth_date'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _fmtTr(s['record_date'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 22,
                    ),
                    tooltip: "Sil",
                    onPressed: () => _confirmDelete(index),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Henüz Veri Eklenmedi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni öğrenci eklemek için formu doldurun.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_add, color: _accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  "Yeni Öğrenci Ekle",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Şube Dropdown
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              isExpanded: true,
              hint: Text(
                _branches.isEmpty ? "Şube yükleniyor..." : "Şube Seçin",
                style: TextStyle(color: Colors.grey.shade500),
              ),
              decoration: InputDecoration(
                labelText: "Kulüp / Şube",
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                prefixIcon: Icon(Icons.business_center, color: _accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _branches.map((branch) {
                return DropdownMenuItem(value: branch, child: Text(branch));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBranch = val),
              validator: (v) => v == null ? "Şube seçimi zorunlu" : null,
            ),
            const SizedBox(height: 14),
            // Ad
            _buildTextField(
              controller: _nameController,
              label: "Öğrenci Adı",
              icon: Icons.person,
              validator: (v) => v == null || v.isEmpty ? "Ad zorunlu" : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            // Soyad
            _buildTextField(
              controller: _surnameController,
              label: "Öğrenci Soyadı",
              icon: Icons.person_outline,
              validator: (v) => v == null || v.isEmpty ? "Soyad zorunlu" : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            // Telefon
            _buildTextField(
              controller: _phoneController,
              label: "Telefon Numarası",
              icon: Icons.phone,
              hint: "05xx xxx xx xx",
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.length < 10
                  ? "Geçerli bir telefon girin"
                  : null,
            ),
            const SizedBox(height: 14),
            // Doğum Tarihi
            _buildDateField(
              controller: _birthDateController,
              label: "Doğum Tarihi",
              icon: Icons.cake,
              onCalendarTap: () => _selectDate(context, _birthDateController),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Doğum tarihi girin";
                if (_parseUserDate(v) == null) {
                  return "Geçerli tarih girin (gg.aa.yyyy)";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Kayıt Tarihi
            _buildDateField(
              controller: _recordDateController,
              label: "Kayıt Tarihi",
              icon: Icons.calendar_today,
              onCalendarTap: () => _selectDate(context, _recordDateController),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Kayıt tarihi girin";
                if (_parseUserDate(v) == null) {
                  return "Geçerli tarih girin (gg.aa.yyyy)";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Kaydet Butonu
            SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _saving
                      ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_gradientStart, _gradientEnd],
                        ),
                  boxShadow: [
                    if (!_saving)
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : _saveStudent,
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Kaydediliyor...",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save, size: 20),
                            const SizedBox(width: 10),
                            const Text(
                              "Öğrenciyi Kaydet",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
        hintText: hint,
        prefixIcon: Icon(icon, color: _accentColor, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onCalendarTap,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      inputFormatters: [_DateInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
        hintText: "gg.aa.yyyy",
        prefixIcon: Icon(icon, color: _accentColor, size: 22),
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_today, color: _accentColor),
          tooltip: "Takvimden seç",
          onPressed: onCalendarTap,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      validator: validator,
    );
  }

  Color _getBranchColor(String branch) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.red,
    ];
    final index = branch.hashCode.abs() % colors.length;
    return colors[index];
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if ((i == 1 || i == 3) && i != trimmed.length - 1) {
        buffer.write('.');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
*/

import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class StudentCollectionPage extends StatefulWidget {
  const StudentCollectionPage({super.key});

  @override
  State<StudentCollectionPage> createState() => _StudentCollectionPageState();
}

class _StudentCollectionPageState extends State<StudentCollectionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _recordDateController = TextEditingController();

  List<String> _branches = [];
  String? _selectedBranch;

  final List<Map<String, String>> _collectedStudents = [];

  bool _loading = true;
  bool _saving = false;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _recordDateController.text = _fmtInput(DateTime.now());

    // 🔥 Akıllı Başlangıç: RAM/Disk üzerinde veri varsa beklemeden anında yükle, yoksa arka planda çek
    _initSmartData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _recordDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 🔥 Akıllı Veri Yükleme Yöntemi
  Future<void> _initSmartData() async {
    if (mounted) setState(() => _loading = true);

    // Eğer AppRepository zaten yüklendiyse branch'leri ve verileri hızla çekelim
    await Future.wait([_loadBranches(), _loadStudents(force: false)]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBranches() async {
    try {
      final list = await GoogleSheetService.getBranchesCached();
      final names = <String>[];
      for (final b in list) {
        var active = "TRUE";
        try {
          active = b.is_active.toString().toUpperCase();
        } catch (_) {}
        if (active == "FALSE") continue;

        final name = b.name.toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
      names.sort();
      if (mounted) setState(() => _branches = names);
    } catch (e) {}
  }

  Future<void> _loadStudents({bool force = false}) async {
    if (force && mounted) {
      setState(() => _isRefreshing = true);
    }

    final raw = await GoogleSheetService.getStudentDataCached(
      forceRefresh: force,
    );
    final list = <Map<String, String>>[];
    for (final m in raw) {
      final name = (m['first_name'] ?? '').toString();
      final surname = (m['last_name'] ?? '').toString();
      if (name.trim().isEmpty && surname.trim().isEmpty) continue;

      list.add({
        'id': (m['id'] ?? '').toString(),
        'name': name,
        'surname': surname,
        'phone': (m['phone'] ?? '').toString(),
        'birth_date': (m['b_date'] ?? '').toString(),
        'record_date': (m['created_at'] ?? '').toString(),
        'branch': (m['branches'] ?? '').toString(),
      });
    }
    list.sort(
      (a, b) => (b['record_date'] ?? '').compareTo(a['record_date'] ?? ''),
    );

    if (!mounted) return;
    setState(() {
      _collectedStudents
        ..clear()
        ..addAll(list);
      _isRefreshing = false;
    });
  }

  DateTime? _parseUserDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;

    if (t.contains('T') || (t.length >= 8 && t.startsWith(RegExp(r'\d{4}')))) {
      final iso = DateTime.tryParse(t.replaceAll(' ', 'T'));
      if (iso != null) return iso;
    }

    final parts = t.split(RegExp(r'[./-]'));
    if (parts.length != 3) return null;
    try {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
      }
      final d = DateTime(year, month, day);
      if (d.day != day || d.month != month || d.year != year) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  String _fmtInput(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}."
      "${d.month.toString().padLeft(2, '0')}."
      "${d.year}";

  String? _toBackendDate(String userInput) {
    final d = _parseUserDate(userInput);
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  String _fmtTr(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return "—";
    final d = _parseUserDate(r);
    if (d == null) return raw;
    try {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final existing = _parseUserDate(controller.text);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => controller.text = _fmtInput(picked));
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen bir şube seçin!"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final loadingFuture = Future.delayed(const Duration(milliseconds: 600));
    final bDateBackend =
        _toBackendDate(_birthDateController.text) ??
        _birthDateController.text.trim();
    final recordBackend =
        _toBackendDate(_recordDateController.text) ??
        _recordDateController.text.trim();

    final ok = await GoogleSheetService.addStudentData(
      firstName: _nameController.text.trim(),
      lastName: _surnameController.text.trim(),
      phone: _phoneController.text.trim(),
      bDate: bDateBackend,
      branches: _selectedBranch!,
      createdAt: recordBackend,
    );
    await loadingFuture;
    if (ok) {
      _collectedStudents.insert(0, {
        "id": "local",
        "name": _nameController.text.trim(),
        "surname": _surnameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "birth_date": bDateBackend,
        "record_date": recordBackend,
        "branch": _selectedBranch!,
      });

      _nameController.clear();
      _surnameController.clear();
      _phoneController.clear();
      _birthDateController.clear();
    }

    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ok ? "Öğrenci başarıyla eklendi!" : "Kaydedilemedi (bağlantı?)",
              ),
            ),
          ],
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final s = _collectedStudents[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text("Kaydı Sil"),
          ],
        ),
        content: Text(
          "${s['name']} ${s['surname']} kaydını silmek istediğinize emin misiniz?",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = s['id'] ?? '';
    if (id.isNotEmpty && id != 'local') {
      await GoogleSheetService.deleteStudentData(id);
    }

    setState(() => _collectedStudents.removeAt(index));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Kayıt silindi."),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ======================== RENK PALETİ ========================
  static const Color _primaryColor = Color(0xFF0F172A);
  static const Color _secondaryColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF3B82F6);
  static const Color _gradientStart = Color(0xFF0F172A);
  static const Color _gradientEnd = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _loading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: () => _loadStudents(force: true),
              color: _accentColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildForm(),
                      const SizedBox(height: 24),
                      _buildStudentListHeader(),
                      const SizedBox(height: 12),
                      _buildStudentList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Saha Öğrenci Toplama",
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: "Yenile",
          onPressed: _isRefreshing ? null : () => _loadStudents(force: true),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Yükleniyor...",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, _gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Öğrenci Bilgi Toplama",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Toplam ${_collectedStudents.length} öğrenci kaydı",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_branches.length} Şube",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.people_alt, color: _accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          "Kayıtlı Öğrenciler",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primaryColor,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _secondaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${_collectedStudents.length}",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _secondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    if (_collectedStudents.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _collectedStudents.length,
      itemBuilder: (context, index) {
        final s = _collectedStudents[index];
        return _buildStudentCard(s, index);
      },
    );
  }

  Widget _buildStudentCard(Map<String, String> s, int index) {
    final branchColor = _getBranchColor(s['branch'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (s['name'] ?? '?').isNotEmpty
                          ? s['name']![0].toUpperCase()
                          : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${s['name']} ${s['surname']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: branchColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: branchColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              s['branch'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: branchColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (s['phone']?.isNotEmpty ?? false)
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  s['phone'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.cake,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _fmtTr(s['birth_date'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _fmtTr(s['record_date'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 22,
                    ),
                    tooltip: "Sil",
                    onPressed: () => _confirmDelete(index),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Henüz Veri Eklenmedi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni öğrenci eklemek için formu doldurun.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_add, color: _accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  "Yeni Öğrenci Ekle",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              isExpanded: true,
              hint: Text(
                _branches.isEmpty ? "Şube yükleniyor..." : "Şube Seçin",
                style: TextStyle(color: Colors.grey.shade500),
              ),
              decoration: InputDecoration(
                labelText: "Kulüp / Şube",
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                prefixIcon: Icon(Icons.business_center, color: _accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _branches.map((branch) {
                return DropdownMenuItem(value: branch, child: Text(branch));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBranch = val),
              validator: (v) => v == null ? "Şube seçimi zorunlu" : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _nameController,
              label: "Öğrenci Adı",
              icon: Icons.person,
              validator: (v) => v == null || v.isEmpty ? "Ad zorunlu" : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _surnameController,
              label: "Öğrenci Soyadı",
              icon: Icons.person_outline,
              validator: (v) => v == null || v.isEmpty ? "Soyad zorunlu" : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _phoneController,
              label: "Telefon Numarası",
              icon: Icons.phone,
              hint: "05xx xxx xx xx",
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.length < 10
                  ? "Geçerli bir telefon girin"
                  : null,
            ),
            const SizedBox(height: 14),
            _buildDateField(
              controller: _birthDateController,
              label: "Doğum Tarihi",
              icon: Icons.cake,
              onCalendarTap: () => _selectDate(context, _birthDateController),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Doğum tarihi girin";
                if (_parseUserDate(v) == null) {
                  return "Geçerli tarih girin (gg.aa.yyyy)";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildDateField(
              controller: _recordDateController,
              label: "Kayıt Tarihi",
              icon: Icons.calendar_today,
              onCalendarTap: () => _selectDate(context, _recordDateController),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Kayıt tarihi girin";
                if (_parseUserDate(v) == null) {
                  return "Geçerli tarih girin (gg.aa.yyyy)";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _saving
                      ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_gradientStart, _gradientEnd],
                        ),
                  boxShadow: [
                    if (!_saving)
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : _saveStudent,
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Kaydediliyor...",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save, size: 20),
                            const SizedBox(width: 10),
                            const Text(
                              "Öğrenciyi Kaydet",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
        hintText: hint,
        prefixIcon: Icon(icon, color: _accentColor, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onCalendarTap,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      inputFormatters: [_DateInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
        hintText: "gg.aa.yyyy",
        prefixIcon: Icon(icon, color: _accentColor, size: 22),
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_today, color: _accentColor),
          tooltip: "Takvimden seç",
          onPressed: onCalendarTap,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      validator: validator,
    );
  }

  Color _getBranchColor(String branch) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.red,
    ];
    final index = branch.hashCode.abs() % colors.length;
    return colors[index];
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if ((i == 1 || i == 3) && i != trimmed.length - 1) {
        buffer.write('.');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

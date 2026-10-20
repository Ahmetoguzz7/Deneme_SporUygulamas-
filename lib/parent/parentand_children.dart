/*
  Bu sayfa, bir veli kullanıcısının çocuklarını hesabına bağlamasına olanak tanır.
  Veli, çocuğunun öğrenci ID'sini girerek onu sistemde arar ve bulursa çocuğunu hesabına bağlar.
*/
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class CocukBaglamaSayfasi extends StatefulWidget {
  final Users veli;
  const CocukBaglamaSayfasi({super.key, required this.veli});

  @override
  State<CocukBaglamaSayfasi> createState() => _CocukBaglamaSayfasiState();
}

class _CocukBaglamaSayfasiState extends State<CocukBaglamaSayfasi> {
  final _idController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _cocukBul() async {
    final studentId = _idController.text.trim();

    if (studentId.isEmpty) {
      _showSnackBar("Lütfen öğrenci ID girin!", isError: true);
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // 🔥 PARALEL VERİ ÇEKME (HIZLI)
      final allUsers = await GoogleSheetService.getUsersCached();

      final student = allUsers.firstWhere(
        (u) => u.app == studentId,
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

      if (student.app.isNotEmpty) {
        // 🔥 ÖĞRENCİYİ BAĞLA
        final success = await GoogleSheetService.addParentStudent(
          widget.veli.app,
          student.app,
        );

        if (success && mounted) {
          _showSnackBar(
            "✅ ${student.first_name} ${student.last_name} başarıyla bağlandı!",
          );
          Navigator.pop(context, true);
        } else {
          _showSnackBar("❌ Bağlama işlemi başarısız oldu!", isError: true);
        }
      } else {
        _showSnackBar(
          "❌ Öğrenci bulunamadı. Lütfen ID'yi kontrol edin.",
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Öğrenci Bağla",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Çocuğunuzun sistemdeki öğrenci ID'sini girerek onu hesabınıza bağlayabilirsiniz.",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idController,
              enabled: !_isSearching,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: "Öğrenci ID",
                hintText: "Örn: STU-001",
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSearching ? null : _cocukBul,
                child: _isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Sorgula ve Bağla",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const VersionFooter(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

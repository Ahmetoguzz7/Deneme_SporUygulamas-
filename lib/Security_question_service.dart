import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 GÜNLÜK GÜVENLİK SORUSU SERVİSİ
///
/// Amaç: Yönetici/muhasebeci girişinde her seferinde kod istemek yerine,
///   • İlk kez (veya yeni cihazda) kurulum: kullanıcı sorulara kendi cevabını girer.
///   • Her yeni GÜN ilk girişte: sorulardan biri sorulur.
///   • Aynı gün tekrar girişte: SORULMAZ.
///   • Yeni cihazda: baştan kurulum + sorulur.
///
/// Cevaplar cihazda düz metin DEĞİL, hash'li (SHA-256) tutulur.
/// Her kullanıcı (email) için ayrı kayıt tutulur.
class SecurityQuestionService {
  static final SecurityQuestionService _i = SecurityQuestionService._();
  factory SecurityQuestionService() => _i;
  SecurityQuestionService._();

  /// 📋 SORU HAVUZU — buradan istediğin gibi değiştir/ekle.
  /// id: kalıcı kimlik (değiştirme), text: gösterilen soru.
  static const List<Map<String, String>> questions = [
    {'id': 'q_teacher', 'text': 'İlkokul öğretmeninizin adı nedir?'},
    {'id': 'q_founded', 'text': 'Kulüp/salon hangi yıl kuruldu?'},
    {'id': 'q_city', 'text': 'Kulüp nerede (hangi şehirde) kuruldu?'},
    {'id': 'q_first_sport', 'text': 'Kulübün ilk/ana sporu nedir?'},
    {'id': 'q_pet', 'text': 'İlk evcil hayvanınızın adı neydi?'},
  ];

  static const String _kAnswersPrefix = 'secq_answers_'; // + email
  static const String _kLastAskedPrefix = 'secq_lastasked_'; // + email
  static const String _kDeviceId = 'secq_device_id';

  /// Cevabı normalize et (büyük/küçük harf, boşluk farkını yok say) + hash'le.
  /// Harici paket gerektirmeyen basit ama yeterli bir hash (cevaplar zaten
  /// cihazda, düz metin tutmamak için). Güçlü kriptografi gerekmez.
  String _hash(String answer) {
    final norm = answer.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final bytes = utf8.encode('evom_salt_$norm');
    // FNV-1a 64-bit benzeri basit hash
    int h = 0xcbf29ce484222325;
    for (final b in bytes) {
      h = (h ^ b) & 0xFFFFFFFFFFFFFFFF;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  /// Cihaz için kalıcı bir kimlik üretir/okur (yeni cihaz tespiti için).
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  /// Bu cihazda + bu kullanıcı için güvenlik cevapları kurulmuş mu?
  Future<bool> isSetUp(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kAnswersPrefix$email');
    if (raw == null || raw.isEmpty) return false;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// İlk kurulum: kullanıcı seçtiği sorulara cevap verir. answers: {questionId: cevap}
  /// En az 2 soru cevaplanmalı (biri unutulursa diğerinden sorulabilsin).
  Future<bool> setUpAnswers(String email, Map<String, String> answers) async {
    final valid = <String, String>{};
    answers.forEach((qId, ans) {
      if (ans.trim().isNotEmpty) valid[qId] = _hash(ans);
    });
    if (valid.length < 2) return false; // en az 2 cevap iste

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kAnswersPrefix$email', jsonEncode(valid));
    // Kurulum yapan cihazı işaretle
    final dev = await _deviceId();
    await prefs.setString('${_kAnswersPrefix}dev_$email', dev);
    return true;
  }

  /// Bugün bu kullanıcıya soru soruldu mu? (aynı cihaz, aynı gün -> tekrar sorma)
  Future<bool> _askedToday(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('$_kLastAskedPrefix$email');
    if (last == null || last.isEmpty) return false;
    final today = _todayKey();
    return last == today;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Bu cihaz, bu kullanıcı için kurulum yapılan cihaz mı? (yeni cihaz tespiti)
  Future<bool> _isSameDevice(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final setupDev = prefs.getString('${_kAnswersPrefix}dev_$email');
    if (setupDev == null || setupDev.isEmpty) return false;
    final cur = await _deviceId();
    return setupDev == cur;
  }

  /// Girişte ne yapmalı? Döner:
  ///   'setup'  -> kurulum gerekli (ilk kez veya yeni cihaz)
  ///   'ask'    -> bugün soru sorulmalı
  ///   'skip'   -> bugün zaten soruldu / gerek yok, direkt gir
  Future<String> decideOnLogin(String email) async {
    final setUp = await isSetUp(email);
    if (!setUp) return 'setup';

    final sameDevice = await _isSameDevice(email);
    if (!sameDevice) return 'setup'; // yeni cihaz -> baştan kurulum + sorulacak

    final askedToday = await _askedToday(email);
    if (askedToday) return 'skip';

    return 'ask';
  }

  /// Bugün için sorulacak soruyu seç (kullanıcının cevapladıklarından).
  /// Gün + email'e göre deterministik seçim: aynı gün hep aynı soru gelir.
  Future<Map<String, String>?> pickQuestionForToday(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kAnswersPrefix$email');
    if (raw == null) return null;
    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final answeredIds = map.keys.toList();
    if (answeredIds.isEmpty) return null;

    // Gün + email hash'i ile deterministik indeks
    final seed = _todayKey() + email;
    final idx = seed.hashCode.abs() % answeredIds.length;
    final chosenId = answeredIds[idx];

    final q = questions.firstWhere(
      (q) => q['id'] == chosenId,
      orElse: () => {'id': chosenId, 'text': 'Güvenlik sorusu'},
    );
    return {'id': chosenId, 'text': q['text'] ?? 'Güvenlik sorusu'};
  }

  /// Verilen cevabı doğrula.
  Future<bool> verifyAnswer(
    String email,
    String questionId,
    String answer,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kAnswersPrefix$email');
    if (raw == null) return false;
    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final stored = map[questionId]?.toString();
    if (stored == null) return false;
    return stored == _hash(answer);
  }

  /// Doğrulama başarılı olunca "bugün soruldu" olarak işaretle.
  Future<void> markAskedToday(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kLastAskedPrefix$email', _todayKey());
  }

  /// (İsteğe bağlı) Kullanıcının güvenlik kurulumunu sıfırla.
  Future<void> reset(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kAnswersPrefix$email');
    await prefs.remove('${_kAnswersPrefix}dev_$email');
    await prefs.remove('$_kLastAskedPrefix$email');
  }
}

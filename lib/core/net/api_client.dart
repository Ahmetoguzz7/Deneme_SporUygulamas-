/*
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // 🔥 Kendi /exec URL'ini koy
  static const _url =
      "https://script.google.com/macros/s/AKfycbzLDgE0zIxZQcnHDQCp4udgOopUSWmbq3sHe8JNbqxpb9VxIfF9wtSVhVu1ZE4RgxrUtA/exec";

  /// JSON POST + timeout + BUSY_RETRY backoff. Hata olursa null döner (sessiz fallback).
  Future<Map<String, dynamic>?> post(
    Map<String, dynamic> body, {
    int maxRetry = 4,
  }) async {
    for (var attempt = 0; attempt <= maxRetry; attempt++) {
      try {
        final resp = await http
            .post(
              Uri.parse(_url),
              headers: {'Content-Type': 'application/json'}, // 🔥 JSON şart
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

        if (decoded['error'] == 'BUSY_RETRY') {
          await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
          continue;
        }
        return decoded;
      } catch (_) {
        if (attempt == maxRetry) return null;
        await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
      }
    }
    return null;
  }

  /// 🔥 OKUMA: bir sayfayı (tabloyu) çeker. Eski backend stili: GET ?sheet=users
  /// Dönüş: satırların listesi (List<Map>). Hata/boşsa boş liste döner.
  ///
  /// ⚠️ Backend'in okumayı farklı veriyorsa SADECE bu metodu değiştir:
  ///   • POST action ise:  final res = await post({'action':'getTable','table':sheet});
  ///                        return (res?['data'] as List?) ?? [];
  Future<List<dynamic>> getSheet(String sheet) async {
    try {
      final resp = await http
          .get(Uri.parse('$_url?sheet=$sheet'))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return [];
      final decoded = jsonDecode(resp.body);

      if (decoded is Map &&
          decoded['success'] == true &&
          decoded['data'] is List) {
        return decoded['data'] as List;
      }
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }
}
*/
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:EVOM_SPOR/config.dart'; // 🔥 tek URL kaynağı

class ApiClient {
  static const _url = kBackendUrl; // 🔥 DEĞİŞTİ: artık config.dart'tan

  /// JSON POST + timeout + BUSY_RETRY backoff. Hata olursa null döner (sessiz fallback).
  Future<Map<String, dynamic>?> post(
    Map<String, dynamic> body, {
    int maxRetry = 4,
  }) async {
    for (var attempt = 0; attempt <= maxRetry; attempt++) {
      try {
        final resp = await http
            .post(
              Uri.parse(_url),
              headers: {'Content-Type': 'application/json'}, // 🔥 JSON şart
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

        if (decoded['error'] == 'BUSY_RETRY') {
          await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
          continue;
        }
        return decoded;
      } catch (_) {
        if (attempt == maxRetry) return null;
        await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
      }
    }
    return null;
  }

  /// 🔥 OKUMA: bir sayfayı (tabloyu) çeker. Eski backend stili: GET ?sheet=users
  /// Dönüş: satırların listesi (List<Map>). Hata/boşsa boş liste döner.
  ///
  /// ⚠️ Backend'in okumayı farklı veriyorsa SADECE bu metodu değiştir:
  ///   • POST action ise:  final res = await post({'action':'getTable','table':sheet});
  ///                        return (res?['data'] as List?) ?? [];
  Future<List<dynamic>> getSheet(String sheet) async {
    try {
      final resp = await http
          .get(Uri.parse('$_url?sheet=$sheet'))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return [];
      final decoded = jsonDecode(resp.body);

      if (decoded is Map &&
          decoded['success'] == true &&
          decoded['data'] is List) {
        return decoded['data'] as List;
      }
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }
}

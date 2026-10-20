import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordService {
  // SHA-256 ile HASHLEME (Geri döndürülemez)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Şifre doğrulama
  bool verifyPassword(String plainPassword, String hashedPassword) {
    final hashedInput = hashPassword(plainPassword);
    return hashedInput == hashedPassword;
  }
}

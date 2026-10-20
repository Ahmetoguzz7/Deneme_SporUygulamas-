import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  static const String _senderEmail = 'oksijenadmiin@gmail.com';
  static const String _appPassword = 'obmdyutkjkslagyi'; // 16 haneli, boşluksuz

  static Future<bool> sendPasswordResetCode(
    String toEmail,
    String code,
    String userName,
  ) async {
    try {
      final smtpServer = gmail(_senderEmail, _appPassword);

      final message = Message()
        ..from = Address(_senderEmail, 'EVOM SPOR Güvenlik')
        ..recipients.add(toEmail)
        ..subject = '🔐 EVOM SPOR - Şifre Sıfırlama Kodunuz'
        ..html =
            '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: Arial, sans-serif;
              background-color: #f4f4f4;
              margin: 0;
              padding: 20px;
            }
            .container {
              max-width: 500px;
              margin: 0 auto;
              background: white;
              border-radius: 16px;
              padding: 30px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .header {
              text-align: center;
              border-bottom: 2px solid #1E293B;
              padding-bottom: 20px;
              margin-bottom: 20px;
            }
            .logo {
              font-size: 28px;
              font-weight: bold;
              color: #1E293B;
            }
            .code {
              font-size: 42px;
              font-weight: bold;
              letter-spacing: 8px;
              text-align: center;
              background: #F1F5F9;
              padding: 20px;
              border-radius: 12px;
              margin: 20px 0;
              color: #1E293B;
            }
            .warning {
              background: #FEF3C7;
              padding: 12px;
              border-radius: 8px;
              font-size: 12px;
              color: #92400E;
              text-align: center;
            }
            .footer {
              text-align: center;
              font-size: 12px;
              color: #666;
              margin-top: 20px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">🏀 EVOM SPOR</div>
            </div>
            <p>Merhaba <strong>$userName</strong>,</p>
            <p>Şifre sıfırlama talebinde bulundunuz. Aşağıdaki güvenlik kodunu kullanarak yeni şifrenizi oluşturabilirsiniz:</p>
            
            <div class="code">$code</div>
            
            <p>Bu kod <strong>15 dakika</strong> geçerlidir.</p>
            <p>Eğer bu işlemi siz yapmadıysanız, lütfen bu e-postayı dikkate almayın.</p>
            
            <div class="warning">
              ⚠️ Güvenlik uyarısı: Bu kodu kimseyle paylaşmayın. EVOM SPOR çalışanları asla şifrenizi sormaz.
            </div>
            
            <div class="footer">
              © ${DateTime.now().year} EVOM SPOR - Tüm hakları saklıdır.
            </div>
          </div>
        </body>
        </html>
        ''';

      final sendReport = await send(message, smtpServer);
      print("✅ Email gönderildi: $sendReport");
      return true;
    } catch (e) {
      print("❌ Email hatası: $e");
      return false;
    }
  }
}

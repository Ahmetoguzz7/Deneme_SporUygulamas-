import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class DekontServisi {
  static Future<void> dekontOlusturVeGonder({
    required String ogrenciAdi,
    required String tcNo,
    required String odemeTarihi,
    required String odeyenKisi,
  }) async {
    final pdf = pw.Document();

    // 1. Türkçe karakter desteği için fontu yükle
    // Not: assets/fonts/Roboto-Regular.ttf dosyasının var olduğundan emin ol!
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // 2. Sayfa İçeriğini Oluştur
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),

            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    "ODEME DEKONTU",
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Sayin Yetkili,",
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  "$tcNo T.C. Kimlik numarasina sahip $ogrenciAdi isimli ogrencinin aidati, "
                  "$odemeTarihi tarihinde $odeyenKisi tarafindan odenmistir.",
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Islem Tarihi: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}",
                    ),
                    pw.Text(
                      "Imza/Onay",
                      style: const pw.TextStyle(
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }, // build sonu
      ), // Page sonu
    ); // addPage sonu

    // 3. Dosyayı telefonun geçici hafızasına kaydet
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/dekont_$tcNo.pdf");
    await file.writeAsBytes(await pdf.save());

    // 4. Maili Hazırla ve Gönder
    final Email email = Email(
      body: 'Sayin Yetkili, odeme dekontu ekte yer almaktadir.',
      subject: 'Aidat Odemesi - $ogrenciAdi',
      recipients: ['oguz@example.com'],
      attachmentPaths: [file.path],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      print("Mail gonderme hatasi: $e");
    }
  }
}

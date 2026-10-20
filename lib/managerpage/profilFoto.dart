import 'package:flutter/material.dart';

class ProfilSayfasi extends StatelessWidget {
  const ProfilSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    const String profilFotoUrl =
        'https://picsum.photos/400'; // Test için geçici görsel

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: GestureDetector(
          onTap: () {
            // 🔥 Fotoğrafa basılınca pop-up diyalogu tetikliyoruz
            showDialog(
              context: context,
              barrierDismissible: true, // Dışarı basınca kapansın
              builder: (context) =>
                  const ProfilFotoPopup(imageUrl: profilFotoUrl),
            );
          },
          // 📌 Küçük Profil Fotoğrafı
          child: const Hero(
            tag:
                'profil_foto_kahramani', // İki taraftaki tag BİREBİR aynı olmalı kanka
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(profilFotoUrl),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 Büyütülmüş Fotoğrafı Gösteren Pop-up Widget'ı
class ProfilFotoPopup extends StatelessWidget {
  final String imageUrl;
  const ProfilFotoPopup({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
      insetPadding: const EdgeInsets.all(10), // Kenarlardan ufak bir boşluk
      child: GestureDetector(
        onTap: () =>
            Navigator.of(context).pop(), // Fotoğrafa tekrar basınca kapansın
        child: InteractiveViewer(
          // 💡 Instagram'daki gibi iki parmakla zoom yapabilmek için sihirli dokunuş
          panEnabled: true,
          maxScale: 4.0,
          child: Hero(
            tag:
                'profil_foto_kahramani', // Küçük fotoğraftaki tag ile birebir aynı
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape
                    .circle, // İstersen kare yapmak için BoxShape.rectangle yapabilirsin kanka
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

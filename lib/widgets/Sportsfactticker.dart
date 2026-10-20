import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Yükleme ekranlarında kendi kendine dönen spor/futbol bilgileri.
/// Overlay'lerdeki statik "ipucu" yazısının yerine konur; kendi
/// zamanlayıcısı vardır, her birkaç saniyede bir bilgi değişir.
class SportsFactRotatingText extends StatefulWidget {
  final Duration interval;
  final TextStyle? style;
  const SportsFactRotatingText({
    super.key,
    this.interval = const Duration(seconds: 4),
    this.style,
  });

  @override
  State<SportsFactRotatingText> createState() => _SportsFactRotatingTextState();
}

class _SportsFactRotatingTextState extends State<SportsFactRotatingText> {
  static const List<String> _facts = [
    "⚽ Bir futbol maçı 45+45 dakikadan, toplam 90 dakikadır.",
    "⚽ Sahaya her takım 11 oyuncuyla çıkar; biri kalecidir.",
    "⚽ Penaltı noktası kaleye 11 metre uzaklıktadır.",
    "🏆 İlk Dünya Kupası 1930'da Uruguay'da oynandı.",
    "⚽ İki sarı kart, bir kırmızı karta eşittir.",
    "⚽ Kornerden doğrudan gol atılabilir.",
    "⚽ Kaleci topu yalnızca kendi ceza sahasında elle oynayabilir.",
    "⚽ Futbol topunun çevresi yaklaşık 68–70 cm'dir.",
    "⚽ Ofsayt kuralı, hücumcuyu son savunmadan öne geçince sınırlar.",
    "🥅 Kale 7,32 m eninde, 2,44 m yüksekliğindedir.",
    "⚽ Taç atışı iki ayak yerde ve top baş arkasından atılır.",
    "🏆 Dünya Kupası her 4 yılda bir düzenlenir.",
    "⚽ Santra çizgisi sahayı iki eşit yarıya böler.",
    "⚽ Faul sonrası oyun serbest vuruşla devam eder.",
    "⚽ Kaleci hariç kimse topa elle dokunamaz.",
    "⚽ Sarı kart uyarı, kırmızı kart oyundan atılma demektir.",
    "⚽ Hakem, oyunun ek (uzatma) süresini kendisi belirler.",
    "⚽ Futbol, dünyada en çok izlenen spordur.",
    "💪 Isınma yapmak sakatlık riskini ciddi biçimde azaltır.",
    "💧 Su içmek dayanıklılık ve odak için şarttır.",
    "😴 Kaslar en çok uykuda onarılır; dinlenmeyi ihmal etme.",
    "🏃 Düzenli tempolu koşu kalp sağlığını güçlendirir.",
    "💪 Kuvvet ve esneklik birlikte çalışınca performans artar.",
    "🍎 Dengeli beslenme, antrenmanın yarısı kadar önemlidir.",
    "🧠 Odaklanma, çoğu zaman yetenekten önce gelir.",
    "🏆 Şampiyonluk tek maçta değil, istikrarla kazanılır.",
    "🏃 Kısa ısınma turları kasları oyuna hazırlar.",
    "💧 Antrenman öncesi ve sonrası su dengesi önemlidir.",
  ];

  late int _index;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _index = Random().nextInt(_facts.length);
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _facts.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.85),
          height: 1.4,
        );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(_facts[_index], key: ValueKey(_index), style: style),
    );
  }
}

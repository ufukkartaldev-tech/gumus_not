import 'package:flutter/material.dart';

class NoteTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String content;

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.content,
  });

  static List<NoteTemplate> get defaultTemplates => [
    NoteTemplate(
      id: 'cornell',
      name: 'Cornell Not Sistemi',
      description: 'Öğrenme verimliliğini artıran akademik not alma yöntemi.',
      icon: Icons.school,
      color: Colors.blue,
      content: '''# 🎓 Ders/Konu Başlığı
Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}

## 💡 Anahtar Kelimeler & İpuçları
- [Önemli Kavram 1]
- [Soru 1]

---

## 📝 Notlar
Bu bölüme ders sırasında aldığınız detaylı notları yazın.

*   Madde 1
*   Madde 2

## 🏷️ Özet
Bu dersin/konunun 2-3 cümlelik özeti nedir?

''',
    ),
    NoteTemplate(
      id: 'meeting',
      name: 'Toplantı Tutanağı',
      description: 'Kurumsal toplantılar için profesyonel kayıt formatı.',
      icon: Icons.business,
      color: Colors.orange,
      content: '''# 🤝 Toplantı: [Konu]
**Tarih:** ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}
**Katılımcılar:** 
- [Kişi 1]
- [Kişi 2]

---

## 📋 Gündem Maddeleri
1.  
2.  

## 💬 Tartışılan Konular
*   

## ✅ Alınan Kararlar
1.  [Karar 1]
2.  [Karar 2]

## 🚀 Aksiyon Planı (Kim? Ne Zaman?)
- [ ] [Görev] - @Kişi (Son Tarih: )
''',
    ),
    NoteTemplate(
      id: 'daily_journal',
      name: 'Günlük & Planlayıcı',
      description: 'Günü planlamak ve düşünceleri kaydetmek için.',
      icon: Icons.today,
      color: Colors.green,
      content: '''# 📅 Günlük: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}

## 🎯 Bugünün 3 Büyük Hedefi
1.  [ ] 
2.  [ ] 
3.  [ ] 

---

## 🧠 Aklımdakiler
Bugün nasıl hissediyorum? Neler düşünüyorum?

## 🙏 Minnettarım
Bugün iyi giden 3 şey:
1. 
2. 
3. 
''',
    ),
    NoteTemplate(
      id: 'book_summary',
      name: 'Kitap Özeti',
      description: 'Okuduğunuz kitaplardan notlar çıkarın.',
      icon: Icons.book,
      color: Colors.brown,
      content: '''# 📚 Kitap: [Kitap Adı]
**Yazar:** [Yazar Adı]
**Tür:** [Tür]

---

## 🔑 Ana Fikirler
Bu kitap ne anlatıyor?

## 💬 Favori Alıntılar
> "Buraya alıntı yapıştırın." - Sayfa X

## 🚀 Öğrendiklerim & Uygulayacaklarım
1.  
2.  
''',
    ),
     NoteTemplate(
      id: 'project_idea',
      name: 'Proje Fikri',
      description: 'Yeni bir fikir mi var? Hemen yapılandır!',
      icon: Icons.lightbulb,
      color: Colors.purple,
      content: '''# 💡 Proje: [Proje Adı]

## ❓ Problem
Hangi sorunu çözüyoruz?

## ✅ Çözüm
Nasıl çözeceğiz? (MVP Özellikleri)

## 🎯 Hedef Kitle
Kime hitap ediyoruz?

## 🛠️ Teknolojiler / Araçlar
- 
- 

## 📝 İlk Adımlar
1.  [ ] 
''',
    ),
  ];
}

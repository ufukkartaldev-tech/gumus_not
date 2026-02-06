import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class TemplateService {
  static Database? _database;
  static const String _dbName = 'connected_notebook.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        created_at INTEGER NOT NULL,
        is_default INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_templates_category ON templates(category);
      CREATE INDEX idx_templates_name ON templates(name);
    ''');

    await _insertDefaultTemplates(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  }

  static Future<void> _insertDefaultTemplates(Database db) async {
    final templates = _getDefaultTemplates();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final template in templates) {
      await db.insert('templates', {
        ...template,
        'created_at': now,
        'is_default': 1,
      });
    }
  }

  static List<Map<String, dynamic>> _getDefaultTemplates() {
    return [
      {
        'name': 'Boş Not',
        'category': 'Genel',
        'description': 'Basit bir not başlatmak için',
        'icon': '📝',
        'content': '''# Başlık

Notunuzun içeriğini buraya yazın...

## Alt Başlık

- Madde 1
- Madde 2
- Madde 3

**Önemli bilgi:** *vurgulanmış metin*

[[]]''',
      },
      {
        'name': 'Toplantı Notları',
        'category': 'İş',
        'description': 'Toplantıları düzenli tutmak için',
        'icon': '👥',
        'content': '''# Toplantı Notları

**Tarih:** [[Tarih]]
**Katılımcılar:** [[Katılımcılar]]
**Konu:** [[Toplantı Konusu]]

## Gündem

1. 
2. 
3. 

## Kararlar

- 
- 
- 

## Action Items

- [ ] **Sorumlu:** [[İsim]] - **Görev:** [[Görev]] - **Tarih:** [[Tarih]]
- [ ] **Sorumlu:** [[İsim]] - **Görev:** [[Görev]] - **Tarih:** [[Tarih]]

## Sonraki Adımlar

- 
- 

## Notlar

''',
      },
      {
        'name': 'Proje Planı',
        'category': 'İş',
        'description': 'Yeni projeler için planlama şablonu',
        'icon': '🚀',
        'content': '''# Proje Planı

**Proje Adı:** [[Proje Adı]]
**Başlangıç:** [[Başlangıç Tarihi]]
**Bitiş:** [[Bitiş Tarihi]]
**Sorumlu:** [[Proje Yöneticisi]]

## Proje Özeti

[[Proje hakkında kısa açıklama]]

## Hedefler

- [ ] Ana Hedef 1
- [ ] Ana Hedef 2
- [ ] Ana Hedef 3

## Aşamalar

### Aşama 1: [[Aşama Adı]]
**Tarih:** [[Tarih]]
**Görevler:**
- [ ] 
- [ ] 
- [ ]

### Aşama 2: [[Aşama Adı]]
**Tarih:** [[Tarih]]
**Görevler:**
- [ ] 
- [ ] 
- [ ]

## Kaynaklar

- **Bütçe:** [[Bütçe]]
- **Ekip:** [[Ekip Üyeleri]]
- **Araçlar:** [[Gerekli Araçlar]]

## Riskler

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| | | | |

## Başarı Metrikleri

- [[Metrik 1]]
- [[Metrik 2]]
- [[Metrik 3]]

''',
      },
      {
        'name': 'Ders Notları',
        'category': 'Eğitim',
        'description': 'Dersleri düzenli tutmak için',
        'icon': '📚',
        'content': '''# Ders Notları

**Ders:** [[Ders Adı]]
**Tarih:** [[Tarih]]
**Öğretmen:** [[Öğretmen Adı]]

## Konu

[[Dersin ana konusu]]

## Önemli Kavramlar

- **Kavram 1:** [[Açıklama]]
- **Kavram 2:** [[Açıklama]]
- **Kavram 3:** [[Açıklama]]

## Notlar

### Başlık 1

[[Notlarınız]]

### Başlık 2

[[Notlarınız]]

## Örnekler

```
[[Kod örnekleri veya matematiksel formüller]]
```

## Ödevler

- [ ] **Ödev 1:** [[Açıklama]] - **Teslim:** [[Tarih]]
- [ ] **Ödev 2:** [[Açıklama]] - **Teslim:** [[Tarih]]

## Sorular

- 
- 
- 

## İlişkili Konular

[[]]
[[]]

''',
      },
      {
        'name': 'Kitap Özeti',
        'category': 'Kişisel',
        'description': 'Okunan kitapları özetlemek için',
        'icon': '📖',
        'content': '''# Kitap Özeti

**Kitap Adı:** [[Kitap Adı]]
**Yazar:** [[Yazar Adı]]
**Okuma Tarihi:** [[Tarih]]
**Puan:** ⭐⭐⭐⭐⭐

## Kitap Hakkında

[[Kitap hakkında genel bilgi]]

## Ana Fikir

[[Kitabın ana fikri]]

## Önemli Alıntılar

> "[[Önemli alıntı 1]]"

> "[[Önemli alıntı 2]]"

> "[[Önemli alıntı 3]]"

## Karakterler (Eğer Roman ise)

| Karakter | Açıklama |
|----------|----------|
| | |
| | |

## Öğrendiklerim

- 
- 
- 

## Notlarım

[[Kişisel düşünceleriniz]]

## Tavsiye Ediyorum

[[Kime tavsiye edersiniz ve neden]]

## İlgili Kitaplar

[[]]
[[]]

''',
      },
      {
        'name': 'Günlük',
        'category': 'Kişisel',
        'description': 'Günlük yazmak için',
        'icon': '📔',
        'content': '''# Günlük

**Tarih:** [[Tarih]]
**Hava:** [[Hava Durumu]]
**Ruh Hali:** 😊 😐 😔

## Bugün Neler Oldu?

[[Günün önemli olayları]]

## Düşüncelerim

[[Günün düşünceleri]]

## Şükür Listesi

- Şükür ettiğim şey 1
- Şükür ettiğim şey 2
- Şükür ettiğim şey 3

## Yarınki Planlar

- [ ] 
- [ ] 
- [ ]

## İlham Veren Şey

[[Bugün sizi ne ilhamlandırdı]]

## Notlar

[[Ek notlar]]

''',
      },
      {
        'name': 'Yapılacaklar Listesi',
        'category': 'Kişisel',
        'description': 'Günlük görevler için',
        'icon': '✅',
        'content': '''# Yapılacaklar Listesi

**Tarih:** [[Tarih]]

## Öncelikli Görevler 🔴

- [ ] [[Önemli görev 1]]
- [ ] [[Önemli görev 2]]
- [ ] [[Önemli görev 3]]

## Normal Görevler 🟡

- [ ] [[Görev 1]]
- [ ] [[Görev 2]]
- [ ] [[Görev 3]]

## Düşük Öncelikli Görevler 🟢

- [ ] [[Düşük öncelikli görev 1]]
- [ ] [[Düşük öncelikli görev 2]]

## Tamamlandı ✅

- [x] [[Tamamlanan görev]]
- [x] [[Tamamlanan görev]]

## Notlar

[[Ek notlar]]

## Yarınki Planlar

- 
- 
- 

''',
      },
      {
        'name': 'Fikir Toplama',
        'category': 'Yaratıcılık',
        'description': 'Yeni fikirler geliştirmek için',
        'icon': '💡',
        'content': '''# Fikir Toplama

**Tarih:** [[Tarih]]
**Konu:** [[Ana Konu]]

## Ana Fikir

[[Ana fikriniz]]

## Alt Fikirler

### Fikir 1: [[Fikir Adı]]
**Açıklama:** [[Açıklama]]
**Avantajları:**
- 
- 
**Dezavantajları:**
- 
- 

### Fikir 2: [[Fikir Adı]]
**Açıklama:** [[Açıklama]]
**Avantajları:**
- 
- 
**Dezavantajları:**
- 
- 

## Beyin Fırtınası

- Fikir 1
- Fikir 2
- Fikir 3
- Fikir 4
- Fikir 5

## Kaynaklar

- [[Kaynak 1]]
- [[Kaynak 2]]

## İlgili Fikirler

[[]]
[[]]

## Sonraki Adımlar

- [ ] Fikri detaylandır
- [ ] Araştırma yap
- [ ] Prototip oluştur

''',
      },
      {
        'name': 'Seyahat Planı',
        'category': 'Kişisel',
        'description': 'Seyahatleri planlamak için',
        'icon': '✈️',
        'content': '''# Seyahat Planı

**Destinasyon:** [[Şehir/Ülke]]
**Tarihler:** [[Başlangıç]] - [[Bitiş]]
**Bütçe:** [[Bütçe]]

## Uçuş Bilgileri

**Gidiş:** [[Havayolu]] - [[Tarih]] - [[Saat]]
**Dönüş:** [[Havayolu]] - [[Tarih]] - [[Saat]]

## Konaklama

**Otel:** [[Otel Adı]]
**Adres:** [[Adres]]
**Check-in:** [[Tarih]]
**Check-out:** [[Tarih]]

## Güzergah

### Gün 1: [[Tarih]]
- Sabah: [[Plan]]
- Öğlen: [[Plan]]
- Akşam: [[Plan]]

### Gün 2: [[Tarih]]
- Sabah: [[Plan]]
- Öğlen: [[Plan]]
- Akşam: [[Plan]]

### Gün 3: [[Tarih]]
- Sabah: [[Plan]]
- Öğlen: [[Plan]]
- Akşam: [[Plan]]

## Paketleme Listesi

### Giyim
- [ ] 
- [ ] 
- [ ] 

### Belgeler
- [ ] Pasaport
- [ ] Biletler
- [ ] Otel rezervasyonu
- [ ] Sigorta

### Elektronik
- [ ] Telefon şarjı
- [ ] Kamera
- [ ] Adaptör

## Bütçe Detayı

| Kategori | Planlanan | Gerçekleşen |
|----------|-----------|-------------|
| Uçuş | | |
| Konaklama | | |
| Yemek | | |
| Ulaşım | | |
| Alışveriş | | |
| **Toplam** | | |

## İletişim

**Acil Durum:** [[Acil durum kişisi]]
**Otel:** [[Otel telefonu]]
**Konsolosluk:** [[Konsolosluk telefonu]]

## Notlar

[[Ek notlar]]

''',
      },
      {
        'name': 'Alışveriş Listesi',
        'category': 'Kişisel',
        'description': 'Alışveriş listesi için',
        'icon': '🛒',
        'content': '''# Alışveriş Listesi

**Tarih:** [[Tarih]]
**Bütçe:** [[Bütçe]]

## Gıda

### Meyve ve Sebzeler
- [ ] 
- [ ] 
- [ ] 

### Et ve Balık
- [ ] 
- [ ] 
- [ ] 

### Süt Ürünleri
- [ ] 
- [ ] 
- [ ] 

### Bakliyat ve Makarna
- [ ] 
- [ ] 
- [ ] 

### İçecekler
- [ ] 
- [ ] 
- [ ] 

## Temizlik

- [ ] 
- [ ] 
- [ ] 

## Kişisel Bakım

- [ ] 
- [ ] 
- [ ] 

## Ev Eşyaları

- [ ] 
- [ ] 
- [ ] 

## Notlar

[[Ek notlar]]

## Fiyat Karşılaştırması

| Ürün | Mağaza 1 | Mağaza 2 | Mağaza 3 |
|------|----------|----------|----------|
| | | | |

''',
      },
      {
        'name': 'Hedef Belirleme',
        'category': 'Kişisel Gelişim',
        'description': 'Hedefleri belirlemek ve takip etmek için',
        'icon': '🎯',
        'content': '''# Hedef Belirleme

**Tarih:** [[Tarih]]
**Periyot:** [[Haftalık/Aylık/Yıllık]]

## Ana Hedef

[[Bu periyottaki ana hedefiniz]]

## Alt Hedefler

### Hedef 1: [[Hedef Adı]]
**Açıklama:** [[Açıklama]]
**Bitiş Tarihi:** [[Tarih]]
**Ölçüm:** [[Nasıl ölçülecek]]
**Durum:** %0

**Adımlar:**
- [ ] Adım 1
- [ ] Adım 2
- [ ] Adım 3

### Hedef 2: [[Hedef Adı]]
**Açıklama:** [[Açıklama]]
**Bitiş Tarihi:** [[Tarih]]
**Ölçüm:** [[Nasıl ölçülecek]]
**Durum:** %0

**Adımlar:**
- [ ] Adım 1
- [ ] Adım 2
- [ ] Adım 3

### Hedef 3: [[Hedef Adı]]
**Açıklama:** [[Açıklama]]
**Bitiş Tarihi:** [[Tarih]]
**Ölçüm:** [[Nasıl ölçülecek]]
**Durum:** %0

**Adımlar:**
- [ ] Adım 1
- [ ] Adım 2
- [ ] Adım 3

## Günlük Alışkanlıklar

| Alışkanlık | Pzt | Sal | Çar | Per | Cum | Cmt | Paz |
|------------|-----|-----|-----|-----|-----|-----|-----|
| [[Alışkanlık 1]] | | | | | | | |
| [[Alışkanlık 2]] | | | | | | | |
| [[Alışkanlık 3]] | | | | | | | |

## Haftalık Değerlendirme

**Başarılar:**
- 
- 
- 

**Zorluklar:**
- 
- 
- 

## Ödüller

[[Hedeflere ulaştığında kendinize vereceğiniz ödüller]]

## Notlar

[[Ek notlar]]

''',
      },
      {
        'name': 'Problem Çözme',
        'category': 'İş',
        'description': 'Problemleri analiz etmek ve çözmek için',
        'icon': '🔧',
        'content': '''# Problem Çözme

**Tarih:** [[Tarih]]
**Problem:** [[Problem Açıklaması]]
**Öncelik:** 🔴 Yüksek / 🟡 Orta / 🟢 Düşük

## Problem Analizi

### Sorun Tanımı
[[Problemin net tanımı]]

### Etkilenen Alanlar
- [[Alan 1]]
- [[Alan 2]]
- [[Alan 3]]

### Olası Nedenler
1. [[Neden 1]]
2. [[Neden 2]]
3. [[Neden 3]]

## Çözüm Seçenekleri

### Seçenek 1: [[Seçenek Adı]]
**Avantajları:**
- 
- 
**Dezavantajları:**
- 
- 
**Maliyet:** [[Maliyet]]
**Zaman:** [[Zaman]]

### Seçenek 2: [[Seçenek Adı]]
**Avantajları:**
- 
- 
**Dezavantajları:**
- 
- 
**Maliyet:** [[Maliyet]]
**Zaman:** [[Zaman]]

### Seçenek 3: [[Seçenek Adı]]
**Avantajları:**
- 
- 
**Dezavantajları:**
- 
- 
**Maliyet:** [[Maliyet]]
**Zaman:** [[Zaman]]

## Karar

**Seçilen Çözüm:** [[Seçilen çözüm]]
**Gerekçe:** [[Neden bu çözüm seçildi]]

## Uygulama Planı

### Adım 1: [[Adım]]
**Sorumlu:** [[İsim]]
**Tarih:** [[Tarih]]
**Durum:** ⏳ Bekliyor

### Adım 2: [[Adım]]
**Sorumlu:** [[İsim]]
**Tarih:** [[Tarih]]
**Durum:** ⏳ Bekliyor

### Adım 3: [[Adım]]
**Sorumlu:** [[İsim]]
**Tarih:** [[Tarih]]
**Durum:** ⏳ Bekliyor

## Takip

**Başlangıç:** [[Tarih]]
**Bitiş:** [[Tarih]]
**Durum:** ⏳ Devam Ediyor / ✅ Tamamlandı / ❌ Başarısız

## Sonuç

[[Çözümün sonuçları]]

## Dersler

[[Bu problemden çıkarılan dersler]]

## İlgili Problemler

[[]]
[[]]

''',
      },
      {
        'name': 'Mülakat Hazırlığı',
        'category': 'Kariyer',
        'description': 'İş mülakatlarına hazırlık için',
        'icon': '💼',
        'content': '''# Mülakat Hazırlığı

**Şirket:** [[Şirket Adı]]
**Pozisyon:** [[Pozisyon]]
**Tarih:** [[Mülakat Tarihi]]
**Mülakatçı:** [[Mülakatçı Adı]]

## Şirket Araştırması

### Hakkında
[[Şirket hakkında bilgiler]]

### Değerler
- [[Değer 1]]
- [[Değer 2]]
- [[Değer 3]]

### Son Haberler
[[Şirketle ilgili son haberler]]

## Pozisyon Analizi

### Gereksinimler
- [[Gereksinim 1]]
- [[Gereksinim 2]]
- [[Gereksinim 3]]

### Sorumluluklar
- [[Sorumluluk 1]]
- [[Sorumluluk 2]]
- [[Sorumluluk 3]]

## Sıkça Sorulan Sorular

### Kendini Tanıt
**Cevap:** [[Hazırlanan cevap]]

### Bu Şirketi Neden Seçtin?
**Cevap:** [[Hazırlanan cevap]]

### En Güçlü/Yönünüz?
**Cevap:** [[Hazırlanan cevap]]

### En Zayıf Yönünüz?
**Cevap:** [[Hazırlanan cevap]]

### 5 Yıl Sonra Nerede Görmek İstiyorsun?
**Cevap:** [[Hazırlanan cevap]]

### Bu Pozisyondan Ayrılma Nedenin?
**Cevap:** [[Hazırlanan cevap]]

## Teknik Sorular

### Soru 1: [[Soru]]
**Cevap:** [[Cevap]]

### Soru 2: [[Soru]]
**Cevap:** [[Cevap]]

### Soru 3: [[Soru]]
**Cevap:** [[Cevap]]

## Sormak İstediğim Sorular

1. [[Soru 1]]
2. [[Soru 2]]
3. [[Soru 3]]

## Gerekli Belgeler

- [ ] CV
- [ ] Portfolyo
- [ ] Referanslar
- [ ] Sertifika

## Notlar

[[Ek notlar]]

## Değerlendirme

**Mülakat Sonucu:** ⏳ Bekleniyor / ✅ Olumlu / ❌ Olumsuz
**Geri Bildirim:** [[Geri bildirim]]

''',
      },
      {
        'name': 'Finans Takibi',
        'category': 'Kişisel',
        'description': 'Gelir ve gider takibi için',
        'icon': '💰',
        'content': '''# Finans Takibi

**Ay:** [[Ay Yıl]]
**Bütçe:** [[Aylık Bütçe]]

## Gelirler

| Kaynak | Planlanan | Gerçekleşen | Fark |
|--------|-----------|-------------|------|
| Maaş | | | |
| Ek Gelir 1 | | | |
| Ek Gelir 2 | | | |
| **Toplam Gelir** | | | |

## Giderler

### Zorunlu Giderler

| Kategori | Planlanan | Gerçekleşen | Fark |
|----------|-----------|-------------|------|
| Kira/Kredi | | | |
| Faturalar | | | |
| Sigorta | | | |
| Yakıt | | | |
| **Toplam Zorunlu** | | | |

### İsteğe Bağlı Giderler

| Kategori | Planlanan | Gerçekleşen | Fark |
|----------|-----------|-------------|------|
| Gıda | | | |
| Giyim | | | |
| Eğlence | | | |
| Sağlık | | | |
| Alışveriş | | | |
| **Toplam İsteğe Bağlı** | | | |

## Özet

| Kategori | Planlanan | Gerçekleşen | Fark |
|----------|-----------|-------------|------|
| Toplam Gelir | | | |
| Toplam Gider | | | |
| **Net Durum** | | | |

## Tasarruf Hedefleri

- [ ] **Acil Durum Fonu:** [[Hedef]] - [[Mevcut]]
- [ ] **Tatilik:** [[Hedef]] - [[Mevcut]]
- [ ] **Yatırım:** [[Hedef]] - [[Mevcut]]

## Yatırımlar

| Yatırım | Değer | Getiri |
|---------|-------|--------|
| | | |
| | | |

## Borçlar

| Borç | Miktar | Faiz | Aylık Ödeme |
|------|--------|------|-------------|
| | | | |
| | | | |

## Finansal Hedefler

### Kısa Vade (1-6 ay)
- [[Hedef 1]]
- [[Hedef 2]]

### Orta Vade (6-18 ay)
- [[Hedef 1]]
- [[Hedef 2]]

### Uzun Vade (18+ ay)
- [[Hedef 1]]
- [[Hedef 2]]

## Notlar

[[Ek notlar]]

## Gelecek Ay İçin Planlar

- [[Plan 1]]
- [[Plan 2]]

''',
      },
      {
        'name': 'Sağlık ve Fitness',
        'category': 'Kişisel Gelişim',
        'description': 'Sağlık ve fitness takibi için',
        'icon': '💪',
        'content:': '''# Sağlık ve Fitness

**Tarih:** [[Tarih]]
**Hafta:** [[Hafta Numarası]]

## Hedefler

- **Kilo:** [[Hedef Kilo]] - [[Mevcut Kilo]]
- **Yağ Oranı:** [[Hedef Yağ Oranı]]% - [[Mevcut Yağ Oranı]]%
- **Kas Oranı:** [[Hedef Kas Oranı]]% - [[Mevcut Kas Oranı]]%

## Beslenme

### Günlük Kalori Hedefi: [[Kalori]]

| Gün | Kalori | Protein | Karbonhidrat | Yağ | Su |
|-----|--------|---------|--------------|-----|----|
| Pzt | | | | | |
| Sal | | | | | |
| Çar | | | | | |
| Per | | | | | |
| Cum | | | | | |
| Cmt | | | | | |
| Paz | | | | | |

### Öğün Planı

**Kahvaltı:** [[Kahvaltı planı]]
**Öğle Yemeği:** [[Öğle yemeği planı]]
**Akşam Yemeği:** [[Akşam yemeği planı]]
**Ara Öğünler:** [[Ara öğünler]]

## Antrenman Programı

### Pazartesi - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Salı - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Çarşamba - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Perşembe - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Cuma - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Cumartesi - [[Bölge]]
- [[Egzersiz 1]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 2]]: [[Set]] x [[Tekrar]]
- [[Egzersiz 3]]: [[Set]] x [[Tekrar]]

### Pazar - Dinlenme

## Ölçümler

| Tarih | Kilo | Kol | Bel | Kalça | Göğüs |
|-------|------|-----|-----|-------|-------|
| [[Tarih 1]] | | | | | |
| [[Tarih 2]] | | | | | |
| [[Tarih 3]] | | | | | |

## İlerleme

### Bu Hafta Başarıları
- 
- 
- 

### Zorluklar
- 
- 
- 

## Gelecek Hafta Planı

- [[Plan 1]]
- [[Plan 2]]

## Notlar

[[Ek notlar]]

## İlaçlar ve Takviyeler

| İlaç/Takviye | Doz | Sıklık |
|---------------|-----|--------|
| | | |
| | | |

## Doktor Kontrolleri

- [[Kontrol 1]]: [[Tarih]]
- [[Kontrol 2]]: [[Tarih]]

''',
      },
    ];
  }

  static Future<List<Template>> getAllTemplates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'templates',
      orderBy: 'category ASC, name ASC',
    );
    return List.generate(maps.length, (i) => Template.fromMap(maps[i]));
  }

  static Future<List<Template>> getTemplatesByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'templates',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Template.fromMap(maps[i]));
  }

  static Future<Template?> getTemplateById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Template.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> insertTemplate(Template template) async {
    final db = await database;
    return await db.insert('templates', template.toMap());
  }

  static Future<int> updateTemplate(Template template) async {
    final db = await database;
    return await db.update(
      'templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  static Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.delete(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT category FROM templates ORDER BY category ASC',
    );
    return maps.map((map) => map['category'] as String).toList();
  }

  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

# GümüşNot Algoritma ve Mantık Dokümantasyonu

Bu belge, GümüşNot uygulamasının arkasındaki temel algoritmaları ve veri işleme mantıklarını açıklar.

## 1. Kuvvet Yönelimli Grafik Algoritması (Force-Directed Graph)
**Dosya:** `lib/screens/graph_view_screen.dart`

Bu algoritma, notları birbirine bağlı düğümler (node) olarak görselleştirir. Fizik tabanlı bir simülasyon kullanır.

### Mantık:
Her karede (frame) aşağıdaki kuvvetler hesaplanır ve düğüm pozisyonlarına uygulanır:

1.  **İtme Kuvveti (Repulsion):**
    *   Tüm düğümler birbirini iter.
    *   Formül: `F = k / d^2` (k: itme katsayısı, d: mesafe).
    *   Amaç: Düğümlerin üst üste binmesini engellemek.

2.  **Çekme Kuvveti (Attraction - Yay Kuvveti):**
    *   Sadece birbirine bağlı (linklenmiş) düğümler arasında oluşur.
    *   Formül: `F = c * (d - L)` (c: yay sabiti, d: mesafe, L: ideal uzunluk).
    *   Amaç: İlişkili notları birbirine yakın tutmak.

3.  **Merkezcil Kuvvet (Gravity):**
    *   Tüm düğümler hafifçe ekranın merkezine çekilir.
    *   Amaç: Grafiğin ekran dışına savrulmasını önlemek.

4.  **Sürtünme (Damping):**
    *   Her adımda hız belirli bir katsayıyla (örn. 0.9) çarpılır.
    *   Amaç: Sonsuz salınımı engelleyip sistemin durulmasını (stabilize) sağlamak.

## 2. PDF Dışa Aktarma Algoritması
**Dosya:** `lib/services/pdf_export_service.dart`

Markdown formatındaki düz metni analiz edip yapılandırılmış bir PDF belgesine dönüştürür.

### Adımlar:
1.  **Satır Ayrıştırma (Parsing):**
    *   Not içeriği satır satır (`\n`) bölünür.
2.  **Desen Eşleştirme (Pattern Matching):**
    *   `# ` ile başlayanlar -> **Başlık 1** (Büyük, Kalın Font)
    *   `## ` ile başlayanlar -> **Başlık 2** (Orta, Kalın Font)
    *   `- ` ile başlayanlar -> **Madde İşareti** (Bullet Point)
    *   Diğerleri -> **Paragraf**
3.  **Sayfa Oluşturma (Layout):**
    *   `pdf` paketi kullanılarak A4 sayfa yapısı, kenar boşlukları (margin) ve alt/üst bilgiler eklenir.
4.  **Dosya Yazma:**
    *   Oluşturulan binary veri `.pdf` uzantısıyla dosya sistemine kaydedilir.

## 3. Görev Çıkarımı ve Toplama (Task Hub)
**Dosya:** `lib/screens/task_hub_screen.dart`

Uygulama genelindeki yüzlerce notun içinden "yapılacakları" bulur.

### Algoritma:
1.  **Veri Çekme:** Veritabanındaki *tüm* notlar listelenir.
2.  **Regex Taraması:**
    *   Her notun içeriğinde `r'- \[ \] (.*)'` regex deseni aranır.
    *   Bu desen, `- [ ] ` ile başlayan (tamamlanmamış) satırları yakalar.
3.  **Nesneleştirme:**
    *   Bulunan her görev için bir `TaskItem` objesi oluşturulur (Görev metni + Kaynak Not referansı).
4.  **Listeleme:**
    *   Elde edilen liste ekranda gösterilir. Tıklanınca kaynak nota navigasyon sağlanır.

## 4. Backlink (Geri Bağlantı) Sistemi
**Dosya:** `lib/services/database_service.dart`

Notlar arasındaki `[[Başlık]]` şeklindeki bağlantıları yönetir.

### Kayıt Algoritması (Insert/Update):
1.  Bir not kaydedilirken, içeriği `r'\[\[([^\]]+)\]\]'` regex'i ile taranır.
2.  Eşleşen her "Bağlantı Metni" için:
    *   Veritabanında bu başlığa sahip bir not var mı diye bakılır.
    *   **Yoksa:** "Hayalet Not" (Ghost Note) olarak geçici bir kayıt veya taslak oluşturulur.
    *   **Varsa:** Mevcut notun ID'si alınır.
3.  `backlinks` tablosuna `source_id` (kaynak) ve `target_id` (hedef) olarak kaydedilir.

## 5. Okuma Süresi Tahmini
**Dosya:** `lib/widgets/note_card.dart`

Basit bir heuristik algoritma kullanır.

### Formül:
1.  Metin boşluklardan (`\s+`) bölünerek kelime sayısı (`WordCount`) bulunur.
2.  Ortalama bir insanın dakikada 200 kelime okuduğu varsayılır.
3.  `Süre = Tavan(WordCount / 200)` formülüyle dakika cinsinden süre hesaplanır.

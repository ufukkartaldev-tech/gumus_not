# GümüşNot - Akıllı ve Bağlantılı Not Defteri

GümüşNot, Zettelkasten metodolojisinden ilham alan, **local-first** (önce yerel) yaklaşımını benimseyen, çok platformlu ve son derece güvenli bir not alma ekosistemidir. Notlarınızı sadece birer metin yığını olmaktan çıkarıp, birbirine bağlı bir **Kişisel Bilgi Ağı (Personal Knowledge Graph)** haline getirir.

---

## 🚀 Öne Çıkan Özellikler

### 1. Bağlantılı Not Mimarisi (Zettelkasten)
*   **Çift Yönlü Bağlantılar**: `[[Not Başlığı]]` söz dizimi ile notlar arasında dinamik ilişkiler kurun.
*   **Grafik Görünümü (Graph View)**: Bilgi ağınızı interaktif bir harita üzerinde keşfedin.
*   **Hayalet Notlar (Ghost Nodes)**: Henüz oluşturulmamış ancak referans verilmiş notları grafikte gri halkalar olarak görün, tek tıkla hayata geçirin.

### 2. Gelişmiş Görev ve Arama Yönetimi
*   **Görev Merkezi (Task Hub)**: Tüm notlarınızdaki `- [ ]` görevlerini otomatik olarak tarar ve tek bir merkezden yönetmenizi sağlar. Görev durumunu değiştirdiğinizde kaynak not otomatik güncellenir.
*   **Gelişmiş Filtreleme**: Başlık, içerik, etiket ve tarih aralığına göre çok kriterli profesyonel arama motoru.
*   **SQL Konsolu**: Gelişmiş kullanıcılar için doğrudan veritabanı sorgulama imkanı.

### 3. Askeri Seviye Güvenlik (Private Vault)
*   **AES-256 Şifreleme**: Hassas notlarınız veritabanında şifreli olarak saklanır.
*   **Biyometrik Koruma**: Parmak izi ve yüz tanıma (FaceID/TouchID) desteği ile kasanıza güvenli erişim.
*   **Deterministik Kurtarma**: Güvenli ve matematiksel olarak doğrulanabilir şifre kurtarma mekanizması.

### 4. Profesyonel Editör ve Medya
*   **Zengin Markdown & LaTeX**: Karmaşık matematiksel formülleri ve zengin metinleri kolayca yazın.
*   **Çizim ve Eskiz**: Notlarınıza el yazısı notlar veya hızlı şemalar ekleyin.
*   **Dinamik Şablonlar**: Sık kullandığınız not formatları için hazır şablonlar oluşturun.
*   **Resim Desteği**: Kameradan veya galeriden görsel ekleme.

### 5. Esnek Dışa Aktarma (Export)
*   **Çoklu Format**: Notlarınızı PDF veya LaTeX formatında profesyonel çıktılara dönüştürün.
*   **Toplu Dışa Aktarma**: Birden fazla notu aynı anda farklı formatlarda paketleyin.

---

## 📱 Duyarlı Tasarım (Responsive Layout)

GümüşNot, ekran boyutuna göre çalışma alanını optimize eder:
*   **Masaüstü (Desktop)**: Not listesi, Editör ve Grafik/Bilgi panelleri ile 3 sütunlu tam verimlilik modu.
*   **Tablet**: Not listesi ve Editör odaklı 2 sütunlu yapı.
*   **Mobil**: Sayfa geçişli, odaklanmış tek sütunlu klasik mobil deneyimi.

---

## 🛠 Teknoloji Yığını

*   **UI Framework**: [Flutter](https://flutter.dev/) (Multi-platform)
*   **Veritabanı**: SQLite (`sqflite` & `sqflite_common_ffi`)
*   **Durum Yönetimi**: `Provider`
*   **Güvenlik**: `encrypt` (AES-256), `local_auth` (Biyometrik), `flutter_secure_storage`
*   **Render**: `flutter_markdown`, `flutter_math_fork`
*   **Grafik ve Görselleştirme**: `fl_chart`
*   **Dosya Yönetimi**: `pdf`, `printing`, `path_provider`, `archive`, `file_picker`
*   **Medya**: `image_picker`, `cached_network_image`, `signature`
*   **Cloud Sync**: `googleapis`, `googleapis_auth` (Geliştirme aşamasında)
*   **UI Bileşenleri**: `flutter_staggered_grid_view`, `flutter_colorpicker`

---

## ⚙️ Kurulum ve Çalıştırma

1. **Bağımlılıkları Yükleyin**:
   ```bash
   flutter pub get
   ```

2. **Masaüstü Önemli Not (Windows)**:
   SQLite kullanımı için Windows üzerinde gerekli DLL dosyalarının (sqlite3.dll) sistem yolunda veya proje dizininde olduğundan emin olun. Geliştirme ortamında `sqflite_common_ffi` bunu otomatik yönetir.

3. **Çalıştırın**:
   ```bash
   flutter run -d windows  # Windows için
   flutter run -d android   # Android için
   flutter run -d ios       # iOS için
   flutter run -d chrome   # Web (Deneysel) için
   flutter run -d linux    # Linux için
   flutter run -d macos    # macOS için
   ```

4. **Testleri Çalıştırın**:
   ```bash
   flutter test
   flutter test --coverage  # Kapsam raporu için
   ```

---

## 📉 Güncel Durum ve Notlar

### ✅ Tamamlanan Özellikler
*   **Temel Not Yönetimi**: Oluşturma, düzenleme, silme, arama
*   **Zettelkasten Bağlantıları**: Çift yönlü bağlantılar ve grafik görünümü
*   **Görev Merkezi**: Notlardaki görevleri otomatik tarama ve yönetme
*   **Şifreleme**: AES-256 ile not şifreleme ve biyometrik koruma
*   **Markdown ve LaTeX**: Zengin metin ve matematiksel formül desteği
*   **Çizim Özelliği**: El yazısı notlar ve şemalar
*   **Resim Desteği**: Kamera ve galeriden görsel ekleme
*   **PDF/LaTeX Export**: Profesyonel dışa aktarma imkanları
*   **Responsive Tasarım**: Masaüstü, tablet ve mobil uyumlu arayüz

### 🚧 Geliştirme Aşamasında
*   **Windows OCR**: Platform kütüphane uyumsuzlukları nedeniyle geçici olarak devre dışı
*   **Bulut Senkronizasyonu**: Google Drive entegrasyonu altyapısı hazır, mobil sürümlerde devam ediyor
*   **Sesli Not**: Ses kaydetme ve metne çevirme özelliği planlanıyor

### 🐋 Bilinen Sorunlar
*   **Web Platformu**: Bazı güvenlik özellikleri web'de kısıtlı çalışabilir
*   **Performans**: Çok büyük not veritabanlarında grafik görünümü yavaşlayabilir

---

## 🧪 Test ve Kalite

Proje, kapsamlı test stratejisi ile geliştirilmektedir:
*   **Unit Testler**: `flutter test` ile çalıştırılabilir
*   **Widget Testler**: UI bileşenlerinin doğrulanması
*   **Entegrasyon Testler**: Özellikler arası etkileşim testleri
*   **Kapsam Raporu**: `flutter test --coverage` ile detaylı analiz

Detaylı test raporları için `TEST_COVERAGE_REPORT.md` dosyasına bakabilirsiniz.

---

## � Ek Belgeler

Proje hakkında detaylı bilgi için aşağıdaki belgelere göz atabilirsiniz:

*   **[Özellik Yol Haritası](OZELLIK_YOLHARITASI.md)** - Geliştirme planı ve özellik detayları
*   **[Algoritma Dokümanı](ALGORITMA_DOKUMAN.md)** - Temel algoritmalar ve veri yapıları
*   **[Biyometrik Güvenlik](BIYOMETRIK_GUVENLIK.md)** - Şifreleme ve kimlik doğrulama sistemi
*   **[Çizim Özelliği](CIZIM_OZELLIGI.md)** - El yazısı ve çizim desteği
*   **[PDF Export](PDF_EXPORT.md)** - Dışa aktarma özellikleri
*   **[Resim Desteği](RESIM_DESTEGI.md)** - Görsel yönetimi ve optimizasyonu
*   **[Sesli Not](SESLI_NOT.md)** - Ses kaydetme özellikleri (planlanan)
*   **[OCR Özelliği](OCR_OZELLIGI.md)** - Metin tanıma sistemi
*   **[Kalite Raporları](KALITE_RAPORU.md)** - Kod kalitesi ve analiz sonuçları
*   **[Test Kapsamı](TEST_COVERAGE_REPORT.md)** - Detaylı test raporları

---

## 🤝 Katkıda Bulunma

Katkıda bulunmak isterseniz:
1.  Projeyi fork edin
2.  Yeni bir branch oluşturun (`git checkout -b feature/amazing-feature`)
3.  Değişikliklerinizi yapın ve commit edin
4.  Branch'inizi push edin (`git push origin feature/amazing-feature`)
5.  Bir Pull Request oluşturun

---

## �📄 Lisans

Bu proje **MIT Lisansı** altında korunmaktadır. Detaylar için `LICENSE` dosyasına bakabilirsiniz.

Copyright (c) 2026 Ufuk Kartal.


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
*   **Dosya Yönetimi**: `pdf`, `printing`, `path_provider`, `archive`

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
   flutter run -d chrome   # Web (Deneysel) için
   ```

---

## 📉 Güncel Durum ve Notlar
*   **Windows OCR**: Windows platformundaki kütüphane uyumsuzlukları nedeniyle OCR özelliği geçici olarak devre dışı bırakılmıştır.
*   **Bulut Senkronizasyonu**: Google Drive entegrasyonu altyapısı mevcuttur, mobil sürümlerde geliştirme aşamasındadır.

---

## 📄 Lisans

Bu proje **MIT Lisansı** altında korunmaktadır. Detaylar için `LICENSE` dosyasına bakabilirsiniz.

Copyright (c) 2026 Ufuk Kartal.


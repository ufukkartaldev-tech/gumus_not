# Bağlantılı Düşünce Not Defteri - Sistem Analiz Raporu

## 1. Sistem Özeti
Proje, **Flutter** ile geliştirilmiş, yerel (offline-first) çalışan, gelişmiş bir not alma uygulamasıdır. Öne çıkan özellikleri:
*   **Bağlantılı Notlar (Zettelkasten)**: `[[WikiLink]]` formatı ile notlar arası bağlantı.
*   **Grafik Görünümü**: Notlar arasındaki ilişkilerin görselleştirilmesi.
*   **Şifreli Kasa**: AES-256 ile şifrelenmiş özel notlar (`EncryptionService`).
*   **Markdown & LaTeX**: Matematiksel formül ve zengin metin desteği.
*   **Veritabanı**: SQLite (`sqflite`) tabanlı yerel depolama.

## 2. Yapılan Düzeltmeler

### A. Windows Başlatma Hatası (Kritik)
*   **Sorun**: Windows gibi masaüstü platformlarda `sqflite` başlatılırken `sqfliteFfiInit()` çağrısı eksikti. Bu, uygulamanın veritabanına erişmeye çalışırken çökmesine neden olurdu.
*   **Düzeltme**: `lib/main.dart` dosyasına gerekli başlatma kodu eklendi.

### B. Şifre Kurtarma Mantığı Hatası
*   **Sorun**: `EncryptionService` içindeki `verifyRecoveryKey` ve `_generateRecoveryKey` metodları `DateTime.now()` (anlık zaman) bilgisini hashing işlemine dahil ediyordu. Bu, oluşturulan bir kurtarma anahtarının asla doğrulanamamasına (çünkü doğrulama anındaki zaman farklı olacağından) neden oluyordu.
*   **Düzeltme**: Hashing işlemi deterministik hale getirildi (sabit bir 'salt' kullanılarak). Artık oluşturulan anahtar matematiksel olarak doğrulanabilir.
*   *Not*: Mevcut mimaride "Kurtarma Anahtarı" aslında şifrenin bir yinelemesidir. Gerçek bir unutuılan şifre kurtarma senaryosu için mimari değişikliği önerilmektedir (Bkz. Gelecek Özellikler).

### C. Windows OCR Uyumluluk Sorunu
*   **Sorun**: `google_mlkit_text_recognition` kütüphanesi Windows'u desteklemediği için derleme ve çalışma hatalarına yol açıyordu.
*   **Düzeltme**: OCR özelliği ve ilgili kütüphane Windows kararlılığı için geçici olarak projeden kaldırıldı.


## 3. Gelecek Özellik Önerileri

### 🚀 Kısa Vadeli
1.  **Hayalet Notlar (Ghost Nodes)**: (TAMAMLANDI) Grafik görünümünde, henüz oluşturulmamış ancak referans verilen notların (örn. `[[Daha Yazılmadı]]`) silik ve farklı bir renkte (gri) gösterilmesi. Bu, eksik halkaları görmeyi kolaylaştırır ve tıklanarak oluşturulabilir.
2.  **Latex/PDF Dışa Aktarma**: `lib/services/latex_export_service.dart` mevcut ancak arayüzde aktif değil. Bu özelliğin tamamlanması.
3.  **Etiket Yönetimi**: Etiketleri toplu yeniden adlandırma veya silme ekranı.

### 🛠 Teknik & Orta Vadeli
4.  **Güvenli Kurtarma Mimarisi**: Şu anki `verifyRecoveryKey` sadece şifrenin hash'ini kontrol eder. Gerçek bir kurtarma için, Ana Anahtar'ın (Master Key) rastgele oluşturulması ve bu anahtarın hem Şifre hem de Kurtarma Anahtarı ile ayrı ayrı şifrelenerek saklanması gerekir.
5.  **Tam Metin Arama (FTS5)**: Mevcut `LIKE` sorgusu yerine SQLite FTS5 modülü ile çok daha hızlı ve hataya dayanıklı arama.

### ☁️ Uzun Vadeli
6.  **Bulut Senkronizasyonu**: `googleapis` kütüphanesi projeye eklenmiş ancak entegre edilmemiş. Google Drive üzerinden şifreli yedekleme ve senkronizasyon.
7.  **Mobil & Masaüstü Düzen Uyumu**: (TAMAMLANDI) Masaüstü için 3 panelli (Liste | Editör | Graf), tablet için 2 panelli (Liste | Editör), mobil için tek sütunlu akış görünümü eklendi.

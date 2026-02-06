# GümüşNot - Bağlantılı Düşünce Not Defteri

Bu proje, Zettelkasten metodolojisinden esinlenerek geliştirilmiş, **local‑first**, çok platformlu ve güvenli bir not alma uygulamasıdır. Notlarınızı birbirine bağlayarak kişisel bilgi grafiği oluşturmanıza, gelişmiş arama ve görselleştirme ile bu ağı keşfetmenize olanak tanır.

## Özellikler

### 1. Bağlantılı Not Alma (Zettelkasten)
Notlar arasında ilişki kurmak için `[[Not Başlığı]]` formatını kullanabilirsiniz. Bu sayede doğrusal olmayan, ağ yapısında bir bilgi tabanı oluşturabilirsiniz.

### 2. Görsel Harita (Graph View)
Tüm notlarınız ve aralarındaki bağlantılar interaktif bir grafik üzerinde görselleştirilir.
- **Merkez Notlar**: Çok sayıda bağlantısı olan notlar daha büyük ve belirgin gösterilir.
- **Hayalet Notlar (Ghost Nodes)**: Henüz oluşturmadığınız ancak referans verdiğiniz notlar, grafiğin dış çeperinde silik olarak gösterilir. Bunlara tıklayarak hızlıca yeni not oluşturabilirsiniz.

### 3. Gizli Kasa (Private Vault)
Hassas verileriniz ve özel projeleriniz için AES‑256 standardında şifreleme sunan özel bir bölüm bulunur. Bu bölümdeki notlar veritabanında şifreli olarak saklanır ve sadece belirlediğiniz kasa şifresiyle (ve isteğe bağlı biyometrik doğrulama ile) açılabilir.

### 4. Duyarlı Tasarım (Responsive Layout)
Uygulama, çalıştığı cihaza göre arayüzünü otomatik olarak optimize eder:
- **Masaüstü**: Not listesi, editör ve grafik görünümü şeklinde 3 panelli yapı.
- **Tablet**: Not listesi ve editör şeklinde 2 panelli yapı.
- **Mobil**: Tek sütunlu, sayfa geçişli klasik yapı.

### 5. Gelişmiş Editör
- Markdown desteği.
- LaTeX ile matematiksel formül yazımı.
- Kod blokları ve söz dizimi vurgulama.
- **Resim desteği**: Galeriden veya kamera ile resim ekleme.
- **Biyometrik güvenlik**: Parmak izi ve yüz tanıma ile gizli kasa erişimi (local_auth 3.0.0 ile uyumlu).
- **Çizim/Eskiz**: Notlara el yazısı ve çizim ekleme (signature tabanlı tuval).
- **PDF / LaTeX dışa aktarma**: Notları profesyonel PDF veya LaTeX çıktısına dönüştürme.

> Not: OCR ve sesli not desteği mimari olarak planlanmış olup, masaüstü kararlılığı için varsayılan Windows build’inde devre dışı bırakılmıştır.

## Kurulum ve Çalıştırma

Proje Flutter ile geliştirilmiştir. Çalıştırmak için aşağıdaki adımları izleyin:

1. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```

2. Uygulamayı çalıştırın (örn. Windows için):
   ```bash
   flutter run -d windows
   ```

Mobil veya diğer masaüstü platformları için uygun cihaz/hedef seçilerek aynı komut kullanılabilir.

## Mimari ve Teknoloji Yığını

- **Flutter**: UI framework (çok platformlu – mobil ve masaüstü).
- **SQLite (sqflite / sqflite_common_ffi)**: Yerel veritabanı, offline‑first mimari.
- **Provider**: Durum yönetimi (state management) ve reaktif UI.
- **AES‑256 / crypto + encrypt**: Simetrik şifreleme ve güvenli kasa yapısı.
- **local_auth + flutter_secure_storage**: Biyometrik kimlik doğrulama ve güvenli şifre saklama.
- **flutter_markdown + flutter_math_fork**: Markdown ve LaTeX render.
- **pdf + printing**: PDF üretimi ve çıktı alma.
- **file_picker, image_picker, path_provider**: Dosya sistemi ve medya entegrasyonları.

Kod yapısı; `models`, `services`, `providers`, `screens` ve `widgets` klasörleriyle katmanlı bir şekilde organize edilmiştir. Şifreleme, veritabanı erişimi, arama, PDF/LaTeX export ve biyometrik doğrulama gibi sorumluluklar ayrı servisler üzerinden yönetilir.

## Lisans

Bu proje MIT Lisansi (MIT License) altinda lisanslanmistir. Detaylar icin asagidaki metni inceleyebilirsiniz.

```text
MIT License

Copyright (c) 2026 Ufuk Kartal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

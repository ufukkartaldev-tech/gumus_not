# 📸 Resim Desteği - Kullanım Kılavuzu

GümüşNot artık notlarınıza resim ekleme özelliğine sahip! 🎉

## ✨ Özellikler

### 1. Resim Ekleme Yöntemleri

#### 📱 Galeriden Seç
- Cihazınızdaki mevcut fotoğrafları seçin
- Otomatik boyutlandırma (max 1920x1920)
- Kalite optimizasyonu (%85)

#### 📷 Kamera ile Çek
- Anında fotoğraf çekin
- Doğrudan nota ekleyin

### 2. Resim Yönetimi

#### 💾 Otomatik Kaydetme
- Resimler `images/` klasörüne kaydedilir
- Benzersiz dosya adları (timestamp)
- Güvenli dosya yönetimi

#### 🎨 Görsel İyileştirmeler
- Yuvarlatılmış köşeler (border-radius: 12px)
- Gölge efekti
- Loading indicator
- Hata durumunda kullanıcı dostu mesajlar

### 3. Markdown Formatı

```markdown
![Resim Açıklaması](resim_yolu.jpg)
```

## 🚀 Nasıl Kullanılır?

### Adım 1: Editörü Açın
Yeni bir not oluşturun veya mevcut notu düzenleyin.

### Adım 2: Resim Butonuna Tıklayın
Alt toolbar'da resim ikonuna (📷) tıklayın.

### Adım 3: Kaynak Seçin
- **Galeriden Seç**: Mevcut fotoğraflarınızdan seçin
- **Kamera ile Çek**: Yeni fotoğraf çekin

### Adım 4: Resmi Ekleyin
Resim otomatik olarak notunuza eklenir!

## 📝 Örnek Kullanım

```markdown
# Proje Toplantısı Notları

Bugünkü toplantıda aşağıdaki konular görüşüldü:

![Whiteboard Fotoğrafı](images/img_1738584022000.jpg)

## Kararlar
- [ ] Tasarım mockup'ları hazırlanacak
- [ ] Backend API dokümantasyonu güncellenecek

![Ekip Fotoğrafı](images/img_1738584055000.jpg)
```

## 🎯 Gelişmiş Özellikler

### Resim Temizleme
Kullanılmayan resimleri otomatik temizleme:

```dart
// Tüm notlardaki kullanılan resimleri topla
final usedImages = allNotes
    .map((note) => ImageService.extractImagePaths(note.content))
    .expand((paths) => paths)
    .toList();

// Kullanılmayanları sil
await ImageService.cleanupUnusedImages(usedImages);
```

### Toplam Boyut Kontrolü
```dart
final totalSize = await ImageService.getTotalImageSize();
print('Toplam resim boyutu: ${totalSize / 1024 / 1024} MB');
```

## 🔧 Teknik Detaylar

### Desteklenen Formatlar
- JPG/JPEG
- PNG
- GIF
- WebP
- BMP

### Boyut Limitleri
- Maksimum genişlik: 1920px
- Maksimum yükseklik: 1920px
- Kalite: %85 (boyut optimizasyonu için)

### Depolama Konumu
```
[Uygulama Dizini]/images/
├── img_1738584022000.jpg
├── img_1738584055000.png
└── img_1738584088000.jpg
```

## 💡 İpuçları

### 1. Resim Kalitesi
Yüksek çözünürlüklü fotoğraflar otomatik olarak optimize edilir.

### 2. Hızlı Ekleme
Kamera kısayolu ile anında fotoğraf çekip ekleyin.

### 3. Düzenleme
Markdown formatında resim yolunu değiştirerek farklı resimler kullanabilirsiniz.

### 4. Yedekleme
Resimler uygulama dizininde saklanır, yedekleme yaparken `images/` klasörünü dahil edin.

## 🐛 Sorun Giderme

### Resim Görünmüyor
1. Dosya yolunun doğru olduğundan emin olun
2. Resim dosyasının hala mevcut olduğunu kontrol edin
3. Dosya izinlerini kontrol edin

### Kamera Çalışmıyor
1. Uygulama izinlerini kontrol edin
2. Cihaz kamerasının çalıştığından emin olun

### Galeri Açılmıyor
1. Galeri erişim iznini kontrol edin
2. Cihazda galeri uygulamasının yüklü olduğundan emin olun

## 🎨 Gelecek Özellikler

- [ ] Resim düzenleme (kırpma, döndürme)
- [ ] Resim sıkıştırma seçenekleri
- [ ] Toplu resim ekleme
- [ ] Resim galerisi görünümü
- [ ] Resim arama ve filtreleme
- [ ] OCR (resimden metin çıkarma)
- [ ] Resim etiketleme

## 📊 Performans

- **Resim yükleme**: ~100-300ms
- **Kaydetme**: ~50-150ms
- **Önizleme**: Anında
- **Bellek kullanımı**: Optimize edilmiş

## 🔒 Güvenlik

- Resimler yerel olarak saklanır
- Şifreli notlardaki resimler korunur
- Otomatik temizleme ile gereksiz dosyalar silinir

---

**GümüşNot ile görsel notlar almaya başlayın!** 📸✨

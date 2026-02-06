import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Resim yönetimi için servis sınıfı
/// Resimleri seçme, kaydetme ve yönetme işlemlerini yapar
class ImageService {
  static final ImagePicker _picker = ImagePicker();
  
  /// Galeriden resim seç
  /// Dosyadan resim kaydet (Çizim vb. için)
  static Future<String?> saveImageFile(File file) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'images');
      
      final Directory dir = Directory(imagesDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String fileName = 'draw_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = path.join(imagesDir, fileName);

      await file.copy(filePath);
      
      return filePath;
    } catch (e) {
      debugPrint('Resim kaydetme hatası: $e');
      return null;
    }
  }

  static Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImage(image);
      }
      return null;
    } catch (e) {
      debugPrint('Galeri hatası: $e');
      return null;
    }
  }
  
  /// Kameradan resim çek
  static Future<String?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImage(image);
      }
      return null;
    } catch (e) {
      debugPrint('Kamera hatası: $e');
      return null;
    }
  }
  
  /// Resmi uygulama dizinine kaydet
  static Future<String> _saveImage(XFile image) async {
    try {
      // Uygulama doküman dizinini al
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'images');
      
      // Images klasörünü oluştur (yoksa)
      final Directory imageDirectory = Directory(imagesDir);
      if (!await imageDirectory.exists()) {
        await imageDirectory.create(recursive: true);
      }
      
      // Benzersiz dosya adı oluştur
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(image.path);
      final String fileName = 'img_$timestamp$extension';
      final String filePath = path.join(imagesDir, fileName);
      
      // Resmi kopyala
      final File sourceFile = File(image.path);
      await sourceFile.copy(filePath);
      
      debugPrint('Resim kaydedildi: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Resim kaydetme hatası: $e');
      rethrow;
    }
  }
  
  /// Resmi sil
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
        debugPrint('Resim silindi: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Resim silme hatası: $e');
      return false;
    }
  }
  
  /// Not içeriğindeki tüm resim yollarını bul
  static List<String> extractImagePaths(String content) {
    final RegExp imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final Iterable<RegExpMatch> matches = imageRegex.allMatches(content);
    
    return matches
        .map((match) => match.group(1))
        .where((path) => path != null && path.isNotEmpty)
        .cast<String>()
        .toList();
  }
  
  /// Markdown formatında resim linki oluştur
  static String createMarkdownImageLink(String imagePath, {String? altText}) {
    final String alt = altText ?? 'Resim';
    return '![$alt]($imagePath)';
  }
  
  /// Resmin var olup olmadığını kontrol et
  static Future<bool> imageExists(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      return await imageFile.exists();
    } catch (e) {
      return false;
    }
  }
  
  /// Tüm resimlerin toplam boyutunu hesapla
  static Future<int> getTotalImageSize() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'images');
      final Directory imageDirectory = Directory(imagesDir);
      
      if (!await imageDirectory.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (final FileSystemEntity entity in imageDirectory.list()) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Boyut hesaplama hatası: $e');
      return 0;
    }
  }
  
  /// Kullanılmayan resimleri temizle
  static Future<int> cleanupUnusedImages(List<String> usedImagePaths) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'images');
      final Directory imageDirectory = Directory(imagesDir);
      
      if (!await imageDirectory.exists()) {
        return 0;
      }
      
      int deletedCount = 0;
      await for (final FileSystemEntity entity in imageDirectory.list()) {
        if (entity is File) {
          if (!usedImagePaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      debugPrint('$deletedCount kullanılmayan resim silindi');
      return deletedCount;
    } catch (e) {
      debugPrint('Temizleme hatası: $e');
      return 0;
    }
  }
}

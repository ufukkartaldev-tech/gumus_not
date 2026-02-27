import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling image operations
/// Follows Single Responsibility Principle: Only handles image-related operations
class ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick image from gallery
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Limit image size
        maxHeight: 1080,
        imageQuality: 85, // Compress slightly
      );

      if (pickedFile != null) {
        return await _saveImageToAppDirectory(pickedFile);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await _saveImageToAppDirectory(pickedFile);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  /// Save image to app's private directory
  Future<String> _saveImageToAppDirectory(XFile imageFile) async {
    try {
      // Get app's documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory(path.join(appDir.path, 'images'));
      
      // Create images directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final String savedImagePath = path.join(imagesDir.path, fileName);

      // Copy image to app directory
      final File savedImage = await File(imageFile.path).copy(savedImagePath);
      
      return savedImage.path;
    } catch (e) {
      print('Error saving image: $e');
      rethrow;
    }
  }

  /// Get image file size in MB
  Future<double> getImageFileSize(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final int bytes = await imageFile.length();
      return bytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      print('Error getting image file size: $e');
      return 0.0;
    }
  }

  /// Delete image file
  Future<bool> deleteImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Check if image exists
  Future<bool> imageExists(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      return await imageFile.exists();
    } catch (e) {
      print('Error checking if image exists: $e');
      return false;
    }
  }

  /// Get all images in app directory
  Future<List<String>> getAllImages() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory(path.join(appDir.path, 'images'));
      
      if (!await imagesDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await imagesDir.list().toList();
      final List<String> imagePaths = files
          .where((file) => file is File && _isImageFile(file.path))
          .map((file) => file.path)
          .toList();

      return imagePaths;
    } catch (e) {
      print('Error getting all images: $e');
      return [];
    }
  }

  /// Clean up unused images (not referenced in any note)
  Future<void> cleanupUnusedImages(List<String> referencedImagePaths) async {
    try {
      final allImages = await getAllImages();
      
      for (final imagePath in allImages) {
        if (!referencedImagePaths.contains(imagePath)) {
          await deleteImage(imagePath);
        }
      }
    } catch (e) {
      print('Error cleaning up unused images: $e');
    }
  }

  /// Get total size of all images in MB
  Future<double> getTotalImagesSize() async {
    try {
      final allImages = await getAllImages();
      double totalSize = 0.0;

      for (final imagePath in allImages) {
        totalSize += await getImageFileSize(imagePath);
      }

      return totalSize;
    } catch (e) {
      print('Error getting total images size: $e');
      return 0.0;
    }
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String filePath) {
    final String extension = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension);
  }

  /// Get image metadata
  Future<Map<String, dynamic>> getImageMetadata(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Stat stat = await imageFile.stat();
      
      return {
        'path': imagePath,
        'fileName': path.basename(imagePath),
        'size': await getImageFileSize(imagePath),
        'createdAt': stat.modified.toIso8601String(),
        'extension': path.extension(imagePath),
      };
    } catch (e) {
      print('Error getting image metadata: $e');
      return {};
    }
  }

  /// Compress image if too large
  Future<String?> compressImage(String imagePath, {double maxSizeMB = 5.0}) async {
    try {
      final double currentSize = await getImageFileSize(imagePath);
      
      if (currentSize <= maxSizeMB) {
        return imagePath; // No compression needed
      }

      // For now, we'll just return the original image
      // In a real implementation, you might use image package to compress
      print('Image is too large (${currentSize.toStringAsFixed(2)}MB), but compression not implemented yet');
      return imagePath;
    } catch (e) {
      print('Error compressing image: $e');
      return imagePath;
    }
  }

  /// Export images to a directory
  Future<void> exportImages(String exportDirectory) async {
    try {
      final allImages = await getAllImages();
      final Directory exportDir = Directory(exportDirectory);
      
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      for (final imagePath in allImages) {
        final File imageFile = File(imagePath);
        final String fileName = path.basename(imagePath);
        final String exportPath = path.join(exportDirectory, fileName);
        
        await imageFile.copy(exportPath);
      }
    } catch (e) {
      print('Error exporting images: $e');
    }
  }
}

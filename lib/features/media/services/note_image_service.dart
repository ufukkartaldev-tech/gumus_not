import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/image_service.dart';
import '../widgets/image_picker_widget.dart';

/// Service for integrating images with notes
/// Follows Single Responsibility Principle: Only handles note-image integration
class NoteImageService {
  final ImageService _imageService = ImageService();

  /// Extract image paths from note content
  List<String> extractImagePaths(String content) {
    final RegExp imageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    final matches = imageRegex.allMatches(content);
    
    return matches.map((match) => match.group(2)!).toList();
  }

  /// Add image markdown to note content
  String addImageToContent(String content, String imagePath, {String? altText}) {
    final String fileName = imagePath.split('/').last;
    final String alt = altText ?? fileName;
    final String imageMarkdown = '![$alt]($imagePath)';
    
    if (content.isEmpty) {
      return imageMarkdown;
    }
    
    return '$content\n\n$imageMarkdown';
  }

  /// Remove image from note content
  String removeImageFromContent(String content, String imagePath) {
    final RegExp imageRegex = RegExp(r'!\[([^\]]*)\]\(' + RegExp.escape(imagePath) + r'\)');
    return content.replaceAll(imageRegex, '').replaceAll(RegExp(r'\n\n\n'), '\n\n').trim();
  }

  /// Update image references when note content changes
  Future<List<String>> updateImageReferences(Note note) async {
    final currentImagePaths = extractImagePaths(note.content);
    return currentImagePaths;
  }

  /// Clean up unused images from all notes
  Future<void> cleanupUnusedImages(List<Note> allNotes) async {
    final Set<String> referencedImages = <String>{};
    
    for (final note in allNotes) {
      final imagePaths = extractImagePaths(note.content);
      referencedImages.addAll(imagePaths);
    }
    
    await _imageService.cleanupUnusedImages(referencedImages.toList());
  }

  /// Get image statistics for all notes
  Future<Map<String, dynamic>> getImageStatistics(List<Note> allNotes) async {
    final Set<String> allReferencedImages = <String>{};
    int totalImages = 0;
    
    for (final note in allNotes) {
      final imagePaths = extractImagePaths(note.content);
      allReferencedImages.addAll(imagePaths);
      totalImages += imagePaths.length;
    }
    
    final double totalSize = await _imageService.getTotalImagesSize();
    final List<String> allImages = await _imageService.getAllImages();
    final int unusedImages = allImages.length - allReferencedImages.length;
    
    return {
      'totalImages': totalImages,
      'uniqueImages': allReferencedImages.length,
      'unusedImages': unusedImages,
      'totalSizeMB': totalSize,
      'averageSizeMB': totalImages > 0 ? totalSize / totalImages : 0.0,
    };
  }

  /// Validate image paths in note content
  Future<List<String>> validateImagePaths(String content) async {
    final imagePaths = extractImagePaths(content);
    final List<String> invalidPaths = [];
    
    for (final imagePath in imagePaths) {
      if (!await _imageService.imageExists(imagePath)) {
        invalidPaths.add(imagePath);
      }
    }
    
    return invalidPaths;
  }

  /// Fix broken image references in note content
  Future<String> fixBrokenImageReferences(String content) async {
    final invalidPaths = await validateImagePaths(content);
    String fixedContent = content;
    
    for (final invalidPath in invalidPaths) {
      fixedContent = removeImageFromContent(fixedContent, invalidPath);
    }
    
    return fixedContent;
  }

  /// Export images with notes
  Future<void> exportImagesWithNotes(List<Note> notes, String exportDirectory) async {
    final Set<String> uniqueImages = <String>{};
    
    for (final note in notes) {
      final imagePaths = extractImagePaths(note.content);
      uniqueImages.addAll(imagePaths);
    }
    
    // Create images subdirectory in export directory
    final imagesExportDir = '$exportDirectory/images';
    
    // Copy each unique image
    for (final imagePath in uniqueImages) {
      try {
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final String fileName = imagePath.split('/').last;
          final String exportPath = '$imagesExportDir/$fileName';
          await imageFile.copy(exportPath);
        }
      } catch (e) {
        print('Error exporting image $imagePath: $e');
      }
    }
  }

  /// Import images from backup
  Future<List<String>> importImages(String importDirectory) async {
    final List<String> importedPaths = [];
    
    try {
      final Directory importDir = Directory(importDirectory);
      if (!await importDir.exists()) {
        return importedPaths;
      }
      
      final List<FileSystemEntity> files = await importDir.list().toList();
      
      for (final file in files) {
        if (file is File && _isImageFile(file.path)) {
          try {
            final String newPath = await _imageService._saveImageToAppDirectory(
              XFile(file.path),
            );
            importedPaths.add(newPath);
          } catch (e) {
            print('Error importing image ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      print('Error importing images from directory: $e');
    }
    
    return importedPaths;
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String filePath) {
    final String extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  /// Get image preview URL (for web or remote images)
  String? getImagePreviewUrl(String imagePath) {
    // For local files, return the path as-is
    // In a web implementation, this might return a URL
    return imagePath;
  }

  /// Compress all images in notes
  Future<Map<String, String>> compressNoteImages(List<Note> notes) async {
    final Map<String, String> pathMappings = <String, String>{};
    
    for (final note in notes) {
      final imagePaths = extractImagePaths(note.content);
      
      for (final imagePath in imagePaths) {
        try {
          final String? compressedPath = await _imageService.compressImage(imagePath);
          if (compressedPath != null && compressedPath != imagePath) {
            pathMappings[imagePath] = compressedPath;
          }
        } catch (e) {
          print('Error compressing image $imagePath: $e');
        }
      }
    }
    
    return pathMappings;
  }

  /// Update note content with compressed image paths
  String updateContentWithCompressedImages(String content, Map<String, String> pathMappings) {
    String updatedContent = content;
    
    for (final entry in pathMappings.entries) {
      updatedContent = updatedContent.replaceAll(entry.key, entry.value);
    }
    
    return updatedContent;
  }
}

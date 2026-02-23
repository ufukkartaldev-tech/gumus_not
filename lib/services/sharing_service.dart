import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/database_service.dart';

class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  final DatabaseService _dbService = DatabaseService();
  StreamSubscription? _subscription;

  void initialize(BuildContext context) {
    // Uygulama açıldığında paylaşım verilerini kontrol et
    _getInitialSharedData(context);
    
    // Paylaşım dinleyicisini başlat
    _subscription = ReceiveSharingIntent.getMediaStream().listen((value) {
      _handleSharedData(value, context);
    }, onError: (err) {
      print("Paylaşım dinleyici hatası: $err");
    });
  }

  Future<void> _getInitialSharedData(BuildContext context) async {
    try {
      final sharedData = await ReceiveSharingIntent.getInitialMedia();
      if (sharedData.isNotEmpty) {
        _handleSharedData(sharedData, context);
      }

      final sharedText = await ReceiveSharingIntent.getInitialText();
      if (sharedText != null) {
        _handleSharedText(sharedText, context);
      }
    } catch (e) {
      print("Başlangıç paylaşım verisi okuma hatası: $e");
    }
  }

  void _handleSharedData(List<SharedMediaFile> sharedFiles, BuildContext context) {
    for (final file in sharedFiles) {
      _createNoteFromSharedFile(file, context);
    }
  }

  void _handleSharedText(String sharedText, BuildContext context) {
    _createNoteFromSharedText(sharedText, context);
  }

  Future<void> _createNoteFromSharedFile(SharedMediaFile file, BuildContext context) async {
    try {
      final now = DateTime.now();
      final note = Note(
        title: 'Paylaşılan: ${file.path.split('/').last}',
        content: '''Paylaşılan Dosya: ${file.path}
Tür: ${file.type}
Tarih: ${now.toString().substring(0, 19)}

Dosya hakkında notlarınızı buraya ekleyin...''',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        tags: ['paylaşılan', 'dosya'],
        folderName: 'Gelen',
      );

      await _dbService.insertNote(note);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${file.path.split('/').last}" not olarak kaydedildi'),
          action: SnackBarAction(
            label: 'Aç',
            onPressed: () {
              // Not detay sayfasına yönlendir
              Navigator.pushNamed(context, '/note', arguments: note);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Dosya kaydedilemedi: $e')),
      );
    }
  }

  Future<void> _createNoteFromSharedText(String sharedText, BuildContext context) async {
    try {
      final now = DateTime.now();
      
      // Metin türünü analiz et ve başlık/etiketler belirle
      String title = 'Paylaşılan Metin';
      List<String> tags = ['paylaşılan', 'metin'];
      
      if (sharedText.contains('http')) {
        title = 'Paylaşılan Link';
        tags.add('link');
      } else if (sharedText.length > 500) {
        title = 'Paylaşılan Makale';
        tags.add('makale');
      }

      final note = Note(
        title: title,
        content: '''$sharedText

---
Paylaşım Tarihi: ${now.toString().substring(0, 19)}
Kaynak: Paylaşım Menüsü''',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        tags: tags,
        folderName: 'Gelen',
      );

      await _dbService.insertNote(note);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "$title" not olarak kaydedildi'),
          action: SnackBarAction(
            label: 'Aç',
            onPressed: () {
              Navigator.pushNamed(context, '/note', arguments: note);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Metin kaydedilemedi: $e')),
      );
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

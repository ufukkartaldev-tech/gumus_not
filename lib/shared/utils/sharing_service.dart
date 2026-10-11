import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';

/// Dış uygulamalardan paylaşılan veri modeli
class SharedContent {
  final String? text;
  final List<String> filePaths;
  final String? title;

  const SharedContent({
    this.text,
    this.filePaths = const [],
    this.title,
  });

  bool get isEmpty => (text == null || text!.trim().isEmpty) && filePaths.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() => 'SharedContent(text: $text, filePaths: $filePaths, title: $title)';
}

typedef SharedContentCallback = void Function(SharedContent content);

/// Mobil platformlarda dış uygulamalardan gelen metin, link veya medya
/// paylaşımlarını yakalayıp not oluşturma akışına aktaran servis.
class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;
  bool _isInitialized = false;

  /// Desteklenen platform kontrolü (Yalnızca Android ve iOS)
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Servisi başlatır ve gelen paylaşımları dinler.
  void initialize(
    BuildContext context, {
    SharedContentCallback? onContentReceived,
  }) {
    if (!isSupported) {
      debugPrint("Paylaşım yakalama özelliği yalnızca mobil platformlarda desteklenmektedir.");
      return;
    }

    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    // 1. Uygulama açıkken (arka planda) gelen paylaşımları dinle
    try {
      _mediaStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty && context.mounted) {
            _handleIncomingMedia(context, value, onContentReceived);
          }
        },
        onError: (err) {
          debugPrint("Gelen medya akışı hatası: $err");
        },
      );
    } catch (e) {
      debugPrint("getMediaStream başlatılamadı: $e");
    }

    // 2. Uygulama kapalıyken paylaşımla açıldığında (Initial Intent) gelen medyayı yakala
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty && context.mounted) {
            _handleIncomingMedia(context, value, onContentReceived);
            // Tekrar tekrar işlenmemesi için sıfırla
            ReceiveSharingIntent.instance.reset();
          }
        },
        onError: (err) {
          debugPrint("getInitialMedia hatası: $err");
        },
      );
    } catch (e) {
      debugPrint("getInitialMedia çağrılamadı: $e");
    }
  }

  /// Gelen paylaşılan medyayı parse edip callback veya editör akışına iletir
  void _handleIncomingMedia(
    BuildContext context,
    List<SharedMediaFile> mediaFiles,
    SharedContentCallback? onContentReceived,
  ) {
    final parsed = parseSharedMedia(mediaFiles);
    if (parsed.isEmpty) return;

    if (onContentReceived != null) {
      onContentReceived(parsed);
      return;
    }

    if (!context.mounted) return;
    openEditorWithSharedContent(context, parsed);
  }

  /// Gelen SharedMediaFile listesini SharedContent nesnesine dönüştürür
  SharedContent parseSharedMedia(List<SharedMediaFile> mediaFiles) {
    final texts = <String>[];
    final filePaths = <String>[];

    for (final media in mediaFiles) {
      if (media.type == SharedMediaType.text || media.type == SharedMediaType.url) {
        if (media.path.trim().isNotEmpty) {
          texts.add(media.path.trim());
        }
      } else {
        if (media.path.trim().isNotEmpty) {
          filePaths.add(media.path.trim());
        }
      }
    }

    final combinedText = texts.isNotEmpty ? texts.join('\n\n') : null;
    String? title;
    if (texts.isNotEmpty) {
      final firstLine = texts.first.split('\n').first.trim();
      title = firstLine.length > 30 ? '${firstLine.substring(0, 30)}...' : firstLine;
    }

    return SharedContent(
      text: combinedText,
      filePaths: filePaths,
      title: title ?? 'Paylaşılan Not',
    );
  }

  /// Paylaşılan içerikle doğrudan Markdown editörünü açar
  void openEditorWithSharedContent(BuildContext context, SharedContent content) {
    if (!context.mounted) return;

    String initialContent = content.text ?? '';
    if (content.filePaths.isNotEmpty) {
      final imageMarkdown = content.filePaths
          .map((path) => '![Paylaşılan Görsel]($path)')
          .join('\n\n');
      if (initialContent.isNotEmpty) {
        initialContent += '\n\n$imageMarkdown';
      } else {
        initialContent = imageMarkdown;
      }
    }

    final newNote = Note(
      title: content.title ?? 'Paylaşılan Not',
      content: initialContent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      folderName: 'Genel',
      tags: ['Paylaşılan'],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: MarkdownEditor(
            note: newNote,
            onSave: (savedNote) async {
              final noteProvider = Provider.of<NoteProvider>(context, listen: false);
              await noteProvider.addNote(savedNote);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paylaşılan not başarıyla kaydedildi! ✅'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  /// Abonelikleri iptal eder ve belleği temizler
  void dispose() {
    _mediaStreamSubscription?.cancel();
    _mediaStreamSubscription = null;
    _isInitialized = false;
  }
}

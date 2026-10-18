import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connected_notebook/features/ai/providers/ai_provider.dart';
import 'package:connected_notebook/features/ai/models/ai_exception.dart';

/// Modal bottom sheet and streaming runner for developer AI assistant actions in the editor.
class EditorAiSheet {
  final BuildContext context;
  final TextEditingController contentController;
  final String noteId;
  final bool isEncrypted;
  final VoidCallback onStartLoading;
  final VoidCallback onStopLoading;
  final ValueChanged<String> onError;
  final ValueChanged<String> onSuccess;
  final ValueChanged<List<String>> onTagsSuggested;
  final VoidCallback onContentModified;

  EditorAiSheet({
    required this.context,
    required this.contentController,
    required this.noteId,
    required this.isEncrypted,
    required this.onStartLoading,
    required this.onStopLoading,
    required this.onError,
    required this.onSuccess,
    required this.onTagsSuggested,
    required this.onContentModified,
  });

  Future<void> show(AiProvider aiProvider) async {
    if (!aiProvider.isAiEnabled) {
      onError('Lütfen önce Ayarlar\'dan AI sağlayıcınızı yapılandırın.');
      return;
    }

    final fullText = contentController.text;
    if (fullText.trim().isEmpty) {
      onError('Lütfen önce biraz not veya kod yazın.');
      return;
    }

    final selection = contentController.selection;
    final hasSelection = selection.isValid &&
        !selection.isCollapsed &&
        selection.start >= 0 &&
        selection.end <= fullText.length;
    final selectedText = hasSelection
        ? fullText.substring(selection.start, selection.end).trim()
        : '';
    final targetText = selectedText.isNotEmpty ? selectedText : fullText.trim();
    final insertPos = hasSelection
        ? selection.end
        : (selection.isValid ? selection.start : fullText.length);

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1F24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '✨ Geliştirici AI Asistanı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedText.isNotEmpty
                        ? 'Hedef: Seçili Metin / Kod (${selectedText.length} karakter)'
                        : 'Hedef: Tüm Not (${targetText.length} karakter)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: Colors.teal),
                  title: const Text('Kodu Açıkla & Analiz Et'),
                  subtitle: const Text('Adım adım çalışma mantığı, Big-O ve uç durumlar'),
                  onTap: () => Navigator.pop(sheetContext, 'explain_code'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded, color: Colors.indigo),
                  title: const Text('Kodu Refactor Et & İyileştir'),
                  subtitle: const Text('Clean Code, SOLID ve performans optimizasyonu'),
                  onTap: () => Navigator.pop(sheetContext, 'refactor_code'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Colors.cyan),
                  title: const Text('Teknik Dokümantasyon Üret'),
                  subtitle: const Text('Parametreler, dönüş tipleri ve kullanım örneği'),
                  onTap: () => Navigator.pop(sheetContext, 'generate_docs'),
                ),
                ListTile(
                  leading: const Icon(Icons.terminal_rounded, color: Colors.deepPurple),
                  title: const Text('Özel Komut Çalıştır (Serbest Prompt)'),
                  subtitle: const Text('Birim testi yazdır, dil çevir veya özel soru sor'),
                  onTap: () => Navigator.pop(sheetContext, 'custom_prompt'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.summarize_rounded, color: Colors.blue),
                  title: Text(selectedText.isNotEmpty ? 'Seçimi Özetle' : 'Notu Özetle'),
                  onTap: () => Navigator.pop(sheetContext, 'summary'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer_rounded, color: Colors.orange),
                  title: const Text('Etiket Öner'),
                  onTap: () => Navigator.pop(sheetContext, 'tags'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) return;

    String? customInstruction;
    if (action == 'custom_prompt') {
      customInstruction = await _promptCustomAiInstruction(selectedText.isNotEmpty);
      if (customInstruction == null || customInstruction.isEmpty) return;
    }

    onStartLoading();

    try {
      if (action == 'summary') {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamSummary(
            targetText,
            noteId: noteId,
            isEncrypted: isEncrypted,
          ),
          blockTitle: '✨ AI Özeti:',
          insertPos: insertPos,
          successMessage: 'Özet eklendi!',
          useBlockquote: true,
        );
      } else if (action == 'explain_code') {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamCodeExplanation(
            targetText,
            noteId: noteId,
            isEncrypted: isEncrypted,
          ),
          blockTitle: '🔍 AI Kod & Mimari Analizi',
          insertPos: insertPos,
          successMessage: 'Kod analizi eklendi!',
        );
      } else if (action == 'refactor_code') {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamCodeRefactor(
            targetText,
            noteId: noteId,
            isEncrypted: isEncrypted,
          ),
          blockTitle: '🛠️ AI Refactoring Önerisi',
          insertPos: insertPos,
          successMessage: 'Refactoring önerisi eklendi!',
        );
      } else if (action == 'generate_docs') {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamTechnicalDocs(
            targetText,
            noteId: noteId,
            isEncrypted: isEncrypted,
          ),
          blockTitle: '📚 Teknik Dokümantasyon',
          insertPos: insertPos,
          successMessage: 'Teknik dokümantasyon eklendi!',
        );
      } else if (action == 'custom_prompt' && customInstruction != null) {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamCustomPrompt(
            customInstruction,
            targetText,
            noteId: noteId,
            cacheActionKey: 'custom_prompt',
            isEncrypted: isEncrypted,
          ),
          blockTitle: '🤖 AI Yanıtı',
          insertPos: insertPos,
          successMessage: 'AI yanıtı eklendi!',
        );
      } else if (action == 'tags') {
        final suggestedTags = await aiProvider.getTags(
          targetText,
          noteId: noteId,
          isEncrypted: isEncrypted,
        );
        onTagsSuggested(suggestedTags);
        onSuccess('${suggestedTags.length} etiket eklendi!');
      }
    } on AiException catch (e) {
      onError(e.message);
    } catch (e) {
      onError('AI işlemi gerçekleştirilemedi: $e');
    } finally {
      onStopLoading();
      onContentModified();
    }
  }

  Future<void> _streamBlockIntoEditor({
    required Stream<String> stream,
    required String blockTitle,
    required int insertPos,
    required String successMessage,
    bool useBlockquote = false,
  }) async {
    final initialText = contentController.text;
    final blockStart = insertPos.clamp(0, initialText.length);
    final header = useBlockquote
        ? '\n\n> **$blockTitle**\n> '
        : '\n\n### $blockTitle\n\n';
    const footer = '\n\n';

    final initialBlock = '$header$footer';
    final textWithHeader = initialText.replaceRange(
      blockStart,
      blockStart,
      initialBlock,
    );
    var currentBlockLength = initialBlock.length;

    contentController.value = TextEditingValue(
      text: textWithHeader,
      selection: TextSelection.collapsed(
        offset: blockStart + header.length,
      ),
    );

    final pendingChunkBuffer = StringBuffer();
    var formattedBody = '';
    var lastFlushTime = DateTime.now();
    const flushInterval = Duration(milliseconds: 85);

    void flushPendingChunks({bool force = false}) {
      if (pendingChunkBuffer.isEmpty) return;
      final now = DateTime.now();
      if (!force && now.difference(lastFlushTime) < flushInterval) {
        return;
      }
      lastFlushTime = now;

      final rawDelta = pendingChunkBuffer.toString();
      pendingChunkBuffer.clear();

      final formattedDelta = useBlockquote
          ? rawDelta.replaceAll('\n', '\n> ')
          : rawDelta;
      formattedBody += formattedDelta;

      final newBlock = '$header$formattedBody$footer';
      final currentText = contentController.text;
      final safeStart = blockStart.clamp(0, currentText.length);
      final safeEnd = (blockStart + currentBlockLength).clamp(
        safeStart,
        currentText.length,
      );

      final updatedText = currentText.replaceRange(
        safeStart,
        safeEnd,
        newBlock,
      );
      currentBlockLength = newBlock.length;

      contentController.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(
          offset: (safeStart + newBlock.length).clamp(0, updatedText.length),
        ),
      );
    }

    await for (final chunk in stream) {
      pendingChunkBuffer.write(chunk);
      flushPendingChunks(force: false);
    }

    flushPendingChunks(force: true);
    onSuccess(successMessage);
  }

  Future<String?> _promptCustomAiInstruction(bool hasSelection) async {
    final promptController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('✨ Özel AI Komutu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasSelection
                  ? 'Seçili kod/metin bloğu üzerinde yapay zekanın ne yapmasını istiyorsunuz?'
                  : 'Not içeriği üzerinde yapay zekanın ne yapmasını istiyorsunuz?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Örn: Bu fonksiyon için birim testleri (unit test) yaz...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final text = promptController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Çalıştır'),
          ),
        ],
      ),
    );
    return result;
  }
}

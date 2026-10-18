import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/media/services/image_service.dart';
import 'package:connected_notebook/features/notes/widgets/custom_widgets.dart';
import 'package:connected_notebook/features/notes/widgets/math_markdown_renderer.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_live_controller.dart';
import 'package:connected_notebook/features/notes/widgets/floating_accessory_bar.dart';
import 'package:connected_notebook/features/notes/widgets/editor_backlink_section.dart';
import 'package:connected_notebook/features/notes/widgets/editor_bottom_sheets.dart';
import 'package:connected_notebook/features/tools/widgets/cross_reference_tracker.dart';
import 'package:connected_notebook/features/tools/widgets/pomodoro_timer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:connected_notebook/features/export/services/pdf_export_service.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/export/presentation/latex_export_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:connected_notebook/features/notes/services/voice_note_service.dart';
import 'package:connected_notebook/features/security/services/biometric_service.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/features/ai/providers/ai_provider.dart';
import 'package:connected_notebook/features/ai/models/ai_exception.dart';

class MarkdownEditor extends StatefulWidget {
  final Note? note;
  final Function(Note) onSave;
  final Function()? onCancel;

  const MarkdownEditor({
    super.key,
    this.note,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _titleController;
  late MarkdownLivePreviewController _contentController;

  bool _isPreviewMode = false;
  bool _isFocusMode = false;
  bool _isLoading = false;
  bool _isEncrypted = false;
  bool _isUnlocked = false;
  String _storedEncryptedContent = '';
  final NoteEncryptionService _encryptionService = NoteEncryptionService();
  final BiometricService _biometricService = BiometricService();
  int? _selectedColor;
  String? _emojiIcon;
  bool _isPomodoroVisible = false;
  bool _isCrossReferenceVisible = false;
  List<String> _tags = [];
  bool _isVimInsertMode = false; // Start in Normal mode if Vim is enabled
  bool _hasSelection = false;

  // Auto-save & dirty state tracking
  static const Duration _autoSaveDelay = Duration(milliseconds: 1500);
  Timer? _autoSaveTimer;
  int? _persistedNoteId;
  int _createdAt = 0;
  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  bool _isDirty = false;
  bool _isAutoSaving = false;
  bool _allowPop = false;

  final VoiceNoteService _voiceNoteService = VoiceNoteService();
  bool _isRecording = false;
  bool _isAiLoading = false;
  StreamSubscription<String>? _aiStreamSubscription;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  final List<Color> _noteColors = [
    Colors.white,
    Colors.red.shade50,
    Colors.pink.shade50,
    Colors.purple.shade50,
    Colors.deepPurple.shade50,
    Colors.indigo.shade50,
    Colors.blue.shade50,
    Colors.lightBlue.shade50,
    Colors.cyan.shade50,
    Colors.teal.shade50,
    Colors.green.shade50,
    Colors.lightGreen.shade50,
    Colors.lime.shade50,
    Colors.yellow.shade50,
    Colors.amber.shade50,
    Colors.orange.shade50,
    Colors.deepOrange.shade50,
    Colors.brown.shade50,
    Colors.blueGrey.shade50,
  ];

  @override
  void initState() {
    super.initState();
    _persistedNoteId = widget.note?.id;
    _createdAt = widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tags = List<String>.from(widget.note?.tags ?? []);

    String content = widget.note?.content ?? '';
    _isEncrypted = widget.note?.isEncrypted ?? false;

    if (_isEncrypted) {
      _storedEncryptedContent = widget.note?.content ?? '';
      if (NoteEncryptionService.isEncryptedPayload(_storedEncryptedContent)) {
        content = NoteEncryptionService.lockedNotePlaceholder;
      } else {
        // Legacy body: the flag used to be a no-op, so the text was stored
        // in clear. Treat it as already unlocked.
        content = _storedEncryptedContent;
        _isUnlocked = true;
      }
    }

    _contentController = MarkdownLivePreviewController(text: content);
    _selectedColor = widget.note?.color;
    _emojiIcon = widget.note?.emojiIcon;

    _lastSavedTitle = _titleController.text.trim();
    _lastSavedContent = _contentController.text;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NoteEditorProvider>().initialize(widget.note);
      }
    });

    _titleController.addListener(_onEditorFieldChanged);
    _contentController.addListener(_onContentChanged);
    _setupVimMode();
  }

  void _setupVimMode() {
    _contentFocusNode.onKeyEvent = (node, event) {
      final shortcutManager = Provider.of<AppShortcutManager>(context, listen: false);
      if (!shortcutManager.isVimModeEnabled) return KeyEventResult.ignored;

      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _isVimInsertMode = false);
          return KeyEventResult.handled;
        }

        if (!_isVimInsertMode) {
          final char = event.character;
          if (char == 'i' || char == 'a') {
            setState(() => _isVimInsertMode = true);
            if (char == 'a') {
              final offset = _contentController.selection.baseOffset;
              if (offset >= 0 && offset < _contentController.text.length) {
                _contentController.selection = TextSelection.collapsed(offset: offset + 1);
              }
            }
            return KeyEventResult.handled;
          }

          final text = _contentController.text;
          var selection = _contentController.selection;

          if (!selection.isValid) {
            selection = const TextSelection.collapsed(offset: 0);
          }

          final currentOffset = selection.baseOffset.clamp(0, text.length);

          if (char == 'h' && currentOffset > 0) {
            _contentController.selection = TextSelection.collapsed(offset: currentOffset - 1);
            return KeyEventResult.handled;
          } else if (char == 'l' && currentOffset < text.length) {
            _contentController.selection = TextSelection.collapsed(offset: currentOffset + 1);
            return KeyEventResult.handled;
          } else if (char == 'j' || char == 'k') {
            final nextOffset = computeVerticalLineOffset(
              text,
              currentOffset,
              moveDown: char == 'j',
            );
            _contentController.selection = TextSelection.collapsed(offset: nextOffset);
            return KeyEventResult.handled;
          } else if (char == '0') {
            // Move to start of current line
            final lineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0);
            _contentController.selection = TextSelection.collapsed(
              offset: lineStart == -1 ? 0 : lineStart + 1,
            );
            return KeyEventResult.handled;
          } else if (char == r'$') {
            // Move to end of current line
            final lineEnd = text.indexOf('\n', currentOffset);
            _contentController.selection = TextSelection.collapsed(
              offset: lineEnd == -1 ? text.length : lineEnd,
            );
            return KeyEventResult.handled;
          } else if (char == 'x' && currentOffset < text.length) {
            _contentController.text = text.replaceRange(currentOffset, currentOffset + 1, '');
            _contentController.selection = TextSelection.collapsed(offset: currentOffset);
            return KeyEventResult.handled;
          }

          // In normal mode, block all other printable character input
          if (char != null) {
            return KeyEventResult.handled;
          }
        }
      }
      return KeyEventResult.ignored;
    };
  }

  /// Computes the target cursor offset when moving vertically (`j` = down, `k` = up)
  /// across newline boundaries while preserving the current column index.
  @visibleForTesting
  static int computeVerticalLineOffset(
    String text,
    int currentOffset, {
    required bool moveDown,
  }) {
    if (text.isEmpty) return 0;
    final clamped = currentOffset.clamp(0, text.length);

    // Find start and end of current line
    final prevNewline = clamped == 0 ? -1 : text.lastIndexOf('\n', clamped - 1);
    final currentLineStart = prevNewline + 1;
    final nextNewline = text.indexOf('\n', clamped);
    final column = clamped - currentLineStart;

    if (moveDown) {
      if (nextNewline == -1) return clamped; // Already on last line
      final targetLineStart = nextNewline + 1;
      final nextNextNewline = text.indexOf('\n', targetLineStart);
      final targetLineEnd = nextNextNewline == -1 ? text.length : nextNextNewline;
      final targetLineLength = targetLineEnd - targetLineStart;
      return targetLineStart + (column <= targetLineLength ? column : targetLineLength);
    } else {
      if (prevNewline == -1) return clamped; // Already on first line
      final prevPrevNewline = prevNewline == 0 ? -1 : text.lastIndexOf('\n', prevNewline - 1);
      final targetLineStart = prevPrevNewline + 1;
      final targetLineEnd = prevNewline;
      final targetLineLength = targetLineEnd - targetLineStart;
      return targetLineStart + (column <= targetLineLength ? column : targetLineLength);
    }
  }


  void _onEditorFieldChanged() {
    if (!mounted) return;
    _checkDirtyAndScheduleAutoSave();
  }

  void _onContentChanged() {
    if (!mounted) return;
    final hasSelection = _contentController.selection.isValid &&
        !_contentController.selection.isCollapsed;
    if (hasSelection != _hasSelection || _isPreviewMode) {
      setState(() {
        _hasSelection = hasSelection;
      });
    }
    _checkDirtyAndScheduleAutoSave();
  }

  void _checkDirtyAndScheduleAutoSave() {
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text;
    final dirty =
        currentTitle != _lastSavedTitle || currentContent != _lastSavedContent;

    if (dirty != _isDirty) {
      setState(() {
        _isDirty = dirty;
      });
    }

    if (dirty && currentTitle.isNotEmpty && !_isAiLoading) {
      _scheduleAutoSave();
    } else if (!dirty) {
      _autoSaveTimer?.cancel();
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, _performAutoSave);
  }

  Future<void> _performAutoSave() async {
    if (!mounted || !_isDirty || _isLoading || _isAutoSaving) return;
    final currentTitle = _titleController.text.trim();
    if (currentTitle.isEmpty) return;

    setState(() => _isAutoSaving = true);
    try {
      await _persistNoteInternal(closeAfterSave: false);
    } catch (e) {
      debugPrint('Auto-save error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAutoSaving = false);
      }
    }
  }

  Note _buildCurrentNoteSnapshot() {
    final wasEncrypted = widget.note?.isEncrypted ?? false;
    final content = (wasEncrypted && !_isUnlocked)
        ? _storedEncryptedContent
        : _contentController.text;

    return Note(
      id: _persistedNoteId,
      title: _titleController.text.trim(),
      content: content,
      createdAt: _createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isEncrypted: _isEncrypted,
      tags: _tags,
      color: _selectedColor,
      folderName: widget.note?.folderName ?? 'Genel',
      emojiIcon: _emojiIcon,
    );
  }

  Future<Note> _persistNoteInternal({required bool closeAfterSave}) async {
    final note = _buildCurrentNoteSnapshot();
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final Note persistedNote;
    if (note.id == null) {
      persistedNote = await noteProvider.addNote(note);
      _persistedNoteId = persistedNote.id;
    } else {
      await noteProvider.updateNote(note);
      persistedNote = note;
    }

    _lastSavedTitle = _titleController.text.trim();
    _lastSavedContent = _contentController.text;
    _isDirty = false;

    if (closeAfterSave) {
      _allowPop = true;
      widget.onSave(persistedNote);
    }
    return persistedNote;
  }

  Future<void> _handleBackOrCancel() async {
    _autoSaveTimer?.cancel();
    if (!_isDirty) {
      _allowPop = true;
      if (widget.onCancel != null) {
        widget.onCancel!();
      } else if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    // If title is non-empty, offer to save or discard; if title is empty, warn before discarding.
    final canSave = _titleController.text.trim().isNotEmpty;
    final decision = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kaydedilmemiş Değişiklikler Var'),
        content: Text(
          canSave
              ? 'Notunuzda henüz kaydedilmemiş değişiklikler bulunuyor. Çıkmadan önce kaydetmek ister misiniz?'
              : 'Başlık girilmediği için not henüz kaydedilemedi. Çıkarsanız yazdığınız içerik kaybolacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Düzenlemeye Dön'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Kaydetmeden Çık'),
          ),
          if (canSave)
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: const Text('Kaydet ve Çık'),
            ),
        ],
      ),
    );

    if (!mounted || decision == null || decision == 'cancel') return;

    if (decision == 'save' && canSave) {
      await _saveNote();
      return;
    }

    if (decision == 'discard') {
      setState(() {
        _isDirty = false;
        _allowPop = true;
      });
      if (widget.onCancel != null) {
        widget.onCancel!();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _aiStreamSubscription?.cancel();
    _titleController.removeListener(_onEditorFieldChanged);
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Görsel Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
              title: const Text('Galeriden Seç'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.green),
              title: const Text('Kamera ile Çek'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      String? imagePath;
      final imageService = context.read<ImageService>();
      if (source == ImageSource.gallery) {
        imagePath = await imageService.pickImageFromGallery();
      } else {
        imagePath = await imageService.pickImageFromCamera();
      }

      if (imagePath != null) {
        final markdownImage = '![Görsel ${DateTime.now().toString().substring(0, 10)}]($imagePath)';
        _insertTextAtCursor('\n$markdownImage\n');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görsel başarıyla eklendi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Görsel eklenirken hata oluştu: $e');
    }
  }

  void _insertTextAtCursor(String syntax) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) {
      _contentController.text = '$text$syntax';
      _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
    } else {
      final newText = text.replaceRange(selection.start, selection.end, syntax);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + syntax.length),
      );
    }
    _contentFocusNode.requestFocus();
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _voiceNoteService.stopListening();
      setState(() => _isRecording = false);
    } else {
      final success = await _voiceNoteService.initialize();
      if (success) {
        setState(() => _isRecording = true);
        final initialText = _contentController.text;
        
        await _voiceNoteService.startListening((text) {
           final separator = initialText.isEmpty || initialText.endsWith(' ') || initialText.endsWith('\n') ? '' : ' ';
           setState(() {
              _contentController.text = initialText + separator + text;
              _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
           });
        });
      } else {
        _showError('Mikrofon izni alınamadı veya sistem desteklemiyor.');
      }
    }
  }

  Future<void> _saveNote() async {
    _autoSaveTimer?.cancel();
    if (_titleController.text.trim().isEmpty) {
      _showError('Başlık gerekli');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _persistNoteInternal(closeAfterSave: true);
    } catch (e) {
      _showError('Kayıt hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _toggleEncryption() async {
    if (!_isEncrypted) {
      final hasEnv = await _encryptionService.hasEnvelope();
      final hasLocal = await _encryptionService.hasLocalKey();

      if (!hasEnv) {
        final created = await _promptSetupMasterPassword();
        if (!created) return;
      } else if (!hasLocal) {
        final unlocked = await _promptUnlockWithMasterPassword();
        if (!unlocked) return;
      }

      if (!mounted) return;
      setState(() {
        _isEncrypted = true;
        _isUnlocked = true;
        _isDirty = true;
      });
      _scheduleAutoSave();
      _showSuccess('Not kaydedilirken şifrelenecek 🔒');
      return;
    }

    if (!_isUnlocked) {
      await _unlockVault();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şifreleme Kaldırılsın mı?'),
        content: const Text('Not düz metin olarak saklanacak. Devam edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isEncrypted = false;
      _isDirty = true;
    });
    _scheduleAutoSave();
    _showSuccess('Şifreleme kaldırıldı');
  }

  Future<bool> _promptSetupMasterPassword() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kasa Parolası Belirleyin 🔒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notlarınızı başka bir cihaza taşıdığınızda veya cihazınız sıfırlandığında şifreli notlarınızı kurtarabilmek için bir Kasa Parolası belirleyin.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kasa Parolası (en az 6 karakter)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parola Tekrar',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final p1 = passController.text;
                final p2 = confirmController.text;
                if (p1.length < 6) {
                  setDialogState(() => errorText = 'Parola en az 6 karakter olmalıdır.');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => errorText = 'Parolalar eşleşmiyor.');
                  return;
                }
                try {
                  await _encryptionService.setupMasterPassword(p1);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (e) {
                  setDialogState(() => errorText = 'Hata: $e');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<bool> _promptUnlockWithMasterPassword() async {
    final passController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kasa Parolasını Girin 🔑'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Şifreli kasa anahtarını (.vault_key.json) bu cihazda açmak için kasa parolanızı girin.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kasa Parolası',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _encryptionService.unlockWithMasterPassword(
                    passController.text,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on InvalidVaultPasswordException {
                  setDialogState(() => errorText = 'Parola hatalı.');
                } catch (e) {
                  setDialogState(() => errorText = 'Kasa açılamadı: $e');
                }
              },
              child: const Text('Kasayı Aç'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _unlockVault() async {
    try {
      final hasLocal = await _encryptionService.hasLocalKey();
      final hasEnv = await _encryptionService.hasEnvelope();

      if (hasLocal) {
        final canCheck = await _biometricService.canCheckBiometrics();
        if (canCheck) {
          final authenticated = await _biometricService.authenticate();
          if (!authenticated) {
            _showError('Kimlik doğrulanamadı, kasa açılamadı');
            return;
          }
        }
      } else if (hasEnv) {
        final unlocked = await _promptUnlockWithMasterPassword();
        if (!unlocked) return;
      }

      String decrypted;
      try {
        decrypted = await _encryptionService.decrypt(_storedEncryptedContent);
      } on NoteDecryptionException {
        if (hasEnv) {
          final unlocked = await _promptUnlockWithMasterPassword();
          if (!unlocked) return;
          decrypted = await _encryptionService.decrypt(_storedEncryptedContent);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      _autoSaveTimer?.cancel();
      _lastSavedContent = decrypted;
      setState(() {
        _contentController.text = decrypted;
        _isUnlocked = true;
        _isDirty = false;
      });
    } on NoteDecryptionException {
      _showError('Kasa anahtarı okunamadı; veri bozuk veya anahtar kayıpsa not açılamaz');
    } catch (e) {
      _showError('Kasa açma hatası: $e');
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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

  Future<void> _streamBlockIntoEditor({
    required Stream<String> stream,
    required String blockTitle,
    required int insertPos,
    required String successMessage,
    bool useBlockquote = false,
  }) async {
    _autoSaveTimer?.cancel();

    final initialText = _contentController.text;
    final blockStart = insertPos.clamp(0, initialText.length);
    final header = useBlockquote
        ? '\n\n> **$blockTitle**\n> '
        : '\n\n### $blockTitle\n\n';
    const footer = '\n\n';

    // Insert the initial empty block header once at [blockStart]
    final initialBlock = '$header$footer';
    final textWithHeader = initialText.replaceRange(
      blockStart,
      blockStart,
      initialBlock,
    );
    var currentBlockLength = initialBlock.length;

    _contentController.value = TextEditingValue(
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
      if (!mounted || pendingChunkBuffer.isEmpty) return;
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
      final currentText = _contentController.text;
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

      _contentController.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(
          offset: (safeStart + newBlock.length).clamp(0, updatedText.length),
        ),
      );
    }

    await for (final chunk in stream) {
      if (!mounted) break;
      pendingChunkBuffer.write(chunk);
      flushPendingChunks(force: false);
    }

    // Final flush for any remaining tokens in the buffer
    flushPendingChunks(force: true);
    _checkDirtyAndScheduleAutoSave();
    _showSuccess(successMessage);
  }

  Future<void> _showAiMenu() async {
    final aiProvider = context.read<AiProvider>();
    if (!aiProvider.isAiEnabled) {
      _showError('Lütfen önce Ayarlar\'dan AI sağlayıcınızı yapılandırın.');
      return;
    }

    final fullText = _contentController.text;
    if (fullText.trim().isEmpty) {
      _showError('Lütfen önce biraz not veya kod yazın.');
      return;
    }

    final selection = _contentController.selection;
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
      builder: (context) {
        final theme = Theme.of(context);
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
                  onTap: () => Navigator.pop(context, 'explain_code'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded, color: Colors.indigo),
                  title: const Text('Kodu Refactor Et & İyileştir'),
                  subtitle: const Text('Clean Code, SOLID ve performans optimizasyonu'),
                  onTap: () => Navigator.pop(context, 'refactor_code'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Colors.cyan),
                  title: const Text('Teknik Dokümantasyon Üret'),
                  subtitle: const Text('Parametreler, dönüş tipleri ve kullanım örneği'),
                  onTap: () => Navigator.pop(context, 'generate_docs'),
                ),
                ListTile(
                  leading: const Icon(Icons.terminal_rounded, color: Colors.deepPurple),
                  title: const Text('Özel Komut Çalıştır (Serbest Prompt)'),
                  subtitle: const Text('Birim testi yazdır, dil çevir veya özel soru sor'),
                  onTap: () => Navigator.pop(context, 'custom_prompt'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.summarize_rounded, color: Colors.blue),
                  title: Text(selectedText.isNotEmpty ? 'Seçimi Özetle' : 'Notu Özetle'),
                  onTap: () => Navigator.pop(context, 'summary'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer_rounded, color: Colors.orange),
                  title: const Text('Etiket Öner'),
                  onTap: () => Navigator.pop(context, 'tags'),
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

    setState(() => _isAiLoading = true);

    try {
      final String noteId = (_persistedNoteId ?? widget.note?.id)?.toString() ??
          _titleController.text.trim();

      if (action == 'summary') {
        await _streamBlockIntoEditor(
          stream: aiProvider.streamSummary(
            targetText,
            noteId: noteId,
            isEncrypted: _isEncrypted,
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
            isEncrypted: _isEncrypted,
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
            isEncrypted: _isEncrypted,
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
            isEncrypted: _isEncrypted,
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
            isEncrypted: _isEncrypted,
          ),
          blockTitle: '🤖 AI Yanıtı',
          insertPos: insertPos,
          successMessage: 'AI yanıtı eklendi!',
        );
      } else if (action == 'tags') {
        final suggestedTags = await aiProvider.getTags(
          targetText,
          noteId: noteId,
          isEncrypted: _isEncrypted,
        );
        setState(() {
          for (var tag in suggestedTags) {
            if (!_tags.contains(tag)) _tags.add(tag);
          }
        });
        _checkDirtyAndScheduleAutoSave();
        _showSuccess('${suggestedTags.length} etiket eklendi!');
      }
    } on AiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('AI işlemi gerçekleştirilemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
        _checkDirtyAndScheduleAutoSave();
      }
    }
  }


  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kağıt Rengi Seç'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _selectedColor != null ? Color(_selectedColor!) : Colors.white,
            availableColors: _noteColors,
            onColorChanged: (c) {
              setState(() {
                _selectedColor = c.toARGB32();
                _isDirty = true;
              });
              _scheduleAutoSave();
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (widget.note == null && _persistedNoteId == null) {
      _showError('Önce notu kaydetmelisiniz');
      return;
    }
    if (_isEncrypted && !_isUnlocked) {
      _showError('Şifreli notu dışa aktarmak için önce kilidini açmalısınız');
      return;
    }

    try {
      final currentNote = _buildCurrentNoteSnapshot();
      await PdfExportService.exportToPdf(currentNote);
    } catch (e) {
      _showError('PDF oluşturulurken hata: $e');
    }
  }

  void _showMathSymbolSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => EditorMathSymbolSheet(
        onSelectSyntax: _insertTextAtCursor,
      ),
    );
  }

  void _showTagAndMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditorTagAndMoodSheet(
        initialTags: _tags,
        onTagsChanged: (newTags) {
          setState(() {
            _tags = newTags;
            _isDirty = true;
          });
          _scheduleAutoSave();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final bgColor = _selectedColor != null
        ? Color(_selectedColor!)
        : Theme.of(context).colorScheme.surface;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final hasSelection = _contentController.selection.isValid && !_contentController.selection.isCollapsed;

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackOrCancel();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _isFocusMode ? null : _buildMinimalAppBar(context),
        body: SafeArea(
          child: Stack(
            children: [
              // Zen Mode Paper Canvas
              Positioned.fill(
                child: Hero(
                  tag: 'note_${_persistedNoteId ?? widget.note?.id ?? 'new_$_createdAt'}',
                  child: Material(
                    color: Colors.transparent,
                    child: _isPreviewMode ? _buildPreview() : _buildZenEditor(context),
                  ),
                ),
              ),

              // Mobile Floating Accessory Bar (Docked right above keyboard)
              if (!_isFocusMode && !_isPreviewMode && (!isDesktop || keyboardHeight > 0))
                Positioned(
                  bottom: keyboardHeight > 0 ? keyboardHeight + 8 : 16,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: FloatingAccessoryBar(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        onPickImage: _pickImage,
                        onToggleMathSheet: _showMathSymbolSheet,
                      ),
                    ),
                  ),
                ),

              // Desktop Floating Selection Bubble Menu
              if (!_isFocusMode && !_isPreviewMode && isDesktop && hasSelection)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DesktopSelectionBubbleMenu(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                    ),
                  ),
                ),

              // Focus Mode (Zen) Exit Button
              if (_isFocusMode)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                      tooltip: 'Odak Modundan Çık',
                      onPressed: () => setState(() => _isFocusMode = false),
                    ),
                  ),
                ),

              // Floating Pomodoro Timer
              if (_isFocusMode || _isPomodoroVisible)
                Positioned(
                  top: _isFocusMode ? 60 : 16,
                  right: 16,
                  child: const PomodoroTimer(),
                ),

              // Cross-Reference Side Panel (Optional toggle)
              if ((widget.note != null || _persistedNoteId != null) &&
                  _isCrossReferenceVisible &&
                  !_isFocusMode)
                Positioned(
                  top: 16,
                  right: 16,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300, maxHeight: 350),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SingleChildScrollView(
                              child: CrossReferenceTracker(
                                currentNote: _buildCurrentNoteSnapshot(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _isCrossReferenceVisible = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMinimalAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _isAutoSaving
        ? 'Otomatik kaydediliyor...'
        : (_isDirty ? 'Kaydedilmemiş değişiklik' : '');

    return CustomAppBar(
      title: statusLabel,
      showBackButton: true,
      onBackPressed: _handleBackOrCancel,
      actions: [
        // Vault Lock / Unlock Toggle
        IconButton(
          icon: Icon(
            !_isEncrypted
                ? Icons.lock_outline
                : (_isUnlocked ? Icons.lock_open : Icons.lock),
            color: _isEncrypted ? theme.colorScheme.primary : null,
          ),
          onPressed: _toggleEncryption,
          tooltip: !_isEncrypted
              ? 'Notu Şifrele'
              : (_isUnlocked ? 'Şifrelemeyi Kaldır' : 'Kasayı Aç'),
        ),

        // Live Preview / Preview Toggle
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_note_rounded : Icons.remove_red_eye_outlined,
            color: _isPreviewMode ? theme.colorScheme.primary : null,
          ),
          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          tooltip: _isPreviewMode ? 'Düzenleme Modu' : 'Tam Önizleme',
        ),

        // Voice Note Toggle
        IconButton(
          icon: Icon(
            _isRecording ? Icons.mic : Icons.mic_none,
            color: _isRecording ? Colors.red : null,
          ),
          onPressed: _toggleVoiceRecording,
          tooltip: 'Sesli Not',
        ),

        // AI Assistant Toggle
        IconButton(
          icon: _isAiLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          onPressed: _isAiLoading ? null : _showAiMenu,
          tooltip: 'Yapay Zeka Asistanı',
        ),

        // Save Button (Clean and prominent)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveNote,
            icon: _isAutoSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_isDirty ? 'Kaydet*' : 'Kaydet'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
        ),

        // Overflow Options Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tooltip: 'Daha Fazla Seçenek',
          onSelected: (value) async {
            switch (value) {
              case 'color':
                _showColorPicker();
                break;
              case 'tags':
                _showTagAndMoodSheet();
                break;
              case 'pomodoro':
                setState(() => _isPomodoroVisible = !_isPomodoroVisible);
                break;
              case 'backlinks':
                setState(() => _isCrossReferenceVisible = !_isCrossReferenceVisible);
                break;
              case 'pdf':
                _exportToPdf();
                break;
              case 'latex':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => LatexExportScreen(
                      note: _buildCurrentNoteSnapshot(),
                    ),
                  ),
                );
                break;
              case 'share':
                final textToShare = '${_titleController.text.trim()}\n\n${_contentController.text}';
                if (kIsWeb) {
                  await Clipboard.setData(ClipboardData(text: textToShare));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Metin panoya kopyalandı!')),
                    );
                  }
                } else {
                  Share.share(textToShare);
                }
                break;
              case 'focus':
                setState(() => _isFocusMode = true);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'tags',
              child: Row(
                children: [
                  Icon(Icons.label_outline_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Etiketler & Mod'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'color',
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 20, color: _selectedColor != null ? Color(_selectedColor!) : null),
                  const SizedBox(width: 12),
                  const Text('Kağıt Rengi'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'focus',
              child: const Row(
                children: [
                  Icon(Icons.fullscreen_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Zen Odak Modu'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pomodoro',
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: _isPomodoroVisible ? Colors.red : null),
                  const SizedBox(width: 12),
                  Text(_isPomodoroVisible ? 'Pomodoro Gizle' : 'Pomodoro Sayacı'),
                ],
              ),
            ),
            if (widget.note != null || _persistedNoteId != null)
              PopupMenuItem(
                value: 'backlinks',
                child: const Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Çapraz Bağlantılar'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'share',
              child: const Row(
                children: [
                  Icon(Icons.share_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Notu Paylaş'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('PDF Olarak Kaydet'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'latex',
              child: const Row(
                children: [
                  Icon(Icons.text_format_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('LaTeX Olarak Dışa Aktar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The Content-First Zen Mode Editor
  Widget _buildZenEditor(BuildContext context) {
    final theme = Theme.of(context);

    final mood = EditorTagAndMoodSheet.findCurrentMood(_tags);
    final nonMoodTags = _tags.where((t) => !t.startsWith('mood:')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Field - Large H1 Notion-like header
        // Notion-like header: emoji icon + color picker
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Row(
            children: [
              if (_emojiIcon != null)
                GestureDetector(
                  onTap: _showEmojiPicker,
                  child: Text(_emojiIcon!, style: const TextStyle(fontSize: 56)),
                ),
              if (_emojiIcon == null)
                TextButton.icon(
                  onPressed: _showEmojiPicker,
                  icon: const Icon(Icons.add_reaction_outlined, size: 18),
                  label: const Text('İkon Ekle'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.disabledColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _showColorPicker,
                icon: const Icon(Icons.color_lens_outlined, size: 18),
                label: const Text('Renk'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.disabledColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _contentFocusNode.requestFocus(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -0.6,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Başlıksız Not',
              hintStyle: TextStyle(
                color: theme.disabledColor.withValues(alpha: 0.28),
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),

        // Subtle, integrated Metadata Strip (Mood & Tag chips)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Mood Chip
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showTagAndMoodSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood ?? '😊', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          mood == null ? 'Mod ekle' : 'Mod',
                          style: TextStyle(fontSize: 12, color: theme.disabledColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Tags chips
                ...nonMoodTags.map((tag) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )),

                // Add Tag Chip
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showTagAndMoodSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: theme.disabledColor),
                        const SizedBox(width: 2),
                        Text(
                          'Etiket',
                          style: TextStyle(fontSize: 12, color: theme.disabledColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

      // The Smooth Continuous Canvas Body (No dividers, no boxes)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              maxLines: null,
              expands: true,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.7,
                fontSize: 16.5,
                letterSpacing: 0.1,
              ),
              cursorColor: theme.colorScheme.primary,
              cursorWidth: 2.2,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                hintText: 'Düşüncelerinizi buraya dökün...',
                hintStyle: TextStyle(
                  color: theme.disabledColor.withValues(alpha: 0.3),
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Backlinks Section
        EditorBacklinkSection(
          currentNoteId: _persistedNoteId ?? widget.note?.id,
          currentTitle: _titleController.text,
        ),

        // Bottom spacer to ensure text is never covered by the floating bar
        const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (_emojiIcon != null) ...[
              Text(_emojiIcon!, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
            ],
            Text(
              _titleController.text.isEmpty ? 'Başlıksız Not' : _titleController.text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    letterSpacing: -0.6,
                  ),
            ),
            const SizedBox(height: 16),
            MathMarkdownRenderer(
              data: _contentController.text,
              selectable: true,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() {
              _emojiIcon = emoji.emoji;
              _isDirty = true;
            });
            _scheduleAutoSave();
            Navigator.pop(ctx);
          },
          config: const Config(),
        ),
      ),
    );
  }
}

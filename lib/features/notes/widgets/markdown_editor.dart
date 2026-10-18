import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/features/ai/providers/ai_provider.dart';
import 'package:connected_notebook/features/export/presentation/latex_export_screen.dart';
import 'package:connected_notebook/features/export/services/pdf_export_service.dart';
import 'package:connected_notebook/features/media/services/image_service.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/services/voice_note_service.dart';
import 'package:connected_notebook/features/notes/widgets/custom_widgets.dart';
import 'package:connected_notebook/features/notes/widgets/editor_ai_sheet.dart';
import 'package:connected_notebook/features/notes/widgets/editor_app_bar.dart';
import 'package:connected_notebook/features/notes/widgets/editor_bottom_sheets.dart';
import 'package:connected_notebook/features/notes/widgets/editor_vault_dialogs.dart';
import 'package:connected_notebook/features/notes/widgets/editor_vim_handler.dart';
import 'package:connected_notebook/features/notes/widgets/editor_zen_canvas.dart';
import 'package:connected_notebook/features/notes/widgets/floating_accessory_bar.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_live_controller.dart';
import 'package:connected_notebook/features/notes/widgets/math_markdown_renderer.dart';
import 'package:connected_notebook/features/security/services/biometric_service.dart';
import 'package:connected_notebook/features/tools/widgets/cross_reference_tracker.dart';
import 'package:connected_notebook/features/tools/widgets/pomodoro_timer.dart';

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

  /// Exposes vertical line offset calculations for tests and backward compatibility.
  @visibleForTesting
  static int computeVerticalLineOffset(
    String text,
    int currentOffset, {
    required bool moveDown,
  }) =>
      EditorVimHandler.computeVerticalLineOffset(
        text,
        currentOffset,
        moveDown: moveDown,
      );

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _titleController;
  late MarkdownLivePreviewController _contentController;
  late EditorVimHandler _vimHandler;

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

    _vimHandler = EditorVimHandler(
      context: context,
      controller: _contentController,
      focusNode: _contentFocusNode,
      onModeChanged: () {
        if (mounted) setState(() {});
      },
    );
    _vimHandler.attach();
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
          _showSuccess('Görsel başarıyla eklendi');
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _toggleEncryption() async {
    if (!_isEncrypted) {
      final hasEnv = await _encryptionService.hasEnvelope();
      final hasLocal = await _encryptionService.hasLocalKey();

      if (!hasEnv) {
        final created = await EditorVaultDialogs.promptSetupMasterPassword(
          context,
          _encryptionService,
        );
        if (!created) return;
      } else if (!hasLocal) {
        final unlocked = await EditorVaultDialogs.promptUnlockWithMasterPassword(
          context,
          _encryptionService,
        );
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

    final confirmed = await EditorVaultDialogs.confirmRemoveEncryption(context);
    if (!confirmed) return;

    setState(() {
      _isEncrypted = false;
      _isDirty = true;
    });
    _scheduleAutoSave();
    _showSuccess('Şifreleme kaldırıldı');
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
        final unlocked = await EditorVaultDialogs.promptUnlockWithMasterPassword(
          context,
          _encryptionService,
        );
        if (!unlocked) return;
      }

      String decrypted;
      try {
        decrypted = await _encryptionService.decrypt(_storedEncryptedContent);
      } on NoteDecryptionException {
        if (hasEnv) {
          final unlocked = await EditorVaultDialogs.promptUnlockWithMasterPassword(
            context,
            _encryptionService,
          );
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

  void _showAiAssistantMenu() {
    final aiProvider = context.read<AiProvider>();
    final noteId = (_persistedNoteId ?? widget.note?.id)?.toString() ??
        _titleController.text.trim();

    final sheet = EditorAiSheet(
      context: context,
      contentController: _contentController,
      noteId: noteId,
      isEncrypted: _isEncrypted,
      onStartLoading: () => setState(() => _isAiLoading = true),
      onStopLoading: () {
        if (mounted) setState(() => _isAiLoading = false);
      },
      onError: _showError,
      onSuccess: _showSuccess,
      onTagsSuggested: (tags) {
        setState(() {
          for (final tag in tags) {
            if (!_tags.contains(tag)) _tags.add(tag);
          }
        });
      },
      onContentModified: _checkDirtyAndScheduleAutoSave,
    );

    sheet.show(aiProvider);
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

  @override
  Widget build(BuildContext context) {
    final bgColor = _selectedColor != null
        ? Color(_selectedColor!)
        : Theme.of(context).colorScheme.surface;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final hasSelection = _hasSelection;

    final statusLabel = _isAutoSaving
        ? 'Otomatik kaydediliyor...'
        : (_isDirty ? 'Kaydedilmemiş değişiklik' : '');

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackOrCancel();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _isFocusMode
            ? null
            : EditorAppBar(
                statusLabel: statusLabel,
                isDirty: _isDirty,
                isAutoSaving: _isAutoSaving,
                isLoading: _isLoading,
                isEncrypted: _isEncrypted,
                isUnlocked: _isUnlocked,
                isPreviewMode: _isPreviewMode,
                isRecording: _isRecording,
                isAiLoading: _isAiLoading,
                selectedColor: _selectedColor,
                isPomodoroVisible: _isPomodoroVisible,
                isCrossReferenceVisible: _isCrossReferenceVisible,
                canShowBacklinks: widget.note != null || _persistedNoteId != null,
                onBackPressed: _handleBackOrCancel,
                onToggleEncryption: _toggleEncryption,
                onTogglePreview: () => setState(() => _isPreviewMode = !_isPreviewMode),
                onToggleVoiceRecording: _toggleVoiceRecording,
                onShowAiMenu: _showAiAssistantMenu,
                onSaveNote: _saveNote,
                onSelectColor: _showColorPicker,
                onShowTagSheet: _showTagAndMoodSheet,
                onTogglePomodoro: () => setState(() => _isPomodoroVisible = !_isPomodoroVisible),
                onToggleBacklinks: () => setState(() => _isCrossReferenceVisible = !_isCrossReferenceVisible),
                onExportPdf: _exportToPdf,
                onExportLatex: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => LatexExportScreen(
                        note: _buildCurrentNoteSnapshot(),
                      ),
                    ),
                  );
                },
                onShare: () async {
                  final textToShare = '${_titleController.text.trim()}\n\n${_contentController.text}';
                  if (kIsWeb) {
                    await Clipboard.setData(ClipboardData(text: textToShare));
                    if (context.mounted) {
                      _showSuccess('Metin panoya kopyalandı!');
                    }
                  } else {
                    Share.share(textToShare);
                  }
                },
                onToggleFocusMode: () => setState(() => _isFocusMode = true),
              ),
        body: SafeArea(
          child: Stack(
            children: [
              // Zen Mode Paper Canvas
              Positioned.fill(
                child: Hero(
                  tag: 'note_${_persistedNoteId ?? widget.note?.id ?? 'new_$_createdAt'}',
                  child: Material(
                    color: Colors.transparent,
                    child: _isPreviewMode
                        ? _buildPreview()
                        : EditorZenCanvas(
                            titleController: _titleController,
                            titleFocusNode: _titleFocusNode,
                            contentController: _contentController,
                            contentFocusNode: _contentFocusNode,
                            emojiIcon: _emojiIcon,
                            tags: _tags,
                            currentNote: _buildCurrentNoteSnapshot(),
                            onSelectBacklinkNote: (note) {
                              Navigator.of(context).pushNamed(
                                '/note-editor',
                                arguments: note,
                              );
                            },
                            onShowEmojiPicker: _showEmojiPicker,
                            onShowColorPicker: _showColorPicker,
                            onShowTagSheet: _showTagAndMoodSheet,
                          ),
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
}

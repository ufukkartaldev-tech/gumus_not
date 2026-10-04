import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:connected_notebook/features/tools/widgets/cross_reference_tracker.dart';
import 'package:connected_notebook/features/tools/widgets/tag_manager_widget.dart';
import 'package:connected_notebook/features/tools/widgets/pomodoro_timer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:connected_notebook/features/export/services/pdf_service.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/export/presentation/latex_export_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:connected_notebook/features/notes/services/voice_note_service.dart';

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
  int? _selectedColor;
  String? _emojiIcon;
  bool _isPomodoroVisible = false;
  bool _isCrossReferenceVisible = false;
  List<String> _tags = [];
  bool _isVimInsertMode = false; // Start in Normal mode if Vim is enabled

  final VoiceNoteService _voiceNoteService = VoiceNoteService();
  bool _isRecording = false;

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
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tags = List<String>.from(widget.note?.tags ?? []);

    String content = widget.note?.content ?? '';
    _isEncrypted = widget.note?.isEncrypted ?? false;

    if (_isEncrypted) {
      content = '🔒 Bu not şifreli. İçeriği görmek için kasayı açın.';
    }

    _contentController = MarkdownLivePreviewController(text: content);
    _selectedColor = widget.note?.color;
    _emojiIcon = widget.note?.emojiIcon;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NoteEditorProvider>().initialize(widget.note);
      }
    });

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
          // Normal mode commands
          final char = event.character;
          if (char == 'i' || char == 'a') {
            setState(() => _isVimInsertMode = true);
            return KeyEventResult.handled;
          }

          final text = _contentController.text;
          var selection = _contentController.selection;
          
          if (!selection.isValid) {
            selection = const TextSelection.collapsed(offset: 0);
          }

          int currentOffset = selection.baseOffset;

          if (char == 'h' && currentOffset > 0) {
            _contentController.selection = TextSelection.collapsed(offset: currentOffset - 1);
            return KeyEventResult.handled;
          } else if (char == 'l' && currentOffset < text.length) {
            _contentController.selection = TextSelection.collapsed(offset: currentOffset + 1);
            return KeyEventResult.handled;
          } else if (char == 'k' || char == 'j') {
            // Very basic j/k navigation - move by approx characters or lines if we could compute it easily
            // For a robust vim we need line offsets, but here we can just skip 50 chars for demo
            if (char == 'j' && currentOffset + 50 <= text.length) {
               _contentController.selection = TextSelection.collapsed(offset: currentOffset + 50);
            } else if (char == 'k' && currentOffset - 50 >= 0) {
               _contentController.selection = TextSelection.collapsed(offset: currentOffset - 50);
            }
            return KeyEventResult.handled;
          } else if (char == 'x' && currentOffset < text.length) {
            _contentController.text = text.replaceRange(currentOffset, currentOffset + 1, '');
            _contentController.selection = TextSelection.collapsed(offset: currentOffset);
            return KeyEventResult.handled;
          }

          // In normal mode, block all other character input
          if (char != null) {
             return KeyEventResult.handled; 
          }
        }
      }
      return KeyEventResult.ignored;
    };
  }


  void _onContentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
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

    if (source == null) return;

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
    if (_titleController.text.trim().isEmpty) {
      _showError('Başlık gerekli');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final plaintextContent = _contentController.text;

      final note = Note(
        id: widget.note?.id,
        title: _titleController.text.trim(),
        content: plaintextContent,
        createdAt: widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: _tags,
        color: _selectedColor,
        emojiIcon: _emojiIcon,
      );

      if (widget.note == null) {
        await Provider.of<NoteProvider>(context, listen: false).addNote(note);
      } else {
        await Provider.of<NoteProvider>(context, listen: false).updateNote(note);
      }
      widget.onSave(note);
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
              setState(() => _selectedColor = c.value);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (widget.note == null) {
      _showError('Önce notu kaydetmelisiniz');
      return;
    }

    try {
      final currentNote = widget.note!.copyWith(
        content: _contentController.text,
        title: _titleController.text,
      );

      await PdfService.exportToPdf(currentNote);
    } catch (e) {
      _showError('PDF oluşturulurken hata: $e');
    }
  }

  void _showMathSymbolSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final mathItems = [
          {'label': 'x²', 'syntax': r'x^2'},
          {'label': 'a/b', 'syntax': r'\frac{a}{b}'},
          {'label': '√x', 'syntax': r'\sqrt{x}'},
          {'label': '∑', 'syntax': r'\sum_{i=1}^{n}'},
          {'label': '∫', 'syntax': r'\int_{a}^{b} f(x) dx'},
          {'label': 'π', 'syntax': r'\pi'},
          {'label': 'θ', 'syntax': r'\theta'},
          {'label': 'lim', 'syntax': r'\lim_{x \to \infty}'},
          {'label': 'Mermaid', 'syntax': "```mermaid\ngraph TD\n  A[Başla] --> B[Devam]\n```\n"},
          {'label': r'Blok $$', 'syntax': "\$\$\nE = mc^2\n\$\$\n"},
        ];

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            color: isDark ? const Color(0xFF1E1F24) : Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.functions_rounded, color: Colors.purple, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Matematik & Diyagram Ekle',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mathItems.map((item) {
                    return ActionChip(
                      label: Text(item['label']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onPressed: () {
                        Navigator.pop(context);
                        _insertTextAtCursor(item['syntax']!);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTagAndMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                color: isDark ? const Color(0xFF1E1F24) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Not Bilgileri & Etiketler',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildMoodSelector(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TagManagerWidget(
                        initialTags: _tags,
                        onTagsChanged: (newTags) {
                          setState(() => _tags = newTags);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMoodSelector() {
    final moods = ['😊', '😐', '😢', '😡', '🚀', '💡', '🔥'];
    final selectedMood = _findCurrentMood();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Mod:',
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          ...moods.map((mood) {
            final isSelected = selectedMood == mood;
            return GestureDetector(
              onTap: () => _updateMood(mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 1.5) : null,
                ),
                child: Text(
                  mood,
                  style: TextStyle(fontSize: isSelected ? 22 : 18),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String? _findCurrentMood() {
    for (var tag in _tags) {
      if (tag.startsWith('mood:')) {
        return tag.substring(5);
      }
    }
    return null;
  }

  void _updateMood(String mood) {
    setState(() {
      _tags.removeWhere((tag) => tag.startsWith('mood:'));
      _tags.add('mood:$mood');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _selectedColor != null
        ? Color(_selectedColor!)
        : Theme.of(context).colorScheme.background;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final hasSelection = _contentController.selection.isValid && !_contentController.selection.isCollapsed;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isFocusMode ? null : _buildMinimalAppBar(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Zen Mode Paper Canvas
            Positioned.fill(
              child: Hero(
                tag: 'note_${widget.note?.id ?? 'new_${widget.note?.createdAt}'}',
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
                  color: Colors.black.withOpacity(0.4),
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
            if (widget.note != null && _isCrossReferenceVisible && !_isFocusMode)
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
                            child: CrossReferenceTracker(currentNote: widget.note!),
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
    );
  }

  PreferredSizeWidget _buildMinimalAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final mood = _findCurrentMood();

    return CustomAppBar(
      title: '',
      showBackButton: true,
      onBackPressed: widget.onCancel,
      actions: [
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

        // Save Button (Clean and prominent)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveNote,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Kaydet'),
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
                  MaterialPageRoute(builder: (ctx) => LatexExportScreen(note: widget.note!)),
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
                  const SizedBox(width: 12),
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
            if (widget.note != null)
              PopupMenuItem(
                value: 'backlinks',
                child: const Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('Çapraz Bağlantılar'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'share',
              child: const Row(
                children: [
                  Icon(Icons.share_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text('Notu Paylaş'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('PDF Olarak Kaydet'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'latex',
              child: const Row(
                children: [
                  Icon(Icons.text_format_rounded, size: 20),
                  const SizedBox(width: 12),
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

    final mood = _findCurrentMood();
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
                color: theme.disabledColor.withOpacity(0.28),
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
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
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
                        color: theme.colorScheme.primary.withOpacity(0.09),
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
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.2), width: 0.8),
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
                  color: theme.disabledColor.withOpacity(0.3),
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
        _buildBacklinkSection(),

        // Bottom spacer to ensure text is never covered by the floating bar
        const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildBacklinkSection() {
    final theme = Theme.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final currentTitle = _titleController.text.trim().toLowerCase();
    
    if (currentTitle.isEmpty) return const SizedBox.shrink();

    // Find notes that link to this one
    final backlinks = noteProvider.notes.where((n) {
      if (n.id == widget.note?.id) return false;
      return n.content.toLowerCase().contains('\[\[$currentTitle\]\]');
    }).toList();

    if (backlinks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Geri Bağlantılar (${backlinks.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...backlinks.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/note-editor', arguments: n);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.content.length > 60 ? '${n.content.substring(0, 60)}...' : n.content,
                          style: TextStyle(fontSize: 12, color: theme.disabledColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
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

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() => _emojiIcon = emoji.emoji);
            Navigator.pop(ctx);
          },
          config: const Config(),
        ),
      ),
    );
  }
}

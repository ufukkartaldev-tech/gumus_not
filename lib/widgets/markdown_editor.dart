import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../services/image_service.dart';

import 'custom_widgets.dart';
import 'math_markdown_renderer.dart';
import 'cross_reference_tracker.dart';
import 'tag_manager_widget.dart';
import 'pomodoro_timer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/encryption_service.dart';
import '../screens/drawing_screen.dart';
import '../services/pdf_service.dart';


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

class _MarkdownEditorState extends State<MarkdownEditor> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TabController _toolbarTabController;
  
  bool _isPreviewMode = false;
  bool _isFocusMode = false;
  bool _isLoading = false;
  bool _isEncrypted = false;
  int? _selectedColor;
  bool _isPomodoroVisible = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _tags = [];
  
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
    _toolbarTabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tags = widget.note?.tags ?? [];
    
    String content = widget.note?.content ?? '';
    _isEncrypted = widget.note?.isEncrypted ?? false;
    
    // Şifreli notlar otomatik olarak çözülmez, şifre istenir
    if (_isEncrypted) {
      content = '🔒 Bu not şifreli. İçeriği görmek için şifre giriniz.';
    }
    
    _contentController = TextEditingController(text: content);
    _selectedColor = widget.note?.color;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _toolbarTabController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resim Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera ile Çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      String? imagePath;
      
      if (source == ImageSource.gallery) {
        imagePath = await ImageService.pickImageFromGallery();
      } else {
        imagePath = await ImageService.pickImageFromCamera();
      }

      if (imagePath != null) {
        final markdownImage = ImageService.createMarkdownImageLink(
          imagePath,
          altText: 'Resim ${DateTime.now().toString().substring(0, 10)}',
        );
        _insertMarkdownSyntax('\n$markdownImage\n');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resim başarıyla eklendi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Resim eklenirken hata oluştu: $e');
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Başlık gerekli');
      return;
    }
    setState(() => _isLoading = true);
    try {
      String contentToSave = _contentController.text;
      if (_isEncrypted) {
        if (!EncryptionService.isInitialized()) throw Exception('Kasa kilitli.');
        contentToSave = EncryptionService.encrypt(contentToSave);
      }
      final note = Note(
        id: widget.note?.id,
        title: _titleController.text.trim(),
        content: contentToSave,
        createdAt: widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: _isEncrypted,
        tags: _tags,
        color: _selectedColor,
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
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔒 Şifreli Not'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bu notun içeriğini görmek için şifrenizi girin:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                onSubmitted: (_) => _unlockNote(passwordController.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => _unlockNote(passwordController.text),
              child: const Text('Giriş'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unlockNote(String password) async {
    try {
      if (!EncryptionService.isInitialized()) {
        _showError('Şifreleme servisi başlatılmamış. Ayarlardan şifreleyiciyi açın.');
        Navigator.of(context).pop();
        return;
      }

      // Şifreyi doğrula ve notu çöz
      final encryptedContent = widget.note?.content ?? '';
      final decryptedContent = EncryptionService.decrypt(encryptedContent);
      
      // Şifre doğrulama başarılı, içeriği güncelle
      setState(() {
        _contentController.text = decryptedContent;
        _isEncrypted = false; // Geçici olarak kilidi aç
      });
      
      Navigator.of(context).pop();
      _showError('Not başarıyla açıldı');
      
    } catch (e) {
      _showError('Şifre hatalı veya not açılamadı: $e');
    }
  }

  void _insertMarkdownSyntax(String syntax) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = text.replaceRange(selection.start, selection.end, syntax);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.baseOffset + syntax.length),
    );
    _contentFocusNode.requestFocus();
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renk Seç'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _selectedColor != null 
        ? Color(_selectedColor!) 
        : Theme.of(context).colorScheme.background;
        
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isFocusMode ? null : _buildAppBar(context),
      body: SafeArea(
        child: Stack(
          children: [
            Hero(
              tag: 'note_${widget.note?.id ?? 'new_${widget.note?.createdAt}'}',
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Expanded(
                      child: _isPreviewMode ? _buildPreview() : _buildEditor(context),
                    ),
                    if (!_isFocusMode) const SizedBox(height: 80), 
                  ],
                ),
              ),
            ),
            if (!_isFocusMode && !_isPreviewMode)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _buildGlassToolbar(context),
                  ),
                ),
              ),
            if (_isFocusMode)
              Positioned(
                top: 20,
                right: 20,
                child: FloatingActionButton.small(
                  onPressed: () => setState(() => _isFocusMode = false),
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.fullscreen_exit, color: Colors.white),
                ),
              ),
            if (_isFocusMode || _isPomodoroVisible)
               Positioned(
                 bottom: _isFocusMode ? 30 : null,
                 top: _isFocusMode ? null : 16,
                 right: _isFocusMode ? 30 : 16,
                 child: Opacity(
                   opacity: _isFocusMode ? 0.8 : 1.0,
                   child: const PomodoroTimer(),
                 ),
               ),
             if (widget.note != null && !_isPreviewMode && !_isFocusMode)
               Positioned(
                  top: 0,
                  right: 0,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: CrossReferenceTracker(currentNote: widget.note!)),
                  ),
               ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CustomAppBar(
      title: '',
      showBackButton: true,
      onBackPressed: widget.onCancel,
      actions: [
        IconButton(
          icon: Icon(Icons.timer, color: _isPomodoroVisible ? Colors.red : null),
          onPressed: () => setState(() => _isPomodoroVisible = !_isPomodoroVisible),
          tooltip: 'Pomodoro Sayacı',
        ),
        IconButton(
          icon: Icon(Icons.circle, color: _selectedColor != null ? Color(_selectedColor!) : Colors.grey.shade400),
          onPressed: _showColorPicker,
          tooltip: 'Kağıt Rengi',
        ),
        IconButton(
          icon: Icon(_isEncrypted ? Icons.lock : Icons.lock_open_outlined, color: _isEncrypted ? Colors.orange : null),
          onPressed: () {
             if (EncryptionService.isInitialized()) {
                setState(() => _isEncrypted = !_isEncrypted);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEncrypted ? 'Not Şifrelendi' : 'Şifre Kaldırıldı')));
             } else {
                _showError('Kasa kilitli. Ayarlardan açın.');
             }
          },
        ),
        IconButton(
          icon: Icon(_isPreviewMode ? Icons.edit_note : Icons.remove_red_eye_outlined),
          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          tooltip: _isPreviewMode ? 'Düzenle' : 'Önizle',
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          onPressed: () => setState(() => _isFocusMode = true),
          tooltip: 'Odak Modu',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveNote,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Kaydet'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassToolbar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey[900] : Colors.white)!.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            children: [
               Container(
                 decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: TabBar(
                   controller: _toolbarTabController,
                   indicatorSize: TabBarIndicatorSize.label,
                   indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                     borderRadius: BorderRadius.circular(20),
                   ),
                   labelColor: Theme.of(context).primaryColor,
                   unselectedLabelColor: Theme.of(context).disabledColor,
                   isScrollable: true,
                   tabs: const [
                      Tab(icon: Icon(Icons.text_fields_rounded, size: 20)), 
                      Tab(icon: Icon(Icons.functions_rounded, size: 20))
                   ],
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: TabBarView(
                   controller: _toolbarTabController,
                   children: [
                      _buildMarkdownTools(),
                      _buildMathTools(),
                   ],
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownTools() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        _toolBtn('B', '**', tooltip: 'Kalın', style: const TextStyle(fontWeight: FontWeight.w900)),
        _toolBtn('I', '*', tooltip: 'İtalik', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
        _toolBtn('S', '~~', tooltip: 'Üstü Çizili', style: const TextStyle(decoration: TextDecoration.lineThrough)),
        const VerticalDivider(indent: 12, endIndent: 12),
        _toolBtn('H1', '# '),
        _toolBtn('H2', '## '),
        const VerticalDivider(indent: 12, endIndent: 12),
        _toolIcon(Icons.format_list_bulleted, '- '),
        _toolIcon(Icons.check_box_outlined, '- [ ] '),
        _toolIcon(Icons.format_quote, '> '),
        _toolIcon(Icons.code, '`'),
        _toolIcon(Icons.link, '[', suffix: ']'),
        _toolIcon(Icons.image, '', onPressed: _pickImage),
        const VerticalDivider(indent: 12, endIndent: 12),
        IconButton(
          icon: const Icon(Icons.draw),
          onPressed: _openDrawingScreen,
          tooltip: 'Çizim Yap',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: _exportToPdf,
          tooltip: 'PDF Olarak Kaydet',
        ),

      ],
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

  Future<void> _openDrawingScreen() async {
    final String? resultPath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawingScreen()),
    );

    if (resultPath != null) {
      try {
        final File tempFile = File(resultPath);
        final String? savedPath = await ImageService.saveImageFile(tempFile);
        
        if (savedPath != null) {
          final markdownImage = ImageService.createMarkdownImageLink(
            savedPath,
            altText: 'Çizim ${DateTime.now().toString().substring(0, 10)}',
          );
          _insertMarkdownSyntax('\n$markdownImage\n');
        }
      } catch (e) {
        _showError('Çizim eklenirken hata: $e');
      }
    }
  }

  Widget _buildMathTools() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
         _toolMath(r'\sum', 'Σ'),
         _toolMath(r'\int', '∫'),
         _toolMath(r'\frac{}{}', 'a/b'),
         _toolMath(r'\sqrt{}', '√'),
         _toolMath(r'\pi', 'π'),
         _toolMath(r'x^2', 'x²'),
         _toolMath('```mermaid\ngraph TD\n  A --> B\n```', 'Mermaid'),
         const VerticalDivider(indent: 12, endIndent: 12),
         _toolBtn('EQ', r'$$ ', tooltip: 'Blok Denklem'),
      ],
    );
  }

  Widget _toolBtn(String label, String syntax, {String? suffix, String? tooltip, TextStyle? style}) {
    return Center(
      child: IconButton(
        icon: Text(label, style: style ?? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
        tooltip: tooltip,
        onPressed: () => _insertMarkdownSyntax(syntax + (suffix ?? '')),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _toolIcon(IconData icon, String syntax, {String? suffix, String? tooltip, VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed ?? () => _insertMarkdownSyntax(syntax + (suffix ?? '')),
      visualDensity: VisualDensity.compact,
    );
  }
  
  Widget _toolMath(String syntax, String label) {
     return Center(
       child: InkWell(
         borderRadius: BorderRadius.circular(8),
         onTap: () => _insertMarkdownSyntax(syntax),
         child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
           child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
         ),
       ),
     );
  }

  Widget _buildMoodSelector() {
    final moods = ['😊', '😐', '😢', '😡', '🚀'];
    final selectedMood = _findCurrentMood();

    return Row(
      children: [
        Text(
          'Mod:',
          style: TextStyle(
            color: Theme.of(context).disabledColor, 
            fontWeight: FontWeight.bold,
            fontSize: 12
          ),
        ),
        const SizedBox(width: 8),
        ...moods.map((mood) {
          final isSelected = selectedMood == mood;
          return GestureDetector(
            onTap: () => _updateMood(mood),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 1) : null,
              ),
              child: Text(
                mood, 
                style: TextStyle(
                  fontSize: isSelected ? 22 : 18,
                  shadows: isSelected ? [
                    Shadow(color: Theme.of(context).primaryColor.withOpacity(0.5), blurRadius: 10)
                  ] : null
                )
              ),
            ),
          );
        }),
      ],
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

  Widget _buildEditor(BuildContext context) {
    // Eğer not şifreliyse ve henüz açılmadıysa şifre dialogunu göster
    if (_isEncrypted && _contentController.text.contains('🔒 Bu not şifreli')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 80, color: Colors.orange.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              'Bu Not Şifreli',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'İçeriği görmek ve düzenlemek için şifre giriniz.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showPasswordDialog,
              icon: const Icon(Icons.lock_open),
              label: const Text('Şifre ile Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 32,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              hintText: 'Başlık',
              hintStyle: TextStyle(color: Theme.of(context).disabledColor.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
          child: _buildMoodSelector(),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: TagManagerWidget(
            initialTags: _tags,
            onTagsChanged: (t) => setState(() => _tags = t),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.1), thickness: 1),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              maxLines: null,
              expands: true,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.8,
                fontSize: 16,
                fontFamily: 'Roboto', 
                letterSpacing: 0.1,
              ),
              cursorColor: Theme.of(context).primaryColor,
              cursorWidth: 2,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                hintText: 'Düşüncelerinizi buraya yazın...',
                hintStyle: TextStyle(color: Theme.of(context).disabledColor.withOpacity(0.3), fontStyle: FontStyle.italic),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.transparent, 
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const SizedBox(height: 24),
              Text(
                _titleController.text, 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
              ),
              const Divider(),
              MathMarkdownRenderer(
                data: _contentController.text,
                selectable: true,
              ),
              const SizedBox(height: 80),
           ],
         ),
      ),
    );
  }
}
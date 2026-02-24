import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({Key? key}) : super(key: key);

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İçe/Dışa Aktar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Section
            _buildSection(
              title: 'Dışa Aktar',
              icon: Icons.upload_file,
              child: Column(
                children: [
                  _buildExportOption(
                    title: 'JSON Formatında Dışa Aktar',
                    description: 'Tüm notları JSON dosyası olarak dışa aktar',
                    icon: Icons.code,
                    onTap: () => _exportNotes('json'),
                  ),
                  const SizedBox(height: 12),
                  _buildExportOption(
                    title: 'Markdown Formatında Dışa Aktar',
                    description: 'Tüm notları ayrı markdown dosyaları olarak dışa aktar',
                    icon: Icons.description,
                    onTap: () => _exportNotes('markdown'),
                  ),
                  const SizedBox(height: 12),
                  _buildExportOption(
                    title: 'Arşiv Formatında Dışa Aktar',
                    description: 'Tüm notları ve medya dosyalarını zip arşivi olarak dışa aktar',
                    icon: Icons.archive,
                    onTap: () => _exportNotes('archive'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Import Section
            _buildSection(
              title: 'İçe Aktar',
              icon: Icons.download,
              child: Column(
                children: [
                  _buildImportOption(
                    title: 'JSON Dosyasından İçe Aktar',
                    description: 'JSON formatında dışa aktarılmış notları içe aktar',
                    icon: Icons.code,
                    onTap: () => _importNotes('json'),
                  ),
                  const SizedBox(height: 12),
                  _buildImportOption(
                    title: 'Markdown Dosyalarından İçe Aktar',
                    description: 'Birden çok markdown dosyasını içe aktar',
                    icon: Icons.description,
                    onTap: () => _importNotes('markdown'),
                  ),
                  const SizedBox(height: 12),
                  _buildImportOption(
                    title: 'Arşiv Dosyasından İçe Aktar',
                    description: 'Zip arşivindeki notları içe aktar',
                    icon: Icons.archive,
                    onTap: () => _importNotes('archive'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status Message
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildExportOption({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: _isExporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: _isExporting ? null : onTap,
      ),
    );
  }

  Widget _buildImportOption({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: _isImporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: _isImporting ? null : onTap,
      ),
    );
  }

  Future<void> _exportNotes(String format) async {
    setState(() {
      _isExporting = true;
      _statusMessage = '';
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final notes = noteProvider.notes;

      switch (format) {
        case 'json':
          await _exportAsJson(notes);
          break;
        case 'markdown':
          await _exportAsMarkdown(notes);
          break;
        case 'archive':
          await _exportAsArchive(notes);
          break;
      }

      setState(() {
        _statusMessage = 'Notlar başarıyla dışa aktarıldı';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Dışa aktarım hatası: $e';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _importNotes(String format) async {
    setState(() {
      _isImporting = true;
      _statusMessage = '';
    });

    try {
      switch (format) {
        case 'json':
          await _importFromJson();
          break;
        case 'markdown':
          await _importFromMarkdown();
          break;
        case 'archive':
          await _importFromArchive();
          break;
      }

      setState(() {
        _statusMessage = 'Notlar başarıyla içe aktarıldı';
      });
      
      // Refresh notes list
      Provider.of<NoteProvider>(context, listen: false).loadNotes();
    } catch (e) {
      setState(() {
        _statusMessage = 'İçe aktarım hatası: $e';
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _exportAsJson(List<Note> notes) async {
    final data = notes.map((note) => note.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    
    final fileName = 'notes_export_${DateTime.now().millisecondsSinceEpoch}.json';
    await _saveFile(fileName, jsonString);
  }

  Future<void> _exportAsMarkdown(List<Note> notes) async {
    final archive = Archive();
    
    for (final note in notes) {
      final fileName = '${note.title.replaceAll(RegExp(r'[^\w\s-]'), '_').trim()}.md';
      final content = '''# ${note.title}

**Oluşturulma:** ${DateTime.fromMillisecondsSinceEpoch(note.createdAt)}
**Güncellenme:** ${DateTime.fromMillisecondsSinceEpoch(note.updatedAt)}
**Etiketler:** ${note.tags.map((tag) => '#$tag').join(' ')}

---

${note.content}
''';
      archive.addFile(ArchiveFile(fileName, content.length, content.codeUnits));
    }
    
    final zipData = ZipEncoder().encode(archive);
    final fileName = 'notes_markdown_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    await _saveFile(fileName, zipData!);
  }

  Future<void> _exportAsArchive(List<Note> notes) async {
    final archive = Archive();
    
    // Add notes as JSON
    final notesData = notes.map((note) => note.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(notesData);
    archive.addFile(ArchiveFile('notes.json', jsonString.length, jsonString.codeUnits));
    
    // Add individual markdown files
    for (final note in notes) {
      final fileName = 'notes/${note.title.replaceAll(RegExp(r'[^\w\s-]'), '_').trim()}.md';
      final content = '''# ${note.title}

**Oluşturulma:** ${DateTime.fromMillisecondsSinceEpoch(note.createdAt)}
**Güncellenme:** ${DateTime.fromMillisecondsSinceEpoch(note.updatedAt)}
**Etiketler:** ${note.tags.map((tag) => '#$tag').join(' ')}

---

${note.content}
''';
      archive.addFile(ArchiveFile(fileName, content.length, content.codeUnits));
    }
    
    final zipData = ZipEncoder().encode(archive);
    final fileName = 'notes_archive_export_${DateTime.now().millisecondsSinceEpoch}.zip';
    await _saveFile(fileName, zipData!);
  }

  Future<void> _importFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.bytes != null) {
      final jsonString = utf8.decode(result.files.single.bytes!);
      final List<dynamic> data = json.decode(jsonString);
      
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      for (final item in data) {
        final note = Note.fromMap(item as Map<String, dynamic>);
        await noteProvider.addNote(note);
      }
    }
  }

  Future<void> _importFromMarkdown() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
      allowMultiple: true,
    );

    if (result != null) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      for (final file in result.files) {
        if (file.bytes != null) {
          final content = utf8.decode(file.bytes!);
          final lines = content.split('\n');
          
          String title = file.name.replaceAll(RegExp(r'\.(md|markdown)$'), '');
          String noteContent = content;
          
          // Try to extract title from first line if it starts with #
          if (lines.isNotEmpty && lines.first.startsWith('# ')) {
            title = lines.first.substring(2);
            noteContent = lines.skip(1).join('\n');
          }
          
          final note = Note(
            title: title,
            content: noteContent,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          
          await noteProvider.addNote(note);
        }
      }
    }
  }

  Future<void> _importFromArchive() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      for (final file in archive) {
        if (file.name == 'notes.json') {
          final jsonString = utf8.decode(file.content as List<int>);
          final List<dynamic> data = json.decode(jsonString);
          
          for (final item in data) {
            final note = Note.fromMap(item as Map<String, dynamic>);
            await noteProvider.addNote(note);
          }
          break;
        }
      }
    }
  }

  Future<void> _saveFile(String fileName, dynamic data) async {
    String? outputFile;
    try {
      if (data is String) {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Dosyayı Kaydet',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json', 'txt'],
        );
      } else {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Arşivi Kaydet',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
      }

      if (outputFile != null) {
        final file = File(outputFile);
        if (data is String) {
          await file.writeAsString(data);
        } else if (data is List<int>) {
          await file.writeAsBytes(data);
        }
        
        setState(() {
          _statusMessage = 'Dosya başarıyla kaydedildi: $outputFile';
        });
      } else {
        setState(() {
          _statusMessage = 'Kaydetme iptal edildi.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Kaydetme hatası: $e';
      });
    }
  }
}

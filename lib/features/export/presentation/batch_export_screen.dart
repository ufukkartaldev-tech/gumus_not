import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class BatchExportScreen extends StatefulWidget {
  const BatchExportScreen({Key? key}) : super(key: key);

  @override
  State<BatchExportScreen> createState() => _BatchExportScreenState();
}

class _BatchExportScreenState extends State<BatchExportScreen> {
  List<Note> _selectedNotes = [];
  bool _isExporting = false;
  String _exportFormat = 'txt';
  bool _includeEncrypted = false;
  String? _exportPath;
  int _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    await noteProvider.loadNotes();
    setState(() {
      _selectedNotes = noteProvider.notes;
    });
  }

  Future<void> _startExport() async {
    if (_selectedNotes.isEmpty) {
      _showError(context, 'Lütfen dışa aktarılacak notları seçin.');
      return;
    }

    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory == null) return;

    setState(() {
      _isExporting = true;
      _exportPath = directory;
      _errorMessage = null;
      _progress = 0;
    });

    try {
      // Simple text export for now
      await _exportToText(directory);
      _showSuccess(context, 'Notlar başarıyla dışa aktarıldı!', directoryPath: directory);
    } catch (e) {
      _showError(context, 'Dışa aktarma hatası: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _exportToText(String directoryPath) async {
    final directory = Directory(directoryPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/notes_export_$timestamp.txt');
    
    final content = StringBuffer();
    for (int i = 0; i < _selectedNotes.length; i++) {
      final note = _selectedNotes[i];
      content.writeln('=== ${note.title} ===');
      content.writeln('Created: ${DateTime.fromMillisecondsSinceEpoch(note.createdAt)}');
      content.writeln('Tags: ${note.tags.join(', ')}');
      content.writeln('');
      content.writeln(note.content);
      content.writeln('');
      content.writeln('');
      
      setState(() {
        _progress = ((i + 1) / _selectedNotes.length * 100).round();
      });
    }
    
    await file.writeAsString(content.toString());
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message, {String? directoryPath}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        action: directoryPath != null
            ? SnackBarAction(
                label: 'Klasörü Aç',
                textColor: Colors.white,
                onPressed: () => _openDirectory(directoryPath),
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _openDirectory(String directoryPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [directoryPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [directoryPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directoryPath]);
      }
    } catch (e) {
      _showError(context, 'Klasör açılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplu Dışa Aktar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFormatSelector(),
            const SizedBox(height: 16),
            _buildNoteList(),
            const SizedBox(height: 16),
            _buildExportButton(),
            if (_isExporting) ...[
              const SizedBox(height: 16),
              _buildProgressIndicator(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dışa Aktarma Formatı',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('TXT'),
                  value: 'txt',
                  groupValue: _exportFormat,
                  onChanged: (value) {
                    setState(() {
                      _exportFormat = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('PDF'),
                  value: 'pdf',
                  groupValue: _exportFormat,
                  onChanged: (value) {
                    setState(() {
                      _exportFormat = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Seçili Notlar: ${_selectedNotes.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedNotes.length == Provider.of<NoteProvider>(context).notes.length) {
                        _selectedNotes = [];
                      } else {
                        _selectedNotes = List.from(Provider.of<NoteProvider>(context).notes);
                      }
                    });
                  },
                  child: Text(_selectedNotes.length == Provider.of<NoteProvider>(context).notes.length 
                      ? 'Hepsini Kaldır' 
                      : 'Hepsini Seç'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedNotes.length,
                itemBuilder: (context, index) {
                  final note = _selectedNotes[index];
                  return CheckboxListTile(
                    title: Text(note.title),
                    subtitle: Text(
                      '${note.tags.join(', ')} • ${DateTime.fromMillisecondsSinceEpoch(note.createdAt).toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: true,
                    onChanged: (value) {
                      setState(() {
                        if (value == false) {
                          _selectedNotes.removeAt(index);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _startExport,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        child: Text(
          _isExporting ? 'Dışa Aktarılıyor...' : 'Dışa Aktarı Başla',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$_progress% tamamlandı',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

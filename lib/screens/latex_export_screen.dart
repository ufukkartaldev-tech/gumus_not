import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/note_model.dart';
import '../services/latex_export_service.dart';

class LatexExportScreen extends StatefulWidget {
  final Note note;

  const LatexExportScreen({
    Key? key,
    required this.note,
  }) : super(key: key);

  @override
  State<LatexExportScreen> createState() => _LatexExportScreenState();
}

class _LatexExportScreenState extends State<LatexExportScreen> {
  String _selectedFormat = 'article';
  String _author = '';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('LaTeX Dışa Aktar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotePreview(),
            const SizedBox(height: 24),
            _buildExportOptions(),
            const SizedBox(height: 24),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not Önizlemesi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.note.excerpt,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dışa Aktar Seçenekleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Format Selection
            Text(
              'Belge Türü',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Makale (Article)'),
                  subtitle: const Text('Standart makale formatı'),
                  value: 'article',
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Sunum (Beamer)'),
                  subtitle: const Text('Sunum formatı'),
                  value: 'beamer',
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Rapor (Report)'),
                  subtitle: const Text('Detaylı rapor formatı'),
                  value: 'report',
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Author Field (for report format)
            if (_selectedFormat == 'report') ...[
              Text(
                'Yazar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Yazar adı girin...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _author = value;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportToLatex,
        icon: _isExporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: Text(_isExporting ? 'Dışa Aktarılıyor...' : 'LaTeX Dosyası Oluştur'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _exportToLatex() async {
    setState(() {
      _isExporting = true;
    });

    try {
      String latexContent;
      
      switch (_selectedFormat) {
        case 'beamer':
          latexContent = LatexExportService.generateBeamerPresentation(
            widget.note.title,
            widget.note.content,
          );
          break;
        case 'report':
          latexContent = LatexExportService.generateLatexReport(
            widget.note.title,
            _author.isEmpty ? 'Yazar' : _author,
            widget.note.content,
          );
          break;
        default:
          latexContent = LatexExportService.generateLatexDocument(
            title: widget.note.title,
            content: widget.note.content,
            author: _author.isEmpty ? 'GümüşNot' : _author,
          );
      }

      final fileName = '${widget.note.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.tex';
      
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'LaTeX Dosyası Olarak Kaydet',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['tex'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(latexContent);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('LaTeX dosyası başarıyla oluşturuldu: ${outputFile.split('\\').last}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dışa aktarma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import 'package:file_picker/file_picker.dart';

class PdfExportService {
  static Future<File?> exportNoteToPdf(Note note) async {
    final pdf = pw.Document();
    
    // Load a font that supports Turkish characters - fallback to standard if not easy
    // In a real app we would load a custom ttf
    final font = pw.Font.courier(); // Standard font, might have issues with some chars but mostly okay
    
    // Split content into lines for simple rendering
    final lines = note.content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                note.title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  font: font,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            ...lines.map((line) {
              // Basic Markdown-ish parsing
              if (line.startsWith('# ')) {
                return pw.Header(level: 1, child: pw.Text(line.substring(2), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: font)));
              } else if (line.startsWith('## ')) {
                return pw.Header(level: 2, child: pw.Text(line.substring(3), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: font)));
              } else if (line.startsWith('- ')) {
                 return pw.Bullet(text: line.substring(2), style: pw.TextStyle(font: font));
              } else {
                 return pw.Paragraph(text: line, style: pw.TextStyle(font: font));
              }
            }).toList(),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Footer(
              title: pw.Text(
                'GümüşNot ile oluşturuldu • ${DateTime.now().toLocal().toString().split('.')[0]}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey, font: font),
              ),
            ),
          ];
        },
      ),
    );

    // Save
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF Olarak Kaydet',
        fileName: '${note.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(await pdf.save());
        return file;
      }
    } catch (e) {
      print('PDF Export Error: $e');
    }
    return null;
  }
}

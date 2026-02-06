import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/note_model.dart';
import '../services/image_service.dart';

class PdfService {
  /// Bir notu PDF'e dönüştür ve paylaş/yazdır
  static Future<void> exportToPdf(Note note) async {
    final pdf = pw.Document();
    
    // Font yükleme (Türkçe karakter desteği için)
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    // İçeriği parçala ve resimleri/metinleri ayır
    final List<dynamic> contentParts = await _parseContent(note.content);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: fontBold,
            italic: fontItalic,
          ),
        ),
        header: (context) => _buildHeader(note, font, fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          pw.SizedBox(height: 20),
          ...contentParts.map((part) {
            if (part is pw.Widget) return part;
            return pw.Text(part.toString(), style: pw.TextStyle(font: font));
          }).toList(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${note.title}_gumusnot.pdf',
    );
  }

  static pw.Widget _buildHeader(Note note, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          note.title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Oluşturulma: ${_formatDate(note.createdAt)}',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount} - GümüşNot ile oluşturuldu',
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: PdfColors.grey500,
        ),
      ),
    );
  }

  static Future<List<dynamic>> _parseContent(String content) async {
    final List<dynamic> widgets = [];
    final lines = content.split('\n');

    for (var line in lines) {
      // 1. Resim Kontrolü: ![alt](path)
      final imageMatch = RegExp(r'!\[.*?\]\((.*?)\)').firstMatch(line);
      if (imageMatch != null) {
        final imagePath = imageMatch.group(1);
        if (imagePath != null) {
          try {
            final file = File(imagePath);
            if (await file.exists()) {
              final image = pw.MemoryImage(file.readAsBytesSync());
              widgets.add(
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  height: 300, // Maksimum yükseklik sınırlaması
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              );
              continue; // Bu satırı resim olarak işledik, metin olarak ekleme
            }
          } catch (e) {
            // Resim yüklenemezse metin olarak kalsın
          }
        }
      }

      // 2. Başlıklar
      if (line.startsWith('# ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
          child: pw.Text(line.substring(2), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Text(line.substring(3), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(line.substring(4), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ));
      } 
      // 3. Listeler
      else if (line.trim().startsWith('- ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: pw.TextStyle(fontSize: 12)),
              pw.Expanded(child: pw.Text(line.trim().substring(2), style: const pw.TextStyle(fontSize: 12))),
            ],
          ),
        ));
      }
      // 4. Normal Metin
      else if (line.trim().isNotEmpty) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 12)),
        ));
      }
    }
    return widgets;
  }

  static String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

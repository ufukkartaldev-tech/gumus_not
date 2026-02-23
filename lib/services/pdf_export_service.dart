import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<File?> exportNoteToPdf(Note note) async {
    final pdf = pw.Document();
    
    // PREMIUM: Google Fonts kullanarak Türkçe karakter desteği getiriyoruz
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final italicFont = await PdfGoogleFonts.robotoItalic();
    
    // İçeriği satırlara böl
    final lines = note.content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'GümüşNot Profesyonel Döküman',
              style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8, font: font),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            border: const pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Oluşturulma: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font),
                ),
                pw.Text(
                  'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Başlık Bölümü
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      note.title.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),
            
            // İçerik Bölümü
            ...lines.map((line) {
              final trimmed = line.trim();
              
              // 1. Resim Kontrolü: ![alt](path)
              final imageMatch = RegExp(r'!\[.*?\]\((.*?)\)').firstMatch(trimmed);
              if (imageMatch != null) {
                final imagePath = imageMatch.group(1);
                if (imagePath != null && File(imagePath).existsSync()) {
                  final image = pw.MemoryImage(File(imagePath).readAsBytesSync());
                  return pw.Container(
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.symmetric(vertical: 10),
                    height: 250,
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  );
                }
              }

              if (trimmed.startsWith('# ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 15, bottom: 5),
                  child: pw.Text(trimmed.substring(2), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: boldFont, color: PdfColors.blue800)),
                );
              } else if (trimmed.startsWith('## ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                  child: pw.Text(trimmed.substring(3), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: boldFont, color: PdfColors.grey800)),
                );
              } else if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('- [x] ')) {
                final isDone = trimmed.startsWith('- [x] ');
                return pw.Row(
                  children: [
                    pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey), borderRadius: pw.BorderRadius.circular(2))),
                    pw.SizedBox(width: 8),
                    pw.Text(trimmed.substring(6), style: pw.TextStyle(font: font, color: isDone ? PdfColors.grey : PdfColors.black)),
                  ],
                );
              } else if (trimmed.startsWith('- ')) {
                return pw.Bullet(text: trimmed.substring(2), style: pw.TextStyle(font: font, fontSize: 11));
              } else if (trimmed.startsWith('> ')) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border(left: pw.BorderSide(color: PdfColors.grey400, width: 3))),
                  child: pw.Text(trimmed.substring(2), style: pw.TextStyle(font: italicFont, color: PdfColors.grey800, fontSize: 11)),
                );
              } else if (trimmed.isEmpty) {
                return pw.SizedBox(height: 8);
              } else {
                return pw.Paragraph(
                  text: trimmed,
                  style: pw.TextStyle(font: font, fontSize: 11, lineHeight: 1.5, color: PdfColors.grey900),
                  textAlign: pw.TextAlign.justify,
                );
              }
            }).toList(),
          ];
        },
      ),
    );

    // Kaydetme Diyaloğu
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Profesyonel PDF Olarak Kaydet',
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

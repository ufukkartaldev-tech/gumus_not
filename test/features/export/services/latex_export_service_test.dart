import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/export/services/latex_export_service.dart';

void main() {
  group('LatexExportService Tests', () {
    test('converts markdown headings to LaTeX sections', () {
      const markdown = '''# Birinci Seviye
## İkinci Seviye
### Üçüncü Seviye''';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\section{Birinci Seviye}'));
      expect(latex, contains('\\subsection{İkinci Seviye}'));
      expect(latex, contains('\\subsubsection{Üçüncü Seviye}'));
    });

    test('converts unordered lists to LaTeX itemize environment', () {
      const markdown = '''- Birinci madde
- İkinci madde
- Üçüncü madde''';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\begin{itemize}'));
      expect(latex, contains('\\item Birinci madde'));
      expect(latex, contains('\\item İkinci madde'));
      expect(latex, contains('\\item Üçüncü madde'));
      expect(latex, contains('\\end{itemize}'));
    });

    test('converts code blocks to verbatim environment', () {
      const markdown = '''```dart
void main() {
  print('Merhaba');
}
```''';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\begin{verbatim}'));
      expect(latex, contains("print('Merhaba');"));
      expect(latex, contains('\\end{verbatim}'));
    });

    test('converts blockquotes to quote environment', () {
      const markdown = '> Bu önemli bir alıntıdır.';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\begin{quote}'));
      expect(latex, contains('Bu önemli bir alıntıdır.'));
      expect(latex, contains('\\end{quote}'));
    });

    test('converts inline bold, italic, and code styling', () {
      const markdown = 'Bu **kalın**, bu *italik* ve bu `kod` örneğidir.';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\textbf{kalın}'));
      expect(latex, contains('\\textit{italik}'));
      expect(latex, contains('\\texttt{kod}'));
    });

    test('converts math formulas correctly', () {
      const markdown = 'Inline formül: \$E=mc^2\$ ve Blok: \$\$\\int_0^1 x dx\$\$';

      final latex = LatexExportService.convertToLatex(markdown);

      expect(latex, contains('\\( E=mc^2 \\)'));
      expect(latex, contains('\\[ \\int_0^1 x dx \\]'));
    });

    test('generateLatexDocument produces complete document with preamble', () {
      final doc = LatexExportService.generateLatexDocument(
        title: 'Fizik Notları',
        content: '# Giriş\nİlk paragraf.',
        author: 'Ahmet',
      );

      expect(doc, contains('\\documentclass[12pt,a4paper]{article}'));
      expect(doc, contains('\\title{Fizik Notları}'));
      expect(doc, contains('\\author{Ahmet}'));
      expect(doc, contains('\\begin{document}'));
      expect(doc, contains('\\section{Giriş}'));
      expect(doc, contains('\\end{document}'));
    });
  });
}

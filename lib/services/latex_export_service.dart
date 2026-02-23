import 'package:flutter/material.dart';

class LatexExportService {
  static String convertToLatex(String markdownContent) {
    List<String> lines = markdownContent.split('\n');
    List<String> resultLines = [];
    bool inList = false;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      String trimmed = line.trim();

      // Liste Yönetimi (Itemize)
      if (trimmed.startsWith('- ')) {
        if (!inList) {
          resultLines.add('\\begin{itemize}');
          inList = true;
        }
        resultLines.add('  \\item ${trimmed.substring(2)}');
      } else {
        if (inList) {
          resultLines.add('\\end{itemize}');
          inList = false;
        }

        // Başlıklar
        if (trimmed.startsWith('# ')) {
          resultLines.add('\\section{${trimmed.substring(2)}}');
        } else if (trimmed.startsWith('## ')) {
          resultLines.add('\\subsection{${trimmed.substring(3)}}');
        } else if (trimmed.startsWith('### ')) {
          resultLines.add('\\subsubsection{${trimmed.substring(4)}}');
        } 
        // Kod Blokları
        else if (trimmed.startsWith('```')) {
          resultLines.add('\\begin{verbatim}');
          i++;
          while (i < lines.length && !lines[i].trim().startsWith('```')) {
            resultLines.add(lines[i]);
            i++;
          }
          resultLines.add('\\end{verbatim}');
        }
        // Alıntılar
        else if (trimmed.startsWith('> ')) {
          resultLines.add('\\begin{quote}');
          resultLines.add(trimmed.substring(2));
          resultLines.add('\\end{quote}');
        }
        // Standart Paragraf
        else if (trimmed.isNotEmpty) {
          resultLines.add(trimmed);
        } else {
          resultLines.add(''); // Boş satır
        }
      }
    }
    
    if (inList) resultLines.add('\\end{itemize}');

    String combined = resultLines.join('\n');

    // Satır içi formatlamalar (Inline)
    combined = combined.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '\\textbf{${m.group(1)}}');
    combined = combined.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '\\textit{${m.group(1)}}');
    combined = combined.replaceAllMapped(RegExp(r'`(.+?)`'), (m) => '\\texttt{${m.group(1)}}');
    
    // Matematik
    combined = combined.replaceAllMapped(RegExp(r'\$\$(.+?)\$\$', dotAll: true), (m) => '\\[ ${m.group(1)} \\]');
    combined = combined.replaceAllMapped(RegExp(r'\$(.+?)\$'), (m) => '\\( ${m.group(1)} \\)');

    return combined;
  }

  static String generateLatexDocument({required String title, required String content, String author = 'GümüşNot'}) {
    final convertedContent = convertToLatex(content);
    
    return '''
\\documentclass[12pt,a4paper]{article}
\\usepackage[utf8]{inputenc}
\\usepackage[turkish]{babel} % TÜRKÇE DESTEĞİ
\\usepackage[T1]{fontenc}
\\usepackage{amsmath, amsfonts, amssymb}
\\usepackage{graphicx}
\\usepackage{hyperref}
\\usepackage{geometry}
\\usepackage{xcolor}
\\usepackage{verbatim}

\\geometry{a4paper, margin=1in}

\\title{$title}
\\author{$author}
\\date{\\today}

\\begin{document}

\\maketitle
\\newpage

$convertedContent

\\end{document}
''';
  }

  static String generateBeamerPresentation(String title, String content) {
    final convertedContent = convertToLatex(content);
    
    return '''
\\documentclass[12pt]{beamer}
\\usepackage[utf8]{inputenc}
\\usepackage[turkish]{babel}
\\usepackage[T1]{fontenc}
\\usepackage{amsmath, amsfonts, amssymb}

\\usetheme{Madrid}
\\title{$title}
\\author{GümüşNot}

\\begin{document}
\\frame{\\titlepage}

\\begin{frame}[fragile]
$convertedContent
\\end{frame}

\\end{document}
''';
  }
}

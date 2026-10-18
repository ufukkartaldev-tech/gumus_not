import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/github.dart';
import 'package:flutter_highlighter/themes/darcula.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class WikilinkSyntax extends md.InlineSyntax {
  WikilinkSyntax() : super(r'\[\[(.*?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match.group(1)!;
    final element = md.Element('a', [md.Text('[[$title]]')]);
    element.attributes['href'] = 'zettel://$title';
    parser.addNode(element);
    return true;
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^\$\n]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match.group(1)!;
    final element = md.Element.text('inline-math', formula);
    parser.addNode(element);
    return true;
  }
}

class InlineMathBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  InlineMathBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final formula = element.textContent.trim();
    final textStyle = preferredStyle ?? Theme.of(context).textTheme.bodyMedium;
    return Math.tex(
      formula,
      mathStyle: MathStyle.text,
      textStyle: textStyle,
      onErrorFallback: (err) => Text(
        '\$$formula\$',
        style: (textStyle ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class MathMarkdownRenderer extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool selectable;

  const MathMarkdownRenderer({
    super.key,
    required this.data,
    this.style,
    this.textAlign,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    return _parseMarkdownWithMathAndMermaid(context, data);
  }

  Widget _parseMarkdownWithMathAndMermaid(BuildContext context, String text) {
    // 1. First, split by Math blocks ($$ ... $$)
    final mathRegex = RegExp(r'(\$\$[\s\S]*?\$\$)');
    final mathMatches = mathRegex.allMatches(text);
    final textParts = text.split(mathRegex);
    
    final finalWidgets = <Widget>[];
    
    for (int i = 0; i < textParts.length; i++) {
      // Process the non-math part for Mermaid blocks
      if (textParts[i].isNotEmpty) {
        finalWidgets.addAll(_parseMermaidBlocks(context, textParts[i]));
      }
      
      // Add the math block if exists
      if (i < mathMatches.length) {
        final mathContent = mathMatches.elementAt(i).group(0)!;
        finalWidgets.add(_buildMathBlock(context, mathContent));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: finalWidgets,
    );
  }

  List<Widget> _parseMermaidBlocks(BuildContext context, String text) {
    // Regular expression for mermaid code blocks: ```mermaid ... ```
    final mermaidRegex = RegExp(r'(```mermaid\s*\n?([\s\S]*?)```)');
    final matches = mermaidRegex.allMatches(text);
    final parts = text.split(mermaidRegex);
    
    final widgets = <Widget>[];
    
    for (int i = 0; i < parts.length; i++) {
      // 1. Render standard Markdown for this part
      if (parts[i].trim().isNotEmpty) {
        widgets.add(MarkdownBody(
          data: parts[i],
          selectable: selectable,
          shrinkWrap: true,
          extensionSet: md.ExtensionSet(
            md.ExtensionSet.gitHubFlavored.blockSyntaxes,
            [
              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
              WikilinkSyntax(),
              InlineMathSyntax(),
            ],
          ),
          onTapLink: (text, href, title) {
            if (href != null && href.startsWith('zettel://')) {
              final targetTitle = href.replaceFirst('zettel://', '');
              // Try to find the note by title
              final provider = Provider.of<NoteProvider>(context, listen: false);
              final note = provider.notes.where((n) => n.title.toLowerCase() == targetTitle.toLowerCase()).firstOrNull;
              if (note != null) {
                // Navigate to note
                Navigator.of(context).pushNamed('/note-editor', arguments: note);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Not bulunamadı: $targetTitle')),
                );
              }
            }
          },
          builders: {
            'code': CodeElementBuilder(context),
            'inline-math': InlineMathBuilder(context),
          },
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: style ?? Theme.of(context).textTheme.bodyMedium,
            blockquoteDecoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 4)),
            ),
          ),
          sizedImageBuilder: (config) =>
              _buildMarkdownImage(config.uri, config.title, config.alt),
        ));
      }
      
      // 2. Render Mermaid block if exists
      if (i < matches.length) {
        final mermaidContent = matches.elementAt(i).group(2)!.trim();
        widgets.add(_buildMermaidBlock(context, mermaidContent));
      }
    }
    
    return widgets;
  }

  Widget _buildMarkdownImage(Uri uri, String? title, String? alt) {
    try {
      // Network image
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            uri.toString(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 100,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildImageError(alt),
          ),
        );
      }
      
      // Local file image
      final file = File(uri.scheme == 'file' ? uri.toFilePath() : uri.toString());
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            errorBuilder: (context, error, stackTrace) => _buildImageError(alt),
          ),
        ),
      );
    } catch (e) {
      return _buildImageError('Hata: $e');
    }
  }

  Widget _buildImageError(String? message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.orange),
          const SizedBox(width: 8),
          Text(message ?? 'Resim yüklenemedi', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMathBlock(BuildContext context, String content) {
    final formula = content.replaceAll(r'$$', '').trim();
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            formula,
            mathStyle: MathStyle.display,
            textStyle: textStyle,
            onErrorFallback: (err) => Text(
              formula,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMermaidBlock(BuildContext context, String content) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 15, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Diyagram Şeması (Mermaid — Yerel / Çevrimdışı)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Mermaid Kodunu Kopyala',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mermaid şeması panoya kopyalandı!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.tealAccent.shade100 : Colors.blueGrey.shade900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      } else {
        language = lg;
      }
    }
    
    // Check if it's a code block (multiline) or inline code
    final isCodeBlock = element.textContent.contains('\n');
    
    if (!isCodeBlock && language.isEmpty) {
      // Inline code
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey.shade800 
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          element.textContent,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    }

    final codeText = element.textContent.trimRight();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xff2b2b2b) 
            : const Color(0xfff8f8f8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                codeText,
                language: language.isEmpty ? 'plaintext' : language,
                theme: Theme.of(context).brightness == Brightness.dark 
                    ? darculaTheme 
                    : githubTheme,
                padding: const EdgeInsets.all(0),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              tooltip: 'Kodu Kopyala',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codeText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kod panoya kopyalandı!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          if (language.isNotEmpty)
            Positioned(
              top: 12,
              left: 16,
              child: Text(
                language.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

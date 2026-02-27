import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:connected_notebook/features/media/widgets/image_picker_widget.dart';

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
          imageBuilder: _buildMarkdownImage,
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
              color: Colors.black.withOpacity(0.1),
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            content.replaceAll(r'$$', '').trim(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMermaidBlock(BuildContext context, String content) {
    // Use mermaid.ink to render the diagram as an SVG
    final encodedContent = base64UrlEncode(utf8.encode(content));
    final imageUrl = 'https://mermaid.ink/svg/$encodedContent';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_graph, size: 14, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Diyagram (Mermaid)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.zoom_out_map, size: 14, color: Colors.grey),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(height: 8),
                      const Text('Diyagram çizilemedi.'),
                      TextButton(
                        onPressed: () {}, // Future: Open in browser
                        child: const Text('Düzenlemede hata olabilir mi?'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedMarkdownEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String) onContentChanged;
  final bool showPreview;

  const EnhancedMarkdownEditor({
    super.key,
    this.initialContent,
    required this.onContentChanged,
    this.showPreview = false,
  });

  @override
  State<EnhancedMarkdownEditor> createState() => _EnhancedMarkdownEditorState();
}

class _EnhancedMarkdownEditorState extends State<EnhancedMarkdownEditor> {
  late TextEditingController _controller;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent ?? '');
    _isPreviewMode = widget.showPreview;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertMathSyntax(String syntax) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    final cursorPos = selection.baseOffset;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      syntax,
    );
    
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorPos + syntax.length,
      ),
    );
    
    widget.onContentChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMathToolbar(context),
        Expanded(
          child: _isPreviewMode ? _buildPreview(context) : _buildEditor(),
        ),
      ],
    );
  }

  Widget _buildMathToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMathButton(context, 'x^2', 'Üst'),
            _buildMathButton(context, 'x_2', 'Alt'),
            _buildMathButton(context, '\\frac{x}{y}', 'Kesir'),
            _buildMathButton(context, r'$$\n$$', 'Matematik Bloğu'),
            _buildMathButton(context, '```mermaid\ngraph TD\n  A --> B\n```', 'Diyagram (Mermaid)'),
          ],
        ),
      ),
    );
  }

  Widget _buildMathButton(BuildContext context, String syntax, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _insertMathSyntax(syntax),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                syntax.replaceAll(r'$$\n$$', 'Bloğu'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(16),
        hintText: 'Markdown yazın...',
      ),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
      ),
      onChanged: widget.onContentChanged,
    );
  }

  Widget _buildPreview(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MathMarkdownRenderer(
        data: _controller.text,
        style: Theme.of(context).textTheme.bodyMedium,
        selectable: true,
      ),
    );
  }
}

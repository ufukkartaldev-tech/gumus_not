import 'package:flutter/material.dart';

/// An intelligent [TextEditingController] that provides live in-line markdown preview.
///
/// Features:
/// - Cursor-aware heading scaling: When the cursor is outside a heading line (# or ##),
///   the `#` tokens are dimmed and the text scales up to H1/H2 sizes, creating a Notion/Medium feel.
/// - In-line styling for Bold, Italic, Strikethrough, Code, Math ($fx$), WikiLinks ([[ ]]),
///   Interactive Checklists (- [ ] / - [x]), Blockquotes, and Lists.
/// - Character-count strictly preserved so caret positioning and selection remain 100% accurate.
class MarkdownLivePreviewController extends TextEditingController {
  MarkdownLivePreviewController({super.text});

  static final RegExp _inlineRegex = RegExp(
    r'(\*\*[^\*\n]+?\*\*)|' // 1: bold **text**
    r'(\*[^\*\n]+?\*)|' // 2: italic *text*
    r'(~~[^~\n]+?~~)|' // 3: strikethrough ~~text~~
    r'(`[^`\n]+?`)|' // 4: code `code`
    r'(\[\[[^\]\n]+?\]\])|' // 5: wikilink [[page]]
    r'(\$[^\$\n]+?\$)|' // 6: math $formula$
    r'(!?\[[^\]\n]*?\]\([^\)\n]+?\))', // 7: link or image
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultStyle = style ??
        theme.textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, height: 1.6);

    if (text.isEmpty) {
      return TextSpan(style: defaultStyle, text: '');
    }

    final cursorPos = selection.isValid ? selection.baseOffset : -1;
    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    int currentOffset = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLength = line.length;
      final lineEnd = currentOffset + lineLength;
      final isCursorOnLine = cursorPos >= currentOffset && cursorPos <= lineEnd;

      _renderLine(
        spans: spans,
        line: line,
        isCursorOnLine: isCursorOnLine,
        defaultStyle: defaultStyle,
        theme: theme,
        isDark: isDark,
      );

      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: defaultStyle));
      }

      currentOffset = lineEnd + 1; // +1 for '\n'
    }

    return TextSpan(style: defaultStyle, children: spans);
  }

  void _renderLine({
    required List<InlineSpan> spans,
    required String line,
    required bool isCursorOnLine,
    required TextStyle defaultStyle,
    required ThemeData theme,
    required bool isDark,
  }) {
    if (line.isEmpty) {
      return;
    }

    // Code block marker ```
    if (line.startsWith('```')) {
      spans.add(
        TextSpan(
          text: line,
          style: defaultStyle.copyWith(
            fontFamily: 'monospace',
            color: isDark ? Colors.tealAccent.shade100 : Colors.teal.shade800,
            backgroundColor: theme.dividerColor.withOpacity(0.12),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      return;
    }

    // Heading 1: # Title
    if (line.startsWith('# ')) {
      final prefix = '# ';
      final content = line.substring(2);
      final prefixColor = isCursorOnLine
          ? theme.colorScheme.primary.withOpacity(0.55)
          : theme.colorScheme.primary.withOpacity(0.20);
      final prefixSize = isCursorOnLine ? 18.0 : 13.0;

      final headingStyle = defaultStyle.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: theme.colorScheme.primary,
        height: 1.35,
      );

      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: prefixColor,
            fontSize: prefixSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      _renderInline(spans, content, headingStyle, theme, isDark);
      return;
    }

    // Heading 2: ## Title
    if (line.startsWith('## ')) {
      final prefix = '## ';
      final content = line.substring(3);
      final prefixColor = isCursorOnLine
          ? theme.colorScheme.secondary.withOpacity(0.55)
          : theme.colorScheme.secondary.withOpacity(0.20);
      final prefixSize = isCursorOnLine ? 16.0 : 12.0;

      final headingStyle = defaultStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: theme.colorScheme.secondary,
        height: 1.35,
      );

      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: prefixColor,
            fontSize: prefixSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      _renderInline(spans, content, headingStyle, theme, isDark);
      return;
    }

    // Heading 3: ### Title
    if (line.startsWith('### ')) {
      final prefix = '### ';
      final content = line.substring(4);
      final prefixColor = isCursorOnLine
          ? theme.disabledColor.withOpacity(0.6)
          : theme.disabledColor.withOpacity(0.25);

      final headingStyle = defaultStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface,
        height: 1.35,
      );

      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: prefixColor,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      _renderInline(spans, content, headingStyle, theme, isDark);
      return;
    }

    // Checklist unchecked: - [ ]
    if (line.startsWith('- [ ] ')) {
      final prefix = '- [ ] ';
      final content = line.substring(6);
      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      );
      _renderInline(spans, content, defaultStyle, theme, isDark);
      return;
    }

    // Checklist checked: - [x] or - [X]
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      final prefix = line.substring(0, 6);
      final content = line.substring(6);
      final completedStyle = defaultStyle.copyWith(
        color: theme.disabledColor,
        decoration: TextDecoration.lineThrough,
      );
      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: Colors.green.shade600,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      );
      _renderInline(spans, content, completedStyle, theme, isDark);
      return;
    }

    // Blockquote: > Quote
    if (line.startsWith('> ')) {
      final prefix = '> ';
      final content = line.substring(2);
      final quoteStyle = defaultStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: defaultStyle.color?.withOpacity(0.85),
      );
      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: theme.colorScheme.primary.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      _renderInline(spans, content, quoteStyle, theme, isDark);
      return;
    }

    // Bullet List: - Item or * Item
    if (line.startsWith('- ') || line.startsWith('* ')) {
      final prefix = line.substring(0, 2);
      final content = line.substring(2);
      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      _renderInline(spans, content, defaultStyle, theme, isDark);
      return;
    }

    // Standard paragraph line with inline markdown
    _renderInline(spans, line, defaultStyle, theme, isDark);
  }

  void _renderInline(
    List<InlineSpan> spans,
    String text,
    TextStyle baseStyle,
    ThemeData theme,
    bool isDark,
  ) {
    if (text.isEmpty) return;

    final matches = _inlineRegex.allMatches(text);
    int lastEnd = 0;

    final syntaxMuted = baseStyle.copyWith(
      color: (baseStyle.color ?? theme.colorScheme.onSurface).withOpacity(0.35),
      fontSize: (baseStyle.fontSize ?? 16) * 0.85,
    );

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;

      // Bold: **text**
      if (matchedText.startsWith('**') && matchedText.endsWith('**') && matchedText.length >= 4) {
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(text: '**', style: syntaxMuted));
        spans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: '**', style: syntaxMuted));
      }
      // Italic: *text*
      else if (matchedText.startsWith('*') && matchedText.endsWith('*') && matchedText.length >= 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(text: '*', style: syntaxMuted));
        spans.add(TextSpan(text: inner, style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
        spans.add(TextSpan(text: '*', style: syntaxMuted));
      }
      // Strikethrough: ~~text~~
      else if (matchedText.startsWith('~~') && matchedText.endsWith('~~') && matchedText.length >= 4) {
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(text: '~~', style: syntaxMuted));
        spans.add(TextSpan(text: inner, style: baseStyle.copyWith(decoration: TextDecoration.lineThrough)));
        spans.add(TextSpan(text: '~~', style: syntaxMuted));
      }
      // Inline Code: `code`
      else if (matchedText.startsWith('`') && matchedText.endsWith('`') && matchedText.length >= 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(text: '`', style: syntaxMuted));
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              color: isDark ? Colors.amber.shade200 : Colors.deepOrange.shade800,
              backgroundColor: theme.dividerColor.withOpacity(0.12),
            ),
          ),
        );
        spans.add(TextSpan(text: '`', style: syntaxMuted));
      }
      // WikiLink: [[page]]
      else if (matchedText.startsWith('[[') && matchedText.endsWith(']]') && matchedText.length >= 4) {
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(text: '[[', style: syntaxMuted.copyWith(color: theme.colorScheme.primary.withOpacity(0.4))));
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
        );
        spans.add(TextSpan(text: ']]', style: syntaxMuted.copyWith(color: theme.colorScheme.primary.withOpacity(0.4))));
      }
      // Math: $formula$
      else if (matchedText.startsWith(r'$') && matchedText.endsWith(r'$') && matchedText.length >= 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        final mathColor = isDark ? Colors.purpleAccent.shade100 : Colors.deepPurple.shade700;
        spans.add(TextSpan(text: r'$', style: syntaxMuted.copyWith(color: mathColor.withOpacity(0.5))));
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              color: mathColor,
              fontStyle: FontStyle.italic,
              fontFamily: 'monospace',
            ),
          ),
        );
        spans.add(TextSpan(text: r'$', style: syntaxMuted.copyWith(color: mathColor.withOpacity(0.5))));
      }
      // Link or image: [title](url) or ![alt](url)
      else if (matchedText.startsWith('![') || matchedText.startsWith('[')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: baseStyle.copyWith(
              color: theme.colorScheme.tertiary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: matchedText, style: baseStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
  }
}

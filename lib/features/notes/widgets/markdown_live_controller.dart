import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// An intelligent [TextEditingController] that provides live in-line markdown preview
/// with an incremental line-level caching engine.
///
/// Features:
/// - Cursor-aware heading scaling: When the cursor is outside a heading line (# or ##),
///   the `#` tokens are dimmed and the text scales up to H1/H2 sizes, creating a Notion/Medium feel.
/// - In-line styling for Bold, Italic, Strikethrough, Code, Math ($fx$), WikiLinks ([[ ]]),
///   Interactive Checklists (- [ ] / - [x]), Blockquotes, and Lists.
/// - Character-count strictly preserved so caret positioning and selection remain 100% accurate.
/// - **Incremental Line-Level Caching**: Unchanged lines are served directly from an
///   in-memory span cache in O(1) time, avoiding redundant regex parsing on large documents.
/// - **Fast Syntax Pre-check**: Lines without markdown control characters bypass regex execution entirely.
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

  /// Bounded line-level cache to eliminate redundant AST/Regex re-parsing
  /// across 500-2,000+ line documents.
  final Map<_LineKey, List<InlineSpan>> _lineSpanCache = {};
  static const int _maxCacheEntries = 5000;

  String? _lastParsedText;
  List<String>? _cachedLines;

  int _debugCacheHitCount = 0;
  int _debugRegexRunCount = 0;

  @visibleForTesting
  int get debugCacheHitCount => _debugCacheHitCount;

  @visibleForTesting
  int get debugRegexRunCount => _debugRegexRunCount;

  @visibleForTesting
  void resetDebugCounters() {
    _debugCacheHitCount = 0;
    _debugRegexRunCount = 0;
  }

  /// Clears the span cache. Useful when themes or styles drastically change.
  void invalidateSpanCache() {
    _lineSpanCache.clear();
    _lastParsedText = null;
    _cachedLines = null;
  }

  /// Quickly tests whether [s] contains any markdown delimiter characters:
  /// `*` (42), `~` (126), `` ` `` (96), `[` (91), `$` (36), `!` (33).
  static bool _hasInlineMarkdownTriggers(String s) {
    final len = s.length;
    for (var i = 0; i < len; i++) {
      final code = s.codeUnitAt(i);
      if (code == 42 || code == 126 || code == 96 || code == 91 || code == 36 || code == 33) {
        return true;
      }
    }
    return false;
  }

  static bool _isHeadingLine(String line) {
    return line.startsWith('# ') || line.startsWith('## ') || line.startsWith('### ');
  }

  @override
  void dispose() {
    _lineSpanCache.clear();
    _lastParsedText = null;
    _cachedLines = null;
    super.dispose();
  }

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

    // Reuse line splitting when text is unchanged (e.g. cursor / arrow key movements)
    final List<String> lines;
    if (_lastParsedText == text && _cachedLines != null) {
      lines = _cachedLines!;
    } else {
      lines = text.split('\n');
      _cachedLines = lines;
      _lastParsedText = text;
    }

    final primaryColorValue = theme.colorScheme.primary.toARGB32();

    int currentOffset = 0;
    bool inCodeBlock = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLength = line.length;
      final lineEnd = currentOffset + lineLength;
      final isCursorOnLine = cursorPos >= currentOffset && cursorPos <= lineEnd;

      final isFence = line.trimLeft().startsWith('```');
      final activeInCodeBlock = isFence ? false : inCodeBlock;
      final isHeading = _isHeadingLine(line);
      final isCursorOnHeading = isHeading && isCursorOnLine;

      final cacheKey = _LineKey(
        text: line,
        isFence: isFence,
        inCodeBlock: activeInCodeBlock,
        isCursorOnHeading: isCursorOnHeading,
        isDark: isDark,
        primaryColor: primaryColorValue,
      );

      final cachedSpans = _lineSpanCache[cacheKey];
      if (cachedSpans != null) {
        _debugCacheHitCount++;
        spans.addAll(cachedSpans);
      } else {
        final lineSpans = <InlineSpan>[];
        if (isFence) {
          lineSpans.add(
            TextSpan(
              text: line,
              style: defaultStyle.copyWith(
                fontFamily: 'monospace',
                color: isDark ? Colors.tealAccent.shade100 : Colors.teal.shade800,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.12),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        } else if (inCodeBlock) {
          lineSpans.add(
            TextSpan(
              text: line,
              style: defaultStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (defaultStyle.fontSize ?? 16) * 0.92,
                color: isDark ? Colors.amber.shade100 : Colors.blueGrey.shade900,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.08),
              ),
            ),
          );
        } else {
          _renderLine(
            spans: lineSpans,
            line: line,
            isCursorOnLine: isCursorOnLine,
            defaultStyle: defaultStyle,
            theme: theme,
            isDark: isDark,
          );
        }

        if (_lineSpanCache.length >= _maxCacheEntries) {
          _lineSpanCache.clear();
        }
        _lineSpanCache[cacheKey] = List.unmodifiable(lineSpans);
        spans.addAll(lineSpans);
      }

      if (isFence) {
        inCodeBlock = !inCodeBlock;
      }

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

    // Heading 1: # Title
    if (line.startsWith('# ')) {
      final prefix = '# ';
      final content = line.substring(2);
      final prefixColor = isCursorOnLine
          ? theme.colorScheme.primary.withValues(alpha: 0.55)
          : theme.colorScheme.primary.withValues(alpha: 0.20);
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
          ? theme.colorScheme.secondary.withValues(alpha: 0.55)
          : theme.colorScheme.secondary.withValues(alpha: 0.20);
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
          ? theme.disabledColor.withValues(alpha: 0.6)
          : theme.disabledColor.withValues(alpha: 0.25);

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
        color: defaultStyle.color?.withValues(alpha: 0.85),
      );
      spans.add(
        TextSpan(
          text: prefix,
          style: defaultStyle.copyWith(
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
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

    // Fast-path: Skip regex execution if line contains no markdown syntax triggers
    if (!_hasInlineMarkdownTriggers(text)) {
      spans.add(TextSpan(text: text, style: baseStyle));
      return;
    }

    _debugRegexRunCount++;
    final matches = _inlineRegex.allMatches(text);
    int lastEnd = 0;

    final syntaxMuted = baseStyle.copyWith(
      color: (baseStyle.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.35),
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
              backgroundColor: theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
        );
        spans.add(TextSpan(text: '`', style: syntaxMuted));
      }
      // WikiLink: [[page]]
      else if (matchedText.startsWith('[[') && matchedText.endsWith(']]') && matchedText.length >= 4) {
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(text: '[[', style: syntaxMuted.copyWith(color: theme.colorScheme.primary.withValues(alpha: 0.4))));
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        );
        spans.add(TextSpan(text: ']]', style: syntaxMuted.copyWith(color: theme.colorScheme.primary.withValues(alpha: 0.4))));
      }
      // Math: $formula$
      else if (matchedText.startsWith(r'$') && matchedText.endsWith(r'$') && matchedText.length >= 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        final mathColor = isDark ? Colors.purpleAccent.shade100 : Colors.deepPurple.shade700;
        spans.add(TextSpan(text: r'$', style: syntaxMuted.copyWith(color: mathColor.withValues(alpha: 0.5))));
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
        spans.add(TextSpan(text: r'$', style: syntaxMuted.copyWith(color: mathColor.withValues(alpha: 0.5))));
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

@immutable
class _LineKey {
  final String text;
  final bool isFence;
  final bool inCodeBlock;
  final bool isCursorOnHeading;
  final bool isDark;
  final int primaryColor;

  const _LineKey({
    required this.text,
    required this.isFence,
    required this.inCodeBlock,
    required this.isCursorOnHeading,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LineKey &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isFence == other.isFence &&
          inCodeBlock == other.inCodeBlock &&
          isCursorOnHeading == other.isCursorOnHeading &&
          isDark == other.isDark &&
          primaryColor == other.primaryColor;

  @override
  int get hashCode => Object.hash(
        text,
        isFence,
        inCodeBlock,
        isCursorOnHeading,
        isDark,
        primaryColor,
      );
}

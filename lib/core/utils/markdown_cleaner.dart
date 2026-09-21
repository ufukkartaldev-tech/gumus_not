/// Utility class to strip raw markdown formatting and produce clean, human-readable plain text.
class MarkdownCleaner {
  MarkdownCleaner._();

  /// Cleans markdown symbols and formatting from [markdown].
  ///
  /// Returns a streamlined plain text representation suitable for card previews and excerpts.
  static String clean(String markdown) {
    if (markdown.trim().isEmpty) {
      return '';
    }

    var text = markdown;

    // Remove images: ![alt](url)
    text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)', multiLine: true), '');

    // Wiki-links: [[Target|Label]] -> Label, [[Target]] -> Target
    text = text.replaceAllMapped(
      RegExp(r'\[\[(?:[^|\]]+\|)?([^\]]+)\]\]'),
      (match) => match.group(1) ?? '',
    );

    // Standard markdown links: [Label](url) -> Label
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // Fenced code blocks: ```lang ... ``` -> content
    text = text.replaceAllMapped(
      RegExp(r'```[a-zA-Z0-9_-]*\n?([\s\S]*?)```', multiLine: true),
      (match) => (match.group(1) ?? '').trim(),
    );

    // Inline code: `code` -> code
    text = text.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // HTML tags: <tag> -> ''
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Math formulas: $$...$$ or $...$ -> inner content
    text = text.replaceAllMapped(
      RegExp(r'\$\$([\s\S]*?)\$\$'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\$([^\$\n]+)\$'),
      (match) => match.group(1) ?? '',
    );

    // Strikethrough: ~~text~~ -> text
    text = text.replaceAllMapped(
      RegExp(r'~~(.*?)~~'),
      (match) => match.group(1) ?? '',
    );

    // Bold & italic variants
    text = text.replaceAllMapped(
      RegExp(r'\*\*\*(.*?)\*\*\*'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'___(.*?)___'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'__(.*?)__'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<!_)_(?!_)(.*?)(?<!_)_(?!_)'),
      (match) => match.group(1) ?? '',
    );

    // Line-by-line cleanups
    final lines = text.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();

      // Skip horizontal rules (---, ***, ___)
      if (RegExp(r'^[-*_]{3,}\s*$').hasMatch(trimmed)) {
        continue;
      }

      // Remove headings: # Header, ## Header
      trimmed = trimmed.replaceFirst(RegExp(r'^#+\s+'), '');

      // Remove blockquotes: > Quote
      trimmed = trimmed.replaceFirst(RegExp(r'^>\s*'), '');

      // Remove task checkboxes: - [ ] Task, - [x] Task, * [ ] Task
      trimmed = trimmed.replaceFirst(RegExp(r'^[\*\-\+]\s*\[[ xX]\]\s*'), '');

      // Remove bullet list markers: - Item, * Item, + Item
      trimmed = trimmed.replaceFirst(RegExp(r'^[\*\-\+]\s+'), '');

      // Remove numbered list markers: 1. Item
      trimmed = trimmed.replaceFirst(RegExp(r'^\d+\.\s+'), '');

      // Strip table borders: | col | col | -> col col
      trimmed = trimmed.replaceAll(RegExp(r'\|'), ' ');

      if (trimmed.isNotEmpty) {
        cleanedLines.add(trimmed);
      }
    }

    // Join lines with space and collapse multiple whitespaces
    final joined = cleanedLines.join(' ');
    return joined.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts standalone hashtag topics (e.g. #flutter, #dev) from [markdown],
  /// ignoring markdown heading hashtags (# Title).
  static List<String> extractHashtags(String markdown) {
    final tags = <String>{};
    final regex = RegExp(
      r'(?:^|[^\w#])#([a-zA-Z0-9_ğüşıöçĞÜŞİÖÇ]+)',
      caseSensitive: false,
    );

    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      // Skip markdown headings
      if (RegExp(r'^#+\s+').hasMatch(trimmed)) {
        continue;
      }

      final matches = regex.allMatches(trimmed);
      for (final match in matches) {
        final tag = match.group(1);
        if (tag != null && tag.isNotEmpty) {
          tags.add(tag.toLowerCase());
        }
      }
    }

    return tags.toList();
  }
}

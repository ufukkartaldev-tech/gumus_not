abstract class IAiService {
  /// Default maximum output tokens for summaries and technical generation.
  static const int defaultMaxOutputTokens = 2048;

  /// Maximum input character budget (~24k tokens) before smart head+tail
  /// context window compaction is applied.
  static const int maxInputChars = 96000;

  /// Compacts overly long note bodies by preserving the beginning (70%) and
  /// ending (30%) sections so LLM context windows never overflow while
  /// retaining both document introduction and conclusions.
  static String compactContextWindow(String text, {int maxChars = maxInputChars}) {
    if (text.length <= maxChars) return text;
    final headLength = (maxChars * 0.7).floor();
    final tailLength = maxChars - headLength;
    final omitted = text.length - maxChars;
    return '${text.substring(0, headLength)}\n\n'
        '[... $omitted karakter bağlam sınırı nedeniyle kırpıldı ...]\n\n'
        '${text.substring(text.length - tailLength)}';
  }

  /// Generates a summary of the provided text.
  Future<String> generateSummary(String text);

  /// Streams a summary of the provided text chunk-by-chunk as tokens arrive.
  Stream<String> streamSummary(String text);

  /// Suggests a list of tags based on the provided text.
  Future<List<String>> suggestTags(String text);

  /// Handles custom dynamic prompts.
  Future<String> customPrompt(String prompt, String content);

  /// Streams responses for custom dynamic prompts chunk-by-chunk.
  Stream<String> streamCustomPrompt(String prompt, String content);

  /// Releases any underlying network clients or resources.
  void dispose() {}
}

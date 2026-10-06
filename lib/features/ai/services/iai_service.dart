abstract class IAiService {
  /// Generates a brief summary of the provided text
  Future<String> generateSummary(String text);
  
  /// Suggests a list of tags based on the provided text
  Future<List<String>> suggestTags(String text);
  
  /// Handles custom dynamic prompts
  Future<String> customPrompt(String prompt, String content);
}

class NoteHistory {
  final String commitHash;
  final String author;
  final DateTime date;
  final String message;

  NoteHistory({
    required this.commitHash,
    required this.author,
    required this.date,
    required this.message,
  });

  factory NoteHistory.fromGitLog(String logLine) {
    // Expected format: commitHash|author|date|message
    final parts = logLine.split('|');
    if (parts.length >= 4) {
      return NoteHistory(
        commitHash: parts[0],
        author: parts[1],
        date: DateTime.parse(parts[2]),
        message: parts.sublist(3).join('|'),
      );
    }
    return NoteHistory(
      commitHash: '',
      author: 'Unknown',
      date: DateTime.now(),
      message: 'Invalid log line: $logLine',
    );
  }
}

class NoteDiff {
  final String commitHash;
  final String diffContent;

  NoteDiff({
    required this.commitHash,
    required this.diffContent,
  });
}

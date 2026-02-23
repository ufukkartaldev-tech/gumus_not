import '../models/note_model.dart';

class TaskItem {
  final Note note;
  final String taskText;
  final bool isCompleted;
  final String originalLine;

  TaskItem({
    required this.note,
    required this.taskText,
    required this.isCompleted,
    required this.originalLine,
  });
}

class TaskService {
  static List<TaskItem> extractTasks(List<Note> notes) {
    List<TaskItem> tasks = [];
    final regex = RegExp(r'^\s*- \[([ xX])\] (.*)', multiLine: true);

    for (var note in notes) {
      if (note.isEncrypted) continue;
      
      final matches = regex.allMatches(note.content);
      for (var match in matches) {
        if (match.group(2) != null) {
          final statusChar = match.group(1)!;
          final isCompleted = statusChar.toLowerCase() == 'x';
          
          tasks.add(TaskItem(
            note: note,
            taskText: match.group(2)!.trim(),
            isCompleted: isCompleted,
            originalLine: match.group(0)!,
          ));
        }
      }
    }
    return tasks;
  }

  static Map<String, dynamic> getServerlyStats(List<Note> notes) {
    final tasks = extractTasks(notes);
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final totalTasks = tasks.length;
    
    // Last 7 days completion (simulated for now since Note doesn't store completion date for tasks)
    // Future: Task model with completion date in DB
    
    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionRate': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
    };
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/tasks/services/task_service.dart';

void main() {
  group('TaskService Tests', () {
    test('extractTasks returns empty list when no tasks exist', () {
      final note = Note(
        id: 1,
        title: 'Normal Note',
        content: 'This is just a normal note.\nNo tasks here.',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final tasks = TaskService.extractTasks([note]);
      expect(tasks, isEmpty);
    });

    test('extractTasks correctly extracts uncompleted tasks', () {
      final note = Note(
        id: 1,
        title: 'Task Note',
        content: '# Tasks\n- [ ] Buy milk\n- [ ] Call mom',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final tasks = TaskService.extractTasks([note]);
      expect(tasks.length, 2);
      
      expect(tasks[0].taskText, 'Buy milk');
      expect(tasks[0].isCompleted, isFalse);
      
      expect(tasks[1].taskText, 'Call mom');
      expect(tasks[1].isCompleted, isFalse);
    });

    test('extractTasks correctly extracts completed tasks', () {
      final note = Note(
        id: 1,
        title: 'Completed Tasks',
        content: 'Done:\n- [x] Read book\n- [X] Write code',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final tasks = TaskService.extractTasks([note]);
      expect(tasks.length, 2);
      
      expect(tasks[0].taskText, 'Read book');
      expect(tasks[0].isCompleted, isTrue);
      
      expect(tasks[1].taskText, 'Write code');
      expect(tasks[1].isCompleted, isTrue);
    });

    test('extractTasks skips encrypted notes', () {
      final note = Note(
        id: 1,
        title: 'Secret Tasks',
        content: '- [ ] Secret task',
        createdAt: 1000,
        updatedAt: 1000,
        isEncrypted: true,
      );

      final tasks = TaskService.extractTasks([note]);
      expect(tasks, isEmpty);
    });

    test('getServerlyStats calculates correctly', () {
      final note1 = Note(
        id: 1,
        title: 'Note 1',
        content: '- [ ] Task 1\n- [x] Task 2',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final note2 = Note(
        id: 2,
        title: 'Note 2',
        content: '- [X] Task 3\n- [ ] Task 4\n- [x] Task 5',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final stats = TaskService.getServerlyStats([note1, note2]);
      
      expect(stats['totalTasks'], 5);
      expect(stats['completedTasks'], 3);
      expect(stats['completionRate'], 0.6); // 3/5
    });

    test('getServerlyStats handles zero tasks safely', () {
      final stats = TaskService.getServerlyStats([]);
      expect(stats['totalTasks'], 0);
      expect(stats['completedTasks'], 0);
      expect(stats['completionRate'], 0.0);
    });
  });
}

import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/optimized_sqlite_note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/sqlite_note_repository.dart';

/// Performance test for note repository with 1000+ notes
void main() {
  group('Note Repository Performance Tests (1000+ notes)', () {
    late OptimizedSqliteNoteRepository optimizedRepository;
    late SqliteNoteRepository legacyRepository;
    final Random random = Random.secure();
    
    // Test data generation
    List<Note> generateTestNotes(int count) {
      final notes = <Note>[];
      final loremIpsum = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.
''';
      
      final tags = ['work', 'personal', 'ideas', 'todo', 'meeting', 'project'];
      final folders = ['Genel', 'Work', 'Personal', 'Archive', 'Projects'];
      
      for (int i = 0; i < count; i++) {
        final hasTasks = random.nextBool();
        final taskCount = hasTasks ? random.nextInt(5) + 1 : 0;
        
        var content = 'Note $i: $loremIpsum\n';
        
        // Add tasks
        for (int t = 0; t < taskCount; t++) {
          final isCompleted = random.nextBool();
          content += isCompleted 
              ? '- [x] Task $t for note $i\n'
              : '- [ ] Task $t for note $i\n';
        }
        
        // Add some links
        if (i > 0 && random.nextDouble() < 0.3) {
          final linkTo = random.nextInt(i);
          content += '\nSee also [[Note $linkTo]]\n';
        }
        
        final note = Note(
          id: i + 1,
          title: 'Test Note $i',
          content: content,
          createdAt: DateTime.now().millisecondsSinceEpoch - random.nextInt(365 * 24 * 60 * 60 * 1000),
          updatedAt: DateTime.now().millisecondsSinceEpoch - random.nextInt(30 * 24 * 60 * 60 * 1000),
          tags: [tags[random.nextInt(tags.length)], tags[random.nextInt(tags.length)]],
          folderName: folders[random.nextInt(folders.length)],
        );
        
        notes.add(note);
      }
      
      return notes;
    }
    
    setUp(() async {
      // Initialize repositories
      optimizedRepository = OptimizedSqliteNoteRepository();
      legacyRepository = SqliteNoteRepository();
      
      // Clear any existing data
      await optimizedRepository.close();
      await legacyRepository.close();
    });
    
    tearDown(() async {
      await optimizedRepository.close();
      await legacyRepository.close();
    });
    
    test('Bulk insert 1000 notes performance', () async {
      const noteCount = 1000;
      final testNotes = generateTestNotes(noteCount);
      
      print('\n=== Bulk Insert Performance Test (1000 notes) ===');
      
      // Test optimized repository
      final optimizedStopwatch = Stopwatch()..start();
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
      }
      optimizedStopwatch.stop();
      
      final optimizedStats = await optimizedRepository.getDatabaseStats();
      print('Optimized Repository:');
      print('  Insert time: ${optimizedStopwatch.elapsedMilliseconds}ms');
      print('  Avg time per note: ${optimizedStopwatch.elapsedMilliseconds / noteCount}ms');
      print('  Database stats: $optimizedStats');
      
      // Clear optimized repository for fair comparison
      await optimizedRepository.close();
      optimizedRepository = OptimizedSqliteNoteRepository();
      
      // Test legacy repository
      final legacyStopwatch = Stopwatch()..start();
      for (final note in testNotes) {
        await legacyRepository.addNote(note);
      }
      legacyStopwatch.stop();
      
      final legacyStats = await legacyRepository.getDatabaseStats();
      print('\nLegacy Repository:');
      print('  Insert time: ${legacyStopwatch.elapsedMilliseconds}ms');
      print('  Avg time per note: ${legacyStopwatch.elapsedMilliseconds / noteCount}ms');
      print('  Database stats: $legacyStats');
      
      // Performance comparison
      final speedup = legacyStopwatch.elapsedMilliseconds / optimizedStopwatch.elapsedMilliseconds;
      print('\nPerformance Comparison:');
      print('  Optimized is ${speedup.toStringAsFixed(2)}x faster for inserts');
      
      expect(optimizedStopwatch.elapsedMilliseconds, lessThan(legacyStopwatch.elapsedMilliseconds * 0.8),
          reason: 'Optimized repository should be faster for bulk inserts');
    });
    
    test('Search performance with FTS5 vs LIKE', () async {
      const noteCount = 1000;
      final testNotes = generateTestNotes(noteCount);
      
      // Insert test data
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
        await legacyRepository.addNote(note);
      }
      
      print('\n=== Search Performance Test ===');
      
      // Test search queries
      final searchQueries = ['Task', 'Lorem', 'Note 500', 'work personal', 'meeting'];
      
      for (final query in searchQueries) {
        print('\nSearch query: "$query"');
        
        // FTS5 search
        final ftsStopwatch = Stopwatch()..start();
        final ftsResults = await optimizedRepository.searchNotes(query);
        ftsStopwatch.stop();
        
        // LIKE search
        final likeStopwatch = Stopwatch()..start();
        final likeResults = await legacyRepository.searchNotes(query);
        likeStopwatch.stop();
        
        print('  FTS5: ${ftsResults.length} results in ${ftsStopwatch.elapsedMilliseconds}ms');
        print('  LIKE: ${likeResults.length} results in ${likeStopwatch.elapsedMilliseconds}ms');
        
        final speedup = likeStopwatch.elapsedMilliseconds / ftsStopwatch.elapsedMilliseconds;
        print('  FTS5 is ${speedup.toStringAsFixed(2)}x faster');
        
        // Verify result consistency
        expect(ftsResults.length, equals(likeResults.length),
            reason: 'Both search methods should return same number of results for query: $query');
      }
    });
    
    test('Pending tasks query performance', () async {
      const noteCount = 1000;
      final testNotes = generateTestNotes(noteCount);
      
      // Insert test data
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
        await legacyRepository.addNote(note);
      }
      
      print('\n=== Pending Tasks Query Performance ===');
      
      // Optimized repository (uses generated column)
      final optimizedStopwatch = Stopwatch()..start();
      final optimizedTasks = await optimizedRepository.getPendingTasks(limit: 100);
      optimizedStopwatch.stop();
      
      // Legacy repository (uses LIKE)
      final legacyStopwatch = Stopwatch()..start();
      final legacyTasks = await legacyRepository.getPendingTasks(limit: 100);
      legacyStopwatch.stop();
      
      print('Optimized (generated column):');
      print('  Results: ${optimizedTasks.length}');
      print('  Time: ${optimizedStopwatch.elapsedMilliseconds}ms');
      
      print('\nLegacy (LIKE query):');
      print('  Results: ${legacyTasks.length}');
      print('  Time: ${legacyStopwatch.elapsedMilliseconds}ms');
      
      final speedup = legacyStopwatch.elapsedMilliseconds / optimizedStopwatch.elapsedMilliseconds;
      print('\nPerformance:');
      print('  Generated column is ${speedup.toStringAsFixed(2)}x faster');
      
      expect(optimizedStopwatch.elapsedMilliseconds, lessThan(legacyStopwatch.elapsedMilliseconds * 0.5),
          reason: 'Generated column should be significantly faster than LIKE');
    });
    
    test('Advanced search with multiple criteria', () async {
      const noteCount = 1000;
      final testNotes = generateTestNotes(noteCount);
      
      // Insert test data
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
      }
      
      print('\n=== Advanced Search Performance ===');
      
      final testScenarios = [
        {
          'name': 'Simple text search',
          'query': 'Task',
          'folder': null,
          'tags': null,
          'hasPendingTasks': null,
        },
        {
          'name': 'Folder + text search',
          'query': 'Lorem',
          'folder': 'Work',
          'tags': null,
          'hasPendingTasks': null,
        },
        {
          'name': 'Tag search',
          'query': null,
          'folder': null,
          'tags': ['work', 'personal'],
          'hasPendingTasks': null,
        },
        {
          'name': 'Pending tasks in folder',
          'query': null,
          'folder': 'Personal',
          'tags': null,
          'hasPendingTasks': true,
        },
        {
          'name': 'Complex multi-criteria',
          'query': 'Note',
          'folder': 'Projects',
          'tags': ['project'],
          'hasPendingTasks': false,
        },
      ];
      
      for (final scenario in testScenarios) {
        print('\nScenario: ${scenario['name']}');
        
        final stopwatch = Stopwatch()..start();
        final results = await optimizedRepository.advancedSearch(
          query: scenario['query'],
          folder: scenario['folder'],
          tags: scenario['tags'] != null ? List<String>.from(scenario['tags']!) : null,
          hasPendingTasks: scenario['hasPendingTasks'],
          limit: 50,
        );
        stopwatch.stop();
        
        print('  Results: ${results.length}');
        print('  Time: ${stopwatch.elapsedMilliseconds}ms');
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Advanced search should complete within 1 second for 1000 notes');
      }
    });
    
    test('Memory usage and scalability', () async {
      const testSizes = [100, 500, 1000, 2000];
      
      print('\n=== Scalability Test ===');
      
      for (final size in testSizes) {
        print('\nTesting with $size notes:');
        
        // Generate and insert notes
        final testNotes = generateTestNotes(size);
        final insertStopwatch = Stopwatch()..start();
        
        for (final note in testNotes) {
          await optimizedRepository.addNote(note);
        }
        
        insertStopwatch.stop();
        
        // Search test
        final searchStopwatch = Stopwatch()..start();
        final searchResults = await optimizedRepository.searchNotes('Task');
        searchStopwatch.stop();
        
        // Get stats
        final stats = await optimizedRepository.getDatabaseStats();
        
        print('  Insert time: ${insertStopwatch.elapsedMilliseconds}ms');
        print('  Search time: ${searchStopwatch.elapsedMilliseconds}ms');
        print('  Search results: ${searchResults.length}');
        print('  Stats: $stats');
        
        // Clear for next test
        await optimizedRepository.close();
        optimizedRepository = OptimizedSqliteNoteRepository();
      }
    });
    
    test('Concurrent operations stress test', () async {
      const noteCount = 500;
      final testNotes = generateTestNotes(noteCount);
      
      print('\n=== Concurrent Operations Stress Test ===');
      
      // Insert initial data
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
      }
      
      // Run concurrent operations
      final operations = <Future>[];
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 10; i++) {
        operations.add(optimizedRepository.searchNotes('Task'));
        operations.add(optimizedRepository.getPendingTasks());
        operations.add(optimizedRepository.getRecentNotes());
        
        if (i % 3 == 0) {
          // Add some update operations
          final noteToUpdate = testNotes[random.nextInt(testNotes.length)];
          noteToUpdate.content += '\nUpdated at ${DateTime.now()}';
          operations.add(optimizedRepository.updateNote(noteToUpdate));
        }
      }
      
      // Wait for all operations
      await Future.wait(operations);
      stopwatch.stop();
      
      print('  Concurrent operations: ${operations.length}');
      print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
      print('  Avg time per operation: ${stopwatch.elapsedMilliseconds / operations.length}ms');
      
      // Get performance stats
      final perfStats = optimizedRepository.getPerformanceStats();
      print('  Performance stats: $perfStats');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Concurrent operations should complete within 5 seconds');
    });
    
    test('Database optimization impact', () async {
      const noteCount = 1000;
      final testNotes = generateTestNotes(noteCount);
      
      print('\n=== Database Optimization Test ===');
      
      // Insert test data
      for (final note in testNotes) {
        await optimizedRepository.addNote(note);
      }
      
      // Measure search before optimization
      final beforeStopwatch = Stopwatch()..start();
      await optimizedRepository.searchNotes('Lorem ipsum');
      beforeStopwatch.stop();
      
      print('Before optimization:');
      print('  Search time: ${beforeStopwatch.elapsedMilliseconds}ms');
      
      // Run optimization
      final optimizeStopwatch = Stopwatch()..start();
      await optimizedRepository.optimizeDatabase();
      optimizeStopwatch.stop();
      
      print('Optimization:');
      print('  Time: ${optimizeStopwatch.elapsedMilliseconds}ms');
      
      // Measure search after optimization
      final afterStopwatch = Stopwatch()..start();
      await optimizedRepository.searchNotes('Lorem ipsum');
      afterStopwatch.stop();
      
      print('After optimization:');
      print('  Search time: ${afterStopwatch.elapsedMilliseconds}ms');
      
      final improvement = beforeStopwatch.elapsedMilliseconds / afterStopwatch.elapsedMilliseconds;
      print('  Improvement: ${improvement.toStringAsFixed(2)}x faster');
      
      // Note: Optimization might not always make searches faster,
      // but it should maintain or improve performance
      expect(afterStopwatch.elapsedMilliseconds, lessThanOrEqualTo(beforeStopwatch.elapsedMilliseconds * 1.5),
          reason: 'Optimization should not significantly degrade performance');
    });
  });
}
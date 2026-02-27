import '../models/note_model.dart';
import '../repositories/inote_repository.dart';

/// Service for analytics and statistics
/// Follows Single Responsibility Principle: Only handles analytics operations
class AnalyticsService {
  final INoteRepository _repository;

  AnalyticsService(this._repository);

  /// Get comprehensive analytics data
  Future<Map<String, dynamic>> getAnalyticsData() async {
    final allNotes = await _repository.getAllNotes();
    
    return {
      'overview': await _getOverviewStats(allNotes),
      'writingHabits': await _getWritingHabits(allNotes),
      'contentAnalysis': await _getContentAnalysis(allNotes),
      'engagement': await _getEngagementMetrics(allNotes),
      'timeAnalysis': await _getTimeAnalysis(allNotes),
    };
  }

  /// Overview statistics
  Future<Map<String, dynamic>> _getOverviewStats(List<Note> notes) async {
    final totalNotes = notes.length;
    final totalWords = notes.fold<int>(0, (sum, note) => sum + note.wordCount);
    final totalCharacters = notes.fold<int>(0, (sum, note) => sum + note.content.length);
    
    final encryptedNotes = notes.where((note) => note.isEncrypted).length;
    final notesWithImages = notes.where((note) => note.content.contains('![')).length;
    final notesWithTasks = notes.where((note) => note.content.contains('- [ ')).length;
    final notesWithLinks = notes.where((note) => note.extractLinks().isNotEmpty).length;
    
    final uniqueTags = notes.fold<Set<String>>({}, (set, note) {
      set.addAll(note.tags);
      return set;
    }).length;
    
    final uniqueFolders = notes.map((note) => note.folderName).toSet().length;

    return {
      'totalNotes': totalNotes,
      'totalWords': totalWords,
      'totalCharacters': totalCharacters,
      'averageWordsPerNote': totalNotes > 0 ? (totalWords / totalNotes).round() : 0,
      'averageCharactersPerNote': totalNotes > 0 ? (totalCharacters / totalNotes).round() : 0,
      'encryptedNotes': encryptedNotes,
      'encryptedPercentage': totalNotes > 0 ? ((encryptedNotes / totalNotes) * 100).round() : 0,
      'notesWithImages': notesWithImages,
      'notesWithTasks': notesWithTasks,
      'notesWithLinks': notesWithLinks,
      'uniqueTags': uniqueTags,
      'uniqueFolders': uniqueFolders,
    };
  }

  /// Writing habits analysis
  Future<Map<String, dynamic>> _getWritingHabits(List<Note> notes) async {
    if (notes.isEmpty) {
      return {
        'dailyAverage': 0,
        'weeklyAverage': 0,
        'monthlyAverage': 0,
        'mostProductiveDay': 'Pazartesi',
        'mostProductiveHour': 9,
        'writingStreak': 0,
        'longestStreak': 0,
        'dailyStats': <Map<String, dynamic>>[],
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Group notes by date
    final Map<DateTime, List<Note>> notesByDate = {};
    for (final note in notes) {
      final date = DateTime(
        note.createdAt ~/ (1000 * 60 * 60 * 24) * (1000 * 60 * 60 * 24),
      );
      notesByDate[date] = (notesByDate[date] ?? [])..add(note);
    }

    // Calculate daily averages
    final totalDays = notesByDate.length;
    final dailyAverage = totalDays > 0 ? (notes.length / totalDays) : 0;
    final weeklyAverage = dailyAverage * 7;
    final monthlyAverage = dailyAverage * 30;

    // Find most productive day of week
    final Map<String, int> dayCounts = {};
    for (final note in notes) {
      final day = _getDayName(note.createdAt);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }
    final mostProductiveDay = dayCounts.entries.isEmpty ? 'Pazartesi' : 
        dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Find most productive hour
    final Map<int, int> hourCounts = {};
    for (final note in notes) {
      final hour = DateTime.fromMillisecondsSinceEpoch(note.createdAt).hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    final mostProductiveHour = hourCounts.entries.isEmpty ? 9 :
        hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Calculate writing streaks
    final sortedDates = notesByDate.keys.toList()..sort();
    int currentStreak = 0;
    int longestStreak = 0;
    
    for (int i = 0; i < sortedDates.length; i++) {
      if (i == 0) {
        currentStreak = 1;
      } else {
        final difference = sortedDates[i].difference(sortedDates[i - 1]).inDays;
        if (difference == 1) {
          currentStreak++;
        } else {
          longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
          currentStreak = 1;
        }
      }
    }
    longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;

    // Generate daily stats for the last 30 days
    final dailyStats = <Map<String, dynamic>>[];
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayNotes = notesByDate[date] ?? [];
      dailyStats.add({
        'date': date.toIso8601String(),
        'count': dayNotes.length,
        'words': dayNotes.fold<int>(0, (sum, note) => sum + note.wordCount),
        'characters': dayNotes.fold<int>(0, (sum, note) => sum + note.content.length),
      });
    }

    return {
      'dailyAverage': dailyAverage.round(),
      'weeklyAverage': weeklyAverage.round(),
      'monthlyAverage': monthlyAverage.round(),
      'mostProductiveDay': mostProductiveDay,
      'mostProductiveHour': mostProductiveHour,
      'writingStreak': currentStreak,
      'longestStreak': longestStreak,
      'dailyStats': dailyStats,
    };
  }

  /// Content analysis
  Future<Map<String, dynamic>> _getContentAnalysis(List<Note> notes) async {
    final Map<String, int> tagFrequency = {};
    final Map<String, int> folderFrequency = {};
    final List<int> wordCounts = [];
    final List<int> characterCounts = [];

    for (final note in notes) {
      // Tag frequency
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }

      // Folder frequency
      folderFrequency[note.folderName] = (folderFrequency[note.folderName] ?? 0) + 1;

      // Content metrics
      wordCounts.add(note.wordCount);
      characterCounts.add(note.content.length);
    }

    // Calculate statistics
    wordCounts.sort();
    characterCounts.sort();
    
    final avgWordCount = wordCounts.isEmpty ? 0 : 
        wordCounts.reduce((a, b) => a + b) / wordCounts.length;
    final avgCharCount = characterCounts.isEmpty ? 0 :
        characterCounts.reduce((a, b) => a + b) / characterCounts.length;

    final medianWordCount = wordCounts.isEmpty ? 0 :
        wordCounts[wordCounts.length ~/ 2];
    final medianCharCount = characterCounts.isEmpty ? 0 :
        characterCounts[characterCounts.length ~/ 2];

    // Get top tags and folders
    final topTags = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);
    
    final topFolders = folderFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);

    return {
      'tagFrequency': tagFrequency,
      'folderFrequency': folderFrequency,
      'topTags': topTags.map((e) => {'tag': e.key, 'count': e.value}).toList(),
      'topFolders': topFolders.map((e) => {'folder': e.key, 'count': e.value}).toList(),
      'averageWordCount': avgWordCount.round(),
      'medianWordCount': medianWordCount,
      'averageCharacterCount': avgCharCount.round(),
      'medianCharacterCount': medianCharCount,
      'wordCountDistribution': _getDistribution(wordCounts),
      'characterCountDistribution': _getDistribution(characterCounts),
    };
  }

  /// Engagement metrics
  Future<Map<String, dynamic>> _getEngagementMetrics(List<Note> notes) async {
    if (notes.isEmpty) {
      return {
        'totalEdits': 0,
        'averageEditsPerNote': 0,
        'recentActivity': 0,
        'engagementScore': 0,
      };
    }

    // Calculate edits (updated_at != created_at)
    final totalEdits = notes.where((note) => note.updatedAt > note.createdAt).length;
    final averageEditsPerNote = (totalEdits / notes.length);

    // Recent activity (notes updated in last 7 days)
    final now = DateTime.now().millisecondsSinceEpoch;
    final weekAgo = now - (7 * 24 * 60 * 60 * 1000);
    final recentActivity = notes.where((note) => note.updatedAt > weekAgo).length;

    // Calculate engagement score (0-100)
    double engagementScore = 0;
    
    // Base score from note count
    engagementScore += (notes.length / 10) * 20; // Max 20 points
    
    // Recent activity bonus
    engagementScore += (recentActivity / notes.length) * 30; // Max 30 points
    
    // Edit frequency bonus
    engagementScore += (totalEdits / notes.length) * 25; // Max 25 points
    
    // Content diversity bonus
    final uniqueTags = notes.fold<Set<String>>({}, (set, note) {
      set.addAll(note.tags);
      return set;
    }).length;
    engagementScore += (uniqueTags / 10) * 25; // Max 25 points
    
    engagementScore = engagementScore.clamp(0.0, 100.0);

    return {
      'totalEdits': totalEdits,
      'averageEditsPerNote': averageEditsPerNote.roundToDouble(),
      'recentActivity': recentActivity,
      'engagementScore': engagementScore.round(),
    };
  }

  /// Time-based analysis
  Future<Map<String, dynamic>> _getTimeAnalysis(List<Note> notes) async {
    if (notes.isEmpty) {
      return {
        'creationTimeline': <Map<String, dynamic>>[],
        'updateTimeline': <Map<String, dynamic>>[],
        'peakHours': <Map<String, dynamic>>[],
        'peakDays': <Map<String, dynamic>>[],
      };
    }

    // Creation timeline (last 30 days)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final creationTimeline = <Map<String, dynamic>>[];
    
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayStart = date.millisecondsSinceEpoch;
      final dayEnd = dayStart + (24 * 60 * 60 * 1000);
      
      final dayNotes = notes.where((note) => 
        note.createdAt >= dayStart && note.createdAt < dayEnd).length;
      
      creationTimeline.add({
        'date': date.toIso8601String(),
        'count': dayNotes,
      });
    }

    // Update timeline (last 30 days)
    final updateTimeline = <Map<String, dynamic>>[];
    
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayStart = date.millisecondsSinceEpoch;
      final dayEnd = dayStart + (24 * 60 * 60 * 1000);
      
      final dayUpdates = notes.where((note) => 
        note.updatedAt >= dayStart && note.updatedAt < dayEnd).length;
      
      updateTimeline.add({
        'date': date.toIso8601String(),
        'count': dayUpdates,
      });
    }

    // Peak hours analysis
    final Map<int, int> hourCounts = {};
    for (final note in notes) {
      final hour = DateTime.fromMillisecondsSinceEpoch(note.createdAt).hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    
    final peakHours = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5)
      .map((e) => {'hour': e.key, 'count': e.value}).toList();

    // Peak days analysis
    final Map<String, int> dayCounts = {};
    for (final note in notes) {
      final day = _getDayName(note.createdAt);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }
    
    final peakDays = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..map((e) => {'day': e.key, 'count': e.value}).toList();

    return {
      'creationTimeline': creationTimeline,
      'updateTimeline': updateTimeline,
      'peakHours': peakHours,
      'peakDays': peakDays,
    };
  }

  /// Get distribution data for charts
  List<Map<String, dynamic>> _getDistribution(List<int> values) {
    if (values.isEmpty) return [];

    values.sort();
    final min = values.first;
    final max = values.last;
    final range = max - min;
    
    if (range == 0) return [{'range': '$min', 'count': values.length}];

    final bucketCount = 10;
    final bucketSize = range / bucketCount;
    final List<Map<String, dynamic>> distribution = [];

    for (int i = 0; i < bucketCount; i++) {
      final bucketMin = min + (i * bucketSize).round();
      final bucketMax = i == bucketCount - 1 ? max : min + ((i + 1) * bucketSize).round() - 1;
      
      final count = values.where((v) => v >= bucketMin && v <= bucketMax).length;
      
      distribution.add({
        'range': i == bucketCount - 1 ? '$bucketMin+' : '$bucketMin-$bucketMax',
        'count': count,
      });
    }

    return distribution;
  }

  /// Get day name from timestamp
  String _getDayName(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    switch (date.weekday) {
      case 1: return 'Pazartesi';
      case 2: return 'Salı';
      case 3: return 'Çarşamba';
      case 4: return 'Perşembe';
      case 5: return 'Cuma';
      case 6: return 'Cumartesi';
      case 7: return 'Pazar';
      default: return 'Pazartesi';
    }
  }

  /// Get quick stats for dashboard
  Future<Map<String, dynamic>> getQuickStats() async {
    final allNotes = await _repository.getAllNotes();
    
    final totalNotes = allNotes.length;
    final totalWords = allNotes.fold<int>(0, (sum, note) => sum + note.wordCount);
    final thisWeek = allNotes.where((note) {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
      final noteDate = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
      return noteDate.isAfter(weekStart);
    }).length;
    
    final lastWeek = allNotes.where((note) {
      final now = DateTime.now();
      final lastWeekStart = DateTime(now.year, now.month, now.day - now.weekday - 6);
      final lastWeekEnd = DateTime(now.year, now.month, now.day - now.weekday);
      final noteDate = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
      return noteDate.isAfter(lastWeekStart) && noteDate.isBefore(lastWeekEnd);
    }).length;

    return {
      'totalNotes': totalNotes,
      'totalWords': totalWords,
      'thisWeek': thisWeek,
      'lastWeek': lastWeek,
      'weeklyGrowth': lastWeek > 0 ? ((thisWeek - lastWeek) / lastWeek * 100).round() : 0,
    };
  }
}

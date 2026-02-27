import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:isolate';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class CrossReferenceTracker extends StatefulWidget {
  final Note currentNote;

  const CrossReferenceTracker({
    Key? key,
    required this.currentNote,
  }) : super(key: key);

  @override
  State<CrossReferenceTracker> createState() => _CrossReferenceTrackerState();
}

class _CrossReferenceTrackerState extends State<CrossReferenceTracker> {
  Map<String, List<int>> _invertedIndex = {};
  Map<String, double> _tfidfScores = {};
  List<RelatedNote> _relatedNotes = [];
  List<String> _suggestedTags = [];
  bool _isLoading = true;
  bool _isCalculatingSimilarity = false;
  final Set<String> _stopwords = {
    'bu', 've', 'veya', 'ama', 'ancak', 'ile', 'için', 'gibi', 'olarak', 'daha',
    'çok', 'az', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz',
    'dokuz', 'on', 'yüz', 'bin', 'milyon', 'milyar', 'yok', 'var', 'değil',
    'mi', 'mı', 'mu', 'mü', 'ise', 'ne', 'nasıl', 'neden', 'nerede', 'ne zaman',
    'kim', 'hangi', 'kaç', 'kaçıncı', 'en', 'daha', 'az', 'çok', 'az', 'hiç',
    'her', 'tüm', 'bazı', 'birkaç', 'birçok', 'pek', 'oldukça', 'gayet', 'çok',
    'az', 'biraz', 'fazla', 'az', 'çok', 'oldukça', 'gayet', 'pek', 'çok',
    'the', 'and', 'or', 'but', 'however', 'with', 'for', 'like', 'as', 'to',
    'from', 'at', 'in', 'on', 'by', 'of', 'is', 'are', 'was', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
    'could', 'should', 'may', 'might', 'must', 'can', 'shall', 'a', 'an', 'the',
    'this', 'that', 'these', 'those', 'it', 'its', 'they', 'them', 'their',
    'he', 'she', 'him', 'her', 'his', 'hers', 'we', 'us', 'our', 'you', 'your',
    'what', 'when', 'where', 'why', 'who', 'how', 'which', 'whom', 'whose',
    'if', 'then', 'else', 'than', 'so', 'such', 'too', 'very', 'quite', 'rather',
    'quite', 'pretty', 'just', 'only', 'also', 'even', 'still', 'yet', 'already',
    'now', 'then', 'here', 'there', 'up', 'down', 'out', 'off', 'over', 'under',
    'again', 'further', 'then', 'once', 'more', 'most', 'some', 'such', 'no',
    'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 'you'
  };

  @override
  void initState() {
    super.initState();
    _buildInvertedIndex();
  }

  void _buildInvertedIndex() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    await noteProvider.loadNotes();
    
    final allNotes = noteProvider.notes;
    final invertedIndex = <String, List<int>>{};
    final documentFrequencies = <String, int>{};
    
    // Build inverted index and document frequencies
    for (int i = 0; i < allNotes.length; i++) {
      final note = allNotes[i];
      final concepts = _extractConcepts(note.content);
      
      for (final concept in concepts) {
        if (!invertedIndex.containsKey(concept)) {
          invertedIndex[concept] = [];
          documentFrequencies[concept] = 0;
        }
        invertedIndex[concept]!.add(note.id!);
        documentFrequencies[concept] = (documentFrequencies[concept] ?? 0) + 1;
      }
    }
    
    // Calculate TF-IDF scores
    final totalDocuments = allNotes.length;
    final tfidfScores = <String, double>{};
    
    for (final concept in invertedIndex.keys) {
      final df = documentFrequencies[concept] ?? 0;
      final idf = totalDocuments > 0 ? (totalDocuments / df) : 1.0;
      tfidfScores[concept] = idf; // IDF score (higher = more important)
    }
    
    setState(() {
      _invertedIndex = invertedIndex;
      _tfidfScores = tfidfScores;
      _isLoading = false;
    });
    
    _findRelatedNotes();
    _generateSmartTags();
  }

  List<String> _extractConcepts(String text) {
    final concepts = <String>{};
    
    // Extract [[wiki-style links]]
    final wikiLinks = RegExp(r'\[\[([^\]]+)\]\]').allMatches(text);
    for (final match in wikiLinks) {
      concepts.add(match.group(1)!.toLowerCase());
    }
    
    // Extract hashtags
    final hashtags = RegExp(r'#(\w+)').allMatches(text);
    for (final match in hashtags) {
      concepts.add(match.group(1)!.toLowerCase());
    }
    
    // Extract capitalized words (excluding stopwords)
    final capitalizedWords = RegExp(r'\b[A-Z][a-zA-Z]+\b').allMatches(text);
    for (final match in capitalizedWords) {
      final word = match.group(0)!;
      if (!_stopwords.contains(word.toLowerCase()) && word.length > 2) {
        concepts.add(word.toLowerCase());
      }
    }
    
    return concepts.toList();
  }

  void _findRelatedNotes() async {
    if (_invertedIndex.isEmpty) return;
    
    setState(() {
      _isCalculatingSimilarity = true;
    });

    // Use isolate for heavy calculations
    final receivePort = ReceivePort();
    await Isolate.spawn(_calculateSimilarityIsolate, {
      'currentNote': widget.currentNote,
      'invertedIndex': _invertedIndex,
      'tfidfScores': _tfidfScores,
      'sendPort': receivePort.sendPort,
    });

    final result = await receivePort.first as List<RelatedNote>;
    
    setState(() {
      _relatedNotes = result.take(10).toList();
      _isCalculatingSimilarity = false;
    });
  }

  static void _calculateSimilarityIsolate(Map<String, dynamic> data) async {
    final currentNote = data['currentNote'] as Note;
    final invertedIndex = data['invertedIndex'] as Map<String, List<int>>;
    final tfidfScores = data['tfidfScores'] as Map<String, double>;
    final sendPort = data['sendPort'] as SendPort;

    final currentConcepts = _extractConceptsStatic(currentNote.content);
    final relatedNotes = <RelatedNote>[];
    
    // Get all notes that share concepts
    final sharedConcepts = <int, Map<String, double>>{};
    
    for (final concept in currentConcepts) {
      final noteIds = invertedIndex[concept] ?? [];
      final conceptWeight = tfidfScores[concept] ?? 1.0;
      
      for (final noteId in noteIds) {
        if (noteId != currentNote.id) {
          sharedConcepts.putIfAbsent(noteId, () => {});
          sharedConcepts[noteId]![concept] = conceptWeight;
        }
      }
    }
    
    // Calculate cosine similarity scores and sort
    for (final entry in sharedConcepts.entries) {
      final noteId = entry.key;
      final concepts = entry.value;
      
      // Calculate cosine similarity
      final similarity = _calculateCosineSimilarityStatic(currentConcepts, concepts, tfidfScores);
      
      relatedNotes.add(RelatedNote(
        note: Note(
          id: noteId,
          title: 'Note $noteId',
          content: '',
          createdAt: 0,
          updatedAt: 0,
          isEncrypted: false,
          tags: [],
        ),
        sharedConcepts: concepts,
        relevanceScore: similarity,
      ));
    }
    
    // Sort by cosine similarity (highest first)
    relatedNotes.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    
    sendPort.send(relatedNotes);
  }

  static List<String> _extractConceptsStatic(String text) {
    final concepts = <String>{};
    final stopwords = {
      'bu', 've', 'veya', 'ama', 'ancak', 'ile', 'için', 'gibi', 'olarak', 'daha',
      'çok', 'az', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz',
      'dokuz', 'on', 'yüz', 'bin', 'milyon', 'milyar', 'yok', 'var', 'değil',
      'mi', 'mı', 'mu', 'mü', 'ise', 'ne', 'nasıl', 'neden', 'nerede', 'ne zaman',
      'kim', 'hangi', 'kaç', 'kaçıncı', 'en', 'daha', 'az', 'çok', 'az', 'hiç',
      'her', 'tüm', 'bazı', 'birkaç', 'birçok', 'pek', 'oldukça', 'gayet', 'çok',
      'az', 'biraz', 'fazla', 'az', 'çok', 'oldukça', 'gayet', 'pek', 'çok',
      'the', 'and', 'or', 'but', 'however', 'with', 'for', 'like', 'as', 'to',
      'from', 'at', 'in', 'on', 'by', 'of', 'is', 'are', 'was', 'were', 'be',
      'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
      'could', 'should', 'may', 'might', 'must', 'can', 'shall', 'a', 'an', 'the',
      'this', 'that', 'these', 'those', 'it', 'its', 'they', 'them', 'their',
      'he', 'she', 'him', 'her', 'his', 'hers', 'we', 'us', 'our', 'you', 'your',
      'what', 'when', 'where', 'why', 'who', 'how', 'which', 'whom', 'whose',
      'if', 'then', 'else', 'than', 'so', 'such', 'too', 'very', 'quite', 'rather',
      'quite', 'pretty', 'just', 'only', 'also', 'even', 'still', 'yet', 'already',
      'now', 'then', 'here', 'there', 'up', 'down', 'out', 'off', 'over', 'under',
      'again', 'further', 'then', 'once', 'more', 'most', 'some', 'such', 'no',
      'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 'you'
    };
    
    // Extract [[wiki-style links]]
    final wikiLinks = RegExp(r'\[\[([^\]]+)\]\]').allMatches(text);
    for (final match in wikiLinks) {
      concepts.add(match.group(1)!.toLowerCase());
    }
    
    // Extract hashtags
    final hashtags = RegExp(r'#(\w+)').allMatches(text);
    for (final match in hashtags) {
      concepts.add(match.group(1)!.toLowerCase());
    }
    
    // Extract capitalized words (excluding stopwords)
    final capitalizedWords = RegExp(r'\b[A-Z][a-zA-Z]+\b').allMatches(text);
    for (final match in capitalizedWords) {
      final word = match.group(0)!;
      if (!stopwords.contains(word.toLowerCase()) && word.length > 2) {
        concepts.add(word.toLowerCase());
      }
    }
    
    return concepts.toList();
  }

  static double _calculateCosineSimilarityStatic(
    List<String> concepts1, 
    Map<String, double> concepts2, 
    Map<String, double> tfidfScores
  ) {
    // Convert concepts1 to weighted vector
    final vector1 = <String, double>{};
    for (final concept in concepts1) {
      vector1[concept] = tfidfScores[concept] ?? 1.0;
    }
    
    // Calculate dot product
    double dotProduct = 0;
    for (final concept in vector1.keys) {
      if (concepts2.containsKey(concept)) {
        dotProduct += vector1[concept]! * concepts2[concept]!;
      }
    }
    
    // Calculate magnitudes
    double magnitude1 = 0;
    for (final weight in vector1.values) {
      magnitude1 += weight * weight;
    }
    magnitude1 = magnitude1 > 0 ? sqrt(magnitude1) : 1.0;
    
    double magnitude2 = 0;
    for (final weight in concepts2.values) {
      magnitude2 += weight * weight;
    }
    magnitude2 = magnitude2 > 0 ? sqrt(magnitude2) : 1.0;
    
    // Calculate cosine similarity
    final similarity = magnitude1 * magnitude2 > 0 ? dotProduct / (magnitude1 * magnitude2) : 0;
    
    // Scale to 0-10 range for display
    return similarity * 10;
  }

  void _generateSmartTags() {
    final currentConcepts = _extractConcepts(widget.currentNote.content);
    final suggestedTags = <String>[];
    
    // Find high-weight concepts that aren't already tags
    for (final concept in currentConcepts) {
      final weight = _tfidfScores[concept] ?? 0;
      if (weight >= 2.0 && !widget.currentNote.tags.contains(concept)) {
        suggestedTags.add(concept);
      }
    }
    
    // Sort by TF-IDF weight and take top 5
    suggestedTags.sort((a, b) => (_tfidfScores[b] ?? 0).compareTo(_tfidfScores[a] ?? 0));
    
    setState(() {
      _suggestedTags = suggestedTags.take(5).toList();
    });
  }

  Note? _getNoteById(int id) {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      return noteProvider.notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildSmartTags(),
          const SizedBox(height: 16),
          _buildRelatedNotes(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(Icons.link, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            'İlişkili Düşünceler (${_relatedNotes.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          if (_isCalculatingSimilarity)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hesaplanıyor...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
              icon: Icon(Icons.share, color: Colors.grey.shade600, size: 16),
              onPressed: () => _navigateToGraphView(),
              tooltip: 'Graf Görünümü',
            ),
          Icon(Icons.info_outline, 
            color: Colors.grey.shade600,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSmartTags() {
    if (_suggestedTags.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 4),
              Text(
                'Otomatik Etiket Önerileri',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _suggestedTags.map((tag) {
              final weight = _tfidfScores[tag] ?? 0;
              return ActionChip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: _getConceptColor(weight).withOpacity(0.1),
                side: BorderSide(color: _getConceptColor(weight)),
                onPressed: () => _addTag(tag),
                avatar: Icon(
                  Icons.add,
                  size: 12,
                  color: _getConceptColor(weight),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedNotes() {
    if (_relatedNotes.isEmpty) {
      return Column(
        children: [
          Text(
            'Bu notla ilişkili başka not bulunamadı.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İpucu: [[KavramAdı]] veya #etiket kullanarak notları birbirine bağlayabilirsiniz.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu notla ortak kavramlara sahip notlar:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        ..._relatedNotes.map((relatedNote) => _buildRelatedNoteCard(relatedNote)),
      ],
    );
  }

  Widget _buildRelatedNoteCard(RelatedNote relatedNote) {
    final concepts = relatedNote.sharedConcepts.entries.toList();
    concepts.sort((a, b) => b.value.compareTo(a.value)); // Sort by TF-IDF weight
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToNote(relatedNote.note),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        relatedNote.note.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${relatedNote.relevanceScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  relatedNote.note.excerpt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: concepts.take(5).map((entry) {
                    final concept = entry.key;
                    final weight = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getConceptColor(weight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        concept,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getConceptColor(double weight) {
    // Color based on TF-IDF weight with semantic meaning
    if (weight >= 3.0) return Colors.red.shade600;    // 🔴 Çok nadir ve bu nota özel terim
    if (weight >= 2.0) return Colors.orange.shade600;  // 🟠 Önemli teknik terim
    if (weight >= 1.0) return Colors.blue.shade600;    // 🔵 Standart ortak kavram
    return Colors.grey.shade600;                        // 🔘 Genel geçer kelime
  }

  void _navigateToNote(Note note) {
    Navigator.of(context).pushNamed('/note-editor', arguments: note);
  }

  void _navigateToGraphView() {
    Navigator.of(context).pushNamed('/graph');
  }

  void _addTag(String tag) {
    // Add tag to current note
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final updatedNote = widget.currentNote.copyWith(
      tags: [...widget.currentNote.tags, tag],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    
    noteProvider.updateNote(updatedNote);
    
    // Remove from suggestions
    setState(() {
      _suggestedTags.remove(tag);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Etiket eklendi: $tag'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class RelatedNote {
  final Note note;
  final Map<String, double> sharedConcepts;
  final double relevanceScore;

  RelatedNote({
    required this.note,
    required this.sharedConcepts,
    required this.relevanceScore,
  });
}

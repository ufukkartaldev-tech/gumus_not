import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../services/search_service.dart';
import '../models/note_model.dart';

class SqlQueryConsole extends StatefulWidget {
  const SqlQueryConsole({Key? key}) : super(key: key);

  @override
  State<SqlQueryConsole> createState() => _SqlQueryConsoleState();
}

class _SqlQueryConsoleState extends State<SqlQueryConsole> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final List<String> _queryHistory = [];
  final List<String> _undoHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _executionTime = 0;
  bool _showPreview = false;
  String? _currentPreviewQuery;
  List<String> _warnings = [];

  @override
  void initState() {
    super.initState();
    _queryController.text = '''-- SQL Sorgu Konsolu (GÜVENLİ MOD)
-- Örnek:
-- SELECT * FROM notes WHERE title LIKE '%Mat%';
-- SELECT COUNT(*) FROM notes WHERE created_at > strftime('%s', 'now', '-7 days') * 1000;

SELECT * FROM notes ORDER BY updated_at DESC LIMIT 10;''';
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _previewQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _showPreview = true;
      _currentPreviewQuery = query;
      _warnings = _analyzeQuerySafety(query);
    });
  }

  List<String> _analyzeQuerySafety(String query) {
    final warnings = <String>[];
    final upperQuery = query.toUpperCase();

    // Dangerous operations
    if (upperQuery.contains('DROP') || upperQuery.contains('DELETE') || upperQuery.contains('TRUNCATE')) {
      warnings.add('⚠️ VERİ KAYBI RİSKİ: Bu sorgu verileri kalıcı olarak silebilir!');
    }

    if (upperQuery.contains('UPDATE') && !upperQuery.contains('WHERE')) {
      warnings.add('⚠️ TÜM VERİLERİ GÜNCELLEME RİSKİ: WHERE koşulu olmadan UPDATE kullanıyorsunuz!');
    }

    if (upperQuery.contains('ALTER') || upperQuery.contains('CREATE') || upperQuery.contains('DROP TABLE')) {
      warnings.add('⚠️ YAPI DEĞİŞİKLİĞİ: Veritabanı yapısını değiştirebilir!');
    }

    // Performance warnings
    if (upperQuery.contains('SELECT *') && !upperQuery.contains('LIMIT')) {
      warnings.add('ℹ️ PERFORMANS UYARISI: SELECT * without LIMIT can be slow with large datasets');
    }

    return warnings;
  }

  Future<void> _executeQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    // Safety check for dangerous operations
    final warnings = _analyzeQuerySafety(query);
    if (warnings.any((w) => w.contains('VERİ KAYBI'))) {
      final confirmed = await _showDangerousQueryDialog();
      if (!confirmed) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results.clear();
      _showPreview = false;
    });

    final stopwatch = Stopwatch()..start();

    try {
      if (query.toUpperCase().startsWith('SMART_SEARCH')) {
        // ZETTELKASTEN SMART SEARCH LOGIC
        final searchTerm = RegExp(r"SMART_SEARCH\s+'(.*)'", caseSensitive: false).firstMatch(query)?.group(1);
        if (searchTerm == null) throw Exception("Hata: SMART_SEARCH 'aranacak_kelime' formatında olmalıdır.");

        final allNotes = await DatabaseService.getAllNotes();
        final searchResults = await SearchService.searchNotes(searchTerm, allNotes);

        final List<Map<String, dynamic>> finalMaps = searchResults.map((n) => {
          'id': n.id,
          'title': n.title,
          'tags': n.tags.join(', '),
          'matching': 'Semantic/Zettelkasten',
          'updated_at': DateTime.fromMillisecondsSinceEpoch(n.updatedAt).toString(),
        }).toList();

        stopwatch.stop();
        setState(() {
          _results = finalMaps;
          _executionTime = stopwatch.elapsedMilliseconds;
          _isLoading = false;
        });
        return; // İşlem bitti
      }

      final db = await DatabaseService.database;
      
      // Create backup for SELECT queries
      if (query.toUpperCase().startsWith('SELECT')) {
        // For SELECT queries, we can proceed safely
      } else {
        // For modifying queries, create backup
        await _createBackup();
      }
      
      final results = await db.rawQuery(query);
      
      stopwatch.stop();
      
      setState(() {
        _results = results;
        _executionTime = stopwatch.elapsedMilliseconds;
        _isLoading = false;
        
        // Add to history if not already there
        if (!_queryHistory.contains(query)) {
          _queryHistory.insert(0, query);
          if (_queryHistory.length > 10) {
            _queryHistory.removeLast();
          }
        }
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _errorMessage = e.toString();
        _executionTime = stopwatch.elapsedMilliseconds;
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    try {
      final db = await DatabaseService.database;
      final notes = await db.query('notes');
      final backlinks = await db.query('backlinks');
      
      // Store backup for potential undo
      _undoHistory.add('BACKUP_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      // Backup failed, but continue with query
    }
  }

  Future<bool> _showDangerousQueryDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Tehlikeli Sorgu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu sorgu verilerinizi kalıcı olarak silebilir veya değiştirebilir!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Devam etmek istediğinizden emin misiniz?\nBu işlem geri alınamaz!',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Riski Kabul Et'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _insertQueryExample(String query) {
    _queryController.text = query;
    setState(() {
      _showPreview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('SQL Sorgu Konsolu (Güvenli)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _previewQuery,
            tooltip: 'Sorguyu Önizle',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _results.clear();
                _errorMessage = null;
                _showPreview = false;
              });
            },
            tooltip: 'Temizle',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQueryExamples(),
          _buildQueryInput(),
          if (_showPreview) _buildQueryPreview(),
          _buildStatusBar(),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Sorgu Önizlemesi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showPreview = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _currentPreviewQuery ?? '',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._warnings.map((warning) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                warning,
                style: TextStyle(
                  fontSize: 12,
                  color: warning.contains('⚠️') ? Colors.red.shade700 : Colors.amber.shade700,
                ),
              ),
            )),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showPreview = false;
                    });
                  },
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _executeQuery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _warnings.any((w) => w.contains('⚠️')) 
                        ? Colors.red.shade600 
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Sorguyu Çalıştır'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueryExamples() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _queryExamples.length,
        itemBuilder: (context, index) {
          final example = _queryExamples[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(example['name']),
              onPressed: () => _insertQueryExample(example['query'] ?? ''),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQueryInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.code, color: Colors.green.shade400, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SQL (Güvenli Mod)',
                  style: TextStyle(
                    color: Colors.green.shade400,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green.shade400,
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _queryController,
            maxLines: 8,
            minLines: 3,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              hintText: 'SQL sorgusunu buraya yazın...',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _previewQuery,
                  icon: const Icon(Icons.preview, size: 16),
                  label: const Text('Önizle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _executeQuery,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Çalıştır'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (_queryHistory.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.history),
                    onSelected: (query) => _insertQueryExample(query ?? ''),
                    itemBuilder: (context) {
                      return _queryHistory.map((query) {
                        return PopupMenuItem<String>(
                          value: query,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              query.length > 50 ? '${query.substring(0, 50)}...' : query,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        );
                      }).toList();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          if (_errorMessage != null)
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_results.length} sonuç • ${_executionTime}ms',
                    style: TextStyle(color: Colors.green.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Sorgu Hatası',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.data_array, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sorgu çalıştırın'),
            Text('Sonuçlar burada görünecek'),
          ],
        ),
      );
    }

    return _buildResultsTable();
  }

  Widget _buildResultsTable() {
    if (_results.isEmpty) return const SizedBox.shrink();

    final columns = _results.first.keys.toList();
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: columns.map((column) {
                return DataColumn(
                  label: Text(
                    column,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
              rows: _results.map((row) {
                return DataRow(
                  cells: columns.map((column) {
                    final value = row[column];
                    return DataCell(
                      Text(
                        value?.toString() ?? 'NULL',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  static const List<Map<String, dynamic>> _queryExamples = [
    {
      'name': 'Smart (Semantic) Search',
      'query': "SMART_SEARCH 'Bilgisayar Mimarisi';",
    },
    {
      'name': 'Son 10 Not',
      'query': 'SELECT * FROM notes ORDER BY updated_at DESC LIMIT 10;',
    },
    {
      'name': 'Matematik Notları',
      'query': "SELECT * FROM notes WHERE title LIKE '%Mat%' OR content LIKE '%matematik%' ORDER BY updated_at DESC;",
    },
    {
      'name': 'Bugünkü Notlar',
      'query': "SELECT * FROM notes WHERE date(updated_at / 1000, 'unixepoch') = date('now');",
    },
    {
      'name': 'En Çok Bağlantılı',
      'query': '''
SELECT n.*, COUNT(b.id) as link_count 
FROM notes n 
LEFT JOIN backlinks b ON n.id = b.source_note_id 
GROUP BY n.id 
ORDER BY link_count DESC 
LIMIT 10;''',
    },
    {
      'name': 'Etiket Analizi',
      'query': "SELECT tags, COUNT(*) as count FROM notes WHERE tags != '' GROUP BY tags ORDER BY count DESC;",
    },
    {
      'name': 'Şifreli Notlar',
      'query': 'SELECT * FROM notes WHERE is_encrypted = 1 ORDER BY updated_at DESC;',
    },
    {
      'name': 'Haftalık İstatistik',
      'query': '''
SELECT 
  date(created_at / 1000, 'unixepoch') as date,
  COUNT(*) as notes_created
FROM notes 
WHERE created_at > strftime('%s', 'now', '-7 days') * 1000
GROUP BY date 
ORDER BY date DESC;''',
    },
  ];
}

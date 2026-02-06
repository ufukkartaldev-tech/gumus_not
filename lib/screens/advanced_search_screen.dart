import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _searchInTitle = true;
  bool _searchInContent = true;
  bool _searchInTags = false;
  List<Note> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final query = _searchController.text.trim();
    
    if (query.isEmpty && _selectedTag.isEmpty && _startDate == null && _endDate == null) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    List<Note> results = List.from(noteProvider.notes);

    // Filter by text query
    if (query.isNotEmpty) {
      results = results.where((note) {
        bool matches = false;
        
        if (_searchInTitle && note.title.toLowerCase().contains(query.toLowerCase())) {
          matches = true;
        }
        
        if (_searchInContent && note.content.toLowerCase().contains(query.toLowerCase())) {
          matches = true;
        }
        
        if (_searchInTags && note.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))) {
          matches = true;
        }
        
        return matches;
      }).toList();
    }

    // Filter by tag
    if (_selectedTag.isNotEmpty) {
      results = results.where((note) => note.tags.contains(_selectedTag)).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      results = results.where((note) => note.updatedAt >= _startDate!.millisecondsSinceEpoch).toList();
    }
    
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      results = results.where((note) => note.updatedAt <= endOfDay.millisecondsSinceEpoch).toList();
    }

    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişmiş Arama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            onPressed: _performSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Ara',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text Search
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Arama terimi...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                
                const SizedBox(height: 16),
                
                // Search Options
                Text(
                  'Arama Alanları',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                CheckboxListTile(
                  title: const Text('Başlık'),
                  value: _searchInTitle,
                  onChanged: (value) {
                    setState(() {
                      _searchInTitle = value ?? true;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                
                CheckboxListTile(
                  title: const Text('İçerik'),
                  value: _searchInContent,
                  onChanged: (value) {
                    setState(() {
                      _searchInContent = value ?? true;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                
                CheckboxListTile(
                  title: const Text('Etiketler'),
                  value: _searchInTags,
                  onChanged: (value) {
                    setState(() {
                      _searchInTags = value ?? false;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 16),
                
                // Tag Filter
                Consumer<NoteProvider>(
                  builder: (context, noteProvider, child) {
                    final tagFrequency = noteProvider.getTagFrequency();
                    
                    if (tagFrequency.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Etiket Filtresi',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildTagChip('Tümü', '', _selectedTag.isEmpty),
                            ...tagFrequency.keys.map((tag) {
                              final count = tagFrequency[tag]!;
                              return _buildTagChip('#$tag ($count)', tag, _selectedTag == tag);
                            }),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Date Range Filter
                Text(
                  'Tarih Aralığı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Başlangıç',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            _startDate != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                : 'Seçilmemiş',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Bitiş',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            _endDate != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'Seçilmemiş',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Clear Filters
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearFilters,
                        child: const Text('Filtreleri Temizle'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _performSearch,
                        child: const Text('Ara'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, String tag, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTag = selected ? tag : '';
        });
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                color: Theme.of(context).disabledColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final note = _searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(note.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (note.tags.isNotEmpty) ...[
                      ...note.tags.take(3).map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Chip(
                          label: Text('#$tag'),
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 10,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )),
                      if (note.tags.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '+${note.tags.length - 3}',
                            style: TextStyle(
                              color: Theme.of(context).disabledColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                color: Theme.of(context).disabledColor,
                fontSize: 12,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop(note);
            },
          ),
        );
      },
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedTag = '';
      _startDate = null;
      _endDate = null;
      _searchInTitle = true;
      _searchInContent = true;
      _searchInTags = false;
      _searchResults = [];
    });
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }
}

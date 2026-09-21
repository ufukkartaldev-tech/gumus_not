import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class CodeSnippetsScreen extends StatefulWidget {
  const CodeSnippetsScreen({Key? key}) : super(key: key);

  @override
  State<CodeSnippetsScreen> createState() => _CodeSnippetsScreenState();
}

class _CodeSnippetsScreenState extends State<CodeSnippetsScreen> {
  String _searchQuery = '';
  String _selectedTag = 'Tümü';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kod Parçacıkları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final allNotes = noteProvider.notes;
          // Filter notes that have 'snippet' or 'kod' in tags, or we just consider notes in 'Kod' folder
          final snippetNotes = allNotes.where((n) {
            final lowerTags = n.tags.map((t) => t.toLowerCase()).toList();
            return lowerTags.contains('snippet') || lowerTags.contains('kod');
          }).toList();
          
          // Extract all unique tags from snippet notes
          final Set<String> allTags = {'Tümü'};
          for (var note in snippetNotes) {
            for (var tag in note.tags) {
              if (tag.toLowerCase() != 'snippet' && tag.toLowerCase() != 'kod') {
                allTags.add(tag);
              }
            }
          }
          
          // Filter by search query and selected tag
          var filteredNotes = snippetNotes.where((n) {
            final matchesSearch = n.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                  n.content.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesTag = _selectedTag == 'Tümü' || n.tags.contains(_selectedTag);
            return matchesSearch && matchesTag;
          }).toList();
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Kod parçacıklarında ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              if (allTags.length > 1)
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allTags.length,
                    itemBuilder: (context, index) {
                      final tag = allTags.elementAt(index);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: _selectedTag == tag,
                          onSelected: (selected) {
                            setState(() => _selectedTag = selected ? tag : 'Tümü');
                          },
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: filteredNotes.isEmpty 
                  ? _buildEmptyState() 
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.code, color: Colors.blue),
                            title: Text(note.title.isEmpty ? 'İsimsiz Kod' : note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              note.excerpt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.of(context).pushNamed('/note-editor', arguments: note);
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newSnippet = Note(
            title: '',
            content: '```\n// Kodunuzu buraya yazın\n```',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            tags: ['snippet'],
          );
          Navigator.of(context).pushNamed('/note-editor', arguments: newSnippet);
        },
        child: const Icon(Icons.add),
        tooltip: 'Yeni Kod Parçacığı',
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code_off, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text(
            'Kod parçacığı bulunamadı',
            style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir kod parçacığı eklemek için + butonuna tıklayın.',
            style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

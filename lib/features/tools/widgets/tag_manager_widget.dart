import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class TagManagerWidget extends StatefulWidget {
  final List<String> initialTags;
  final Function(List<String>) onTagsChanged;

  const TagManagerWidget({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<TagManagerWidget> createState() => _TagManagerWidgetState();
}

class _TagManagerWidgetState extends State<TagManagerWidget> {
  late List<String> _tags;
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;
    
    final cleanTag = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (!_tags.contains(cleanTag)) {
      setState(() {
        _tags.add(cleanTag);
      });
      widget.onTagsChanged(_tags);
    }
    _tagController.clear();
    _tagFocusNode.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onTagsChanged(_tags);
  }

  void _showTagSuggestions() {
    showDialog(
      context: context,
      builder: (context) => Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final allTags = noteProvider.getTagFrequency().keys.toList();
          final suggestions = allTags.where((tag) => !_tags.contains(tag)).toList();
          
          return AlertDialog(
            title: const Text('Etiket Önerileri'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: suggestions.isEmpty
                  ? const Center(child: Text('Öneri bulunmuyor'))
                  : ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final tag = suggestions[index];
                        final count = noteProvider.getTagFrequency()[tag] ?? 0;
                        return ListTile(
                          title: Text('#$tag'),
                          subtitle: Text('$count not'),
                          onTap: () {
                            _addTag(tag);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tag_rounded,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Etiketler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Existing tags
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            return Chip(
              label: Text('#$tag'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _removeTag(tag),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              deleteIconColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 12),
        
        // Add tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                focusNode: _tagFocusNode,
                decoration: InputDecoration(
                  hintText: 'Etiket ekle...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  _addTag(_tagController.text);
                }
              },
              icon: const Icon(Icons.add),
              tooltip: 'Etiket Ekle',
            ),
            IconButton(
              onPressed: _showTagSuggestions,
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: 'Etiket Önerileri',
            ),
          ],
        ),
        
        // Quick tag suggestions
        Consumer<NoteProvider>(
          builder: (context, noteProvider, child) {
            final popularTags = noteProvider.getTagFrequency().entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            
            final topTags = popularTags.take(5).where((entry) => !_tags.contains(entry.key)).toList();
            
            if (topTags.isEmpty) return const SizedBox.shrink();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Popüler Etiketler:',
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: topTags.map((entry) {
                    final tag = entry.key;
                    final count = entry.value;
                    return ActionChip(
                      label: Text('#$tag ($count)'),
                      onPressed: () => _addTag(tag),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      labelStyle: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

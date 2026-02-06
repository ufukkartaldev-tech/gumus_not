import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../screens/note_list_screen.dart';
import '../widgets/tag_cloud_widget.dart';

class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({Key? key}) : super(key: key);

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiket Yönetimi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final tagFrequency = noteProvider.getTagFrequency();
          final allTags = tagFrequency.keys.toList();
          
          // Filter tags based on search
          final filteredTags = _searchQuery.isEmpty
              ? allTags
              : allTags.where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Etiketlerde ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Statistics
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İstatistikler',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Toplam: ${allTags.length} etiket',
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Filtrelenmiş: ${filteredTags.length} etiket',
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tags list
              Expanded(
                child: filteredTags.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.label_off_rounded,
                              size: 64,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Henüz etiket bulunmuyor'
                                  : 'Eşleşen etiket bulunmuyor',
                              style: TextStyle(
                                color: Theme.of(context).disabledColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = filteredTags[index];
                          final count = tagFrequency[tag] ?? 0;
                          final notes = noteProvider.getNotesByTag(tag);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Text(
                                  '#$tag'[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text('#$tag'),
                              subtitle: Text('$count not'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => TagFilteredScreen(tag: tag),
                                        ),
                                      );
                                    },
                                    tooltip: 'Notları Görüntüle',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showRenameTagDialog(tag),
                                    tooltip: 'Etiketi Yeniden Adlandır',
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => TagFilteredScreen(tag: tag),
                                  ),
                                );
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
    );
  }

  void _showRenameTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Etiketi Yeniden Adlandır: #$oldTag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Yeni etiket adı',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final newTag = controller.text.trim().toLowerCase().replaceAll(' ', '_');
              if (newTag.isNotEmpty && newTag != oldTag) {
                _renameTag(oldTag, newTag);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Yeniden Adlandır'),
          ),
        ],
      ),
    );
  }

  void _renameTag(String oldTag, String newTag) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final notes = noteProvider.getNotesByTag(oldTag);
    
    for (final note in notes) {
      final updatedTags = note.tags.map((tag) => tag == oldTag ? newTag : tag).toList();
      final updatedNote = note.copyWith(tags: updatedTags);
      noteProvider.updateNote(updatedNote);
    }
  }
}

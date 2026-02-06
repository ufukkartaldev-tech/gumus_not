import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';

class TagCloudWidget extends StatelessWidget {
  const TagCloudWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final tagFrequency = noteProvider.getTagFrequency();
        
        if (tagFrequency.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Henüz etiket bulunmuyor',
              style: TextStyle(
                color: Theme.of(context).disabledColor,
                fontSize: 14,
              ),
            ),
          );
        }

        // Sort tags by frequency
        final sortedTags = tagFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                    'Etiket Bulutu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sortedTags.length} etiket',
                    style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedTags.map((entry) {
                  final tag = entry.key;
                  final count = entry.value;
                  final maxCount = sortedTags.first.value;
                  final minCount = sortedTags.last.value;
                  
                  // Calculate font size based on frequency
                  double fontSize = 12;
                  if (maxCount != minCount) {
                    final ratio = (count - minCount) / (maxCount - minCount);
                    fontSize = 12 + (ratio * 8); // 12-20 font size range
                  } else {
                    fontSize = 14;
                  }
                  
                  // Calculate opacity based on frequency
                  double opacity = 0.6;
                  if (maxCount != minCount) {
                    final ratio = (count - minCount) / (maxCount - minCount);
                    opacity = 0.6 + (ratio * 0.4); // 0.6-1.0 opacity range
                  } else {
                    opacity = 0.8;
                  }

                  return InkWell(
                    onTap: () {
                      // Navigate to filtered view for this tag
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TagFilteredScreen(tag: tag),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(opacity * 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor.withOpacity(opacity),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(opacity * 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: fontSize * 0.7,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor.withOpacity(opacity),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TagFilteredScreen extends StatefulWidget {
  final String tag;

  const TagFilteredScreen({Key? key, required this.tag}) : super(key: key);

  @override
  State<TagFilteredScreen> createState() => _TagFilteredScreenState();
}

class _TagFilteredScreenState extends State<TagFilteredScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.tag}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final notes = noteProvider.getNotesByTag(widget.tag);
          
          if (notes.isEmpty) {
            return Center(
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
                    'Bu etikete ait not bulunmuyor',
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
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(note.title),
                  subtitle: Text(
                    note.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${note.tags.length} etiket',
                    style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Navigate to note editor if needed
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

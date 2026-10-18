import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class EditorBacklinkSection extends StatelessWidget {
  final int? currentNoteId;
  final String currentTitle;

  const EditorBacklinkSection({
    super.key,
    required this.currentNoteId,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final normalizedTitle = currentTitle.trim().toLowerCase();

    if (normalizedTitle.isEmpty) return const SizedBox.shrink();

    final backlinks = noteProvider.notes.where((n) {
      if (n.id == currentNoteId || n.isEncrypted) return false;
      return n.content.toLowerCase().contains('[[$normalizedTitle]]');
    }).toList();

    if (backlinks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Geri Bağlantılar (${backlinks.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...backlinks.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context)
                      .pushReplacementNamed('/note-editor', arguments: n);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.content.length > 60
                            ? '${n.content.substring(0, 60)}...'
                            : n.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.disabledColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

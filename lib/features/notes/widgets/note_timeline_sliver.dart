import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/widgets/note_card.dart';
import 'package:connected_notebook/features/notes/widgets/swipeable_note_card.dart';

class NoteTimelineSliver extends StatelessWidget {
  final List<Note> notes;
  final ValueChanged<Note> onSelectNote;
  final ValueChanged<Note> onDeleteNote;
  final ValueChanged<Note> onDeleteNoteWithUndo;
  final ValueChanged<Note> onArchiveNote;
  final ValueChanged<Note> onTogglePin;
  final ValueChanged<Note> onExportNote;

  const NoteTimelineSliver({
    super.key,
    required this.notes,
    required this.onSelectNote,
    required this.onDeleteNote,
    required this.onDeleteNoteWithUndo,
    required this.onArchiveNote,
    required this.onTogglePin,
    required this.onExportNote,
  });

  String _formatTimelineHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Bugün';
    }
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Dün';
    }
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final note = notes[index];
          final date = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
          final prevDate = index > 0
              ? DateTime.fromMillisecondsSinceEpoch(notes[index - 1].updatedAt)
              : null;

          final isNewDay = prevDate == null ||
              date.day != prevDate.day ||
              date.month != prevDate.month ||
              date.year != prevDate.year;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNewDay)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
                  child: Text(
                    _formatTimelineHeader(date),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Theme.of(context).disabledColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SwipeableNoteCard(
                          note: note,
                          isPinned: note.tags.contains('sabit'),
                          onTogglePin: () => onTogglePin(note),
                          onDelete: () => onDeleteNoteWithUndo(note),
                          onArchive: () => onArchiveNote(note),
                          child: NoteCard(
                            note: note,
                            isPinned: note.tags.contains('sabit'),
                            onTap: () => onSelectNote(note),
                            onEdit: () => onSelectNote(note),
                            onDelete: () => onDeleteNote(note),
                            onTogglePin: () => onTogglePin(note),
                            onExport: () => onExportNote(note),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        childCount: notes.length,
      ),
    );
  }
}

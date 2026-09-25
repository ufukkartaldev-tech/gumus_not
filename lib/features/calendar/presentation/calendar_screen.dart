import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  /// Returns all notes created OR updated on the given day
  List<Note> _getNotesForDay(DateTime date, List<Note> allNotes) {
    return allNotes.where((note) {
      final created = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
      final updated = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
      return isSameDay(created, date) || isSameDay(updated, date);
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay, List<Note> allNotes) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final notes = _getNotesForDay(selectedDay, allNotes);

    if (notes.isEmpty) {
      // No notes → ask to create new
      _showEmptyDaySheet(selectedDay);
    } else if (notes.length == 1) {
      // Only one note → go directly
      Navigator.of(context).pushNamed('/note-editor', arguments: notes.first);
    } else {
      // Multiple notes → show list
      _showDayNotesSheet(selectedDay, notes);
    }
  }

  void _showEmptyDaySheet(DateTime date) {
    final label = DateFormat('d MMMM yyyy', 'tr').format(date);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('📅 $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Bu gün için henüz not yok.', style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Bu Gün İçin Not Oluştur'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final newNote = Note(
                      title: DateFormat('yyyy-MM-dd').format(date),
                      content: '',
                      createdAt: date.millisecondsSinceEpoch,
                      updatedAt: date.millisecondsSinceEpoch,
                      tags: ['günlük'],
                      folderName: 'Günlükler',
                      emojiIcon: '📅',
                    );
                    Navigator.of(context).pushNamed('/note-editor', arguments: newNote);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDayNotesSheet(DateTime date, List<Note> notes) {
    final theme = Theme.of(context);
    final label = DateFormat('d MMMM yyyy', 'tr').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📅 $label',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('${notes.length} not bulundu',
                              style: TextStyle(fontSize: 13, color: theme.disabledColor)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final newNote = Note(
                            title: DateFormat('yyyy-MM-dd').format(date),
                            content: '',
                            createdAt: date.millisecondsSinceEpoch,
                            updatedAt: date.millisecondsSinceEpoch,
                            tags: ['günlük'],
                            folderName: 'Günlükler',
                            emojiIcon: '📅',
                          );
                          Navigator.of(context).pushNamed('/note-editor', arguments: newNote);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Yeni Not'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final note = notes[index];
                        final updatedAt = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
                        final timeLabel = DateFormat('HH:mm').format(updatedAt);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          leading: note.emojiIcon != null
                              ? Text(note.emojiIcon!, style: const TextStyle(fontSize: 28))
                              : CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.article_outlined,
                                      size: 18, color: theme.primaryColor),
                                ),
                          title: Text(
                            note.title.isEmpty ? 'Başlıksız Not' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: note.content.isNotEmpty
                              ? Text(
                                  MarkdownCleaner.clean(note.content),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: theme.disabledColor),
                                )
                              : null,
                          trailing: Text(timeLabel,
                              style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamed('/note-editor', arguments: note);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Takvim & Günlükler'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final allNotes = noteProvider.notes;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1F24) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TableCalendar<Note>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        eventLoader: (day) => _getNotesForDay(day, allNotes),
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          _onDaySelected(selectedDay, focusedDay, allNotes);
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Selected day note count hint
                    if (_selectedDay != null)
                      Builder(builder: (_) {
                        final notes = _getNotesForDay(_selectedDay!, allNotes);
                        if (notes.isEmpty) {
                          return Text(
                            'Seçili günde not yok — tıklayıp oluşturabilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.disabledColor, fontSize: 13),
                          );
                        }
                        return Text(
                          '${notes.length} not bu güne ait — tıklayarak listeleyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

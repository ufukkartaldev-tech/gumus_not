import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../providers/theme_provider.dart';
import '../models/note_model.dart'; // Ensure Note model is imported

class CommandPalette extends StatefulWidget {
  final Function(Note?)? onNoteSelected; // Make generic, passes nullable Note

  const CommandPalette({Key? key, this.onNoteSelected}) : super(key: key);

  static void show(BuildContext context, {Function(Note?)? onNoteSelected}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => CommandPalette(onNoteSelected: onNoteSelected),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = Provider.of<NoteProvider>(context);

    // Filter commands and notes
    final commands = _getCommands(context);
    final notes = noteProvider.notes;
    
    final filteredCommands = commands.where((cmd) => 
      cmd.label.toLowerCase().contains(_query.toLowerCase())
    ).toList();
    
    final filteredNotes = notes.where((note) => 
      note.title.toLowerCase().contains(_query.toLowerCase())
    ).take(5).toList(); // Limit to 5 notes

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 100, left: 16, right: 16),
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.search, color: theme.disabledColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Bir komut yazın veya not arayın...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 18),
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ESC',
                        style: TextStyle(fontSize: 10, color: theme.disabledColor),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              
              // Results List
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (filteredCommands.isNotEmpty) ...[
                      _buildSectionHeader('KOMUTLAR', theme),
                      ...filteredCommands.map((cmd) => _buildCommandTile(cmd, context)),
                    ],
                    
                    if (filteredNotes.isNotEmpty) ...[
                       if (filteredCommands.isNotEmpty) const Divider(),
                       _buildSectionHeader('NOTLAR', theme),
                       ...filteredNotes.map((note) => _buildNoteTile(note, context)),
                    ],
                    
                    if (filteredCommands.isEmpty && filteredNotes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Sonuç bulunamadı',
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.disabledColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCommandTile(CommandItem cmd, BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(cmd.icon, size: 20, color: theme.colorScheme.secondary),
      title: Text(cmd.label, style: const TextStyle(fontSize: 14)),
      dense: true,
      hoverColor: theme.colorScheme.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        cmd.action();
      },
    );
  }

  Widget _buildNoteTile(Note note, BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.description_outlined, size: 20),
      title: Text(note.title.isNotEmpty ? note.title : 'Başlıksız Not', 
        style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        _formatDate(note.updatedAt),
        style: TextStyle(fontSize: 11, color: theme.disabledColor),
      ),
      dense: true,
      hoverColor: theme.colorScheme.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context); // Close palette
        // if (widget.onNoteSelected != null) {
        //   widget.onNoteSelected!(note);
        // } else {
           // Default nav if no callback
           // We need a way to open the editor. 
           // Usually we can push a route.
           Navigator.of(context).pushNamed('/note-editor', arguments: note).then((_) {
               // Reload notes when coming back
               Provider.of<NoteProvider>(context, listen: false).loadNotes();
           });
        // }
      },
      trailing: const Icon(Icons.keyboard_return, size: 14, color: Colors.grey),
    );
  }
  
  String _formatDate(int timestamp) {
     final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
     return '${date.day}.${date.month}.${date.year}';
  }

  List<CommandItem> _getCommands(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return [
      CommandItem(
        icon: Icons.add,
        label: 'Yeni Not Oluştur',
        action: () {
          Navigator.of(context).pushNamed('/note-editor').then((_) {
             Provider.of<NoteProvider>(context, listen: false).loadNotes();
          });
        },
      ),
      CommandItem(
        icon: Icons.bubble_chart_rounded,
        label: 'Bağlantı Grafiğini Görüntüle',
        action: () => Navigator.of(context).pushNamed('/graph'),
      ),
      CommandItem(
        icon: themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
        label: themeProvider.themeMode == ThemeMode.dark ? 'Aydınlık Temaya Geç' : 'Karanlık Temaya Geç',
        action: () => themeProvider.setThemeMode(themeProvider.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
      ),
      CommandItem(
        icon: Icons.settings,
        label: 'Ayarlar',
        action: () => Navigator.of(context).pushNamed('/settings'),
      ),
      // Future: Export, Templates etc.
    ];
  }
}

class CommandItem {
  final IconData icon;
  final String label;
  final VoidCallback action;

  CommandItem({required this.icon, required this.label, required this.action});
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/settings/presentation/settings_screen.dart';

class NoteNavigationDrawer extends StatelessWidget {
  final VoidCallback onSelectFavorites;
  final VoidCallback onOpenDailyNote;
  final VoidCallback onOpenRandomNote;
  final ValueChanged<String> onSelectFolder;
  final ValueChanged<String> onSelectTag;

  const NoteNavigationDrawer({
    super.key,
    required this.onSelectFavorites,
    required this.onOpenDailyNote,
    required this.onOpenRandomNote,
    required this.onSelectFolder,
    required this.onSelectTag,
  });

  int _countWords(List<Note> notes) {
    int count = 0;
    final wordRegex = RegExp(r'\w+');
    for (final note in notes) {
      if (note.isEncrypted) continue;
      count += wordRegex.allMatches(note.content).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final notes = noteProvider.notes;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              image: DecorationImage(
                image: const AssetImage('assets/header_bg.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.3),
                  BlendMode.darken,
                ),
                onError: (_, _) {},
              ),
            ),
            accountName: const Text(
              'GümüşNot',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              '${notes.length} not • ${_countWords(notes)} kelime',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'GN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: Colors.amber),
                  title: const Text('Sabitlenen Notlar'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelectFavorites();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Bugünün Notu'),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenDailyNote();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shuffle),
                  title: const Text('Rastgele Not'),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenRandomNote();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text('Takvim & Günlük'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/calendar');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hub, color: Colors.indigoAccent),
                  title: const Text('Bağlantı Haritası'),
                  subtitle: const Text('İlişkisel Görünüm'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GraphViewScreen()),
                    );
                  },
                ),
                const Divider(),
                ExpansionTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Klasörler'),
                  children: _buildFolderListForDrawer(context, noteProvider),
                ),
                ExpansionTile(
                  leading: const Icon(Icons.label_outline),
                  title: const Text('Etiketler'),
                  children: _buildTagListForDrawer(context, noteProvider),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Ayarlar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildTagListForDrawer(
    BuildContext context,
    NoteProvider noteProvider,
  ) {
    final tags = noteProvider.tagFrequency.keys;

    if (tags.isEmpty) {
      return [
        const ListTile(
          title: Text('Henüz etiket yok', style: TextStyle(color: Colors.grey)),
        ),
      ];
    }

    return tags
        .map(
          (tag) => ListTile(
            leading: const Icon(Icons.label, size: 18),
            title: Text(tag),
            onTap: () {
              Navigator.pop(context);
              onSelectTag(tag);
            },
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            dense: true,
          ),
        )
        .toList();
  }

  List<Widget> _buildFolderListForDrawer(
    BuildContext context,
    NoteProvider noteProvider,
  ) {
    final folderList = noteProvider.folders;

    if (folderList.isEmpty) {
      return [
        const ListTile(
          title: Text('Klasör bulunamadı', style: TextStyle(color: Colors.grey)),
          contentPadding: EdgeInsets.only(left: 32),
        ),
      ];
    }

    return folderList.map((folder) {
      final count = noteProvider.getNoteCountInFolder(folder);
      return ListTile(
        leading: const Icon(Icons.folder_outlined, size: 18),
        title: Text(folder),
        trailing: Text(
          count.toString(),
          style: TextStyle(
            color: Theme.of(context).disabledColor,
            fontSize: 12,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onSelectFolder(folder);
        },
        contentPadding: const EdgeInsets.only(left: 32, right: 32),
        dense: true,
      );
    }).toList();
  }
}

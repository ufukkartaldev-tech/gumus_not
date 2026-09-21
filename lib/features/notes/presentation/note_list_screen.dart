import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';
import 'package:connected_notebook/core/security/legacy_encryption_service_adapter.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/widgets/note_card.dart';
import 'package:connected_notebook/features/notes/widgets/custom_widgets.dart';
import 'package:connected_notebook/features/tools/widgets/activity_heatmap.dart';
import 'package:connected_notebook/features/tools/widgets/command_palette.dart';
import 'package:connected_notebook/features/notes/widgets/tag_cloud_widget.dart';
import 'package:connected_notebook/features/export/presentation/latex_export_screen.dart';
import 'package:connected_notebook/features/settings/presentation/settings_screen.dart';
import 'package:connected_notebook/features/export/presentation/batch_export_screen.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';
import 'package:connected_notebook/features/notes/presentation/template_selection_screen.dart';
import 'package:connected_notebook/features/notes/presentation/tag_management_screen.dart';
import 'package:connected_notebook/features/search/presentation/advanced_search_screen.dart';
import 'package:connected_notebook/features/export/presentation/import_export_screen.dart';
import 'package:connected_notebook/features/notes/widgets/note_template_manager.dart';
import 'package:connected_notebook/features/tools/widgets/dashboard_stats.dart';
import 'package:connected_notebook/features/tasks/presentation/task_hub_screen.dart';
import 'package:connected_notebook/features/export/services/pdf_export_service.dart';


import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:connected_notebook/features/notes/presentation/template_selection_screen.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({Key? key}) : super(key: key);

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '';
  String _selectedFolder = ''; // 'Genel' vs. Empty means Show All (or use 'Tümü')
  bool _showFavoritesOnly = false; // Filter pinned / favorite notes
  bool _isSidebarCollapsed = false; // Collapsible desktop sidebar state
  bool _isGridView = true; // Default to modern grid view
  bool _isTimelineView = false; // New Timeline View Mode

  // For split view
  Note? _selectedNote;
  bool _isCreatingNewNote = false;

  final List<String> _quotes = [
    "Düşünmek, ruhun kendi kendine konuşmasıdır. - Platon",
    "Yazmak, geleceği hatırlamaktır. - Carlos Fuentes",
    "En soluk mürekkep bile en güçlü hafızadan daha kalıcıdır.",
    "Büyük şeyler, bir araya getirilmiş küçük şeylerin toplamıdır. - Van Gogh",
    "Yaratıcılık, bağlamayan şeyleri bağlamaktır. - Steve Jobs",
    "Not almak, zihnin yükünü kağıda boşaltmaktır.",
    "Bir fikir, not alınmadığı sürece sadece bir hayaldir."
  ];

  String get _quoteOfTheDay {
    final dayOfYear = int.parse("${DateTime.now().month}${DateTime.now().day}");
    return _quotes[dayOfYear % _quotes.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NoteProvider>(context, listen: false).loadNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCommandPalette() {
    CommandPalette.show(context);
  }

  @override
  Widget build(BuildContext context) {
    // Add Keyboard Shortcut Support
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _showCommandPalette,
        // Also support Cmd+K for potential macOS users if needed, though 'control' maps to Cmd on web usually.
        // For strict desktop, might need meta.
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _showCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width < 800) {
              return _buildMobileLayout();
            } else {
              return _buildDesktopWorkbench();
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: _buildAppBar(isSplitView: false),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildNoteList()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          const SizedBox(height: 16),
          CustomFloatingActionButton(
            onPressed: () => _createNote(),
            onLongPress: () => _createNote(templateContent: ''),
            tooltip: 'Yeni Not (Uzun bas: Hızlı Boş Not)',
            label: const Text('Yeni Not'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkbench() {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Left Collapsible Sidebar (Slack/Obsidian/VS Code style)
          _buildDesktopSidebar(),

          // 2. Middle Panel: Note List (width ~360px)
          _buildDesktopNoteListPanel(),

          // 3. Right Panel: Wide Editor Workspace
          Expanded(
            child: _buildDesktopEditorPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final noteProvider = Provider.of<NoteProvider>(context);
    final allNotes = noteProvider.notes;
    final pinnedNotesCount = allNotes.where((n) => n.tags.contains('sabit')).length;
    final tagFreq = noteProvider.getTagFrequency();
    final folderList = noteProvider.folders;

    final sidebarWidth = _isSidebarCollapsed ? 64.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF7F8FA),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.12),
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: _isSidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSidebarCollapsed) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.sticky_note_2, color: theme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'GümüşNot',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _isSidebarCollapsed
                        ? Icons.view_sidebar_outlined
                        : Icons.menu_open_rounded,
                    size: 20,
                  ),
                  tooltip: _isSidebarCollapsed ? 'Kenar Çubuğunu Genişlet' : 'Kenar Çubuğunu Daralt',
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: _isSidebarCollapsed
                ? _buildCollapsedSidebarIcons(pinnedNotesCount)
                : _buildExpandedSidebarContent(
                    allNotes.length,
                    pinnedNotesCount,
                    folderList,
                    tagFreq,
                  ),
          ),

          // Sidebar Footer
          const Divider(height: 1),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildExpandedSidebarContent(
    int totalNotesCount,
    int pinnedNotesCount,
    List<String> folderList,
    Map<String, int> tagFreq,
  ) {
    final theme = Theme.of(context);
    final isAllSelected = !_showFavoritesOnly && _selectedFolder.isEmpty && _selectedTag.isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        // Main Navigation
        _buildSidebarItem(
          icon: Icons.article_outlined,
          selectedIcon: Icons.article,
          title: 'Tüm Notlar',
          count: totalNotesCount,
          isSelected: isAllSelected,
          onTap: () {
            setState(() {
              _showFavoritesOnly = false;
              _selectedFolder = '';
              _selectedTag = '';
            });
          },
        ),
        _buildSidebarItem(
          icon: Icons.push_pin_outlined,
          selectedIcon: Icons.push_pin,
          title: 'Favoriler & Sabitler',
          count: pinnedNotesCount,
          isSelected: _showFavoritesOnly,
          iconColor: Colors.amber,
          onTap: () {
            setState(() {
              _showFavoritesOnly = true;
              _selectedFolder = '';
              _selectedTag = '';
            });
          },
        ),

        const SizedBox(height: 16),
        // Modules Section
        _buildSectionHeader('MODÜLLER'),
        _buildSidebarItem(
          icon: Icons.insights_rounded,
          title: 'Aktivite & Analiz',
          iconColor: Colors.purpleAccent,
          onTap: () => Navigator.of(context).pushNamed('/dashboard'),
        ),
        _buildSidebarItem(
          icon: Icons.check_circle_outline_rounded,
          title: 'Görev Merkezi',
          iconColor: Colors.green,
          onTap: () => Navigator.of(context).pushNamed('/task-hub'),
        ),
        _buildSidebarItem(
          icon: Icons.hub_outlined,
          title: 'Zihin Haritası',
          iconColor: Colors.indigoAccent,
          onTap: () => Navigator.of(context).pushNamed('/graph'),
        ),

        const SizedBox(height: 16),
        // Folders Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('KLASÖRLER'),
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              tooltip: 'Yeni Klasör',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _showCreateFolderDialog,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (folderList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Henüz klasör yok',
              style: TextStyle(fontSize: 12, color: theme.disabledColor),
            ),
          )
        else
          ...folderList.map((folder) {
            final count = Provider.of<NoteProvider>(context, listen: false)
                .getNoteCountInFolder(folder);
            final isSelected = !_showFavoritesOnly && _selectedFolder == folder;
            return _buildSidebarItem(
              icon: isSelected ? Icons.folder_open : Icons.folder_outlined,
              title: folder,
              count: count,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedFolder = folder;
                  _showFavoritesOnly = false;
                  _selectedTag = '';
                });
              },
            );
          }),

        const SizedBox(height: 16),
        // Tags Section
        _buildSectionHeader('ETİKETLER'),
        const SizedBox(height: 4),
        if (tagFreq.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Henüz etiket yok',
              style: TextStyle(fontSize: 12, color: theme.disabledColor),
            ),
          )
        else
          ...tagFreq.entries.map((entry) {
            final isSelected = !_showFavoritesOnly && _selectedTag == entry.key;
            return _buildSidebarItem(
              icon: Icons.tag_rounded,
              title: '#${entry.key}',
              count: entry.value,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedTag = entry.key;
                  _showFavoritesOnly = false;
                  _selectedFolder = '';
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildCollapsedSidebarIcons(int pinnedCount) {
    final theme = Theme.of(context);
    final isAllSelected = !_showFavoritesOnly && _selectedFolder.isEmpty && _selectedTag.isEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: Icon(
              Icons.article_outlined,
              color: isAllSelected ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            tooltip: 'Tüm Notlar',
            onPressed: () {
              setState(() {
                _showFavoritesOnly = false;
                _selectedFolder = '';
                _selectedTag = '';
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.push_pin_outlined,
              color: _showFavoritesOnly ? Colors.amber : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            tooltip: 'Favoriler & Sabitler ($pinnedCount)',
            onPressed: () {
              setState(() {
                _showFavoritesOnly = true;
                _selectedFolder = '';
                _selectedTag = '';
              });
            },
          ),
          const Divider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: Colors.purpleAccent),
            tooltip: 'Aktivite & Analiz',
            onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
            tooltip: 'Görev Merkezi',
            onPressed: () => Navigator.of(context).pushNamed('/task-hub'),
          ),
          IconButton(
            icon: const Icon(Icons.hub_outlined, color: Colors.indigoAccent),
            tooltip: 'Zihin Haritası',
            onPressed: () => Navigator.of(context).pushNamed('/graph'),
          ),
          const Divider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Yeni Klasör',
            onPressed: _showCreateFolderDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final theme = Theme.of(context);
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Ayarlar',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: const Icon(Icons.settings_outlined, size: 20),
        title: const Text('Ayarlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.of(context).pushNamed('/settings'),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    IconData? selectedIcon,
    required String title,
    int? count,
    bool isSelected = false,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = isSelected
        ? theme.primaryColor
        : (iconColor ?? theme.colorScheme.onSurface.withOpacity(0.75));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(isDark ? 0.16 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: theme.primaryColor.withOpacity(isDark ? 0.3 : 0.2),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected && selectedIcon != null ? selectedIcon : icon,
              size: 18,
              color: effectiveColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withOpacity(0.18)
                      : theme.dividerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.primaryColor
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        ),
      ),
    );
  }

  Widget _buildDesktopNoteListPanel() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine current active filter label
    String filterLabel = 'Tüm Notlar';
    bool hasActiveFilter = false;
    if (_showFavoritesOnly) {
      filterLabel = 'Sabitlenen Notlar';
      hasActiveFilter = true;
    } else if (_selectedFolder.isNotEmpty) {
      filterLabel = '📁 $_selectedFolder';
      hasActiveFilter = true;
    } else if (_selectedTag.isNotEmpty) {
      filterLabel = '#$_selectedTag';
      hasActiveFilter = true;
    }

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.12),
          ),
        ),
      ),
      child: Column(
        children: [
          // Middle panel header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              filterLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (hasActiveFilter) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showFavoritesOnly = false;
                                  _selectedFolder = '';
                                  _selectedTag = '';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.dividerColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                      tooltip: _isGridView ? 'Liste Görünümü' : 'Izgara Görünümü',
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Komut Paleti (Ctrl+K)',
                      onPressed: _showCommandPalette,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CustomSearchBar(
                  hintText: 'Notlarda ara...',
                  controller: _searchController,
                  onChanged: (value) {
                    Provider.of<NoteProvider>(context, listen: false).searchNotes(value);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _createNote(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Yeni Not'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.today, size: 20),
                      tooltip: 'Bugünün Notu',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                        ),
                      ),
                      onPressed: _openDailyNote,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Note list content
          Expanded(
            child: _buildNoteList(isSidebar: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEditorPanel() {
    if (_selectedNote != null || _isCreatingNewNote) {
      return MarkdownEditor(
        key: ValueKey(_selectedNote?.id ?? 'new_note_${DateTime.now().millisecondsSinceEpoch}'),
        note: _selectedNote,
        onSave: (savedNote) async {
          await _handleSave(savedNote, null);
          if (mounted) {
            setState(() {
              _selectedNote = savedNote;
              _isCreatingNewNote = false;
            });
            Provider.of<NoteProvider>(context, listen: false).loadNotes();
          }
        },
        onCancel: () {
          setState(() {
            _selectedNote = null;
            _isCreatingNewNote = false;
          });
        },
      );
    }

    return _buildEmptyState();
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Klasör Oluştur'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Klasör Adı',
            hintText: 'Örn: Projeler, Kişisel...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              _createFolderAndNote(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final folderName = controller.text.trim();
                Navigator.pop(context);
                _createFolderAndNote(folderName);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _createFolderAndNote(String folderName) {
    setState(() {
      _selectedFolder = folderName;
      _selectedTag = '';
      _showFavoritesOnly = false;
    });
    _createNote(folderName: folderName);
  }

  PreferredSizeWidget _buildAppBar({bool isSplitView = false}) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text(
              'GümüşNot',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Command Palette Hint (Only show on wide screens, e.g. Desktop Split View)
          if (isSplitView && MediaQuery.of(context).size.width > 900) ...[
             const SizedBox(width: 12),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: Theme.of(context).dividerColor.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.keyboard_command_key, size: 12, color: Theme.of(context).disabledColor),
                   const SizedBox(width: 4),
                   Text(
                     'Ctrl+K',
                     style: TextStyle(fontSize: 10, color: Theme.of(context).disabledColor, fontWeight: FontWeight.bold),
                   ),
                 ],
               ),
             ),
          ]
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      automaticallyImplyLeading: !isSplitView,
      actions: [
        // Responsive Actions: Hide some on smaller screens or if crowded
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Komut Paleti / Arama',
          onPressed: _showCommandPalette,
        ),
        IconButton(
          icon: const Icon(Icons.insights_rounded),
          tooltip: 'Aktivite & Analiz',
          onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
        ),
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Görev Merkezi',
          onPressed: () => Navigator.of(context).pushNamed('/task-hub'),
        ),
        if (MediaQuery.of(context).size.width > 600)
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Rastgele Not',
            onPressed: _openRandomNote,
          ),
        IconButton(
          icon: Icon(_isTimelineView ? Icons.timeline : (_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded)),
          tooltip: _isTimelineView ? 'Zaman Çizelgesi' : (_isGridView ? 'Liste Görünümü' : 'Izgara Görünümü'),
          onPressed: () {
            setState(() {
              if (_isTimelineView) {
                 _isTimelineView = false;
                 _isGridView = true; // Timeline -> Grid
              } else if (_isGridView) {
                 _isGridView = false; // Grid -> List
              } else {
                 _isTimelineView = true; // List -> Timeline
              }
            });
          },
        ),
        if (!isSplitView) // Only mobile shows graph button in app bar
          IconButton(
            icon: const Icon(Icons.bubble_chart_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/graph'),
            tooltip: 'Graf Görünümü',
          ),
        if (!isSplitView)
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            tooltip: 'Ayarlar',
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'settings') Navigator.of(context).pushNamed('/settings');
              if (value == 'batch_export') _showBatchExport();
              if (value == 'tag_management') _showTagManagement();
              if (value == 'templates') _showTemplates();
              if (value == 'import_export') _showImportExport();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'templates', child: Text('Not Şablonları')),
              const PopupMenuItem(value: 'tag_management', child: Text('Etiket Yönetimi')),
              const PopupMenuItem(value: 'import_export', child: Text('İçe/Dışa Aktar')),
              const PopupMenuItem(value: 'batch_export', child: Text('Toplu Dışa Aktar')),
              const PopupMenuItem(value: 'settings', child: Text('Ayarlar')),
            ],
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_rounded, size: 72, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Text(
              'Bir not seçin veya yeni oluşturun',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _createNote(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Not'),
                ),
                OutlinedButton.icon(
                  onPressed: _openDailyNote,
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Bugünün Notu'),
                ),
                OutlinedButton.icon(
                  onPressed: _openRandomNote,
                  icon: const Icon(Icons.shuffle, size: 18),
                  label: const Text('Rastgele Not'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.format_quote, color: Theme.of(context).primaryColor, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    _quoteOfTheDay,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        CustomSearchBar(
          hintText: 'Notlarda ara...',
          onChanged: (value) {
            Provider.of<NoteProvider>(context, listen: false)
                .searchNotes(value);
          },
          controller: _searchController,
        ),
        _buildTagFilter(),
      ],
    );
  }

  Widget _buildNoteList({bool isSidebar = false}) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        if (noteProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var notes = _selectedTag.isEmpty
            ? noteProvider.searchResults
            : noteProvider.getNotesByTag(_selectedTag);

        if (_selectedFolder.isNotEmpty) {
           notes = notes.where((n) => n.folderName == _selectedFolder).toList();
        }

        if (_showFavoritesOnly) {
           notes = notes.where((n) => n.tags.contains('sabit')).toList();
        }

        // Sort: Pinned first, then UpdatedAt
        // We create a new list to avoid modifying the provider's list directly if it is used elsewhere
        final sortedNotes = List<Note>.from(notes);
        sortedNotes.sort((a, b) {
          final aPinned = a.tags.contains('sabit');
          final bPinned = b.tags.contains('sabit');
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        // Calculate Activity Data (heatmap)
        final activityData = <DateTime, int>{}; // Declare map here

        // Populate if map is empty (first load) or even if notes are empty but user has history?
        // Actually best is to iterate through ALL notes from provider, not just filtered ones, for the heatmap.
        // User wants global productivity view usually.
        for (var note in noteProvider.notes) {
           final date = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
           // Normalize date to YMD
           final normalized = DateTime(date.year, date.month, date.day);
           activityData[normalized] = (activityData[normalized] ?? 0) + 1;
        }

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isSidebar && activityData.isNotEmpty && _selectedTag.isEmpty && _searchController.text.isEmpty && !_showFavoritesOnly)
                   SizedBox(
                     height: 150,
                     child: ActivityHeatmap(datasets: activityData),
                   ),
                // Add Tag Cloud when no notes
                if (!isSidebar && _selectedTag.isEmpty && _searchController.text.isEmpty && !_showFavoritesOnly)
                   Container(
                     margin: const EdgeInsets.all(16),
                     child: TagCloudWidget(),
                   ),
                Icon(Icons.note_add_outlined, size: 48, color: Theme.of(context).dividerColor),
                const SizedBox(height: 16),
                Text(
                  'Not bulunamadı',
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              ],
            ),
          );
        }

        int crossAxisCount = 2;
        if (isSidebar) {
           crossAxisCount = 1;
        } else {
           crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;
        }

        // Show heatmap only on main view (no search/filter and not in desktop sidebar list)
        final showHeatmap = !isSidebar && _selectedTag.isEmpty && _searchController.text.isEmpty && _selectedFolder.isEmpty && !_showFavoritesOnly && activityData.isNotEmpty;

        return CustomScrollView(
          slivers: [
            if (showHeatmap)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    DashboardStats(notes: noteProvider.notes),
                    ActivityHeatmap(datasets: activityData),
                  ],
                ),
              ),

            // Add Tag Cloud when not searching or filtering
            if (!isSidebar && _selectedTag.isEmpty && _searchController.text.isEmpty && _selectedFolder.isEmpty && !_showFavoritesOnly)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: TagCloudWidget(),
                ),
              ),

            if (_isTimelineView)
              _buildTimelineSliver(sortedNotes)
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                sliver: _isGridView
                  ? SliverMasonryGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childCount: sortedNotes.length,
                      itemBuilder: (context, index) {
                           final note = sortedNotes[index];
                           final isSelected = _selectedNote?.id == note.id;
                           return Container(
                             decoration: isSelected && isSidebar ? BoxDecoration(
                               color: Theme.of(context).primaryColor.withOpacity(0.08),
                               borderRadius: BorderRadius.circular(14),
                               border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                             ) : null,
                             child: NoteCard(
                               note: note,
                               isPinned: note.tags.contains('sabit'),
                               onTap: () => _selectNote(note),
                               onEdit: () => _selectNote(note),
                               onDelete: () => _deleteNote(note),
                               onTogglePin: () => _togglePin(note),
                               onExport: () => _showExportOptions(note),
                             ),
                           );
                      },
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = sortedNotes[index];
                          final isSelected = _selectedNote?.id == note.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: isSelected && isSidebar ? BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                            ) : null,
                            child: NoteCard(
                              note: note,
                              isPinned: note.tags.contains('sabit'),
                              onTap: () => _selectNote(note),
                              onEdit: () => _selectNote(note),
                              onDelete: () => _deleteNote(note),
                              onTogglePin: () => _togglePin(note),
                              onExport: () => _showExportOptions(note),
                            ),
                          );
                        },
                        childCount: sortedNotes.length,
                      ),
                    ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTagFilter() {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final tagFrequency = noteProvider.getTagFrequency();

        if (tagFrequency.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: tagFrequency.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildTagChip('Tümü', '', _selectedTag.isEmpty);
              }

              final tag = tagFrequency.keys.elementAt(index - 1);
              final count = tagFrequency[tag]!;
              return _buildTagChip('#$tag ($count)', tag, _selectedTag == tag);
            },
          ),
        );
      },
    );
  }

  Widget _buildTagChip(String label, String tag, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
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
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(20),
           side: BorderSide(
             color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
           ),
        ),
      ),
    );
  }

  Future<void> _createNote({String? templateContent, String? folderName}) async {
    // Şablon seçimi yapılmadıysa (ve parametre boşsa) seçim ekranını aç
    if (templateContent == null) {
      final selectedContent = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const TemplateSelectionScreen()),
      );

      if (selectedContent == null) return; // Kullanıcı geri bastı
      templateContent = selectedContent;
    }

    final width = MediaQuery.of(context).size.width;

    // Geçici bir "Yeni Not" oluştur (İçeriği şablonlu veya boş)
    final newNote = Note(
      title: 'Başlıksız Not', // Editörde kullanıcı değiştirecek
      content: templateContent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      folderName: folderName ?? (_selectedFolder.isNotEmpty ? _selectedFolder : 'Genel'),
      tags: _selectedTag.isNotEmpty ? [_selectedTag] : [],
    );

    if (width >= 800) {
      setState(() {
        _selectedNote = newNote; // Split view için şablonlu notu set et
        _isCreatingNewNote = true;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: MarkdownEditor(
              note: newNote, // Şablonlu notu editöre ver
              onSave: (savedNote) async {
                await _handleSave(savedNote, null);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      );
    }
  }

  void _selectNote(Note note) async {
    if (note.isEncrypted && !context.read<VaultProvider>().isUnlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreli notu açmak için önce kasayı açın.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _openEditor(note, null);
  }

  void _openEditor(Note note, String? encryptionPassword) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 800) {
      setState(() {
        _selectedNote = note;
        _isCreatingNewNote = false;
        // Password handling logic inside Editor/onSave would be needed here
        // For standard impl, we handle it in onSave wrapper in build method
      });
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
            body: MarkdownEditor(
              note: note,
              onSave: (updatedNote) async {
                await _handleSave(updatedNote, encryptionPassword);
                if (mounted) {
                   Navigator.pop(context);
                   Provider.of<NoteProvider>(context, listen: false).loadNotes();
                }
              },
              onCancel: () => Navigator.pop(context),
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  // Handle saving logic centrally (yeni/not-olanı ayırt ederek)
  Future<void> _handleSave(Note savedNote, String? encryptionPassword) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    if (savedNote.isEncrypted) {
      final vaultProvider = context.read<VaultProvider>();
      if (!vaultProvider.isUnlocked) {
        throw Exception('Şifreli not kaydetmek için önce kasayı açın');
      }

      if (savedNote.id == null) {
        await vaultProvider.createPrivateNote(
          title: savedNote.title,
          content: savedNote.content,
          tags: savedNote.tags,
          folderName: savedNote.folderName,
          color: savedNote.color,
        );
      } else {
        await vaultProvider.updatePrivateNote(
          note: savedNote,
          plainTextContent: savedNote.content,
        );
      }
    } else {
      if (savedNote.id == null) {
        await noteProvider.addNote(savedNote);
      } else {
        await noteProvider.updateNote(savedNote);
      }
    }
  }

  // Password Input Dialog
  Future<String?> _showPasswordDialog({required bool isCreate}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCreate ? 'Şifre Belirle' : 'Şifreli Not'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Şifre',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(isCreate ? 'Kilitle' : 'Aç'),
          ),
        ],
      ),
    );
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu Sil'),
        content: Text('${note.title} adlı notu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(context, listen: false).deleteNote(note.id!);
              if (_selectedNote?.id == note.id) {
                setState(() {
                  _selectedNote = null;
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBatchExport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BatchExportScreen(),
      ),
    );
  }

  void _showImportExport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ImportExportScreen(),
      ),
    );
  }

  void _showTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NoteTemplateManager(),
      ),
    );
  }

  void _showAdvancedSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdvancedSearchScreen(),
      ),
    );
  }

  void _showTagManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TagManagementScreen(),
      ),
    );
  }



  void _showExportOptions(Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşlemler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(note.isEncrypted ? Icons.lock_open : Icons.lock_outline, color: Colors.orange),
              title: Text(note.isEncrypted ? 'Şifreyi Kaldır' : 'Notu Kilitle'),
              subtitle: Text(note.isEncrypted ? 'Notu deşifre et' : 'Parola ile koruma altına al'),
              onTap: () async {
                Navigator.pop(context);
                if (note.isEncrypted) {
                   // Unlock logic (similar to open)
                   final password = await _showPasswordDialog(isCreate: false);
                    if (password != null) {
                       try {
                          final decrypted = await context.read<LegacyEncryptionServiceAdapter>().decryptWithPassword(
                            encryptedPackage: note.content,
                            password: password,
                          );
                          final openNote = note.copyWith(content: decrypted, isEncrypted: false);
                          Provider.of<NoteProvider>(context, listen: false).updateNote(openNote);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notun kilidi açıldı.')));
                       } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre yanlış!'), backgroundColor: Colors.red));
                       }
                    }
                } else {
                   // Lock logic
                   final password = await _showPasswordDialog(isCreate: true);
                   if (password != null && password.isNotEmpty) {
                      final encrypted = await context.read<LegacyEncryptionServiceAdapter>().encryptWithPassword(
                        plainText: note.content,
                        password: password,
                      );
                      final lockedNote = note.copyWith(content: encrypted, isEncrypted: true);
                      Provider.of<NoteProvider>(context, listen: false).updateNote(lockedNote);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not kilitlendi.')));
                   }
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Olarak Kaydet'),
              subtitle: const Text('Okunabilir belge formatı'),
              onTap: () async {
                Navigator.pop(context);
                final file = await PdfExportService.exportNoteToPdf(note);
                if (file != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF kaydedildi: ${file.path.split('/').last}')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.functions, color: Colors.blue),
              title: const Text('LaTeX Kaynak Kodu'),
              subtitle: const Text('Akademik ve matematiksel formüller için'),
              onTap: () {
                Navigator.pop(context);
                _exportToLatex(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportToLatex(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LatexExportScreen(note: note),
      ),
    );
  }

  void _openRandomNote() {
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;
    if (notes.isNotEmpty) {
      final randomNote = (notes..shuffle()).first;
      _selectNote(randomNote);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiç not bulunamadı!')),
      );
    }
  }

  void _openDailyNote() {
    final now = DateTime.now();
    final title = 'Günlük Not: ${now.day}.${now.month}.${now.year}';
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;

    try {
      final existingNote = notes.firstWhere((n) => n.title == title);
      _selectNote(existingNote);
    } catch (_) {
      // Create new daily note
      final newNote = Note(
        title: title,
        content: '# $title\n\n## Hedefler\n- [ ] \n\n## Notlar\n',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      Provider.of<NoteProvider>(context, listen: false).addNote(newNote).then((_) {
         // After adding, we need to select it.
         // But the provider reload might be async.
         // Let's rely on finding it again or passing the ID if NoteProvider returns it.
         // Assuming basic add, let's find it by title again safely after a small delay or reload
         Provider.of<NoteProvider>(context, listen: false).loadNotes().then((_) {
             final created = Provider.of<NoteProvider>(context, listen: false).notes.firstWhere((n) => n.title == title);
             _selectNote(created);
         });
      });
    }

  }

  void _togglePin(Note note) {
    var tags = List<String>.from(note.tags);
    if (tags.contains('sabit')) {
      tags.remove('sabit');
    } else {
      tags.add('sabit');
    }

    final updatedNote = note.copyWith(tags: tags);
    Provider.of<NoteProvider>(context, listen: false).updateNote(updatedNote);

    // Feedback
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tags.contains('sabit') ? 'Not sabitlendi' : 'Sabitleme kaldırıldı'),
        duration: const Duration(seconds: 1),
      )
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              image: DecorationImage(
                image: const AssetImage('assets/header_bg.png'), // Varsa
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken
                ),
                onError: (_, __) {}, // Hata olursa sadece renk kalsın
              ),
            ),
            accountName: const Text(
              'GümüşNot',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            accountEmail: Text(
              '${Provider.of<NoteProvider>(context).notes.length} not • ${_countWords(Provider.of<NoteProvider>(context).notes)} kelime',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'GN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor
                )
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.insights_rounded, color: Colors.purpleAccent),
                  title: const Text('Aktivite & Analiz'),
                  subtitle: const Text('İstatistikler ve Verimlilik'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/dashboard');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: Colors.amber),
                  title: const Text('Sabitlenen Notlar'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _showFavoritesOnly = true;
                      _selectedFolder = '';
                      _selectedTag = '';
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Bugünün Notu'),
                  onTap: () {
                    Navigator.pop(context);
                    _openDailyNote();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shuffle),
                  title: const Text('Rastgele Not'),
                  onTap: () {
                    Navigator.pop(context);
                    _openRandomNote();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: const Text('Görev Merkezi'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/task-hub');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hub, color: Colors.indigoAccent),
                  title: const Text('Bağlantı Haritası'),
                  subtitle: const Text('İlişkisel Görünüm'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GraphViewScreen()));
                  },
                ),
                const Divider(),
                ExpansionTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Klasörler'),
                  children: _buildFolderListForDrawer(),
                ),
                ExpansionTile(
                  leading: const Icon(Icons.label_outline),
                  title: const Text('Etiketler'),
                  children: _buildTagListForDrawer(),
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

  List<Widget> _buildTagListForDrawer() {
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;
    final tags = <String>{};
    for (var note in notes) {
      tags.addAll(note.tags);
    }

    if (tags.isEmpty) {
      return [const ListTile(title: Text('Henüz etiket yok', style: TextStyle(color: Colors.grey)))];
    }

    return tags.map((tag) => ListTile(
      leading: const Icon(Icons.label, size: 18),
      title: Text(tag),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedTag = tag;
          _showFavoritesOnly = false;
        });
      },
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      dense: true,
    )).toList();
  }

  int _countWords(List<Note> notes) {
    int count = 0;
    for (var note in notes) {
      count += RegExp(r'\w+').allMatches(note.content).length;
    }
    return count;
  }

  List<Widget> _buildFolderListForDrawer() {
     final folderList = Provider.of<NoteProvider>(context).folders;

     if (folderList.isEmpty) {
        return [const ListTile(title: Text('Klasör bulunamadı', style: TextStyle(color: Colors.grey)), contentPadding: EdgeInsets.only(left: 32))];
     }

     return folderList.map((folder) {
        final count = Provider.of<NoteProvider>(context).getNoteCountInFolder(folder);
        return ListTile(
           leading: const Icon(Icons.folder_outlined, size: 18),
           title: Text(folder),
           trailing: Text(count.toString(), style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12)),
           onTap: () {
              Navigator.pop(context);
              setState(() {
                 _selectedFolder = folder;
                 _selectedTag = '';
                 _showFavoritesOnly = false;
                 _searchController.clear();
              });
           },
           contentPadding: const EdgeInsets.only(left: 32, right: 32),
           dense: true,
        );
     }).toList();
  }

  Widget _buildTimelineSliver(List<Note> notes) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final note = notes[index];
          final date = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
          final prevDate = index > 0 ? DateTime.fromMillisecondsSinceEpoch(notes[index - 1].updatedAt) : null;

          bool isNewDay = prevDate == null ||
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
                            fontSize: 18
                         )
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
                                     "${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                     style: TextStyle(
                                        color: Theme.of(context).disabledColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12
                                     )
                                  ),
                               ]
                            ),
                         ),
                         Column(
                            children: [
                               const SizedBox(height: 16),
                               Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                     color: Theme.of(context).primaryColor,
                                     shape: BoxShape.circle,
                                     border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                                  ),
                               ),
                               Expanded(
                                  child: Container(
                                     width: 2,
                                     color: Theme.of(context).dividerColor.withOpacity(0.5),
                                  )
                               )
                            ],
                         ),
                         Expanded(
                            child: Padding(
                               padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                               child: NoteCard(
                                  note: note,
                                  isPinned: note.tags.contains('sabit'),
                                  onTap: () => _selectNote(note),
                                  onEdit: () => _selectNote(note),
                                  onDelete: () => _deleteNote(note),
                                  onTogglePin: () => _togglePin(note),
                                  onExport: () => _showExportOptions(note),
                               ),
                            ),
                         )
                      ],
                   ),
                )
             ],
          );
        },
        childCount: notes.length,
      ),
    );
  }

  String _formatTimelineHeader(DateTime date) {
     final now = DateTime.now();
     if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Bugün';
     }
     if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        return 'Dün';
     }
     final months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
     return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

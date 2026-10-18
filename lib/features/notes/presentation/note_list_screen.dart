import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/widgets/note_card.dart';
import 'package:connected_notebook/features/notes/widgets/swipeable_note_card.dart';
import 'package:connected_notebook/features/notes/widgets/custom_widgets.dart';
import 'package:connected_notebook/features/tools/widgets/activity_heatmap.dart';
import 'package:connected_notebook/features/tools/widgets/command_palette.dart';
import 'package:connected_notebook/features/notes/widgets/tag_cloud_widget.dart';
import 'package:connected_notebook/features/notes/widgets/note_desktop_sidebar.dart';
import 'package:connected_notebook/features/notes/widgets/note_navigation_drawer.dart';
import 'package:connected_notebook/features/notes/widgets/note_timeline_sliver.dart';

import 'package:connected_notebook/features/export/presentation/batch_export_screen.dart';
import 'package:connected_notebook/features/notes/presentation/template_selection_screen.dart';
import 'package:connected_notebook/features/notes/presentation/tag_management_screen.dart';
import 'package:connected_notebook/features/search/presentation/advanced_search_screen.dart';
import 'package:connected_notebook/features/export/presentation/import_export_screen.dart';
import 'package:connected_notebook/features/notes/widgets/note_template_manager.dart';
import 'package:connected_notebook/features/tools/widgets/dashboard_stats.dart';
import 'package:connected_notebook/shared/widgets/empty_state_widget.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Provider.of<NoteProvider>(context, listen: false).searchNotes(value);
    });
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: theme.colorScheme.surface,
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
    return NoteDesktopSidebar(
      isCollapsed: _isSidebarCollapsed,
      showFavoritesOnly: _showFavoritesOnly,
      selectedFolder: _selectedFolder,
      selectedTag: _selectedTag,
      onToggleCollapse: () {
        setState(() {
          _isSidebarCollapsed = !_isSidebarCollapsed;
        });
      },
      onSelectAllNotes: () {
        setState(() {
          _showFavoritesOnly = false;
          _selectedFolder = '';
          _selectedTag = '';
        });
      },
      onSelectFavorites: () {
        setState(() {
          _showFavoritesOnly = true;
          _selectedFolder = '';
          _selectedTag = '';
        });
      },
      onSelectFolder: (folder) {
        setState(() {
          _selectedFolder = folder;
          _showFavoritesOnly = false;
          _selectedTag = '';
        });
      },
      onSelectTag: (tag) {
        setState(() {
          _selectedTag = tag;
          _showFavoritesOnly = false;
          _selectedFolder = '';
        });
      },
      onCreateFolder: _showCreateFolderDialog,
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
            color: theme.dividerColor.withValues(alpha: isDark ? 0.08 : 0.12),
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
                                  color: theme.dividerColor.withValues(alpha: 0.15),
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
                  onChanged: _onSearchChanged,
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
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
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
        key: ValueKey(_selectedNote?.id ?? 'new_note'),
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
                 color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
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
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: 'Takvim & Günlük',
          onPressed: () => Navigator.of(context).pushNamed('/calendar'),
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
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'templates', child: Text('Not Şablonları')),
              const PopupMenuItem(value: 'tag_management', child: Text('Etiket Yönetimi')),
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
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
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
          onChanged: _onSearchChanged,
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

        var notes = noteProvider.searchResults;

        if (_selectedTag.isNotEmpty) {
          notes = notes.where((n) => n.tags.contains(_selectedTag)).toList();
        }

        if (_selectedFolder.isNotEmpty) {
          notes = notes.where((n) => n.folderName == _selectedFolder).toList();
        }

        if (_showFavoritesOnly) {
          notes = notes.where((n) => n.tags.contains('sabit')).toList();
        }

        // Sort: Pinned first, then UpdatedAt (preserve relevance order when searching)
        final sortedNotes = List<Note>.from(notes);
        if (noteProvider.searchQuery.trim().isEmpty) {
          sortedNotes.sort((a, b) {
            final aPinned = a.tags.contains('sabit');
            final bPinned = b.tags.contains('sabit');
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
        }

        final activityData = noteProvider.activityData;

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
                                  EmptyStateWidget(
                    icon: _searchController.text.isNotEmpty ? Icons.search_off_rounded : Icons.edit_document,
                    title: _searchController.text.isNotEmpty ? 'Sonuç Bulunamadı' : 'Buralar Çok Issız',
                    message: _searchController.text.isNotEmpty 
                        ? 'Aramanızla eşleşen hiçbir not bulamadık.'
                        : 'İkinci beyninizi inşa etmeye başlamak için ilk notunuzu oluşturun.',
                    buttonText: _searchController.text.isEmpty ? 'Yeni Not Oluştur' : null,
                    onButtonPressed: _searchController.text.isEmpty ? () => _createNote() : null,
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
                               color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                               borderRadius: BorderRadius.circular(14),
                               border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                             ) : null,
                             child: SwipeableNoteCard(
                               note: note,
                               isPinned: note.tags.contains('sabit'),
                               onTogglePin: () => _togglePin(note),
                               onDelete: () => _deleteNoteWithUndo(note),
                               onArchive: () => _archiveNote(note),
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
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                            ) : null,
                            child: SwipeableNoteCard(
                              note: note,
                              isPinned: note.tags.contains('sabit'),
                              onTogglePin: () => _togglePin(note),
                              onDelete: () => _deleteNoteWithUndo(note),
                              onArchive: () => _archiveNote(note),
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
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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

    if (!mounted) return;
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
          builder: (routeContext) => Scaffold(
            body: MarkdownEditor(
              note: newNote, // Şablonlu notu editöre ver
              onSave: (savedNote) async {
                await _handleSave(savedNote, null);
                if (routeContext.mounted) {
                  Navigator.of(routeContext).pop();
                }
              },
              onCancel: () {
                Navigator.of(routeContext).pop();
              },
            ),
          ),
        ),
      );
    }
  }

  void _selectNote(Note note) async {

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
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
            body: MarkdownEditor(
              note: note,
              onSave: (updatedNote) async {
                await _handleSave(updatedNote, encryptionPassword);
                if (routeContext.mounted) {
                  Navigator.pop(routeContext);
                }
                await noteProvider.loadNotes();
              },
              onCancel: () => Navigator.pop(routeContext),
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

    if (savedNote.id == null) {
      await noteProvider.addNote(savedNote);
    } else {
      await noteProvider.updateNote(savedNote);
    }
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

  void _archiveNote(Note note) {
    final tags = List<String>.from(note.tags);
    final wasArchived = tags.contains('arsiv');
    if (!wasArchived) {
      tags.add('arsiv');
    } else {
      tags.remove('arsiv');
    }
    final updated = note.copyWith(tags: tags);
    Provider.of<NoteProvider>(context, listen: false).updateNote(updated);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasArchived
              ? '"${note.title.isEmpty ? 'Başlıksız Not' : note.title}" arşivden çıkarıldı.'
              : '"${note.title.isEmpty ? 'Başlıksız Not' : note.title}" arşivlendi.',
        ),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () {
            final revertedTags = List<String>.from(note.tags);
            final reverted = note.copyWith(tags: revertedTags);
            Provider.of<NoteProvider>(context, listen: false).updateNote(reverted);
          },
        ),
      ),
    );
  }

  void _deleteNoteWithUndo(Note note) {
    if (note.id == null) return;
    final noteToDelete = note;
    Provider.of<NoteProvider>(context, listen: false).deleteNote(note.id!);
    if (_selectedNote?.id == note.id) {
      setState(() {
        _selectedNote = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${note.title.isEmpty ? 'Başlıksız Not' : note.title}" silindi.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () {
            Provider.of<NoteProvider>(context, listen: false).addNote(noteToDelete);
          },
        ),
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

  void showImportExport() {
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

  void showAdvancedSearch() {
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
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşlemler',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.teal),
              title: const Text('Notu Paylaş'),
              subtitle: const Text('Metin olarak paylaş veya panoya kopyala'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final paylasilacakMetin = '${note.title}\n\n${note.content}';
                if (kIsWeb) {
                  // Webdeysek paylaşım menüsü açılmaz, metni panoya kopyalayalım
                  await Clipboard.setData(ClipboardData(text: paylasilacakMetin));
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Bağlantı/Metin panoya kopyalandı!')),
                    );
                  }
                } else {
                  // Mobildeysek normal paylaşım penceresi açılsın
                  Share.share(paylasilacakMetin);
                }
              },
            ),
          ],
        ),
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

  Future<void> _openDailyNote() async {
    final now = DateTime.now();
    final title = 'Günlük Not: ${now.day}.${now.month}.${now.year}';
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final notes = noteProvider.notes;

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

      await noteProvider.addNote(newNote);
      await noteProvider.loadNotes();
      if (!mounted) return;
      final created = noteProvider.notes.firstWhere((n) => n.title == title);
      _selectNote(created);
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
    return NoteNavigationDrawer(
      onSelectFavorites: () {
        setState(() {
          _showFavoritesOnly = true;
          _selectedFolder = '';
          _selectedTag = '';
        });
      },
      onOpenDailyNote: _openDailyNote,
      onOpenRandomNote: _openRandomNote,
      onSelectFolder: (folder) {
        setState(() {
          _selectedFolder = folder;
          _selectedTag = '';
          _showFavoritesOnly = false;
          _searchController.clear();
        });
      },
      onSelectTag: (tag) {
        setState(() {
          _selectedTag = tag;
          _showFavoritesOnly = false;
        });
      },
    );
  }

  Widget _buildTimelineSliver(List<Note> notes) {
    return NoteTimelineSliver(
      notes: notes,
      onSelectNote: _selectNote,
      onDeleteNote: _deleteNote,
      onDeleteNoteWithUndo: _deleteNoteWithUndo,
      onArchiveNote: _archiveNote,
      onTogglePin: _togglePin,
      onExportNote: _showExportOptions,
    );
  }
}



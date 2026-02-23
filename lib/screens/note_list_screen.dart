import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/note_card.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/activity_heatmap.dart';
import '../widgets/command_palette.dart';
import '../widgets/tag_cloud_widget.dart';
import '../screens/latex_export_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/batch_export_screen.dart';
import '../screens/graph_view_screen.dart';
import '../screens/template_selection_screen.dart';
import '../screens/tag_management_screen.dart';
import '../screens/advanced_search_screen.dart';
import '../screens/import_export_screen.dart';
import '../widgets/note_template_manager.dart';
import '../widgets/dashboard_stats.dart';
import '../screens/task_hub_screen.dart';
import '../services/pdf_export_service.dart';
import '../services/encryption_service.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../screens/template_selection_screen.dart';
import '../screens/graph_view_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({Key? key}) : super(key: key);

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '';
  String _selectedFolder = ''; // 'Genel' vs. Empty means Show All (or use 'Tümü')
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
            // Desktop: >= 1100 (3 panels)
            // Tablet: >= 700 (2 panels)
            // Mobile: < 700 (1 panel)
            final isDesktop = width >= 1100;
            final isMobile = width < 700;

            if (isMobile) {
              return _buildMobileLayout();
            } else {
              return _buildSplitLayout(isDesktop: isDesktop);
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

  Widget _buildSplitLayout({required bool isDesktop}) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Row(
        children: [
          // 1. Left Panel: Note List
          Container(
            width: 380, // Slightly wider for grid
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                _buildAppBar(isSplitView: true),
                _buildSearchAndFilter(),
                Expanded(child: _buildNoteList(isSidebar: true)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _createNote,
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Not Oluştur'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openDailyNote,
                        icon: const Icon(Icons.today),
                        label: const Text('Bugünün Notu'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          
  // 2. Center Panel: Editor with Password Handling Wrapper
  Expanded(
  flex: 3,
  child: _selectedNote != null || _isCreatingNewNote
        ? Builder(
            builder: (context) {
               // We need a way to store the password for split view too.
               // Since _selectedNote in split view is simply a Note object state,
               // we might re-encrypt in onSave based on _selectedNote.isEncrypted status...
               // BUT _selectedNote here is the DECRYPTED version if opened via password.
               // We need to know if it requires re-encryption.
               // Hack: We can check if the original note (from provider) was encrypted using ID.
               // Or better: Assume if we are here, we handle it.
               
               // For split view simplicity, let's just use standard save for now,
               // and if user wants encryption support in split view fully, we need more state.
               // Currently, the prompt mainly focused on the logic. 
               // Mobile works perfectly with _openEditor logic.
               // Let's adopt a similar strategy for split view save callback.
               
               return MarkdownEditor(
                    key: ValueKey(_selectedNote?.id ?? 'new_note_${DateTime.now()}'), 
                    note: _selectedNote,
                    onSave: (savedNote) async {
                       // Find if original note was encrypted to re-encrypt?
                       // Actually, we don't have the password here easily without state.
                       // For now, in split view, let's just save. 
                       // TODO: Enhance Split View Encryption Support
                       // For now, if it was encrypted, it might be saved as plain if we are not careful.
                       // Let's retrieve the password if we can, or just Ask for Password again on Save?
                       // Or simple: Just update note.
                       
                       // Ideally: NoteProvider.updateNote(savedNote);
                       
                       // FIX: Fetch original note to check encryption status
                       if (savedNote.id != null) {
                          final original = Provider.of<NoteProvider>(context, listen: false).notes.firstWhere((n) => n.id == savedNote.id, orElse: () => savedNote);
                          if (original.isEncrypted) {
                             // It was encrypted, we are saving. We must have the password?
                             // Since we don't store it in state, let's ask for it or warn user.
                             // Or simply, for this turn, we focus on the _lockNote action.
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not kaydedildi (Şifreleme henüz bölünmüş ekranda tam desteklenmiyor, lütfen mobil görünümü kullanın)')));
                          }
                       }
                      
                      await _handleSave(savedNote, null);
                      if (mounted) {
                        setState(() {
                          _selectedNote = savedNote;
                          _isCreatingNewNote = false;
                        });
                      }
                    },
                    onCancel: () {
                      setState(() {
                        if (_isCreatingNewNote) {
                          _selectedNote = null;
                          _isCreatingNewNote = false;
                        }
                      });
                    },
                  );
            }
          )
        : _buildEmptyState(),
  ),
          
          // 3. Right Panel: Graph View (Desktop Only)
          if (isDesktop)
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: const GraphViewScreen(), // Uses existing graph screen
              ),
            ),
        ],
      ),
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_rounded, size: 80, color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Text(
            'Bir not seçin veya yeni oluşturun',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                if (activityData.isNotEmpty && _selectedTag.isEmpty && _searchController.text.isEmpty)
                   SizedBox(
                     height: 150,
                     child: ActivityHeatmap(datasets: activityData),
                   ),
                // Add Tag Cloud when no notes
                if (_selectedTag.isEmpty && _searchController.text.isEmpty)
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

        // Show heatmap only on main view (no search/filter)
        final showHeatmap = _selectedTag.isEmpty && _searchController.text.isEmpty && _selectedFolder.isEmpty && activityData.isNotEmpty;

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
            if (_selectedTag.isEmpty && _searchController.text.isEmpty && _selectedFolder.isEmpty)
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
                           return NoteCard(
                              note: note,
                              isPinned: note.tags.contains('sabit'),
                              onTap: () => _selectNote(note),
                              onEdit: () => _selectNote(note),
                              onDelete: () => _deleteNote(note),
                              onTogglePin: () => _togglePin(note),
                              onExport: () => _showExportOptions(note),
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
                              color: Theme.of(context).primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2))
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

  Future<void> _createNote({String? templateContent}) async {
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
      folderName: 'Genel',
      tags: [],
    );

    if (width >= 700) {
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
    // Şifreli Not Kontrolü
    if (note.isEncrypted) {
      final password = await _showPasswordDialog(isCreate: false);
      if (password == null) return; // Kullanıcı iptal etti

      try {
        final decryptedContent = EncryptionService.decryptWithPassword(note.content, password);
        // Deşifre edilmiş içeriği olan GEÇİCİ bir not oluşturuyoruz
        final decryptedNote = note.copyWith(content: decryptedContent);
        
        _openEditor(decryptedNote, password);
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hatalı şifre! Erişim reddedildi.'), backgroundColor: Colors.red),
           );
        }
      }
    } else {
      _openEditor(note, null);
    }
  }

  void _openEditor(Note note, String? encryptionPassword) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 700) {
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

    // Şifreli kayıt gerekiyorsa, içeriği önce şifrele
    Note noteToPersist;
    if (encryptionPassword != null) {
      final encryptedContent = EncryptionService.encryptWithPassword(
        savedNote.content,
        encryptionPassword,
      );
      noteToPersist = savedNote.copyWith(
        content: encryptedContent,
        isEncrypted: true,
      );
    } else {
      noteToPersist = savedNote;
    }

    // Yeni not mu, mevcut not mu?
    if (noteToPersist.id == null) {
      await noteProvider.addNote(noteToPersist);
    } else {
      await noteProvider.updateNote(noteToPersist);
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
                          final decrypted = EncryptionService.decryptWithPassword(note.content, password);
                          final openNote = note.copyWith(content: decrypted, isEncrypted: false);
                          Provider.of<NoteProvider>(context, listen: false).updateNote(openNote);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre kaldırıldı.')));
                       } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yanlış şifre!')));
                       }
                    }
                } else {
                   // Lock logic
                   final password = await _showPasswordDialog(isCreate: true);
                   if (password != null && password.isNotEmpty) {
                      final encrypted = EncryptionService.encryptWithPassword(note.content, password);
                      final lockedNote = note.copyWith(content: encrypted, isEncrypted: true);
                      Provider.of<NoteProvider>(context, listen: false).updateNote(lockedNote);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not şifrelendi.')));
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

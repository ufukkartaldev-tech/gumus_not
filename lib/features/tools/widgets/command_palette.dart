import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/features/export/presentation/batch_export_screen.dart';
import 'package:connected_notebook/features/notes/presentation/tag_management_screen.dart';
import 'package:connected_notebook/features/search/presentation/advanced_search_screen.dart';
import 'package:connected_notebook/features/notes/widgets/note_template_manager.dart';
import 'package:connected_notebook/features/notes/presentation/private_vault_screen.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';

/// Item representation in the Raycast/Linear command palette.
class PaletteItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final String category; // 'KOMUTLAR', 'NOTLAR', 'GEZİNME', 'SİSTEM'
  final VoidCallback action;
  final String? shortcut;

  PaletteItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.category,
    required this.action,
    this.shortcut,
  });
}

/// Command Palette (Ctrl+K / Cmd+K) transformed into a Raycast / Linear style
/// command center for GümüşNot.
class CommandPalette extends StatefulWidget {
  final Function(Note?)? onNoteSelected;

  const CommandPalette({Key? key, this.onNoteSelected}) : super(key: key);

  static void show(BuildContext context, {Function(Note?)? onNoteSelected}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CommandPalette',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CommandPalette(onNoteSelected: onNoteSelected);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * curvedAnimation.value,
            sigmaY: 10 * curvedAnimation.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  String _selectedCategoryFilter = 'Tümü'; // 'Tümü', 'Komutlar', 'Notlar'
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final total = _getCurrentItems().length;
      if (total > 0) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % total;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final total = _getCurrentItems().length;
      if (total > 0) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + total) % total;
        });
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      final items = _getCurrentItems();
      if (items.isNotEmpty && _selectedIndex < items.length) {
        final selected = items[_selectedIndex];
        Navigator.pop(context);
        selected.action();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final targetOffset = _selectedIndex * itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  List<PaletteItem> _getCurrentItems() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final vaultProvider = Provider.of<VaultProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final allItems = <PaletteItem>[];

    // 1. Actions / Commands
    allItems.addAll(_getActions(context, vaultProvider, themeProvider));

    // 2. Note items
    for (final note in noteProvider.notes) {
      final title = note.title.isEmpty ? 'Başlıksız Not' : MarkdownCleaner.clean(note.title);
      final preview = note.excerpt;
      allItems.add(
        PaletteItem(
          id: 'note_${note.id ?? note.createdAt}',
          title: title,
          subtitle: preview.isNotEmpty ? preview : _formatDate(note.updatedAt),
          icon: note.isEncrypted ? Icons.lock_rounded : Icons.description_outlined,
          iconColor: note.color != null ? Color(note.color!) : null,
          category: 'NOTLAR',
          action: () {
            if (widget.onNoteSelected != null) {
              widget.onNoteSelected!(note);
            } else {
              Navigator.of(context).pushNamed('/note-editor', arguments: note).then((_) {
                Provider.of<NoteProvider>(context, listen: false).loadNotes();
              });
            }
          },
          shortcut: '↵ Aç',
        ),
      );
    }

    // Filter by category filter pills
    var filtered = allItems;
    if (_selectedCategoryFilter == 'Komutlar') {
      filtered = filtered.where((i) => i.category != 'NOTLAR').toList();
    } else if (_selectedCategoryFilter == 'Notlar') {
      filtered = filtered.where((i) => i.category == 'NOTLAR').toList();
    }

    // Filter by query string
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where((i) {
        final inTitle = i.title.toLowerCase().contains(q);
        final inSub = i.subtitle?.toLowerCase().contains(q) ?? false;
        final inCategory = i.category.toLowerCase().contains(q);
        return inTitle || inSub || inCategory;
      }).toList();
    }

    return filtered;
  }

  List<PaletteItem> _getActions(
    BuildContext context,
    VaultProvider vaultProvider,
    ThemeProvider themeProvider,
  ) {
    final isVaultUnlocked = vaultProvider.isUnlocked;
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return [
      // Quick Note
      PaletteItem(
        id: 'new_note',
        title: 'Yeni Not Oluştur',
        subtitle: 'Temiz bir sayfada yeni not yaz',
        icon: Icons.add_circle_outline_rounded,
        iconColor: Colors.blue,
        category: 'HIZLI EYLEMLER',
        shortcut: 'Ctrl+N',
        action: () {
          Navigator.of(context).pushNamed('/note-editor').then((_) {
            Provider.of<NoteProvider>(context, listen: false).loadNotes();
          });
        },
      ),



      // Vault Lock / Unlock (Kasayı Kilitle / Kilidi Aç)
      PaletteItem(
        id: 'toggle_vault',
        title: isVaultUnlocked ? 'Kasayı Kilitle' : 'Kasa Kilidini Aç',
        subtitle: isVaultUnlocked
            ? 'Şifreli notları anında koruma altına al'
            : 'Gizli kasadaki şifreli notlara eriş',
        icon: isVaultUnlocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
        iconColor: Colors.orange,
        category: 'GÜVENLİK',
        action: () async {
          if (isVaultUnlocked) {
            await vaultProvider.lockVault();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gizli kasa kilitlendi.')),
              );
            }
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const PrivateVaultScreen()),
            );
          }
        },
      ),



      // Daily Journal Note (Günün Notu)
      PaletteItem(
        id: 'daily_note',
        title: 'Günün Notu (Günlük)',
        subtitle: 'Bugünün tarihli günlüğünü aç veya oluştur',
        icon: Icons.today_rounded,
        iconColor: Colors.teal,
        category: 'HIZLI EYLEMLER',
        action: () => _openOrCreateDailyNote(context),
      ),

      // Random Note
      PaletteItem(
        id: 'random_note',
        title: 'Rastgele Not Aç',
        subtitle: 'Kütüphanenden tesadüfi bir not keşfet',
        icon: Icons.shuffle_rounded,
        iconColor: Colors.purpleAccent,
        category: 'KEŞİF',
        action: () => _openRandomNote(context),
      ),

      // Graph View
      PaletteItem(
        id: 'graph_view',
        title: 'Bağlantı Grafiğini Aç',
        subtitle: 'Notlar arasındaki ilişkileri ve zihin haritasını incele',
        icon: Icons.hub_outlined,
        iconColor: Colors.cyan,
        category: 'GEZİNME',
        action: () => Navigator.of(context).pushNamed('/graph'),
      ),



      // Note Template Manager
      PaletteItem(
        id: 'templates',
        title: 'Şablon Yöneticisi',
        subtitle: 'Hazır not şablonlarını yönet ve seç',
        icon: Icons.dashboard_customize_outlined,
        iconColor: Colors.amber,
        category: 'ARAÇLAR',
        action: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const NoteTemplateManager()),
          );
        },
      ),

      // Tag Management
      PaletteItem(
        id: 'tags_management',
        title: 'Etiket Yönetimi',
        subtitle: 'Etiketleri birleştir, düzenle ve organize et',
        icon: Icons.label_outline_rounded,
        iconColor: Colors.blueAccent,
        category: 'ARAÇLAR',
        action: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const TagManagementScreen()),
          );
        },
      ),

      // Advanced Search
      PaletteItem(
        id: 'advanced_search',
        title: 'Gelişmiş Arama',
        subtitle: 'Filtreler, tarihler ve etiketlerle derinlemesine ara',
        icon: Icons.saved_search_rounded,
        iconColor: Colors.indigoAccent,
        category: 'ARAÇLAR',
        action: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AdvancedSearchScreen()),
          );
        },
      ),

      // Toggle Theme
      PaletteItem(
        id: 'toggle_theme',
        title: isDark ? 'Aydınlık Temaya Geç' : 'Karanlık Temaya Geç',
        subtitle: isDark ? 'Gündüz moduna geçiş yap' : 'Gece moduna geçiş yap',
        icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        iconColor: Colors.amber,
        category: 'SİSTEM',
        action: () {
          themeProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
      ),

      // Database Optimize
      PaletteItem(
        id: 'optimize_db',
        title: 'Veritabanını Optimize Et',
        subtitle: 'İndeksleri temizle ve depolama performansını artır',
        icon: Icons.speed_rounded,
        iconColor: Colors.tealAccent,
        category: 'SİSTEM',
        action: () async {
          await context.optimizeNoteDatabase();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veritabanı başarıyla optimize edildi.')),
            );
          }
        },
      ),

      // Settings
      PaletteItem(
        id: 'settings',
        title: 'Ayarlar',
        subtitle: 'Uygulama tercihleri, yedekleme ve sistem yapılandırması',
        icon: Icons.settings_outlined,
        iconColor: Colors.grey,
        category: 'SİSTEM',
        action: () => Navigator.of(context).pushNamed('/settings'),
      ),
    ];
  }

  void _showQuickTaskDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Hızlı Görev Ekle'),
          ],
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Yapılacak görevi yazın...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.pop(ctx);
              _addTaskToNotes(context, val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _addTaskToNotes(context, textController.text.trim());
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _addTaskToNotes(BuildContext context, String taskText) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final notes = noteProvider.notes;

    // Look for a note titled 'Hızlı Görevler' or create one
    Note? targetNote = notes.cast<Note?>().firstWhere(
      (n) => n?.title.trim().toLowerCase() == 'hızlı görevler',
      orElse: () => null,
    );

    final taskLine = '- [ ] $taskText';

    if (targetNote != null) {
      final updatedContent = targetNote.content.isEmpty
          ? taskLine
          : '${targetNote.content}\n$taskLine';
      await noteProvider.updateNote(
        targetNote.copyWith(
          content: updatedContent,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newNote = Note(
        title: 'Hızlı Görevler',
        content: '# Hızlı Görevler\n\n$taskLine',
        createdAt: now,
        updatedAt: now,
        tags: ['gorevler', 'hizli'],
      );
      await noteProvider.addNote(newNote);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görev eklendi: "$taskText"'),
          action: SnackBarAction(
            label: 'Görevler',
            onPressed: () => Navigator.of(context).pushNamed('/task-hub'),
          ),
        ),
      );
    }
  }

  void _openOrCreateDailyNote(BuildContext context) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final dailyTitle = 'Günlük - $dateStr';

    final existing = noteProvider.notes.cast<Note?>().firstWhere(
      (n) => n?.title.trim() == dailyTitle,
      orElse: () => null,
    );

    if (existing != null) {
      Navigator.of(context).pushNamed('/note-editor', arguments: existing);
    } else {
      final timestamp = now.millisecondsSinceEpoch;
      final dailyNote = Note(
        title: dailyTitle,
        content: '## $dailyTitle\n\n### Günün Odak Noktaları\n- [ ] \n\n### Notlar & Düşünceler\n',
        createdAt: timestamp,
        updatedAt: timestamp,
        tags: ['gunluk'],
      );
      await noteProvider.addNote(dailyNote);
      if (context.mounted) {
        final created = noteProvider.notes.firstWhere(
          (n) => n.title == dailyTitle,
          orElse: () => dailyNote,
        );
        Navigator.of(context).pushNamed('/note-editor', arguments: created);
      }
    }
  }

  void _openRandomNote(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final notes = noteProvider.notes;
    if (notes.isNotEmpty) {
      final random = (List<Note>.from(notes)..shuffle()).first;
      Navigator.of(context).pushNamed('/note-editor', arguments: random);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kütüphanede hiç not bulunamadı.')),
      );
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _getCurrentItems();

    // Reset selected index if bounds exceeded
    if (_selectedIndex >= items.length && items.isNotEmpty) {
      _selectedIndex = items.length - 1;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 70, left: 16, right: 16),
          width: 640,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.primary.withOpacity(0.25)
                  : theme.dividerColor.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
                blurRadius: 36,
                offset: const Offset(0, 16),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Raycast Search Input Header
                _buildSearchHeader(theme, isDark),

                // 2. Category Filter Pills
                _buildCategoryPills(theme, isDark),

                const Divider(height: 1, thickness: 1),

                // 3. Results List
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildResultsList(items, theme, isDark),
                ),

                const Divider(height: 1, thickness: 1),

                // 4. Linear Style Shortcut Footer
                _buildFooterBar(items.length, theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _inputFocusNode,
              decoration: InputDecoration(
                hintText: 'Bir komut yazın veya not arayın...',
                hintStyle: TextStyle(
                  color: theme.disabledColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              onChanged: (value) {
                setState(() {
                  _query = value;
                  _selectedIndex = 0;
                });
              },
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _selectedIndex = 0;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 16,
              color: theme.disabledColor,
            ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              'ESC',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: theme.disabledColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills(ThemeData theme, bool isDark) {
    final categories = ['Tümü', 'Komutlar', 'Notlar'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategoryFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategoryFilter = cat;
                  _selectedIndex = 0;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.4)
                        : theme.dividerColor.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsList(List<PaletteItem> items, ThemeData theme, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == _selectedIndex;

        // Display category header if category changed
        final showHeader = index == 0 || items[index - 1].category != item.category;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: theme.disabledColor,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            _buildItemTile(item, isSelected, index, theme, isDark),
          ],
        );
      },
    );
  }

  Widget _buildItemTile(
    PaletteItem item,
    bool isSelected,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    final accent = item.iconColor ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(isDark ? 0.16 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.35 : 0.25),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          Navigator.pop(context);
          item.action();
        },
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withOpacity(isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 18, color: accent),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: item.subtitle != null
            ? Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.disabledColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: isSelected
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.shortcut ?? '↵ Seç',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            : (item.shortcut != null
                ? Text(
                    item.shortcut!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.disabledColor,
                    ),
                  )
                : null),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: theme.disabledColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"$_query" için eşleşen bir komut veya not yok',
              style: TextStyle(
                fontSize: 12,
                color: theme.disabledColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterBar(int count, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildKeyBadge('↑↓', 'Gezin', theme, isDark),
              const SizedBox(width: 12),
              _buildKeyBadge('↵', 'Seç', theme, isDark),
              const SizedBox(width: 12),
              _buildKeyBadge('ESC', 'Kapat', theme, isDark),
            ],
          ),
          Text(
            '$count sonuç',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBadge(String key, String label, ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: theme.disabledColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.disabledColor,
          ),
        ),
      ],
    );
  }
}

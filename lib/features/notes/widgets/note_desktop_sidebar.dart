import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class NoteDesktopSidebar extends StatelessWidget {
  final bool isCollapsed;
  final bool showFavoritesOnly;
  final String selectedFolder;
  final String selectedTag;
  final VoidCallback onToggleCollapse;
  final VoidCallback onSelectAllNotes;
  final VoidCallback onSelectFavorites;
  final ValueChanged<String> onSelectFolder;
  final ValueChanged<String> onSelectTag;
  final VoidCallback onCreateFolder;

  const NoteDesktopSidebar({
    super.key,
    required this.isCollapsed,
    required this.showFavoritesOnly,
    required this.selectedFolder,
    required this.selectedTag,
    required this.onToggleCollapse,
    required this.onSelectAllNotes,
    required this.onSelectFavorites,
    required this.onSelectFolder,
    required this.onSelectTag,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final noteProvider = Provider.of<NoteProvider>(context);
    final allNotes = noteProvider.notes;
    final pinnedNotesCount =
        allNotes.where((n) => n.tags.contains('sabit')).length;
    final tagFreq = noteProvider.getTagFrequency();
    final folderList = noteProvider.folders;

    final sidebarWidth = isCollapsed ? 64.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF7F8FA),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.08 : 0.12),
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
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sticky_note_2,
                          color: theme.primaryColor,
                          size: 20,
                        ),
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
                    isCollapsed
                        ? Icons.view_sidebar_outlined
                        : Icons.menu_open_rounded,
                    size: 20,
                  ),
                  tooltip: isCollapsed
                      ? 'Kenar Çubuğunu Genişlet'
                      : 'Kenar Çubuğunu Daralt',
                  onPressed: onToggleCollapse,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: isCollapsed
                ? _buildCollapsedSidebarIcons(context, pinnedNotesCount)
                : _buildExpandedSidebarContent(
                    context,
                    noteProvider,
                    allNotes.length,
                    pinnedNotesCount,
                    folderList,
                    tagFreq,
                  ),
          ),

          // Sidebar Footer
          const Divider(height: 1),
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  Widget _buildExpandedSidebarContent(
    BuildContext context,
    NoteProvider noteProvider,
    int totalNotesCount,
    int pinnedNotesCount,
    List<String> folderList,
    Map<String, int> tagFreq,
  ) {
    final theme = Theme.of(context);
    final isAllSelected =
        !showFavoritesOnly && selectedFolder.isEmpty && selectedTag.isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        // Main Navigation
        _buildSidebarItem(
          context,
          icon: Icons.article_outlined,
          selectedIcon: Icons.article,
          title: 'Tüm Notlar',
          count: totalNotesCount,
          isSelected: isAllSelected,
          onTap: onSelectAllNotes,
        ),
        _buildSidebarItem(
          context,
          icon: Icons.push_pin_outlined,
          selectedIcon: Icons.push_pin,
          title: 'Favoriler & Sabitler',
          count: pinnedNotesCount,
          isSelected: showFavoritesOnly,
          iconColor: Colors.amber,
          onTap: onSelectFavorites,
        ),

        const SizedBox(height: 16),
        // Modules Section
        _buildSectionHeader(context, 'MODÜLLER'),
        _buildSidebarItem(
          context,
          icon: Icons.hub_outlined,
          title: 'Zihin Haritası',
          iconColor: Colors.indigoAccent,
          onTap: () => Navigator.of(context).pushNamed('/graph'),
        ),
        _buildSidebarItem(
          context,
          icon: Icons.calendar_month_outlined,
          title: 'Takvim & Günlük',
          iconColor: Colors.orangeAccent,
          onTap: () => Navigator.of(context).pushNamed('/calendar'),
        ),

        const SizedBox(height: 16),
        // Folders Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'KLASÖRLER'),
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              tooltip: 'Yeni Klasör',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onCreateFolder,
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
            final count = noteProvider.getNoteCountInFolder(folder);
            final isSelected = !showFavoritesOnly && selectedFolder == folder;
            return _buildSidebarItem(
              context,
              icon: isSelected ? Icons.folder_open : Icons.folder_outlined,
              title: folder,
              count: count,
              isSelected: isSelected,
              onTap: () => onSelectFolder(folder),
            );
          }),

        const SizedBox(height: 16),
        // Tags Section
        _buildSectionHeader(context, 'ETİKETLER'),
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
            final isSelected = !showFavoritesOnly && selectedTag == entry.key;
            return _buildSidebarItem(
              context,
              icon: Icons.tag_rounded,
              title: '#${entry.key}',
              count: entry.value,
              isSelected: isSelected,
              onTap: () => onSelectTag(entry.key),
            );
          }),
      ],
    );
  }

  Widget _buildCollapsedSidebarIcons(BuildContext context, int pinnedCount) {
    final theme = Theme.of(context);
    final isAllSelected =
        !showFavoritesOnly && selectedFolder.isEmpty && selectedTag.isEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: Icon(
              Icons.article_outlined,
              color: isAllSelected
                  ? theme.primaryColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            tooltip: 'Tüm Notlar',
            onPressed: onSelectAllNotes,
          ),
          IconButton(
            icon: Icon(
              Icons.push_pin_outlined,
              color: showFavoritesOnly
                  ? Colors.amber
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            tooltip: 'Favoriler & Sabitler ($pinnedCount)',
            onPressed: onSelectFavorites,
          ),
          const Divider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.hub_outlined, color: Colors.indigoAccent),
            tooltip: 'Zihin Haritası',
            onPressed: () => Navigator.of(context).pushNamed('/graph'),
          ),
          const Divider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Yeni Klasör',
            onPressed: onCreateFolder,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    if (isCollapsed) {
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
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onTap: () => Navigator.of(context).pushNamed('/settings'),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
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
        : (iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.75));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: isDark ? 0.16 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: theme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
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
                      : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withValues(alpha: 0.18)
                      : theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.primaryColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

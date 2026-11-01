import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';

/// Minimalist, sleek desktop note list item designed for high-density,
/// Obsidian / Apple Notes-like desktop productivity.
class DesktopNoteTile extends StatefulWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback? onExport;

  const DesktopNoteTile({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDuplicate,
    this.onExport,
  });

  @override
  State<DesktopNoteTile> createState() => _DesktopNoteTileState();
}

class _DesktopNoteTileState extends State<DesktopNoteTile> {
  bool _isHovered = false;

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[dateTime.weekday - 1];
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return '$day.$month';
    }
  }

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final theme = Theme.of(context);
    final isPinned = widget.note.tags.contains('sabit');

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 36,
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 16,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Text(
                isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              const Text(
                'Çoğalt',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        if (widget.onExport != null)
          PopupMenuItem<String>(
            value: 'export',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.file_upload_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Dışa Aktar',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(height: 6),
        PopupMenuItem<String>(
          value: 'delete',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                'Sil',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case 'pin':
          widget.onTogglePin();
          break;
        case 'duplicate':
          widget.onDuplicate();
          break;
        case 'export':
          widget.onExport?.call();
          break;
        case 'delete':
          widget.onDelete();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPinned = widget.note.tags.contains('sabit');
    final isEncrypted = widget.note.isEncrypted;

    // Filter out internal tags
    final displayTags = widget.note.tags
        .where((t) => t != 'sabit' && !t.startsWith('mood:'))
        .take(2)
        .toList();

    // Cleaned preview snippet
    final previewText = isEncrypted
        ? 'Şifrelenmiş not içeriği'
        : (widget.note.content.trim().isEmpty
            ? 'Ek metin yok'
            : MarkdownCleaner.clean(widget.note.content).trim());

    final noteTitle = widget.note.title.trim().isEmpty
        ? 'Başlıksız Not'
        : MarkdownCleaner.clean(widget.note.title).trim();

    // Accent indicator & background colors
    final primaryColor = theme.colorScheme.primary;
    final Color itemBackground;
    if (widget.isSelected) {
      itemBackground = primaryColor.withValues(alpha: isDark ? 0.16 : 0.08);
    } else if (_isHovered) {
      itemBackground = theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: isDark ? 0.4 : 0.5);
    } else {
      itemBackground = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(context, details),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: itemBackground,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: widget.isSelected
                  ? primaryColor.withValues(alpha: isDark ? 0.4 : 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: widget.onTap,
              splashColor: primaryColor.withValues(alpha: 0.1),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active selection indicator bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: widget.isSelected ? 3.5 : 0,
                      height: 48,
                      margin: EdgeInsets.only(right: widget.isSelected ? 8 : 0),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Title + Timestamp
                          Row(
                            children: [
                              if (widget.note.emojiIcon != null &&
                                  widget.note.emojiIcon!.isNotEmpty) ...[
                                Text(
                                  widget.note.emojiIcon!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  noteTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: widget.isSelected
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.92),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimestamp(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    widget.note.updatedAt,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Row 2: Preview snippet
                          Text(
                            previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: isEncrypted
                                  ? Colors.orange.withValues(alpha: 0.85)
                                  : theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.65),
                              fontStyle: isEncrypted ? FontStyle.italic : null,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Row 3: Meta pills & icons (Pin, Encrypted, Tags)
                          Row(
                            children: [
                              if (isPinned) ...[
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 5),
                              ],
                              if (isEncrypted) ...[
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 11,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 5),
                              ],
                              ...displayTags.map(
                                (tag) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

/// A wrapper widget that equips any note card with mobile swipe micro-interactions:
/// - Swipe Right (startToEnd): Toggle Pin (Sabitle / Sabitlemeyi Kaldır)
/// - Swipe Left (endToStart): Delete / Archive modal (Sil / Arşivle)
class SwipeableNoteCard extends StatelessWidget {
  final Note note;
  final Widget child;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final bool isPinned;

  const SwipeableNoteCard({
    super.key,
    required this.note,
    required this.child,
    required this.onTogglePin,
    required this.onDelete,
    required this.onArchive,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('swipe_note_${note.id ?? note.createdAt}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Sabitle / Sabitlemeyi Kaldır
          HapticFeedback.mediumImpact();
          onTogglePin();
          return false; // Bounce back smoothly
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Sil / Arşivle
          HapticFeedback.mediumImpact();
          final action = await _showSwipeActionSheet(context);
          if (action == 'archive') {
            onArchive();
          } else if (action == 'delete') {
            onDelete();
          }
          return false; // Bounce back or let provider reload list
        }
        return false;
      },
      background: _buildRightSwipeBackground(theme),
      secondaryBackground: _buildLeftSwipeBackground(theme),
      child: child,
    );
  }

  Widget _buildRightSwipeBackground(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isPinned
            ? const Color(0xFF64748B) // Slate grey for unpin
            : const Color(0xFFD97706), // Warm amber for pin
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSwipeBackground(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48), // Rose red for delete / archive
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sil / Arşivle',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 10),
          Icon(
            Icons.delete_sweep_rounded,
            color: Colors.white,
            size: 22,
          ),
        ],
      ),
    );
  }

  Future<String?> _showSwipeActionSheet(BuildContext context) {
    final noteTitle = note.title.isEmpty ? 'Başlıksız Not' : note.title;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  noteTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.archive_outlined, color: Colors.indigo, size: 22),
                ),
                title: const Text('Notu Arşivle', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Listeden gizler, arşive taşır (#arsiv)'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(ctx, 'archive'),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                ),
                title: const Text('Notu Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                subtitle: const Text('Notu siler (Geri alabilirsiniz)'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

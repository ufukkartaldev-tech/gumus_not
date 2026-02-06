import 'package:flutter/material.dart';
import '../models/note_model.dart';
// import 'package:intl/intl.dart'; // Removed to avoid dependency error

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onExport;
  final bool isPinned;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onExport,
    this.onTogglePin,
    this.isPinned = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.01).animate( // Subtle scale up
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkCount = widget.note.extractLinks().length;
    final isEncrypted = widget.note.isEncrypted;
    // If note has a custom color, use it. Otherwise use primary color.
    final noteColor = widget.note.color != null ? Color(widget.note.color!) : null;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine the accent color for this card
    final accentColor = noteColor ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: const BorderRadius.all(Radius.circular(20)), // Smoother corners
            boxShadow: [
              // Dynamic shadow based on hover state
              BoxShadow(
                color: accentColor.withValues(alpha: _isHovered ? 0.2 : 0.05),
                blurRadius: _isHovered ? 16 : 6,
                offset: Offset(0, _isHovered ? 8 : 4),
                spreadRadius: _isHovered ? 1 : 0,
              ),
              // Subtle ambient shadow
              if (!_isHovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
            ],
            border: Border.all(
              color: _isHovered ? accentColor.withValues(alpha: 0.5) : theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.6),
              width: _isHovered ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: accentColor.withValues(alpha: 0.1),
              hoverColor: Colors.transparent, 
              child: Stack(
                children: [
                  // Decorative background gradient blend (Rich Glass Effect)
                  if (noteColor != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            noteColor.withValues(alpha: isDark ? 0.15 : 0.1),
                            noteColor.withValues(alpha: isDark ? 0.05 : 0.02),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  
                  // Encrypted Pattern Overlay
                  if (isEncrypted)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.03,
                        child: CustomPaint(
                          painter: GridPainter(color: accentColor),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Title and Date/Actions
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Decorative marker or Lock Icon
                                      if (isEncrypted) ...[
                                         Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                               color: Colors.orange.withValues(alpha: 0.2),
                                               shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.lock_rounded, size: 14, color: Colors.orange),
                                         ),
                                         const SizedBox(width: 8),
                                      ] else if (noteColor != null) ...[
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: noteColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: noteColor.withValues(alpha: 0.4),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      
                                      Expanded(
                                        child: Text(
                                          widget.note.title.isEmpty ? 'Başlıksız Not' : widget.note.title,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800, // Bolder
                                            fontSize: 18,
                                            height: 1.2,
                                            color: theme.textTheme.titleMedium?.color,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                    // Meta Info
                                    Row(
                                      children: [
                                         Icon(Icons.access_time_rounded, size: 12, color: theme.disabledColor),
                                         const SizedBox(width: 4),
                                         Text(
                                          _formatDate(widget.note.updatedAt),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                            color: theme.disabledColor,
                                          ),
                                        ),
                                        if (!isEncrypted) ...[
                                          const SizedBox(width: 8),
                                          const Text('•', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_calculateReadingTime(widget.note.content)} dk',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 11,
                                              color: theme.disabledColor,
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Excerpt (Blurred if encrypted)
                        const SizedBox(height: 12),
                        if (isEncrypted)
                           Container(
                              width: double.infinity,
                              height: 40,
                              decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(4),
                                 gradient: LinearGradient(
                                    colors: [
                                       theme.disabledColor.withValues(alpha: 0.1),
                                       theme.disabledColor.withValues(alpha: 0.05),
                                    ],
                                 ),
                              ),
                              child: Center(
                                 child: Text(
                                    '•••••••••••••••••',
                                    style: TextStyle(letterSpacing: 4, color: theme.disabledColor.withValues(alpha: 0.5)),
                                 ),
                              ),
                           )
                        else if (widget.note.excerpt.isNotEmpty)
                          Text(
                            widget.note.excerpt,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),

                        // Footer: Tags, Links and Actions
                        const SizedBox(height: 16),
                        Row(
                          children: [
                             // Pinned Indicator
                             if (widget.isPinned)
                               Padding(
                                 padding: const EdgeInsets.only(right: 8.0),
                                 child: Tooltip(
                                   message: 'Sabitlenmiş',
                                   child: Icon(Icons.push_pin_rounded, size: 16, color: accentColor),
                                 ),
                               ),

                             // Link Count Badge
                             if (linkCount > 0) 
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(8),
                                   border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                                 ),
                                 child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Icon(Icons.link_rounded, size: 12, color: theme.colorScheme.primary),
                                     const SizedBox(width: 4),
                                     Text(
                                       '$linkCount',
                                       style: TextStyle(
                                         color: theme.colorScheme.primary,
                                         fontWeight: FontWeight.w700,
                                         fontSize: 11
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                            
                            const Spacer(),
                            
                            // Actions always visible on mobile, hover on desktop
                            if (_isHovered || MediaQuery.of(context).size.width < 700) 
                              _buildActionButtons(theme, context, isEncrypted),
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
    );
  }

  Widget _buildActionButtons(ThemeData theme, BuildContext context, bool isEncrypted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isEncrypted)
        _ActionButton(
          icon: Icons.edit_rounded,
          onTap: widget.onEdit,
          color: theme.colorScheme.primary,
          tooltip: 'Düzenle',
        ),
        if (!isEncrypted) const SizedBox(width: 4),
        if (widget.onTogglePin != null) ...[
          _ActionButton(
            icon: widget.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            onTap: widget.onTogglePin!,
            color: widget.isPinned ? theme.colorScheme.primary : theme.disabledColor,
            tooltip: widget.isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle',
          ),
          const SizedBox(width: 4),
        ],
        _ActionButton(
          icon: Icons.more_horiz_rounded, // More actions instead of crowded row
          onTap: () {
             // Show bottom sheet or menu
             widget.onExport?.call();
          },
          color: theme.disabledColor,
          tooltip: 'Diğer İşlemler',
        ),
      ],
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}dk';
      }
      return '${difference.inHours}sa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g';
    } else {
      return '${date.day}/${date.month}';
    }
  }
  String _calculateReadingTime(String content) {
    if (content.isEmpty) return '1';
    final wordCount = content.split(RegExp(r'\s+')).length;
    final readingTime = (wordCount / 200).ceil();
    return readingTime.toString();
  }
}

// Custom Painter for subtle grid background pattern
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      for (double j = 0; j < size.height; j += step) {
        if ((i + j) % (step * 2) == 0) {
           canvas.drawCircle(Offset(i, j), 1, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

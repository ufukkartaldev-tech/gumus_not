import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/widgets/editor_backlink_section.dart';
import 'package:connected_notebook/features/notes/widgets/editor_bottom_sheets.dart';

/// The Content-First Zen Mode Canvas: Notion-style large header, metadata strip, and seamless text editor.
class EditorZenCanvas extends StatelessWidget {
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final String? emojiIcon;
  final List<String> tags;
  final Note currentNote;
  final ValueChanged<Note> onSelectBacklinkNote;
  final VoidCallback onShowEmojiPicker;
  final VoidCallback onShowColorPicker;
  final VoidCallback onShowTagSheet;

  const EditorZenCanvas({
    super.key,
    required this.titleController,
    required this.titleFocusNode,
    required this.contentController,
    required this.contentFocusNode,
    required this.emojiIcon,
    required this.tags,
    required this.currentNote,
    required this.onSelectBacklinkNote,
    required this.onShowEmojiPicker,
    required this.onShowColorPicker,
    required this.onShowTagSheet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = EditorTagAndMoodSheet.findCurrentMood(tags);
    final nonMoodTags = tags.where((t) => !t.startsWith('mood:')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Notion-like header: emoji icon + color picker
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Row(
            children: [
              if (emojiIcon != null)
                GestureDetector(
                  onTap: onShowEmojiPicker,
                  child: Text(emojiIcon!, style: const TextStyle(fontSize: 56)),
                ),
              if (emojiIcon == null)
                TextButton.icon(
                  onPressed: onShowEmojiPicker,
                  icon: const Icon(Icons.add_reaction_outlined, size: 18),
                  label: const Text('İkon Ekle'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.disabledColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onShowColorPicker,
                icon: const Icon(Icons.color_lens_outlined, size: 18),
                label: const Text('Renk'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.disabledColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Title Field - Large H1 Notion-like header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
          child: TextField(
            controller: titleController,
            focusNode: titleFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => contentFocusNode.requestFocus(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -0.6,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Başlıksız Not',
              hintStyle: TextStyle(
                color: theme.disabledColor.withValues(alpha: 0.28),
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),

        // Subtle, integrated Metadata Strip (Mood & Tag chips)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Mood Chip
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onShowTagSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood ?? '😊', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          mood == null ? 'Mod ekle' : 'Mod',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.disabledColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Tags chips
                ...nonMoodTags.map(
                  (tag) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                // Add Tag Chip
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onShowTagSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: theme.disabledColor),
                        const SizedBox(width: 2),
                        Text(
                          'Etiket',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.disabledColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // The Smooth Continuous Canvas Body (No dividers, no boxes)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: TextField(
              controller: contentController,
              focusNode: contentFocusNode,
              maxLines: null,
              expands: true,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.7,
                fontSize: 16.5,
                letterSpacing: 0.1,
              ),
              cursorColor: theme.colorScheme.primary,
              cursorWidth: 2.2,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                hintText: 'Düşüncelerinizi buraya dökün...',
                hintStyle: TextStyle(
                  color: theme.disabledColor.withValues(alpha: 0.3),
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Backlinks Section
        EditorBacklinkSection(
          currentNoteId: currentNote.id,
          currentTitle: currentNote.title,
        ),
      ],
    );
  }
}

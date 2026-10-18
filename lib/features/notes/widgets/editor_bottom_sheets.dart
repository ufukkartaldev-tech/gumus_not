import 'package:flutter/material.dart';
import 'package:connected_notebook/features/tools/widgets/tag_manager_widget.dart';

class EditorMathSymbolSheet extends StatelessWidget {
  final ValueChanged<String> onSelectSyntax;

  const EditorMathSymbolSheet({
    super.key,
    required this.onSelectSyntax,
  });

  static const List<Map<String, String>> _mathItems = [
    {'label': 'x²', 'syntax': r'x^2'},
    {'label': 'a/b', 'syntax': r'\frac{a}{b}'},
    {'label': '√x', 'syntax': r'\sqrt{x}'},
    {'label': '∑', 'syntax': r'\sum_{i=1}^{n}'},
    {'label': '∫', 'syntax': r'\int_{a}^{b} f(x) dx'},
    {'label': 'π', 'syntax': r'\pi'},
    {'label': 'θ', 'syntax': r'\theta'},
    {'label': 'lim', 'syntax': r'\lim_{x \to \infty}'},
    {
      'label': 'Mermaid',
      'syntax': '```mermaid\ngraph TD\n  A[Başla] --> B[Devam]\n```\n',
    },
    {'label': r'Blok $$', 'syntax': '\$\$\nE = mc^2\n\$\$\n'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        color: isDark ? const Color(0xFF1E1F24) : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.functions_rounded,
                  color: Colors.purple,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Matematik & Diyagram Ekle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mathItems.map((item) {
                return ActionChip(
                  label: Text(
                    item['label']!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onSelectSyntax(item['syntax']!);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorTagAndMoodSheet extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const EditorTagAndMoodSheet({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
  });

  static String? findCurrentMood(List<String> tags) {
    for (final tag in tags) {
      if (tag.startsWith('mood:')) {
        return tag.substring(5);
      }
    }
    return null;
  }

  @override
  State<EditorTagAndMoodSheet> createState() => _EditorTagAndMoodSheetState();
}

class _EditorTagAndMoodSheetState extends State<EditorTagAndMoodSheet> {
  static const List<String> _moods = ['😊', '😐', '😢', '😡', '🚀', '💡', '🔥'];
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initialTags);
  }

  String? _findCurrentMood() => EditorTagAndMoodSheet.findCurrentMood(_tags);

  void _updateMood(String mood) {
    setState(() {
      _tags.removeWhere((tag) => tag.startsWith('mood:'));
      _tags.add('mood:$mood');
    });
    widget.onTagsChanged(List<String>.from(_tags));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedMood = _findCurrentMood();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        color: isDark ? const Color(0xFF1E1F24) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Not Bilgileri & Etiketler',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Mod:',
                    style: TextStyle(
                      color: theme.disabledColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ..._moods.map((mood) {
                    final isSelected = selectedMood == mood;
                    return GestureDetector(
                      onTap: () => _updateMood(mood),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.primaryColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: theme.primaryColor,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Text(
                          mood,
                          style: TextStyle(fontSize: isSelected ? 22 : 18),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TagManagerWidget(
                initialTags: _tags,
                onTagsChanged: (newTags) {
                  setState(() => _tags = List<String>.from(newTags));
                  widget.onTagsChanged(newTags);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

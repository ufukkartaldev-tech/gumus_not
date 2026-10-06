import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating accessory bar designed to sit above the keyboard on mobile
/// and floating formatting bubble on desktop.
class FloatingAccessoryBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPickImage;
  final VoidCallback? onToggleMathSheet;

  const FloatingAccessoryBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onPickImage,
    this.onToggleMathSheet,
  });

  static void wrapOrInsert({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String prefix,
    required String suffix,
  }) {
    HapticFeedback.selectionClick();
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) {
      controller.text = '$text$prefix$suffix';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length - suffix.length,
      );
      focusNode.requestFocus();
      return;
    }

    if (selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$suffix');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    }
    focusNode.requestFocus();
  }

  static void insertAtLineStart({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String linePrefix,
  }) {
    HapticFeedback.selectionClick();
    final text = controller.text;
    final selection = controller.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    int lineStart = text.lastIndexOf('\n', cursorPos - 1);
    if (lineStart == -1) {
      lineStart = 0;
    } else {
      lineStart += 1;
    }

    final newText = text.replaceRange(lineStart, lineStart, linePrefix);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos + linePrefix.length),
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1F24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          children: [
              // [ B ] Bold
              _AccessoryButton(
                label: 'B',
                tooltip: 'Kalın (**bold**)',
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                onPressed: () => wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '**',
                  suffix: '**',
                ),
              ),
              // [ I ] Italic
              _AccessoryButton(
                label: 'I',
                tooltip: 'İtalik (*italic*)',
                textStyle: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                onPressed: () => wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '*',
                  suffix: '*',
                ),
              ),
              const _AccessoryDivider(),
              // [ H1 ] Heading 1
              _AccessoryButton(
                label: 'H1',
                tooltip: 'Başlık 1 (# )',
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                onPressed: () => insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '# ',
                ),
              ),
              // [ H2 ] Heading 2
              _AccessoryButton(
                label: 'H2',
                tooltip: 'Başlık 2 (## )',
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                onPressed: () => insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '## ',
                ),
              ),
              const _AccessoryDivider(),
              // [ [[ ]] ] WikiLink
              _AccessoryButton(
                label: '[[ ]]',
                tooltip: 'Bağlantı ([[Not]])',
                textStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '[[',
                  suffix: ']]',
                ),
              ),
              // [ - [ ] ] Checklist
              _AccessoryButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Görev Kutusu (- [ ] )',
                onPressed: () => insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '- [ ] ',
                ),
              ),
              // [ Liste ] Bullet List
              _AccessoryButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Madde İşareti (- )',
                onPressed: () => insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '- ',
                ),
              ),
              const _AccessoryDivider(),
              // [ Görsel ] Image
              _AccessoryButton(
                icon: Icons.image_rounded,
                tooltip: 'Görsel Ekle',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onPickImage();
                },
              ),
              // [ $fx ] Math Formula
              _AccessoryButton(
                label: r'$fx',
                tooltip: r'Matematik Denklemi ($fx$)',
                textStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.purpleAccent.shade100 : Colors.deepPurple,
                ),
                onPressed: () {
                  if (onToggleMathSheet != null) {
                    onToggleMathSheet!();
                  } else {
                    wrapOrInsert(
                      controller: controller,
                      focusNode: focusNode,
                      prefix: r'$',
                      suffix: r'$',
                    );
                  }
                },
              ),
              const _AccessoryDivider(),
              // Extra: Quote
              _AccessoryButton(
                icon: Icons.format_quote_rounded,
                tooltip: 'Alıntı (> )',
                onPressed: () => insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '> ',
                ),
              ),
              // Extra: Code
              _AccessoryButton(
                icon: Icons.code_rounded,
                tooltip: 'Kod (`kod`)',
                onPressed: () => wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '`',
                  suffix: '`',
                ),
              ),
              // Extra: Hide keyboard
              _AccessoryButton(
                icon: Icons.keyboard_hide_rounded,
                tooltip: 'Klavyeyi Gizle',
                onPressed: () => focusNode.unfocus(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating contextual format bubble on Desktop/Web when text is selected.
class DesktopSelectionBubbleMenu extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const DesktopSelectionBubbleMenu({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2E33) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccessoryButton(
                label: 'B',
                tooltip: 'Kalın',
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '**',
                  suffix: '**',
                ),
              ),
              _AccessoryButton(
                label: 'I',
                tooltip: 'İtalik',
                textStyle: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 14),
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '*',
                  suffix: '*',
                ),
              ),
              _AccessoryButton(
                label: 'S',
                tooltip: 'Üstü Çizili',
                textStyle: const TextStyle(decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold, fontSize: 14),
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '~~',
                  suffix: '~~',
                ),
              ),
              const _AccessoryDivider(),
              _AccessoryButton(
                label: 'H1',
                tooltip: 'H1',
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                onPressed: () => FloatingAccessoryBar.insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '# ',
                ),
              ),
              _AccessoryButton(
                label: 'H2',
                tooltip: 'H2',
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                onPressed: () => FloatingAccessoryBar.insertAtLineStart(
                  controller: controller,
                  focusNode: focusNode,
                  linePrefix: '## ',
                ),
              ),
              const _AccessoryDivider(),
              _AccessoryButton(
                icon: Icons.code_rounded,
                tooltip: 'Kod',
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '`',
                  suffix: '`',
                ),
              ),
              _AccessoryButton(
                label: '[[ ]]',
                tooltip: 'WikiLink',
                textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: theme.colorScheme.primary),
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: '[[',
                  suffix: ']]',
                ),
              ),
              _AccessoryButton(
                label: r'$fx',
                tooltip: 'Matematik Formülü',
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                onPressed: () => FloatingAccessoryBar.wrapOrInsert(
                  controller: controller,
                  focusNode: focusNode,
                  prefix: r'$',
                  suffix: r'$',
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _AccessoryButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;
  final TextStyle? textStyle;

  const _AccessoryButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: textStyle ??
                          TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                    )
                  : Icon(
                      icon,
                      size: 19,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessoryDivider extends StatelessWidget {
  const _AccessoryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
    );
  }
}

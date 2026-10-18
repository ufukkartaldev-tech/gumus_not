import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';

/// Handles Vim normal/insert mode key navigation and commands for the markdown editor.
class EditorVimHandler {
  final BuildContext context;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onModeChanged;

  bool isInsertMode = false;

  EditorVimHandler({
    required this.context,
    required this.controller,
    required this.focusNode,
    required this.onModeChanged,
  });

  void attach() {
    focusNode.onKeyEvent = handleKeyEvent;
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    final shortcutManager = Provider.of<AppShortcutManager>(context, listen: false);
    if (!shortcutManager.isVimModeEnabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        isInsertMode = false;
        onModeChanged();
        return KeyEventResult.handled;
      }

      if (!isInsertMode) {
        final char = event.character;
        if (char == 'i' || char == 'a') {
          isInsertMode = true;
          onModeChanged();
          if (char == 'a') {
            final offset = controller.selection.baseOffset;
            if (offset >= 0 && offset < controller.text.length) {
              controller.selection = TextSelection.collapsed(offset: offset + 1);
            }
          }
          return KeyEventResult.handled;
        }

        final text = controller.text;
        var selection = controller.selection;

        if (!selection.isValid) {
          selection = const TextSelection.collapsed(offset: 0);
        }

        final currentOffset = selection.baseOffset.clamp(0, text.length);

        if (char == 'h' && currentOffset > 0) {
          controller.selection = TextSelection.collapsed(offset: currentOffset - 1);
          return KeyEventResult.handled;
        } else if (char == 'l' && currentOffset < text.length) {
          controller.selection = TextSelection.collapsed(offset: currentOffset + 1);
          return KeyEventResult.handled;
        } else if (char == 'j' || char == 'k') {
          final nextOffset = computeVerticalLineOffset(
            text,
            currentOffset,
            moveDown: char == 'j',
          );
          controller.selection = TextSelection.collapsed(offset: nextOffset);
          return KeyEventResult.handled;
        } else if (char == '0') {
          // Move to start of current line
          final lineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0);
          controller.selection = TextSelection.collapsed(
            offset: lineStart == -1 ? 0 : lineStart + 1,
          );
          return KeyEventResult.handled;
        } else if (char == r'$') {
          // Move to end of current line
          final lineEnd = text.indexOf('\n', currentOffset);
          controller.selection = TextSelection.collapsed(
            offset: lineEnd == -1 ? text.length : lineEnd,
          );
          return KeyEventResult.handled;
        } else if (char == 'x' && currentOffset < text.length) {
          controller.text = text.replaceRange(currentOffset, currentOffset + 1, '');
          controller.selection = TextSelection.collapsed(offset: currentOffset);
          return KeyEventResult.handled;
        }

        // In normal mode, block all other printable character input
        if (char != null) {
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  /// Computes the target cursor offset when moving vertically (`j` = down, `k` = up)
  /// across newline boundaries while preserving the current column index.
  @visibleForTesting
  static int computeVerticalLineOffset(
    String text,
    int currentOffset, {
    required bool moveDown,
  }) {
    if (text.isEmpty) return 0;
    final clamped = currentOffset.clamp(0, text.length);

    // Find start and end of current line
    final prevNewline = clamped == 0 ? -1 : text.lastIndexOf('\n', clamped - 1);
    final currentLineStart = prevNewline + 1;
    final nextNewline = text.indexOf('\n', clamped);
    final column = clamped - currentLineStart;

    if (moveDown) {
      if (nextNewline == -1) return clamped; // Already on last line
      final targetLineStart = nextNewline + 1;
      final nextNextNewline = text.indexOf('\n', targetLineStart);
      final targetLineEnd = nextNextNewline == -1 ? text.length : nextNextNewline;
      final targetLineLength = targetLineEnd - targetLineStart;
      return targetLineStart + (column <= targetLineLength ? column : targetLineLength);
    } else {
      if (prevNewline == -1) return clamped; // Already on first line
      final prevPrevNewline = prevNewline == 0 ? -1 : text.lastIndexOf('\n', prevNewline - 1);
      final targetLineStart = prevPrevNewline + 1;
      final targetLineEnd = prevNewline;
      final targetLineLength = targetLineEnd - targetLineStart;
      return targetLineStart + (column <= targetLineLength ? column : targetLineLength);
    }
  }
}

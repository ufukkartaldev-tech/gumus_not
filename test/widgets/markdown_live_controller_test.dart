import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_live_controller.dart';
import 'package:connected_notebook/features/notes/widgets/floating_accessory_bar.dart';

void main() {
  group('MarkdownLivePreviewController Tests', () {
    testWidgets('buildTextSpan parses H1 heading and preserves exact character length', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = MarkdownLivePreviewController(
                  text: '# Ana Başlık\nBu bir normal paragraftır.',
                );
                // Cursor is not on the first line (offset 15 is on second line)
                controller.selection = const TextSelection.collapsed(offset: 15);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                // Ensure total characters match original text
                expect(span.toPlainText(), equals(controller.text));

                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan formats inline bold, italic, and wikilink with exact length', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const sampleText = 'Metin **kalın** ve *italik* ve [[Bağlantı]] ve `kod` ve \$E=mc^2\$';
                final controller = MarkdownLivePreviewController(text: sampleText);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span.toPlainText(), equals(sampleText));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('buildTextSpan formats checklists correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const sampleText = '- [ ] Yapılacak iş\n- [x] Tamamlanan iş';
                final controller = MarkdownLivePreviewController(text: sampleText);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span.toPlainText(), equals(sampleText));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });

  group('FloatingAccessoryBar Helper Tests', () {
    testWidgets('wrapOrInsert wraps selected text correctly', (tester) async {
      final controller = TextEditingController(text: 'Seçili metin burada');
      final focusNode = FocusNode();

      // Select 'metin' (indices 7 to 12)
      controller.selection = const TextSelection(baseOffset: 7, extentOffset: 12);

      FloatingAccessoryBar.wrapOrInsert(
        controller: controller,
        focusNode: focusNode,
        prefix: '**',
        suffix: '**',
      );

      expect(controller.text, equals('Seçili **metin** burada'));
    });

    testWidgets('wrapOrInsert inserts empty syntax when no selection', (tester) async {
      final controller = TextEditingController(text: 'Metin');
      final focusNode = FocusNode();

      controller.selection = const TextSelection.collapsed(offset: 5);

      FloatingAccessoryBar.wrapOrInsert(
        controller: controller,
        focusNode: focusNode,
        prefix: '[[',
        suffix: ']]',
      );

      expect(controller.text, equals('Metin[[]]'));
      expect(controller.selection.baseOffset, equals(7));
    });

    testWidgets('insertAtLineStart inserts prefix at line beginning', (tester) async {
      final controller = TextEditingController(text: 'İlk satır\nİkinci satır');
      final focusNode = FocusNode();

      // Cursor is somewhere inside the second line (offset 15)
      controller.selection = const TextSelection.collapsed(offset: 15);

      FloatingAccessoryBar.insertAtLineStart(
        controller: controller,
        focusNode: focusNode,
        linePrefix: '# ',
      );

      expect(controller.text, equals('İlk satır\n# İkinci satır'));
    });
  });
}

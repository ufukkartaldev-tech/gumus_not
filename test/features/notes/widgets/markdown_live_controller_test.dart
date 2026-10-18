import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_live_controller.dart';

void main() {
  group('MarkdownLivePreviewController Caching & Performance Tests', () {
    testWidgets('Renders inline styles and preserves exact characters', (tester) async {
      final controller = MarkdownLivePreviewController(
        text: '# Heading 1\n**Bold Text** and *italic* and `code`',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                expect(span.toPlainText(), '# Heading 1\n**Bold Text** and *italic* and `code`');
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.dispose();
    });

    testWidgets('Bypasses regex completely for plain text lines', (tester) async {
      final controller = MarkdownLivePreviewController(
        text: 'Bu satirda hicbir markdown isareti yoktur.\nIkinci duz satir.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                controller.resetDebugCounters();
                controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                // Zero regex runs because neither line has markdown trigger chars (*, ~, `, [, $, !)
                expect(controller.debugRegexRunCount, 0);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.dispose();
    });

    testWidgets('Line-level cache serves unchanged lines in O(1) time without re-running regex',
        (tester) async {
      final initialLines = List.generate(50, (i) => 'Satir $i: **onemli** kod `var x = $i;`').join('\n');
      final controller = MarkdownLivePreviewController(text: initialLines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // First pass: populates cache
                controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(controller.debugRegexRunCount, greaterThan(0));

                // Second pass (same text): 100% cache hits
                controller.resetDebugCounters();
                controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(controller.debugCacheHitCount, 50);
                expect(controller.debugRegexRunCount, 0);

                // Edit line 25 only: 49 lines must hit cache, only line 25 is re-parsed
                controller.resetDebugCounters();
                final linesList = initialLines.split('\n');
                linesList[25] = 'Satir 25: **guncellenmis** yeni deger `var x = 999;`';
                controller.text = linesList.join('\n');

                controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(controller.debugCacheHitCount, 49);
                expect(controller.debugRegexRunCount, 1);

                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.dispose();
    });

    testWidgets('Code block interiors do not execute inline regex', (tester) async {
      const codeBlockText = '```dart\nfinal x = **not_bold**;\nfinal y = `not_inline`;\n```';
      final controller = MarkdownLivePreviewController(text: codeBlockText);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                controller.resetDebugCounters();
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span.toPlainText(), codeBlockText);
                // Interior code block lines are styled monospace without regex
                expect(controller.debugRegexRunCount, 0);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      controller.dispose();
    });
  });
}

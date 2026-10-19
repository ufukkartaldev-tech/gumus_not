import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';

void main() {
  group('MarkdownCleaner Tests', () {
    test('strips headers, bold, italics, and code blocks from text', () {
      const rawMarkdown = '''
# Başlık 1
## Alt Başlık

Bu bir **kalın metin**, bu ise *italik* ve `kod` örneğidir.

```dart
void test() {
  print('hello');
}
```
''';

      final cleaned = MarkdownCleaner.clean(rawMarkdown);

      expect(cleaned, isNot(contains('#')));
      expect(cleaned, isNot(contains('*')));
      expect(cleaned, isNot(contains('`')));
      expect(cleaned, contains('Başlık 1'));
      expect(cleaned, contains('kalın metin'));
      expect(cleaned, contains('italik'));
      expect(cleaned, contains('kod örneğidir'));
    });

    test('extracts targets from wikilinks properly', () {
      const markdown = 'Detaylar için [[Flutter Mimarisi]] ve [[Dart Dili|Dart]] notlarına bakın.';
      final cleaned = MarkdownCleaner.clean(markdown);

      expect(cleaned, isNot(contains('[[')));
      expect(cleaned, isNot(contains(']]')));
      expect(cleaned, contains('Flutter Mimarisi'));
      expect(cleaned, contains('Dart'));
    });

    test('strips HTML tags and images', () {
      const markdown = 'Metin <span style="color:red">renkli</span> ve resim ![logo](http://example.com/logo.png).';
      final cleaned = MarkdownCleaner.clean(markdown);

      expect(cleaned, isNot(contains('<span')));
      expect(cleaned, isNot(contains('![logo]')));
      expect(cleaned, contains('Metin renkli ve resim .'));
    });

    test('extractHashtags extracts valid hashtags including Turkish characters', () {
      const markdown = '''
# Bu bir başlık (#etiket değil)
Bugün #flutter ve #geliştirici üzerine çalıştık. #algoritma_101 harikaydı.
''';

      final tags = MarkdownCleaner.extractHashtags(markdown);

      expect(tags, contains('flutter'));
      expect(tags, contains('geliştirici'));
      expect(tags, contains('algoritma_101'));
      // The markdown heading should NOT be extracted as a hashtag
      expect(tags, isNot(contains('bu')));
      expect(tags, isNot(contains('etiket')));
    });
  });
}

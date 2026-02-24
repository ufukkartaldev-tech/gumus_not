import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/shared/utils/image_service.dart';

void main() {
  group('ImageService Unit Tests', () {
    test('createMarkdownImageLink creates valid markdown syntax', () {
      final link = ImageService.createMarkdownImageLink('/path/to/image.png');
      expect(link, '![Resim](/path/to/image.png)');
      
      final linkWithAlt = ImageService.createMarkdownImageLink('/path/to/image.png', altText: 'Custom Alt');
      expect(linkWithAlt, '![Custom Alt](/path/to/image.png)');
    });

    test('extractImagePaths correctly finds image paths from markdown', () {
      final content = '''
# Title
Here is an image:
![Test 1](/local/path/img1.png)

Some text...
![Alt](/local/path/img2.jpg)
''';

      final paths = ImageService.extractImagePaths(content);
      expect(paths.length, 2);
      expect(paths[0], '/local/path/img1.png');
      expect(paths[1], '/local/path/img2.jpg');
    });

    test('extractImagePaths handles empty content safely', () {
      final paths = ImageService.extractImagePaths('');
      expect(paths, isEmpty);
      
      final pathsNoImages = ImageService.extractImagePaths('Just text without images.');
      expect(pathsNoImages, isEmpty);
    });
  });
}

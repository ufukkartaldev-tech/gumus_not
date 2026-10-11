import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:connected_notebook/shared/utils/sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedContent Model Tests', () {
    test('Should detect empty content properly', () {
      const empty1 = SharedContent();
      const empty2 = SharedContent(text: '   ', filePaths: []);
      expect(empty1.isEmpty, isTrue);
      expect(empty2.isEmpty, isTrue);

      const withText = SharedContent(text: 'Merhaba Dünya');
      expect(withText.isNotEmpty, isTrue);

      const withFiles = SharedContent(filePaths: ['/path/to/img.png']);
      expect(withFiles.isNotEmpty, isTrue);
    });

    test('toString should include essential fields', () {
      const content = SharedContent(text: 'Not içeriği', filePaths: ['/path/1.png'], title: 'Başlık');
      expect(content.toString(), contains('Not içeriği'));
      expect(content.toString(), contains('/path/1.png'));
    });
  });

  group('SharingService Parsing Tests', () {
    final service = SharingService();

    test('Should parse text and url shared media files', () {
      final mediaList = [
        SharedMediaFile(
          path: 'https://flutter.dev',
          type: SharedMediaType.url,
        ),
        SharedMediaFile(
          path: 'Flutter harika bir framework!',
          type: SharedMediaType.text,
        ),
      ];

      final parsed = service.parseSharedMedia(mediaList);
      expect(parsed.isNotEmpty, isTrue);
      expect(parsed.text, contains('https://flutter.dev'));
      expect(parsed.text, contains('Flutter harika bir framework!'));
      expect(parsed.filePaths, isEmpty);
    });

    test('Should parse image and file media files', () {
      final mediaList = [
        SharedMediaFile(
          path: '/storage/emulated/0/Download/photo.jpg',
          type: SharedMediaType.image,
        ),
        SharedMediaFile(
          path: '/storage/emulated/0/Download/doc.pdf',
          type: SharedMediaType.file,
        ),
      ];

      final parsed = service.parseSharedMedia(mediaList);
      expect(parsed.filePaths.length, 2);
      expect(parsed.filePaths[0], '/storage/emulated/0/Download/photo.jpg');
      expect(parsed.filePaths[1], '/storage/emulated/0/Download/doc.pdf');
    });

    test('Should combine text and files in a single payload', () {
      final mediaList = [
        SharedMediaFile(
          path: 'Toplantı Notları:\nMadde 1',
          type: SharedMediaType.text,
        ),
        SharedMediaFile(
          path: '/path/diagram.png',
          type: SharedMediaType.image,
        ),
      ];

      final parsed = service.parseSharedMedia(mediaList);
      expect(parsed.text, contains('Toplantı Notları:'));
      expect(parsed.filePaths.length, 1);
      expect(parsed.title, 'Toplantı Notları:');
    });
  });

  group('SharingService Lifecycle Tests', () {
    test('dispose should clear resources safely without throwing', () {
      final service = SharingService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}

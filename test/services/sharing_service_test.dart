import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/services/sharing_service.dart';

void main() {
  group('SharingService Unit Tests', () {
    test('SharingService is a singleton', () {
      final instance1 = SharingService();
      final instance2 = SharingService();
      
      expect(identical(instance1, instance2), isTrue);
    });

    test('dispose does not throw errors', () {
      final service = SharingService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}

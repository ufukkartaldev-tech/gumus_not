import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/home_widget/services/widget_service.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() {
  group('WidgetService redaction (SRS Section 6.2 & Phase 2)', () {
    test('redacts title, content, tags, and emoji of encrypted notes', () {
      final secretNote = Note(
        id: 42,
        title: 'Banka Hesap Şifrelerim',
        content: 'enc:v1:iv_b64:ciphertext_b64',
        createdAt: 1700000000000,
        updatedAt: 1700000050000,
        isEncrypted: true,
        tags: ['finans', 'gizli'],
        folderName: 'Kasa',
        emojiIcon: '💳',
      );

      final redacted = WidgetService.redactForWidget(secretNote);

      expect(redacted.id, 42);
      expect(redacted.title, WidgetService.redactedEncryptedTitle);
      expect(redacted.title.contains('Banka'), isFalse);
      expect(redacted.content, isEmpty);
      expect(redacted.tags, isEmpty);
      expect(redacted.emojiIcon, '🔒');
      expect(redacted.isEncrypted, isTrue);
    });

    test('preserves plaintext notes unchanged for widget serialization', () {
      final publicNote = Note(
        id: 7,
        title: 'Alışveriş Listesi',
        content: '- [ ] Süt al\n- [ ] Ekmek al',
        createdAt: 1700000000000,
        updatedAt: 1700000050000,
        isEncrypted: false,
        tags: ['gunluk'],
        folderName: 'Genel',
        emojiIcon: '🛒',
      );

      final result = WidgetService.redactForWidget(publicNote);

      expect(result.title, 'Alışveriş Listesi');
      expect(result.content, '- [ ] Süt al\n- [ ] Ekmek al');
      expect(result.tags, ['gunluk']);
      expect(result.emojiIcon, '🛒');
    });

    test('buildRedactedWidgetPayload prevents secret leakage in both recentNotes and pendingTasks', () {
      final secretTaskNote = Note(
        id: 99,
        title: 'Gizli Satın Alma Planı',
        content: 'enc:v1:abc:def',
        createdAt: 100,
        updatedAt: 200,
        isEncrypted: true,
        tags: ['sirket-ici'],
      );
      final plainTaskNote = Note(
        id: 100,
        title: 'Haftalık Rapor',
        content: '- [ ] Sunumu hazırla',
        createdAt: 100,
        updatedAt: 300,
        isEncrypted: false,
        tags: ['is'],
      );

      final payload = WidgetService.buildRedactedWidgetPayload(
        recentNotes: [secretTaskNote, plainTaskNote],
        pendingTasks: [secretTaskNote],
        timestampMs: 123456789,
      );

      final serializedPayload = payload.toString();
      expect(serializedPayload.contains('Gizli Satın Alma Planı'), isFalse);
      expect(serializedPayload.contains('enc:v1:abc:def'), isFalse);
      expect(serializedPayload.contains('sirket-ici'), isFalse);
      expect(serializedPayload.contains('Haftalık Rapor'), isTrue);
      expect(payload['lastUpdated'], 123456789);
    });
  });
}

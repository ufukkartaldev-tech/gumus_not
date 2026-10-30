import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/backlink_service.dart';

void main() {
  group('BacklinkService Tests', () {
    late MockNoteRepository repository;
    late BacklinkService backlinkService;

    setUp(() {
      repository = MockNoteRepository();
      backlinkService = BacklinkService(repository);
    });

    Note createNote({
      required int id,
      required String title,
      required String content,
      bool isEncrypted = false,
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        createdAt: 1000,
        updatedAt: 1000,
        isEncrypted: isEncrypted,
      );
    }

    test('getReferringNotes returns notes that mention target note via wikilink', () async {
      final noteTarget = createNote(id: 1, title: 'Dart Temelleri', content: 'Giriş');
      final noteReferrer = createNote(
        id: 2,
        title: 'Flutter Notu',
        content: 'Önce [[Dart Temelleri]] öğrenilmelidir.',
      );
      final noteOther = createNote(id: 3, title: 'Başka Not', content: 'Bağlantısız metin.');

      await repository.addNote(noteTarget);
      await repository.addNote(noteReferrer);
      await repository.addNote(noteOther);

      final referring = await backlinkService.getReferringNotes(1);

      expect(referring.length, equals(1));
      expect(referring.first.id, equals(2));
      expect(referring.first.title, equals('Flutter Notu'));
    });

    test('getReferringNotes ignores encrypted notes to prevent data leaks', () async {
      final noteTarget = createNote(id: 1, title: 'Hedef Not', content: 'Açık metin');
      final noteEncrypted = createNote(
        id: 2,
        title: 'Kilitli Not',
        content: 'Şifreli [[Hedef Not]] referansı',
        isEncrypted: true,
      );

      await repository.addNote(noteTarget);
      await repository.addNote(noteEncrypted);

      final referring = await backlinkService.getReferringNotes(1);
      expect(referring, isEmpty);
    });

    test('getLinkedNotes returns target notes referenced in current note', () async {
      final noteSource = createNote(
        id: 1,
        title: 'Mühendislik Notları',
        content: 'Bkz: [[Matematik]] ve [[Fizik]].',
      );
      final noteTarget1 = createNote(id: 2, title: 'Matematik', content: 'Calculus');
      final noteTarget2 = createNote(id: 3, title: 'Fizik', content: 'Mekanik');

      await repository.addNote(noteSource);
      await repository.addNote(noteTarget1);
      await repository.addNote(noteTarget2);

      final linked = await backlinkService.getLinkedNotes(1);

      expect(linked.length, equals(2));
      expect(linked.map((n) => n.title), containsAll(['Matematik', 'Fizik']));
    });

    test('getOrphanedNotes finds notes with zero incoming links', () async {
      final connected1 = createNote(id: 1, title: 'Bağlı Not 1', content: 'Bkz [[Bağlı Not 2]]');
      final connected2 = createNote(id: 2, title: 'Bağlı Not 2', content: 'İçerik');
      final orphan = createNote(id: 3, title: 'Yalnız Not', content: 'Hiçbir yerden linklenmemiş');

      await repository.addNote(connected1);
      await repository.addNote(connected2);
      await repository.addNote(orphan);

      final orphans = await backlinkService.getOrphanedNotes();

      // connected1 and orphan are orphaned (no incoming links to connected1 or orphan)
      expect(orphans.map((n) => n.id), containsAll([1, 3]));
      expect(orphans.map((n) => n.id), isNot(contains(2)));
    });

    test('getHubNotes returns notes with at least minimum outgoing links', () async {
      final hub = createNote(
        id: 1,
        title: 'Ana İndeks',
        content: '[[A]], [[B]], [[C]], [[D]]',
      );
      final noteA = createNote(id: 2, title: 'A', content: '');
      final noteB = createNote(id: 3, title: 'B', content: '');
      final noteC = createNote(id: 4, title: 'C', content: '');
      final noteD = createNote(id: 5, title: 'D', content: '');

      await repository.addNote(hub);
      await repository.addNote(noteA);
      await repository.addNote(noteB);
      await repository.addNote(noteC);
      await repository.addNote(noteD);

      final hubs = await backlinkService.getHubNotes(minimumLinks: 3);
      expect(hubs.length, equals(1));
      expect(hubs.first.id, equals(1));
    });

    test('SRS 4.2 & 8.2: renameNoteLinks and extractLinks support [[Title|Alias]] syntax', () async {
      final target = createNote(id: 1, title: 'Eski Kavram', content: 'Tanım');
      final referrer = createNote(
        id: 2,
        title: 'Makale',
        content: 'Bkz [[Eski Kavram|Kavram Özeti]] ve [[Eski Kavram]].',
      );

      await repository.addNote(target);
      await repository.addNote(referrer);

      expect(referrer.extractLinks(), equals(['Eski Kavram', 'Eski Kavram']));
      final referring = await backlinkService.getReferringNotes(1);
      expect(referring.map((n) => n.id), equals([2]));

      final updatedCount = await backlinkService.renameNoteLinks(
        oldTitle: 'Eski Kavram',
        newTitle: 'Yeni Kavram',
        excludeNoteId: 1,
      );
      expect(updatedCount, equals(1));

      final updatedReferrer = await repository.getNoteById(2);
      expect(
        updatedReferrer?.content,
        equals('Bkz [[Yeni Kavram|Kavram Özeti]] ve [[Yeni Kavram]].'),
      );
    });
  });
}

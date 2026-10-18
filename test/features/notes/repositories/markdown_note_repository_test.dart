import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/markdown_note_repository.dart';

void main() {
  late Directory notesDir;
  late MarkdownNoteRepository repository;

  const testKeyBase64 = '3q2+7wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
  final encryptionService = NoteEncryptionService(
    keyReader: (_) async => testKeyBase64,
    keyWriter: (key, value) async {},
  );

  setUp(() async {
    notesDir = await Directory.systemTemp.createTemp('gumusnot_repo_test');
    repository = MarkdownNoteRepository(
      encryptionService: encryptionService,
      enableGit: false,
      notesDirResolver: () async => notesDir,
    );
  });

  tearDown(() async {
    if (notesDir.existsSync()) await notesDir.delete(recursive: true);
  });

  Note note({
    required String title,
    required String content,
    bool isEncrypted = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Note(
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      isEncrypted: isEncrypted,
      tags: const ['test'],
      folderName: 'Test',
    );
  }

  String storedFileByTitle(String fileName) =>
      File(p.join(notesDir.path, fileName)).readAsStringSync();

  group('MarkdownNoteRepository encryption at rest & title filenames', () {
    test('plain notes are saved as <Title>.md and stay readable on disk', () async {
      final id = await repository.addNote(note(title: 'Açık Not', content: 'düz metin'));

      final raw = storedFileByTitle('Açık Not.md');
      expect(raw, contains('düz metin'));
      expect(NoteEncryptionService.isEncryptedPayload('düz metin'), isFalse);

      final loaded = await repository.getNoteById(id);
      expect(loaded?.content, 'düz metin');
      expect(loaded?.isEncrypted, isFalse);
    });

    test('renaming a note renames its markdown file on disk', () async {
      final id = await repository.addNote(note(title: 'Eski İsim', content: 'içerik'));
      expect(File(p.join(notesDir.path, 'Eski İsim.md')).existsSync(), isTrue);

      final existing = await repository.getNoteById(id);
      await repository.updateNote(existing!.copyWith(title: 'Yeni İsim'));

      expect(File(p.join(notesDir.path, 'Eski İsim.md')).existsSync(), isFalse);
      expect(File(p.join(notesDir.path, 'Yeni İsim.md')).existsSync(), isTrue);
      expect((await repository.getNoteById(id))?.title, 'Yeni İsim');
    });

    test('duplicate note titles get numbered filenames without overwriting', () async {
      final id1 = await repository.addNote(note(title: 'Günlük', content: 'birinci'));
      final id2 = await repository.addNote(note(title: 'Günlük', content: 'ikinci'));

      expect(File(p.join(notesDir.path, 'Günlük.md')).existsSync(), isTrue);
      expect(File(p.join(notesDir.path, 'Günlük (2).md')).existsSync(), isTrue);
      expect((await repository.getNoteById(id1))?.content, 'birinci');
      expect((await repository.getNoteById(id2))?.content, 'ikinci');
    });

    test('encrypted note bodies never touch the disk as plaintext', () async {
      const secret = 'gizli çekirdek tarif: 3 yumurta';
      final id = await repository.addNote(
        note(title: 'Kilitli', content: secret, isEncrypted: true),
      );

      final raw = storedFileByTitle('Kilitli.md');
      expect(raw.contains(secret), isFalse);
      expect(raw, contains('enc:v1:'));
      expect(raw, contains('isEncrypted: true'));

      final loaded = await repository.getNoteById(id);
      expect(loaded?.isEncrypted, isTrue);
      expect(NoteEncryptionService.isEncryptedPayload(loaded!.content), isTrue);
      expect(loaded.content.contains(secret), isFalse);
    });

    test('unlocked updates re-encrypt new content', () async {
      final id = await repository.addNote(
        note(title: 'Kilitli', content: 'v1', isEncrypted: true),
      );
      final stored = await repository.getNoteById(id);

      await repository.updateNote(stored!.copyWith(content: 'v2 güncel'));

      final raw = storedFileByTitle('Kilitli.md');
      expect(raw.contains('v2 güncel'), isFalse);
      expect(raw, contains('enc:v1:'));
    });

    test('saving a locked note keeps the stored ciphertext and renames file', () async {
      final id = await repository.addNote(
        note(title: 'Kilitli', content: 'kalıcı içerik', isEncrypted: true),
      );
      final stored = await repository.getNoteById(id);
      final ciphertext = stored!.content;

      // Editor re-save while still locked: content is the placeholder.
      await repository.updateNote(stored.copyWith(
        content: NoteEncryptionService.lockedNotePlaceholder,
        title: 'Yeni Başlık',
      ));

      expect(File(p.join(notesDir.path, 'Kilitli.md')).existsSync(), isFalse);
      final raw = storedFileByTitle('Yeni Başlık.md');
      expect(raw.contains(NoteEncryptionService.lockedNotePlaceholder), isFalse);
      expect(raw, contains('Yeni Başlık'));

      final reloaded = await repository.getNoteById(id);
      expect(reloaded!.content, ciphertext);
    });

    test('legacy plaintext body with encrypted flag stays readable', () async {
      final id = await repository.addNote(
        note(title: 'Eski', content: 'eski düz metin', isEncrypted: true),
      );
      // Simulate the legacy state: encrypted flag, plaintext body, <id>.md filename.
      final titleFile = File(p.join(notesDir.path, 'Eski.md'));
      if (titleFile.existsSync()) await titleFile.delete();
      final legacyFile = File(p.join(notesDir.path, '$id.md'));
      final now = DateTime.now().millisecondsSinceEpoch;
      await legacyFile.writeAsString('''
---
title: "Eski"
createdAt: $now
updatedAt: $now
isEncrypted: true
folderName: "Test"
---
eski düz metin''');

      final loaded = await repository.getNoteById(id);
      expect(loaded!.isEncrypted, isTrue);
      expect(loaded.content, 'eski düz metin');
    });

    test('in-memory cache serves repeated queries with zero extra disk reads', () async {
      final id1 = await repository.addNote(
        note(title: 'Birinci', content: '[[İkinci]] bağlantı'),
      );
      final id2 = await repository.addNote(
        note(title: 'İkinci', content: '- [ ] görev'),
      );

      final readsAfterWrites = repository.debugDiskReadCount;

      // Repeated queries should all be served from the warm in-memory cache.
      await repository.getAllNotes();
      await repository.searchNotes('görev');
      await repository.getBacklinksForNote(id2);
      await repository.getOutgoingLinksForNote(id1);
      await repository.getFolders();
      await repository.getTagFrequency();
      await repository.getNoteById(id1);

      expect(repository.debugDiskReadCount, readsAfterWrites);

      // Even after invalidating the TTL, unchanged files on disk are skipped via FileStat.
      repository.invalidateCache();
      await repository.getAllNotes();
      expect(repository.debugDiskReadCount, readsAfterWrites);

      // An externally dropped file is read once, while existing files stay cached.
      await File(p.join(notesDir.path, 'Dışarıdan.md')).writeAsString('# Merhaba');
      repository.invalidateCache();
      final all = await repository.getAllNotes();
      expect(all.length, 3);
      expect(repository.debugDiskReadCount, readsAfterWrites + 1);
    });

    test('searchNotes never matches encrypted payload prefix or ciphertext body', () async {
      await repository.addNote(
        note(title: 'Gizli Kasa', content: 'çok gizli bilgi', isEncrypted: true),
      );
      await repository.addNote(
        note(title: 'Normal Not', content: 'açık içerik', isEncrypted: false),
      );

      // Searching for "enc" or "v1" (present in enc:v1:... payload) must not match the encrypted note.
      expect(await repository.searchNotes('enc:v1'), isEmpty);
      expect(await repository.searchNotes('çok gizli'), isEmpty);

      // Title search still finds the encrypted note.
      final byTitle = await repository.searchNotes('Gizli Kasa');
      expect(byTitle.length, 1);
      expect(byTitle.first.title, 'Gizli Kasa');
    });
  });
}


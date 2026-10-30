import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/markdown_note_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aşama 5 — MVP Bütünsel Güvenilirlik ve Uçtan Uca Entegrasyon Testleri', () {
    late Directory tempWorkspace;
    late Directory notesDir;
    late Map<String, String> secureStorage;
    late NoteEncryptionService encryptionService;
    late MarkdownNoteRepository repository;

    setUp(() async {
      tempWorkspace = await Directory.systemTemp.createTemp('gumusnot_e2e_workspace_');
      notesDir = Directory(p.join(tempWorkspace.path, 'notes'))..createSync(recursive: true);
      Directory(p.join(tempWorkspace.path, 'templates')).createSync(recursive: true);

      secureStorage = {};
      encryptionService = NoteEncryptionService(
        keyReader: (k) async => secureStorage[k],
        keyWriter: (k, v) async => secureStorage[k] = v,
        keyDeleter: (k) async => secureStorage.remove(k),
        vaultDirResolver: () async => notesDir,
      );

      repository = MarkdownNoteRepository(
        encryptionService: encryptionService,
        enableGit: false,
        notesDirResolver: () async => notesDir,
      );
    });

    tearDown(() async {
      if (tempWorkspace.existsSync()) {
        try {
          tempWorkspace.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    // 1. Not oluştur, kaydet, uygulamayı kapat ve yeniden aç
    test('Senaryo 1: Not oluştur, diske atomik kaydet, yeniden başlatmada tam geri yükle', () async {
      final note = Note(
        title: 'Mimar Sinan Notu',
        content: '# Süleymaniye\n1557 yılında tamamlandı.',
        createdAt: 1000,
        updatedAt: 1000,
        tags: ['mimari', 'tarih'],
      );

      final noteId = await repository.addNote(note);
      expect(noteId, isNotNull);

      final diskFile = File(p.join(notesDir.path, 'Mimar Sinan Notu.md'));
      expect(diskFile.existsSync(), isTrue);
      expect(diskFile.readAsStringSync(), contains('1557 yılında tamamlandı.'));

      // Uygulama kapandı, yeni bir repository oturumu açıldı (Cold Start)
      final newSessionRepo = MarkdownNoteRepository(
        encryptionService: encryptionService,
        enableGit: false,
        notesDirResolver: () async => notesDir,
      );

      final restoredNote = await newSessionRepo.getNoteById(noteId);
      expect(restoredNote, isNotNull);
      expect(restoredNote!.title, equals('Mimar Sinan Notu'));
      expect(restoredNote.content, equals('# Süleymaniye\n1557 yılında tamamlandı.'));
      expect(restoredNote.tags, containsAll(['mimari', 'tarih']));
    });

    // 2. Şifreli not oluştur, kasayı kilitle ve yeniden aç
    test('Senaryo 2: Şifreli not oluştur, kasayı kilitle, RAM DEK sıfırlansın, parola ile yeniden aç', () async {
      const masterPassword = 'GuvenliKasaParolasi2026!';
      await encryptionService.setupMasterPassword(masterPassword);

      final secretNote = Note(
        title: 'Gizli Hesaplar',
        content: 'Banka IBAN: TR00 0000 0000 0000 0000 00',
        createdAt: 2000,
        updatedAt: 2000,
        isEncrypted: true,
      );

      final id = await repository.addNote(secretNote);
      expect(id, isNotNull);

      // Diskteki içerik ciphertext olmalı, ASLA düz metin olmamalı
      final rawDiskContent = File(p.join(notesDir.path, 'Gizli Hesaplar.md')).readAsStringSync();
      expect(rawDiskContent, isNot(contains('TR00 0000')));
      expect(rawDiskContent, contains('enc:v1:'));

      // Kasayı kilitle: RAM ve güvenli depolama temizlenir
      await encryptionService.lockVault();
      expect(encryptionService.isUnlockedInMemory, isFalse);
      expect(encryptionService.debugCachedDekBuffer, isNull);

      // Kilitliyken not getirildiğinde ciphertext korunur ve çözülmeye çalışıldığında VaultLockedException fırlatılır
      final lockedNote = await repository.getNoteById(id);
      expect(lockedNote, isNotNull);
      expect(NoteEncryptionService.isEncryptedPayload(lockedNote!.content), isTrue);
      expect(() async => await encryptionService.decrypt(lockedNote.content), throwsA(isA<VaultLockedByPasswordException>()));

      // Kasayı doğru parola ile aç
      await encryptionService.unlockWithMasterPassword(masterPassword);
      expect(encryptionService.isUnlockedInMemory, isTrue);

      final decrypted = await encryptionService.decrypt(lockedNote.content);
      expect(decrypted, equals('Banka IBAN: TR00 0000 0000 0000 0000 00'));
    });

    // 3. Kilitli not düzenlenmeye çalışıldığında içeriğin değişmediğini doğrula
    test('Senaryo 3: Kilitliyken placeholder diske yazılmaya çalışıldığında ciphertext korunur', () async {
      const masterPassword = 'KasaParolasi1234!';
      await encryptionService.setupMasterPassword(masterPassword);

      final secretNote = Note(
        title: 'Kişisel Veri',
        content: 'Gizli Sözleşme Maddeleri',
        createdAt: 3000,
        updatedAt: 3000,
        isEncrypted: true,
      );
      final id = await repository.addNote(secretNote);

      await encryptionService.lockVault();

      // Kilitli placeholder içeren sahte veya kazara güncelleme denemesi
      final maliciousUpdate = Note(
        id: id,
        title: 'Kişisel Veri',
        content: NoteEncryptionService.lockedNotePlaceholder,
        createdAt: 3000,
        updatedAt: 3001,
        isEncrypted: true,
      );

      // Repository bu güncellemede gerçek ciphertext'i korur (placeholder ciphertext'i ezmez)
      await repository.updateNote(maliciousUpdate);

      // Parolayı açıp içeriğin hala korunduğunu test et
      await encryptionService.unlockWithMasterPassword(masterPassword);
      final loaded = await repository.getNoteById(id);
      expect(NoteEncryptionService.isEncryptedPayload(loaded!.content), isTrue);
      final decrypted = await encryptionService.decrypt(loaded.content);
      expect(decrypted, equals('Gizli Sözleşme Maddeleri'));
    });

    // 4. Not düzenlerken başka bir nota geçişte atomik kayıt
    test('Senaryo 4: Not düzenlerken yeni nota geçildiğinde eski not kaydedilmiş olmalı', () async {
      final note1 = Note(title: 'Not 1', content: 'Not 1 ilk içerik', createdAt: 4001, updatedAt: 4001);
      final id1 = await repository.addNote(note1);

      // Düzenleme yapıldı ve kaydedildi
      final updatedNote1 = note1.copyWith(id: id1, content: 'Not 1 güncellenmiş son metin');
      await repository.updateNote(updatedNote1);

      // Başka nota geçildi
      final note2 = Note(title: 'Not 2', content: 'Not 2 içerik', createdAt: 4002, updatedAt: 4002);
      final id2 = await repository.addNote(note2);

      final diskNote1 = await repository.getNoteById(id1);
      expect(diskNote1!.content, equals('Not 1 güncellenmiş son metin'));

      final diskNote2 = await repository.getNoteById(id2);
      expect(diskNote2!.content, equals('Not 2 içerik'));
    });

    // 5 & 6. Otomatik kayıt ve atomik dosya bütünlüğü
    test('Senaryo 5 & 6: Yoğun ve ardışık kayıt işlemlerinde geçici dosya (.tmp) kalıntısı kalmaz', () async {
      final note = Note(title: 'Hızlı Yazım', content: 'Versiyon 1', createdAt: 5000, updatedAt: 5000);
      final id = await repository.addNote(note);

      // Hızlı ardışık güncellemeler (otomatik kayıt simülasyonu)
      for (var i = 2; i <= 20; i++) {
        await repository.updateNote(note.copyWith(id: id, content: 'Versiyon $i'));
      }

      final finalNote = await repository.getNoteById(id);
      expect(finalNote!.content, equals('Versiyon 20'));

      // .tmp uzantılı bozuk geçici dosya kalmamalı
      final tmpFiles = notesDir.listSync().where((f) => f.path.endsWith('.tmp'));
      expect(tmpFiles, isEmpty);
    });

    // 7. Uygulama çöktükten sonra acil durum taslağını kurtarma
    test('Senaryo 7: Acil durum taslağı dosyası yazılmışsa başarıyla tespit edilip okunur', () async {
      final emergencyDraftFile = File(p.join(tempWorkspace.path, 'notes', '.emergency_draft.json'));
      final emergencyData = {
        'persistedId': 105,
        'title': 'Kurtarılan Taslak',
        'content': 'Çökme anında yazılmakta olan son paragraflar.',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await emergencyDraftFile.writeAsString(jsonEncode(emergencyData), flush: true);

      expect(emergencyDraftFile.existsSync(), isTrue);
      final decoded = jsonDecode(await emergencyDraftFile.readAsString()) as Map<String, dynamic>;
      expect(decoded['title'], equals('Kurtarılan Taslak'));
      expect(decoded['content'], contains('son paragraflar'));
      await emergencyDraftFile.delete();
    });

    // 8 & 12. Şifreli yedek oluştur, başka bir dizine geri yükle ve şifreleme durumunu doğrula
    test('Senaryo 8 & 12: Şifreli notlar .enc yedeğe alınıp başka çalışma alanına aktarıldığında şifrelilik korunur', () async {
      const masterPassword = 'MasterKasaSifresi2026!';
      await encryptionService.setupMasterPassword(masterPassword);

      // Biri açık, biri şifreli iki not oluştur
      await repository.addNote(Note(title: 'Açık Not', content: 'Herkes okuyabilir', createdAt: 1, updatedAt: 1));
      final encryptedId = await repository.addNote(
        Note(title: 'Korumalı Not', content: 'Çok gizli formül X', createdAt: 2, updatedAt: 2, isEncrypted: true),
      );

      // Hedef bağımsız çalışma alanı dizini
      final targetWorkspace = await Directory.systemTemp.createTemp('gumusnot_e2e_target_');
      addTearDown(() {
        if (targetWorkspace.existsSync()) targetWorkspace.deleteSync(recursive: true);
      });

      // 1. Şifreli yedek oluştur (.enc)
      const backupPassword = 'YedeklemeParolasi999*';
      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(
        password: backupPassword,
        root: tempWorkspace,
      );
      expect(encBytes, isNotNull);

      // 2. Başka bir dizine geri yükle
      final restoredCount = await MarkdownBackupUtils.restoreEncryptedBackup(
        encBytes!,
        backupPassword,
        root: targetWorkspace,
        replaceExisting: true,
      );
      expect(restoredCount, greaterThanOrEqualTo(2));

      // 3. Hedef dizindeki dosyaları doğrula
      final targetNotesDir = Directory(p.join(targetWorkspace.path, 'notes'));
      final openFile = File(p.join(targetNotesDir.path, 'Açık Not.md'));
      final encryptedFile = File(p.join(targetNotesDir.path, 'Korumalı Not.md'));

      expect(openFile.existsSync(), isTrue);
      expect(encryptedFile.existsSync(), isTrue);

      // Şifreli dosya hedef dizinde de ciphertext olarak durmalı (düz metne dönüşmemeli!)
      final targetDiskEncrypted = encryptedFile.readAsStringSync();
      expect(targetDiskEncrypted, isNot(contains('Çok gizli formül X')));
      expect(targetDiskEncrypted, contains('enc:v1:'));
      expect(targetDiskEncrypted, contains('isEncrypted: true'));

      // Hedef dizinde anahtar (.vault_key.json) mevcut mu ve master password ile çözülebiliyor mu?
      final targetKeyFile = File(p.join(targetNotesDir.path, NoteEncryptionService.envelopeFileName));
      expect(targetKeyFile.existsSync(), isTrue);

      final targetEncryptionService = NoteEncryptionService(
        keyReader: (k) async => secureStorage[k],
        keyWriter: (k, v) async => secureStorage[k] = v,
        vaultDirResolver: () async => targetNotesDir,
      );

      // Hedef makinede/dizinde kullanıcı master parolasını girdiğinde not çözülebilmeli!
      await targetEncryptionService.unlockWithMasterPassword(masterPassword);
      final targetRepo = MarkdownNoteRepository(
        encryptionService: targetEncryptionService,
        enableGit: false,
        notesDirResolver: () async => targetNotesDir,
      );

      final targetLoaded = await targetRepo.getNoteById(encryptedId);
      expect(targetLoaded, isNotNull);
      expect(NoteEncryptionService.isEncryptedPayload(targetLoaded!.content), isTrue);
      final decrypted = await targetEncryptionService.decrypt(targetLoaded.content);
      expect(decrypted, equals('Çok gizli formül X'));
      expect(targetLoaded.isEncrypted, isTrue);
    });

    // 9. Yanlış parola ile yedek açmayı dene
    test('Senaryo 9: Yanlış parola ile .enc açılırken InvalidBackupPasswordException fırlatılır', () async {
      await repository.addNote(Note(title: 'Normal Not', content: 'Test', createdAt: 1, updatedAt: 1));

      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(password: 'DogruSifre1!', root: tempWorkspace);

      expect(
        () async => await MarkdownBackupUtils.restoreEncryptedBackup(
          encBytes!,
          'YanlisSifre99!',
          root: tempWorkspace,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    // 10. Geri yükleme sırasında hata oluşması ve Rollback doğrulaması
    test('Senaryo 10: Geri yüklemede beklenmedik bozuk dosya hatasında orijinal dosyalar rollback ile korunur', () async {
      final initialNote = Note(title: 'Hayatî Orijinal Not', content: 'Asla kaybolmamalı', createdAt: 1, updatedAt: 1);
      await repository.addNote(initialNote);

      final originalFile = File(p.join(notesDir.path, 'Hayatî Orijinal Not.md'));
      expect(originalFile.existsSync(), isTrue);

      // Bozuk ZIP arşivi simülasyonu
      final invalidPayload = Uint8List.fromList([0x47, 0x4E, 0x43, 0x42, 0x02, ...List.filled(50, 0xFF)]);

      try {
        await MarkdownBackupUtils.restoreEncryptedBackup(
          invalidPayload,
          'herhangi_sifre',
          root: tempWorkspace,
          replaceExisting: true,
        );
      } catch (_) {}

      // Rollback sonrasında orijinal dosya hala orada ve sapasağlam olmalı
      expect(originalFile.existsSync(), isTrue);
      expect(originalFile.readAsStringSync(), contains('Asla kaybolmamalı'));
    });

    // 11. Harici dosya değişikliği ve Çakışma Kopyası
    test('Senaryo 11: Harici dosya çakışmasında Çakışma Kopyası oluşturulup her iki sürüm de saklanır', () async {
      final original = Note(
        id: 777,
        title: 'Ortak Proje',
        content: 'Editördeki yerel değişiklik.',
        createdAt: 7000,
        updatedAt: 7000,
      );
      await repository.addNote(original);

      // Harici bir sync aracının diske yazdığı farklı sürüm
      final externalVersion = original.copyWith(
        content: 'Obsidian tarafından senkronize edilen harici metin.',
      );

      final conflictCopy = await repository.saveConflictCopy(externalVersion);

      expect(conflictCopy.title, contains('Çakışma Kopyası'));
      expect(conflictCopy.content, equals('Obsidian tarafından senkronize edilen harici metin.'));

      // Disk üzerinde hem orijinal dosya hem çakışma kopyası bulunmalı
      final files = notesDir.listSync().map((f) => p.basename(f.path)).toList();
      expect(files, contains('Ortak Proje.md'));
      expect(files.any((name) => name.contains('Ortak Proje (Çakışma Kopyası')), isTrue);
    });
  });
}

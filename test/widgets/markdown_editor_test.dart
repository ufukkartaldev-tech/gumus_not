import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/widgets/floating_accessory_bar.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/media/services/image_service.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:provider/provider.dart';

class FakeNoteProvider extends NoteProvider {
  FakeNoteProvider()
      : super(
          repository: MockNoteRepository(),
          searchService: AdvancedSearchService(MockNoteRepository()),
        );

  @override
  List<Note> get notes => [];

  @override
  Future<void> loadNotes() async {}

  @override
  Future<void> addNote(Note note) async {}

  @override
  Future<void> updateNote(Note note) async {}

  @override
  Future<void> deleteNote(int noteId) async {}

  @override
  Map<String, int> getTagFrequency() => {};
}

class FakeVaultProvider extends ChangeNotifier implements VaultProvider {
  @override
  bool get isUnlocked => true;

  @override
  bool get isBusy => false;

  @override
  String? get errorMessage => null;

  @override
  void syncState() {}

  @override
  Future<bool> unlockWithPassword(String password) async => true;

  @override
  Future<String> resolveReadableContent(Note note) async => note.content;

  @override
  Future<Note> createPrivateNote({
    required String title,
    required String content,
    List<String> tags = const [],
    int? color,
    String folderName = 'Genel',
  }) async => Note(title: title, content: content, createdAt: 0, updatedAt: 0);

  @override
  Future<Note> updatePrivateNote({
    required Note note,
    required String plainTextContent,
  }) async => note.copyWith(content: plainTextContent);

  @override
  Future<void> lockVault() async {}

  @override
  Future<bool> unlockWithRecoveryKey(String recoveryKey) async => true;

  @override
  Future<void> initializeVault({required String password, String? recoveryKey}) async {}

  @override
  Future<String> resolveReadableBackupEnvelope(String plainText) async => plainText;

  @override
  Future<String> decryptExternalPayload(String encryptedPayload) async => encryptedPayload;
}

Future<void> setupTestWidget(
  WidgetTester tester,
  Widget child, {
  Size physicalSize = const Size(1200, 1600),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;

  final fakeVaultProvider = FakeVaultProvider();
  final noteEditorProvider = NoteEditorProvider(vaultProvider: fakeVaultProvider);
  final fakeNoteProvider = FakeNoteProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NoteProvider>.value(value: fakeNoteProvider),
        ChangeNotifierProvider<VaultProvider>.value(value: fakeVaultProvider),
        ChangeNotifierProvider<NoteEditorProvider>.value(value: noteEditorProvider),
        Provider<ImageService>(create: (_) => ImageService()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: child,
      ),
    ),
  );

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('MarkdownEditor Content-First Tests', () {
    late Note testNote;
    late Note encryptedNote;

    setUp(() {
      testNote = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is test content for the markdown editor',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['test', 'editor'],
      );

      encryptedNote = Note(
        id: 2,
        title: 'Encrypted Note',
        content: '🔒 Bu not şifreli. İçeriği görmek için kasayı açın.',
        createdAt: 1640995270000,
        updatedAt: 1640995280000,
        isEncrypted: true,
        tags: ['secret'],
      );
    });

    testWidgets('MarkdownEditor displays note title and content seamlessly', (WidgetTester tester) async {
      await setupTestWidget(
        tester,
        MarkdownEditor(note: testNote, onSave: (note) {}),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('This is test content for the markdown editor'), findsOneWidget);
    });

    testWidgets('MarkdownEditor shows encrypted note protection correctly', (WidgetTester tester) async {
      await setupTestWidget(
        tester,
        MarkdownEditor(note: encryptedNote, onSave: (note) {}),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Bu Not Şifreli'), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles title editing and saving', (WidgetTester tester) async {
      Note? savedNote;
      await setupTestWidget(
        tester,
        MarkdownEditor(note: testNote, onSave: (note) => savedNote = note),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Updated Title');
      await tester.pump(const Duration(milliseconds: 100));

      final saveButton = find.text('Kaydet');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(savedNote?.title, 'Updated Title');
    });

    testWidgets('MarkdownEditor toggles full preview mode', (WidgetTester tester) async {
      await setupTestWidget(
        tester,
        MarkdownEditor(note: testNote, onSave: (note) {}),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final previewButton = find.byIcon(Icons.remove_red_eye_outlined);
      expect(previewButton, findsOneWidget);
      await tester.tap(previewButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles cancel operation', (WidgetTester tester) async {
      bool onCancelCalled = false;
      await setupTestWidget(
        tester,
        MarkdownEditor(
          note: testNote,
          onSave: (note) {},
          onCancel: () => onCancelCalled = true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(onCancelCalled, isTrue);
    });

    testWidgets('MarkdownEditor renders FloatingAccessoryBar on mobile view', (WidgetTester tester) async {
      // Set to mobile dimensions
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await setupTestWidget(
        tester,
        MarkdownEditor(note: testNote, onSave: (note) {}),
        physicalSize: const Size(400, 800),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FloatingAccessoryBar), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('[[ ]]'), findsOneWidget);
      expect(find.text(r'$fx', skipOffstage: false), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:connected_notebook/features/backup/presentation/backup_screen.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

import '../../notes/providers/note_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNoteRepository mockRepository;
  late MockSearchService mockSearchService;
  late NoteProvider noteProvider;

  setUp(() {
    mockRepository = MockNoteRepository();
    mockSearchService = MockSearchService();
    noteProvider = NoteProvider(
      repository: mockRepository,
      searchService: mockSearchService,
    );

    when(mockRepository.getAllNotes()).thenAnswer((_) async => [
      Note(id: 1, title: 'Not 1', content: 'İçerik 1', createdAt: 1, updatedAt: 1),
      Note(id: 2, title: 'Not 2', content: 'İçerik 2', createdAt: 1, updatedAt: 1),
    ]);
  });

  Widget buildWindowsBackupScreen() {
    return ChangeNotifierProvider<NoteProvider>.value(
      value: noteProvider,
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: const BackupScreen(),
      ),
    );
  }

  testWidgets('BackupScreen on Windows hides Google Drive and displays .enc and .zip options', (tester) async {
    await tester.pumpWidget(buildWindowsBackupScreen());
    await tester.pumpAndSettle();

    // Verify Google Drive is completely absent on Windows
    expect(find.text('Google Drive Yedekleme'), findsNothing);
    expect(find.text("Drive'a Yedekle"), findsNothing);

    // Verify Windows 1.0 Encrypted Backup (.enc) is present and recommended
    expect(find.text('Şifreli Yerel Yedek (.enc)'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.text('Şifreli Yedek Al'), findsOneWidget);
    expect(find.text('Yedekten Yükle'), findsOneWidget);

    // Verify Portable ZIP option is present with clear unencrypted warning
    expect(find.text('Taşınabilir Not Arşivi (.zip)'), findsOneWidget);
    expect(find.text('ZIP Dışa Aktar'), findsOneWidget);
    expect(find.text('ZIP İçe Aktar'), findsOneWidget);
    expect(find.textContaining('DİKKAT: ZIP dosyası şifresiz'), findsOneWidget);
  });

  testWidgets('BackupScreen displays warning confirmation before creating ZIP archive', (tester) async {
    await tester.pumpWidget(buildWindowsBackupScreen());
    await tester.pumpAndSettle();

    // Scroll to and click ZIP Dışa Aktar
    final zipButton = find.text('ZIP Dışa Aktar');
    await tester.ensureVisible(zipButton);
    await tester.tap(zipButton);
    await tester.pumpAndSettle();

    // Verify confirmation modal appears
    expect(find.text('Şifresiz Arşiv Uyarısı'), findsOneWidget);
    expect(find.text('Anladım, ZIP Oluştur'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(find.text('Şifresiz Arşiv Uyarısı'), findsNothing);
  });
}

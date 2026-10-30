import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/security/presentation/lock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempVaultDir;

  setUp(() async {
    tempVaultDir = await Directory.systemTemp.createTemp('gumusnot_lock_screen_test');
  });

  tearDown(() async {
    if (tempVaultDir.existsSync()) {
      await tempVaultDir.delete(recursive: true);
    }
  });

  testWidgets('LockScreen renders locked title and does not allow popping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GümüşNot Kilitli'), findsOneWidget);
    expect(find.byType(PopScope), findsOneWidget);
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('LockScreen consumes CommandPaletteIntent and NewNoteIntent with DoNothingAction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final actionsFinder = find.descendant(
      of: find.byType(LockScreen),
      matching: find.byType(Actions),
    );
    expect(actionsFinder, findsWidgets);

    final actionsWidget = tester.widget<Actions>(actionsFinder.first);
    expect(actionsWidget.actions.containsKey(CommandPaletteIntent), isTrue);
    expect(actionsWidget.actions.containsKey(NewNoteIntent), isTrue);
    expect(actionsWidget.actions[CommandPaletteIntent], isA<DoNothingAction>());
    expect(actionsWidget.actions[NewNoteIntent], isA<DoNothingAction>());
  });
}

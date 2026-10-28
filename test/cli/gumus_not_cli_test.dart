import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import '../../bin/gumus_not.dart' as cli;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gumus_not_cli_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('add command writes a valid YAML-frontmatter .md note using NoteMarkdownCodec', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await cli.runCli(
      ['add', '--tag', 'cli,test', 'Merhaba Dünya #otomatik'],
      notesDirOverride: tempDir,
      out: out,
      err: err,
    );

    expect(exitCode, 0, reason: err.toString());
    final files = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => NoteMarkdownCodec.isNoteFileName(p.basename(f.path)))
        .toList();
    expect(files.length, 1);

    final note = await NoteMarkdownCodec.deserializeFromFileAsync(files.first);
    expect(note.title, 'Merhaba Dünya #otomatik');
    expect(note.content, 'Merhaba Dünya #otomatik');
    expect(note.folderName, 'Terminal');
    expect(note.tags, containsAll(['cli', 'test', 'otomatik']));
  });

  test('save command persists piped input with custom title and resolves filename collisions', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code1 = await cli.runCli(
      ['save', '--title', 'Sunucu Logu', '--tag', 'error', '--folder', 'DevOps'],
      pipedInput: 'Stacktrace line 1\nStacktrace line 2',
      notesDirOverride: tempDir,
      out: out,
      err: err,
    );
    expect(code1, 0);

    final code2 = await cli.runCli(
      ['save', '--title', 'Sunucu Logu', '--tag', 'warn'],
      pipedInput: 'İkinci kayıt',
      notesDirOverride: tempDir,
      out: out,
      err: err,
    );
    expect(code2, 0);

    expect(File(p.join(tempDir.path, 'Sunucu Logu.md')).existsSync(), isTrue);
    expect(File(p.join(tempDir.path, 'Sunucu Logu (2).md')).existsSync(), isTrue);
  });

  test('list, read, and search commands deserialize .md notes accurately', () async {
    await cli.runCli(
      ['add', '--title', 'Mimari Kararlar', '--tag', 'adr', 'Zarf şifreleme kullanıldı.'],
      notesDirOverride: tempDir,
      out: StringBuffer(),
      err: StringBuffer(),
    );

    final listOut = StringBuffer();
    final listCode = await cli.runCli(
      ['list', '--tag', 'adr'],
      notesDirOverride: tempDir,
      out: listOut,
      err: StringBuffer(),
    );
    expect(listCode, 0);
    expect(listOut.toString(), contains('Mimari Kararlar'));
    expect(listOut.toString(), contains('Mimari Kararlar.md'));

    final readOut = StringBuffer();
    final readCode = await cli.runCli(
      ['read', 'Mimari Kararlar'],
      notesDirOverride: tempDir,
      out: readOut,
      err: StringBuffer(),
    );
    expect(readCode, 0);
    expect(readOut.toString(), contains('Zarf şifreleme kullanıldı.'));

    final searchOut = StringBuffer();
    final searchCode = await cli.runCli(
      ['search', 'şifreleme'],
      notesDirOverride: tempDir,
      out: searchOut,
      err: StringBuffer(),
    );
    expect(searchCode, 0);
    expect(searchOut.toString(), contains('Mimari Kararlar'));
  });
}

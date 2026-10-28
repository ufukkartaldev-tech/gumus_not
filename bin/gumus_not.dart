import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

Future<void> main(List<String> arguments) async {
  final exitCodeValue = await runCli(arguments);
  exit(exitCodeValue);
}

/// Executes the GümüşNot CLI and returns a process exit code.
Future<int> runCli(
  List<String> arguments, {
  String? pipedInput,
  Directory? notesDirOverride,
  StringSink? out,
  StringSink? err,
}) async {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;

  final parser = _buildArgParser();
  final ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderrSink.writeln('Hata: ${e.message}');
    _printUsage(parser, stdoutSink);
    return 1;
  }

  if (argResults['help'] == true || argResults.command == null) {
    _printUsage(parser, stdoutSink);
    return argResults['help'] == true ? 0 : 1;
  }

  final dirOption = argResults['dir'] as String?;
  final notesDir = notesDirOverride ?? await resolveNotesDirectory(customPath: dirOption);
  if (!await notesDir.exists()) {
    await notesDir.create(recursive: true);
  }

  final command = argResults.command!;
  try {
    switch (command.name) {
      case 'add':
        return await _handleAddCommand(command, notesDir, stdoutSink, stderrSink);
      case 'save':
        return await _handleSaveCommand(
          command,
          notesDir,
          stdoutSink,
          stderrSink,
          pipedInput: pipedInput,
        );
      case 'list':
        return await _handleListCommand(command, notesDir, stdoutSink);
      case 'read':
        return await _handleReadCommand(command, notesDir, stdoutSink, stderrSink);
      case 'search':
        return await _handleSearchCommand(command, notesDir, stdoutSink, stderrSink);
      default:
        _printUsage(parser, stdoutSink);
        return 1;
    }
  } catch (e) {
    stderrSink.writeln('İşlem başarısız oldu: $e');
    return 1;
  }
}

ArgParser _buildArgParser() {
  final addParser = ArgParser()
    ..addOption('title', abbr: 'T', help: 'Not başlığı (varsayılan: ilk satırdan üretilir)')
    ..addOption('tag', abbr: 't', help: 'Virgülle ayrılmış etiketler (örn: cli,log)')
    ..addOption('folder', abbr: 'f', defaultsTo: 'Terminal', help: 'Klasör adı');

  final saveParser = ArgParser()
    ..addOption('title', abbr: 'T', help: 'Not başlığı (varsayılan: ilk satırdan üretilir)')
    ..addOption('tag', abbr: 't', help: 'Virgülle ayrılmış etiketler (örn: error,log)')
    ..addOption('folder', abbr: 'f', defaultsTo: 'Terminal', help: 'Klasör adı');

  final listParser = ArgParser()
    ..addOption('tag', abbr: 't', help: 'Belirli bir etikete göre filtrele')
    ..addOption('folder', abbr: 'f', help: 'Belirli bir klasöre göre filtrele')
    ..addOption('limit', abbr: 'n', defaultsTo: '20', help: 'Listelenecek maksimum not sayısı');

  final readParser = ArgParser()
    ..addFlag('raw', abbr: 'r', negatable: false, help: 'YAML frontmatter ile birlikte ham .md içeriğini göster');

  final searchParser = ArgParser()
    ..addOption('limit', abbr: 'n', defaultsTo: '20', help: 'Gösterilecek maksimum sonuç sayısı');

  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Kullanım kılavuzunu gösterir')
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Notların bulunduğu özel dizin yolu (varsayılan: <Belgelerim>/GumusNot/notes)',
    )
    ..addCommand('add', addParser)
    ..addCommand('save', saveParser)
    ..addCommand('list', listParser)
    ..addCommand('read', readParser)
    ..addCommand('search', searchParser);
}

/// Resolves `<Documents>/GumusNot/notes` across Windows, macOS, and Linux.
Future<Directory> resolveNotesDirectory({String? customPath}) async {
  final envOverride = Platform.environment['GUMUS_NOT_NOTES_DIR'];
  if (customPath != null && customPath.trim().isNotEmpty) {
    return Directory(p.normalize(customPath.trim()));
  }
  if (envOverride != null && envOverride.trim().isNotEmpty) {
    return Directory(p.normalize(envOverride.trim()));
  }

  final documentsDir = await _resolveSystemDocumentsPath();
  return Directory(p.join(documentsDir, 'GumusNot', 'notes'));
}

Future<String> _resolveSystemDocumentsPath() async {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      final candidate = Directory(p.join(userProfile, 'Documents'));
      if (await candidate.exists()) {
        return candidate.path;
      }
      final trCandidate = Directory(p.join(userProfile, 'Belgeler'));
      if (await trCandidate.exists()) {
        return trCandidate.path;
      }
      return candidate.path;
    }
  }

  final xdgDocs = Platform.environment['XDG_DOCUMENTS_DIR'];
  if (xdgDocs != null && xdgDocs.isNotEmpty) {
    return xdgDocs;
  }

  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty) {
    return p.join(home, 'Documents');
  }

  return Directory.current.path;
}

/// Reads and deserializes all `.md` notes inside [notesDir] using [NoteMarkdownCodec].
Future<List<(File, Note)>> loadAllMarkdownNotes(Directory notesDir) async {
  if (!await notesDir.exists()) return [];

  final results = <(File, Note)>[];
  await for (final entity in notesDir.list(followLinks: false)) {
    if (entity is! File) continue;
    final fileName = p.basename(entity.path);
    if (!NoteMarkdownCodec.isNoteFileName(fileName)) continue;

    try {
      final note = await NoteMarkdownCodec.deserializeFromFileAsync(entity);
      results.add((entity, note));
    } catch (_) {
      // Skip unreadable files without aborting the CLI command.
    }
  }

  results.sort((a, b) => b.$2.updatedAt.compareTo(a.$2.updatedAt));
  return results;
}

/// Saves a [Note] as a YAML-frontmatter `.md` file atomically using [NoteMarkdownCodec].
Future<File> saveMarkdownNote(Directory notesDir, Note note) async {
  if (!await notesDir.exists()) {
    await notesDir.create(recursive: true);
  }

  final existingNotes = await loadAllMarkdownNotes(notesDir);
  final existingIds = existingNotes.map((entry) => entry.$2.id).whereType<int>().toSet();

  var id = note.id ?? DateTime.now().millisecondsSinceEpoch;
  while (existingIds.contains(id)) {
    id++;
  }

  final noteToSave = note.copyWith(id: id);
  final targetFile = await NoteMarkdownCodec.resolveUniqueFileAsync(
    notesDir,
    noteToSave,
  );
  final serialized = NoteMarkdownCodec.serialize(noteToSave);

  await _writeFileAtomically(targetFile, serialized);
  await _tryGitCommit(notesDir, 'CLI note: ${noteToSave.title}');
  return targetFile;
}

Future<void> _writeFileAtomically(File targetFile, String contents) async {
  final parent = targetFile.parent;
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }

  final tmpFile = File(
    '${targetFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await tmpFile.writeAsString(contents, flush: true);
    await tmpFile.rename(targetFile.path);
  } catch (e) {
    if (await tmpFile.exists()) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
    rethrow;
  }
}

Future<void> _tryGitCommit(Directory notesDir, String message) async {
  final gitDir = Directory(p.join(notesDir.path, '.git'));
  if (!await gitDir.exists()) return;

  try {
    await Process.run('git', ['add', '-A'], workingDirectory: notesDir.path);
    await Process.run(
      'git',
      ['commit', '-m', message],
      workingDirectory: notesDir.path,
    );
  } catch (_) {
    // Git is optional in CLI mode.
  }
}

Future<int> _handleAddCommand(
  ArgResults command,
  Directory notesDir,
  StringSink out,
  StringSink err,
) async {
  if (command.rest.isEmpty) {
    err.writeln('Lütfen not içeriğini girin.');
    return 1;
  }

  final content = command.rest.join(' ').trim();
  if (content.isEmpty) {
    err.writeln('Not içeriği boş olamaz.');
    return 1;
  }

  final explicitTitle = (command['title'] as String?)?.trim();
  final title = (explicitTitle != null && explicitTitle.isNotEmpty)
      ? explicitTitle
      : _generateTitle(content);
  final folder = (command['folder'] as String?)?.trim() ?? 'Terminal';
  final tags = _mergeTags(command['tag'] as String?, content);
  final now = DateTime.now().millisecondsSinceEpoch;

  final note = Note(
    title: title,
    content: content,
    createdAt: now,
    updatedAt: now,
    tags: tags,
    folderName: folder.isEmpty ? 'Terminal' : folder,
  );

  final savedFile = await saveMarkdownNote(notesDir, note);
  out.writeln('Not başarıyla kaydedildi: ${savedFile.path}');
  return 0;
}

Future<int> _handleSaveCommand(
  ArgResults command,
  Directory notesDir,
  StringSink out,
  StringSink err, {
  String? pipedInput,
}) async {
  var content = '';
  if (pipedInput != null) {
    content = pipedInput;
    if (command.rest.isNotEmpty) {
      content = '$content\n${command.rest.join(' ')}';
    }
  } else if (stdin.hasTerminal) {
    if (command.rest.isEmpty) {
      err.writeln('Lütfen veriyi pipe ile gönderin veya argüman olarak verin.');
      return 1;
    }
    content = command.rest.join(' ');
  } else {
    content = await stdin.transform(const SystemEncoding().decoder).join();
    if (command.rest.isNotEmpty) {
      content += '\n${command.rest.join(' ')}';
    }
  }

  if (content.trim().isEmpty) {
    err.writeln('Not içeriği boş olamaz.');
    return 1;
  }

  final explicitTitle = (command['title'] as String?)?.trim();
  final title = (explicitTitle != null && explicitTitle.isNotEmpty)
      ? explicitTitle
      : _generateTitle(content);
  final folder = (command['folder'] as String?)?.trim() ?? 'Terminal';
  final tags = _mergeTags(command['tag'] as String?, content);
  final now = DateTime.now().millisecondsSinceEpoch;

  final note = Note(
    title: title,
    content: content.trimRight(),
    createdAt: now,
    updatedAt: now,
    tags: tags,
    folderName: folder.isEmpty ? 'Terminal' : folder,
  );

  final savedFile = await saveMarkdownNote(notesDir, note);
  out.writeln('Not başarıyla kaydedildi: ${savedFile.path}');
  return 0;
}

Future<int> _handleListCommand(
  ArgResults command,
  Directory notesDir,
  StringSink out,
) async {
  final tagFilter = (command['tag'] as String?)?.trim().toLowerCase();
  final folderFilter = (command['folder'] as String?)?.trim().toLowerCase();
  final limit = int.tryParse(command['limit'] as String? ?? '20') ?? 20;

  var entries = await loadAllMarkdownNotes(notesDir);

  if (tagFilter != null && tagFilter.isNotEmpty) {
    entries = entries
        .where((e) => e.$2.tags.any((t) => t.toLowerCase() == tagFilter))
        .toList();
  }
  if (folderFilter != null && folderFilter.isNotEmpty) {
    entries = entries
        .where((e) => e.$2.folderName.toLowerCase() == folderFilter)
        .toList();
  }

  if (entries.isEmpty) {
    out.writeln('Kayıtlı not bulunamadı (${notesDir.path}).');
    return 0;
  }

  final shown = entries.take(limit).toList();
  out.writeln('Toplam ${entries.length} not bulundu (gösterilen: ${shown.length}):');
  for (final (file, note) in shown) {
    final tagLabel = note.tags.isEmpty ? '' : ' [${note.tags.map((t) => '#$t').join(', ')}]';
    final lockIcon = note.isEncrypted ? '🔒 ' : '';
    out.writeln(
      '- [${note.id}] $lockIcon${note.title} (${note.folderName})$tagLabel -> ${p.basename(file.path)}',
    );
  }
  return 0;
}

Future<int> _handleReadCommand(
  ArgResults command,
  Directory notesDir,
  StringSink out,
  StringSink err,
) async {
  if (command.rest.isEmpty) {
    err.writeln('Lütfen okunacak notun ID, başlık veya dosya adını belirtin.');
    return 1;
  }

  final selector = command.rest.join(' ').trim();
  final selectorLower = selector.toLowerCase();
  final entries = await loadAllMarkdownNotes(notesDir);

  (File, Note)? match;
  for (final entry in entries) {
    final (file, note) = entry;
    final fileName = p.basename(file.path).toLowerCase();
    final stem = p.basenameWithoutExtension(file.path).toLowerCase();
    if (note.id?.toString() == selector ||
        note.title.toLowerCase() == selectorLower ||
        fileName == selectorLower ||
        stem == selectorLower) {
      match = entry;
      break;
    }
  }

  if (match == null) {
    err.writeln('Not bulunamadı: "$selector"');
    return 1;
  }

  final (file, note) = match;
  final showRaw = command['raw'] == true;
  if (showRaw) {
    out.writeln(await file.readAsString());
    return 0;
  }

  out.writeln('# ${note.title}');
  out.writeln('ID: ${note.id} | Klasör: ${note.folderName} | Dosya: ${p.basename(file.path)}');
  if (note.tags.isNotEmpty) {
    out.writeln('Etiketler: ${note.tags.map((t) => '#$t').join(' ')}');
  }
  out.writeln('---');
  if (note.isEncrypted) {
    out.writeln('[🔒 Şifreli Not — İçeriği görüntülemek için GümüşNot uygulamasında Kasa kilidini açın]');
  } else {
    out.writeln(note.content);
  }
  return 0;
}

Future<int> _handleSearchCommand(
  ArgResults command,
  Directory notesDir,
  StringSink out,
  StringSink err,
) async {
  if (command.rest.isEmpty) {
    err.writeln('Lütfen aranacak anahtar kelimeyi girin.');
    return 1;
  }

  final query = command.rest.join(' ').trim().toLowerCase();
  final limit = int.tryParse(command['limit'] as String? ?? '20') ?? 20;
  final entries = await loadAllMarkdownNotes(notesDir);

  final matches = entries.where((entry) {
    final note = entry.$2;
    if (note.title.toLowerCase().contains(query)) return true;
    if (note.tags.any((t) => t.toLowerCase().contains(query))) return true;
    if (!note.isEncrypted && note.content.toLowerCase().contains(query)) {
      return true;
    }
    return false;
  }).take(limit).toList();

  if (matches.isEmpty) {
    out.writeln('"$query" için eşleşen not bulunamadı.');
    return 0;
  }

  out.writeln('"${command.rest.join(' ')}" için ${matches.length} sonuç bulundu:');
  for (final (file, note) in matches) {
    out.writeln(
      '- [${note.id}] ${note.title} (${p.basename(file.path)}): ${note.excerpt}',
    );
  }
  return 0;
}

List<String> _mergeTags(String? rawTagOption, String content) {
  final tagSet = <String>{};
  if (rawTagOption != null && rawTagOption.trim().isNotEmpty) {
    for (final part in rawTagOption.split(',')) {
      final clean = part.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase();
      if (clean.isNotEmpty) {
        tagSet.add(clean);
      }
    }
  }
  for (final extracted in MarkdownCleaner.extractHashtags(content)) {
    tagSet.add(extracted.toLowerCase());
  }
  return tagSet.toList();
}

String _generateTitle(String content) {
  final lines = content
      .trim()
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^#+\s*'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return 'Terminal Note';
  final firstLine = lines.first;
  if (firstLine.length > 50) {
    return '${firstLine.substring(0, 47)}...';
  }
  return firstLine;
}

void _printUsage(ArgParser parser, StringSink out) {
  out.writeln('GümüşNot CLI (Markdown / YAML Frontmatter Depolama)');
  out.writeln('Kullanım:');
  out.writeln('  dart run bin/gumus_not.dart add "Notunuz buraya #etiket"');
  out.writeln('  cat error.log | dart run bin/gumus_not.dart save --tag error,prod --title "Sunucu Hatası"');
  out.writeln('  dart run bin/gumus_not.dart list --tag error');
  out.writeln('  dart run bin/gumus_not.dart read "Sunucu Hatası"');
  out.writeln('  dart run bin/gumus_not.dart search "anahtar kelime"');
  out.writeln('\nGenel Seçenekler:');
  out.writeln(parser.usage);
  out.writeln('\nKomutlar:');
  out.writeln('  add     Doğrudan terminalden yeni bir Markdown (.md) notu ekler');
  out.writeln('  save    Pipe (boru) ile gelen veriyi veya argümanları .md notu olarak kaydeder');
  out.writeln('  list    <Belgelerim>/GumusNot/notes dizinindeki .md notlarını listeler');
  out.writeln('  read    Başlık, ID veya dosya adına göre bir .md notunu okur');
  out.writeln('  search  Not başlıkları, etiketleri ve içeriklerinde arama yapar');
}

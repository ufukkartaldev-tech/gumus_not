import 'dart:io';
import 'package:args/args.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) async {
  // Setup FFI for Desktop/CLI
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final parser = ArgParser()
    ..addCommand('add')
    ..addCommand('save', ArgParser()..addOption('tag', abbr: 't', help: 'Tag for the note'));

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    _printUsage(parser);
    exit(1);
  }

  if (argResults.command == null) {
    _printUsage(parser);
    exit(1);
  }

  final command = argResults.command!;
  String content = '';
  String title = 'Terminal Note';
  String tags = '';

  if (command.name == 'add') {
    if (command.rest.isEmpty) {
      print('Lütfen not içeriğini girin.');
      exit(1);
    }
    content = command.rest.join(' ');
    title = _generateTitle(content);
  } else if (command.name == 'save') {
    // Read from stdin if piped
    if (stdin.hasTerminal) {
      if (command.rest.isEmpty) {
        print('Lütfen veriyi pipe ile gönderin veya argüman olarak verin.');
        exit(1);
      }
      content = command.rest.join(' ');
    } else {
      // Piped input
      content = await stdin.transform(const SystemEncoding().decoder).join();
      if (command.rest.isNotEmpty) {
        content += '\n' + command.rest.join(' ');
      }
    }
    
    title = _generateTitle(content);
    if (command.options.contains('tag')) {
      tags = command['tag'] ?? '';
    }
  }

  if (content.trim().isEmpty) {
    print('Not içeriği boş olamaz.');
    exit(1);
  }

  try {
    // Find the correct database path
    // In Flutter, sqflite_common_ffi defaults to Documents folder or similar, but we can resolve it
    String databasesPath = await databaseFactory.getDatabasesPath();
    String dbPath = p.join(databasesPath, 'connected_notebook.db');
    
    // Connect to DB directly and create tables if they don't exist
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              is_encrypted INTEGER DEFAULT 0,
              tags TEXT,
              color INTEGER,
              folder_name TEXT DEFAULT 'Genel'
            )
          ''');
          // Since it's just CLI fallback, we just create the notes table minimally.
        },
      ),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('notes', {
      'title': title,
      'content': content,
      'created_at': now,
      'updated_at': now,
      'is_encrypted': 0,
      'tags': tags,
      'folder_name': 'Terminal',
    });
    print('Not başarıyla kaydedildi!');
    exit(0);
  } catch (e) {
    print('Not kaydedilemedi: $e');
    exit(1);
  }
}

String _generateTitle(String content) {
  final lines = content.trim().split('\n');
  if (lines.isEmpty) return 'Terminal Note';
  final firstLine = lines.first;
  if (firstLine.length > 30) {
    return '${firstLine.substring(0, 27)}...';
  }
  return firstLine;
}

void _printUsage(ArgParser parser) {
  print('GümüşNot CLI');
  print('Kullanım:');
  print('  dart run bin/gumus_not.dart add "Notunuz buraya"');
  print('  cat error.log | dart run bin/gumus_not.dart save --tag error');
  print('\nKomutlar:');
  print('  add   Doğrudan terminalden yeni bir not ekler');
  print('  save  Pipe (boru) ile gelen veriyi veya argümanları not olarak kaydeder');
}

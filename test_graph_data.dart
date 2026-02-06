import 'lib/models/note_model.dart';

// Test için örnek not verileri - Graf yapısı oluşturmak için
List<Note> createTestNotes() {
  final now = DateTime.now().millisecondsSinceEpoch;
  
  return [
    // Ana notlar
    Note(
      id: 1,
      title: 'Flutter Proje Başlangıcı',
      content: 'Flutter projesine başlama adımları:\n1. Flutter kurulumu\n2. VS Code kurulumu\n3. Emülatör ayarları\n\nİlgili notlar: [[Geliştirme Ortamı Kurulumu]], [[Flutter Widgetları]]',
      createdAt: now - 86400000 * 7, // 7 gün önce
      updatedAt: now - 86400000 * 6,
      tags: ['flutter', 'başlangıç', 'mobil'],
      folderName: 'Flutter',
    ),
    
    Note(
      id: 2,
      title: 'Geliştirme Ortamı Kurulumu',
      content: 'Geliştirme ortamı için gerekli araçlar:\n- Flutter SDK\n- Android Studio\n- VS Code\n- Git\n\nAyrıca bakınız: [[Flutter Proje Başlangıcı]], [[VS Code Eklentileri]]',
      createdAt: now - 86400000 * 6,
      updatedAt: now - 86400000 * 5,
      tags: ['kurulum', 'geliştirme', 'flutter'],
      folderName: 'Flutter',
    ),
    
    Note(
      id: 3,
      title: 'Flutter Widgetları',
      content: 'Temel Flutter widgetları:\n- Container\n- Row/Column\n- Stack\n- ListView\n- GridView\n\nDetaylı bilgi: [[Stateless vs Stateful]], [[Custom Widget Oluşturma]]',
      createdAt: now - 86400000 * 5,
      updatedAt: now - 86400000 * 4,
      tags: ['flutter', 'widget', 'ui'],
      folderName: 'Flutter',
    ),
    
    Note(
      id: 4,
      title: 'Stateless vs Stateful',
      content: 'Widget türleri karşılaştırması:\n\nStateless Widget:\n- Statik içerik\n- Değişmez UI\n- Performanslı\n\nStateful Widget:\n- Dinamik içerik\n- setState() kullanımı\n- State management\n\nİlgili: [[Flutter Widgetları]], [[State Management]]',
      createdAt: now - 86400000 * 4,
      updatedAt: now - 86400000 * 3,
      tags: ['flutter', 'widget', 'state'],
      folderName: 'Flutter',
    ),
    
    Note(
      id: 5,
      title: 'State Management',
      content: 'Flutter state management yöntemleri:\n1. Provider\n2. Bloc/Cubit\n3. Riverpod\n4. GetX\n\nÖneriler: [[Provider Kullanımı]], [[Bloc Pattern]]',
      createdAt: now - 86400000 * 3,
      updatedAt: now - 86400000 * 2,
      tags: ['flutter', 'state', 'provider'],
      folderName: 'Flutter',
    ),
    
    Note(
      id: 6,
      title: 'Provider Kullanımı',
      content: 'Provider paketi kullanımı:\n- ChangeNotifier\n- Consumer\n- Selector\n- MultiProvider\n\nReferans: [[State Management]], [[Flutter Proje Başlangıcı]]',
      createdAt: now - 86400000 * 2,
      updatedAt: now - 86400000 * 1,
      tags: ['flutter', 'provider', 'state'],
      folderName: 'Flutter',
    ),
    
    // Veritabanı notları
    Note(
      id: 7,
      title: 'SQLite ve Flutter',
      content: 'Flutter\'da SQLite kullanımı:\n- sqflite paketi\n- Database helper\n- CRUD işlemleri\n\nAyrıca: [[Veritabanı Tasarımı]], [[Model Oluşturma]]',
      createdAt: now - 86400000 * 8,
      updatedAt: now - 86400000 * 7,
      tags: ['database', 'sqlite', 'flutter'],
      folderName: 'Veritabanı',
    ),
    
    Note(
      id: 8,
      title: 'Veritabanı Tasarımı',
      content: 'Veritabanı tasarım prensipleri:\n- Normalizasyon\n- İlişkiler\n- Indexleme\n\nİlişkili notlar: [[SQLite ve Flutter]], [[Model Oluşturma]]',
      createdAt: now - 86400000 * 7,
      updatedAt: now - 86400000 * 6,
      tags: ['database', 'tasarım', 'sqlite'],
      folderName: 'Veritabanı',
    ),
    
    Note(
      id: 9,
      title: 'Model Oluşturma',
      content: 'Dart model sınıfları:\n- fromMap/toMap\n- copyWith\n- JSON serialization\n\nBağlantılar: [[Veritabanı Tasarımı]], [[SQLite ve Flutter]]',
      createdAt: now - 86400000 * 6,
      updatedAt: now - 86400000 * 5,
      tags: ['dart', 'model', 'database'],
      folderName: 'Veritabanı',
    ),
    
    // UI/UX notları
    Note(
      id: 10,
      title: 'Material Design',
      content: 'Material Design prensipleri:\n- Theme\n- Color palette\n- Typography\n- Components\n\nİlgili: [[Flutter Widgetları]], [[Custom Widget Oluşturma]]',
      createdAt: now - 86400000 * 5,
      updatedAt: now - 86400000 * 4,
      tags: ['ui', 'design', 'material'],
      folderName: 'UI/UX',
    ),
    
    Note(
      id: 11,
      title: 'Custom Widget Oluşturma',
      content: 'Özel widget geliştirme:\n- CustomPainter\n- StatefulWidget\n- Animation\n\nReferanslar: [[Flutter Widgetları]], [[Material Design]], [[Stateless vs Stateful]]',
      createdAt: now - 86400000 * 4,
      updatedAt: now - 86400000 * 3,
      tags: ['flutter', 'widget', 'custom'],
      folderName: 'UI/UX',
    ),
    
    Note(
      id: 12,
      title: 'VS Code Eklentileri',
      content: 'Flutter geliştirme için VS Code eklentileri:\n- Flutter\n- Dart\n- Flutter Snippets\n- Bracket Pair Colorizer\n\nAyrıca bakınız: [[Geliştirme Ortamı Kurulumu]]',
      createdAt: now - 86400000 * 3,
      updatedAt: now - 86400000 * 2,
      tags: ['vscode', 'eklenti', 'geliştirme'],
      folderName: 'Araçlar',
    ),
    
    Note(
      id: 13,
      title: 'Bloc Pattern',
      content: 'Bloc pattern implementasyonu:\n- Bloc/Cubit\n- Events ve States\n- BlocProvider\n- BlocBuilder\n\nİlgili: [[State Management]], [[Provider Kullanımı]]',
      createdAt: now - 86400000 * 2,
      updatedAt: now - 86400000 * 1,
      tags: ['flutter', 'bloc', 'state'],
      folderName: 'Flutter',
    ),
  ];
}

// Test için backlink verileri
List<Backlink> createTestBacklinks() {
  final now = DateTime.now().millisecondsSinceEpoch;
  
  return [
    // Flutter Proje Başlangıcı bağlantıları
    Backlink(sourceNoteId: 1, targetNoteId: 2, linkText: 'Geliştirme Ortamı Kurulumu', createdAt: now - 86400000 * 6),
    Backlink(sourceNoteId: 1, targetNoteId: 3, linkText: 'Flutter Widgetları', createdAt: now - 86400000 * 6),
    
    // Geliştirme Ortamı Kurulumu bağlantıları
    Backlink(sourceNoteId: 2, targetNoteId: 1, linkText: 'Flutter Proje Başlangıcı', createdAt: now - 86400000 * 5),
    Backlink(sourceNoteId: 2, targetNoteId: 12, linkText: 'VS Code Eklentileri', createdAt: now - 86400000 * 5),
    
    // Flutter Widgetları bağlantıları
    Backlink(sourceNoteId: 3, targetNoteId: 1, linkText: 'Flutter Proje Başlangıcı', createdAt: now - 86400000 * 4),
    Backlink(sourceNoteId: 3, targetNoteId: 4, linkText: 'Stateless vs Stateful', createdAt: now - 86400000 * 4),
    Backlink(sourceNoteId: 3, targetNoteId: 11, linkText: 'Custom Widget Oluşturma', createdAt: now - 86400000 * 4),
    
    // Stateless vs Stateful bağlantıları
    Backlink(sourceNoteId: 4, targetNoteId: 3, linkText: 'Flutter Widgetları', createdAt: now - 86400000 * 3),
    Backlink(sourceNoteId: 4, targetNoteId: 5, linkText: 'State Management', createdAt: now - 86400000 * 3),
    Backlink(sourceNoteId: 4, targetNoteId: 11, linkText: 'Custom Widget Oluşturma', createdAt: now - 86400000 * 3),
    
    // State Management bağlantıları
    Backlink(sourceNoteId: 5, targetNoteId: 6, linkText: 'Provider Kullanımı', createdAt: now - 86400000 * 2),
    Backlink(sourceNoteId: 5, targetNoteId: 13, linkText: 'Bloc Pattern', createdAt: now - 86400000 * 2),
    
    // Provider Kullanımı bağlantıları
    Backlink(sourceNoteId: 6, targetNoteId: 5, linkText: 'State Management', createdAt: now - 86400000 * 1),
    Backlink(sourceNoteId: 6, targetNoteId: 1, linkText: 'Flutter Proje Başlangıcı', createdAt: now - 86400000 * 1),
    
    // SQLite ve Flutter bağlantıları
    Backlink(sourceNoteId: 7, targetNoteId: 8, linkText: 'Veritabanı Tasarımı', createdAt: now - 86400000 * 7),
    Backlink(sourceNoteId: 7, targetNoteId: 9, linkText: 'Model Oluşturma', createdAt: now - 86400000 * 7),
    
    // Veritabanı Tasarımı bağlantıları
    Backlink(sourceNoteId: 8, targetNoteId: 7, linkText: 'SQLite ve Flutter', createdAt: now - 86400000 * 6),
    Backlink(sourceNoteId: 8, targetNoteId: 9, linkText: 'Model Oluşturma', createdAt: now - 86400000 * 6),
    
    // Model Oluşturma bağlantıları
    Backlink(sourceNoteId: 9, targetNoteId: 8, linkText: 'Veritabanı Tasarımı', createdAt: now - 86400000 * 5),
    Backlink(sourceNoteId: 9, targetNoteId: 7, linkText: 'SQLite ve Flutter', createdAt: now - 86400000 * 5),
    
    // Material Design bağlantıları
    Backlink(sourceNoteId: 10, targetNoteId: 3, linkText: 'Flutter Widgetları', createdAt: now - 86400000 * 4),
    Backlink(sourceNoteId: 10, targetNoteId: 11, linkText: 'Custom Widget Oluşturma', createdAt: now - 86400000 * 4),
    
    // Custom Widget Oluşturma bağlantıları
    Backlink(sourceNoteId: 11, targetNoteId: 3, linkText: 'Flutter Widgetları', createdAt: now - 86400000 * 3),
    Backlink(sourceNoteId: 11, targetNoteId: 10, linkText: 'Material Design', createdAt: now - 86400000 * 3),
    Backlink(sourceNoteId: 11, targetNoteId: 4, linkText: 'Stateless vs Stateful', createdAt: now - 86400000 * 3),
    
    // VS Code Eklentileri bağlantıları
    Backlink(sourceNoteId: 12, targetNoteId: 2, linkText: 'Geliştirme Ortamı Kurulumu', createdAt: now - 86400000 * 2),
    
    // Bloc Pattern bağlantıları
    Backlink(sourceNoteId: 13, targetNoteId: 5, linkText: 'State Management', createdAt: now - 86400000 * 1),
    Backlink(sourceNoteId: 13, targetNoteId: 6, linkText: 'Provider Kullanımı', createdAt: now - 86400000 * 1),
  ];
}

// Graf yapısı analizi için yardımcı fonksiyon
Map<String, dynamic> analyzeGraphStructure(List<Note> notes, List<Backlink> backlinks) {
  final Map<String, dynamic> analysis = {};
  
  // Not sayısı
  analysis['total_notes'] = notes.length;
  
  // Bağlantı sayısı
  analysis['total_backlinks'] = backlinks.length;
  
  // Klasör dağılımı
  final folderDistribution = <String, int>{};
  for (final note in notes) {
    folderDistribution[note.folderName] = (folderDistribution[note.folderName] ?? 0) + 1;
  }
  analysis['folder_distribution'] = folderDistribution;
  
  // Etiket dağılımı
  final tagDistribution = <String, int>{};
  for (final note in notes) {
    for (final tag in note.tags) {
      tagDistribution[tag] = (tagDistribution[tag] ?? 0) + 1;
    }
  }
  analysis['tag_distribution'] = tagDistribution;
  
  // En çok bağlantı alan notlar (incoming links)
  final incomingLinks = <int, int>{};
  for (final backlink in backlinks) {
    incomingLinks[backlink.targetNoteId] = (incomingLinks[backlink.targetNoteId] ?? 0) + 1;
  }
  
  final topIncomingNotes = incomingLinks.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  analysis['most_referenced_notes'] = topIncomingNotes.take(5).map((entry) {
    final note = notes.firstWhere((n) => n.id == entry.key);
    return {
      'note_id': note.id,
      'title': note.title,
      'incoming_links': entry.value,
    };
  }).toList();
  
  // En çok bağlantı yapan notlar (outgoing links)
  final outgoingLinks = <int, int>{};
  for (final backlink in backlinks) {
    outgoingLinks[backlink.sourceNoteId] = (outgoingLinks[backlink.sourceNoteId] ?? 0) + 1;
  }
  
  final topOutgoingNotes = outgoingLinks.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  analysis['most_connecting_notes'] = topOutgoingNotes.take(5).map((entry) {
    final note = notes.firstWhere((n) => n.id == entry.key);
    return {
      'note_id': note.id,
      'title': note.title,
      'outgoing_links': entry.value,
    };
  }).toList();
  
  return analysis;
}

void main() {
  final notes = createTestNotes();
  final backlinks = createTestBacklinks();
  final analysis = analyzeGraphStructure(notes, backlinks);
  
  print('=== TEST GRAF YAPISI ANALİZİ ===');
  print('Toplam Not: ${analysis['total_notes']}');
  print('Toplam Bağlantı: ${analysis['total_backlinks']}');
  print('');
  
  print('Klasör Dağılımı:');
  final folderDist = analysis['folder_distribution'] as Map<String, int>;
  folderDist.forEach((folder, count) {
    print('  $folder: $count not');
  });
  print('');
  
  print('Etiket Dağılımı:');
  final tagDist = analysis['tag_distribution'] as Map<String, int>;
  tagDist.forEach((tag, count) {
    print('  $tag: $count not');
  });
  print('');
  
  print('En Çok Referans Verilen Notlar:');
  final mostReferenced = analysis['most_referenced_notes'] as List;
  for (final item in mostReferenced) {
    print('  ${item['title']}: ${item['incoming_links']} gelen bağlantı');
  }
  print('');
  
  print('En Çok Bağlantı Yapan Notlar:');
  final mostConnecting = analysis['most_connecting_notes'] as List;
  for (final item in mostConnecting) {
    print('  ${item['title']}: ${item['outgoing_links']} giden bağlantı');
  }
}

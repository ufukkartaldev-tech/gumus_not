class Template {
  final int? id;
  final String name;
  final String content;
  final String category;
  final String description;
  final String? icon;
  final int createdAt;

  Template({
    this.id,
    required this.name,
    required this.content,
    required this.category,
    this.description = '',
    this.icon,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'category': category,
      'description': description,
      'icon': icon,
      'created_at': createdAt,
    };
  }

  factory Template.fromMap(Map<String, dynamic> map) {
    return Template(
      id: map['id'],
      name: map['name'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'],
      createdAt: map['created_at'] ?? 0,
    );
  }

  Template copyWith({
    int? id,
    String? name,
    String? content,
    String? category,
    String? description,
    String? icon,
    int? createdAt,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Template(id: $id, name: $name, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template && other.id == id!;
  }

  @override
  int get hashCode => id!.hashCode;
}

class Note {
  final int? id;
  String title;
  String content;
  int createdAt;
  int updatedAt;
  bool isEncrypted;
  List<String> tags;
  int? color; // New field for storing color value (0xFF... int)
  String folderName; // Folder/category name for organization

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isEncrypted = false,
    this.tags = const [],
    this.color,
    this.folderName = 'Genel', // Default folder
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_encrypted': isEncrypted ? 1 : 0,
      'tags': tags.join(','),
      'color': color,
      'folder_name': folderName,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['created_at'] ?? 0,
      updatedAt: map['updated_at'] ?? 0,
      isEncrypted: (map['is_encrypted'] ?? 0) == 1,
      tags: (map['tags'] as String? ?? '').split(',').where((tag) => tag.isNotEmpty).toList(),
      color: map['color'],
      folderName: map['folder_name'] ?? 'Genel',
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? createdAt,
    int? updatedAt,
    bool? isEncrypted,
    List<String>? tags,
    int? color,
    String? folderName,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      folderName: folderName ?? this.folderName,
    );
  }

  List<String> extractLinks() {
    final RegExp linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkRegex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  String get excerpt {
    final cleanContent = content.replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), '');
    final words = cleanContent.split(' ');
    if (words.length <= 20) {
      return cleanContent;
    }
    return '${words.take(20).join(' ')}...';
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, createdAt: $DateTime.fromMillisecondsSinceEpoch(createdAt))';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class Backlink {
  final int? id;
  final int sourceNoteId;
  final int targetNoteId;
  final String linkText;
  final int createdAt;

  Backlink({
    this.id,
    required this.sourceNoteId,
    required this.targetNoteId,
    required this.linkText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_note_id': sourceNoteId,
      'target_note_id': targetNoteId,
      'link_text': linkText,
      'created_at': createdAt,
    };
  }

  factory Backlink.fromMap(Map<String, dynamic> map) {
    return Backlink(
      id: map['id'],
      sourceNoteId: map['source_note_id'],
      targetNoteId: map['target_note_id'],
      linkText: map['link_text'] ?? '',
      createdAt: map['created_at'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'Backlink(id: $id, sourceNoteId: $sourceNoteId, targetNoteId: $targetNoteId, linkText: $linkText)';
  }
}

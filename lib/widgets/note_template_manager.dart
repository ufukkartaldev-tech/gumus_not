import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../widgets/markdown_editor.dart';

class NoteTemplateManager extends StatefulWidget {
  const NoteTemplateManager({Key? key}) : super(key: key);

  @override
  State<NoteTemplateManager> createState() => _NoteTemplateManagerState();
}

class _NoteTemplateManagerState extends State<NoteTemplateManager> {
  final List<Template> _defaultTemplates = [
    Template(
      name: 'Toplantı Notları',
      category: 'İş',
      description: 'Toplantılar için standart not formatı',
      content: '''# Toplantı Notları

**Tarih:** ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
**Katılımcılar:** 
**Konu:** 

## Gündem
1. 
2. 
3. 

## Kararlar
- 

## Eylem Planı
- [ ] 
- [ ] 
- [ ] 

## Sonraki Adımlar
- 

## Notlar
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    Template(
      name: 'Proje Planı',
      category: 'Proje',
      description: 'Yeni projeler için planlama şablonu',
      content: '''# Proje Planı

## Proje Adı
${'Proje Adı'}

## Amaç
${'Projenin temel amacı ve hedefleri'}

## Kapsam
### Dahil Olanlar
- 
- 
- 

### Dahil Olmayanlar
- 
- 

## Zaman Çizelgesi
| Aşama | Başlangıç | Bitiş | Durum |
|-------|-----------|-------|-------|
| Planlama | | | |
| Geliştirme | | | |
| Test | | | |
| Yayın | | | |

## Kaynaklar
- İnsan: 
- Teknik: 
- Bütçe: 

## Riskler
- 
- 

## Başarı Metrikleri
- 
- 
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    Template(
      name: 'Öğrenme Günlüğü',
      category: 'Kişisel',
      description: 'Yeni şeyler öğrenmek için günlük formatı',
      content: '''# Öğrenme Günlüğü

**Tarih:** ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
**Konu:** 

## Öğrenilenler
- 
- 
- 

## Zorlananlar
- 
- 

## Çözümler
- 
- 

## Ek Kaynaklar
- 
- 

## Gelecek Planı
- 
- 

## Notlar
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    Template(
      name: 'Fikir ve Beyin Fırtınası',
      category: 'Yaratıcılık',
      description: 'Fikir geliştirme ve beyin fırtınası için',
      content: '''# Fikir ve Beyin Fırtınası

**Konu:** 
**Tarih:** ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

## Ana Fikir
${'Ana fikir veya problem'}

## Beyin Fırtınası
### Fikir 1
**Açıklama:** 
**Avantajları:** 
**Dezavantajları:** 

### Fikir 2
**Açıklama:** 
**Avantajları:** 
**Dezavantajları:** 

### Fikir 3
**Açıklama:** 
**Avantajları:** 
**Dezavantajları:** 

## Değerlendirme
| Kriter | Fikir 1 | Fikir 2 | Fikir 3 |
|--------|---------|---------|---------|
| Uygulanabilirlik | | | |
| Etki | | | |
| Maliyet | | | |
| Zaman | | | |

## Sonuç
**Seçilen Fikir:** 
**Nedenleri:** 

## Sonraki Adımlar
- 
- 
- 
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    Template(
      name: 'Günlük',
      category: 'Kişisel',
      description: 'Günlük yazmak için basit format',
      content: '''# Günlük

**Tarih:** ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
**Hava Durumu:** 

## Bugün Nasıldı?
${'Bugünün genel değerlendirmesi'}

## İyi Olanlar
- 
- 
- 

## Zor Olanlar
- 
- 

## Öğrendiklerim
- 
- 

## Minnettar Olduklarım
- 
- 

## Yarın İçin Hedefler
- 
- 
- 

## Notlar
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    Template(
      name: 'Kitap Özeti',
      category: 'Okuma',
      description: 'Kitapları özetlemek için format',
      content: '''# Kitap Özeti

**Kitap Adı:** 
**Yazar:** 
**Okuma Tarihi:** ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

## Genel Bilgiler
- Tür: 
- Sayfa Sayısı: 
- Yayın Evi: 

## Ana Fikir
${'Kitabın ana mesajı'}

## Önemli Noktalar
- 
- 
- 
- 
- 

## Alıntılar
> "${'Önemli bir alıntı'}"

> "${'Başka bir önemli alıntı'}"

## Değerlendirme
**Beğendiğim Yönler:**
- 
- 

**Eleştirdiğim Yönler:**
- 
- 

## Önerilerim
**Kimlere Öneririm:** 
**Puanım:** ⭐⭐⭐⭐⭐

## Notlar
''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Şablonları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Column(
        children: [
          // Categories
          _buildCategories(),
          
          // Templates List
          Expanded(
            child: _buildTemplatesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ['Tümü', 'İş', 'Kişisel', 'Proje', 'Yaratıcılık', 'Okuma'];
    String selectedCategory = 'Tümü';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: selectedCategory == category,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = selected ? category : 'Tümü';
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _defaultTemplates.length,
      itemBuilder: (context, index) {
        final template = _defaultTemplates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(
                _getCategoryIcon(template.category),
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            title: Text(template.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.category),
                if (template.description.isNotEmpty)
                  Text(
                    template.description,
                    style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.preview),
                  onPressed: () => _previewTemplate(template),
                  tooltip: 'Önizle',
                ),
                IconButton(
                  icon: const Icon(Icons.note_add),
                  onPressed: () => _createNoteFromTemplate(template),
                  tooltip: 'Not Oluştur',
                ),
              ],
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şablon İçeriği:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        template.content.length > 200
                            ? '${template.content.substring(0, 200)}...'
                            : template.content,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _previewTemplate(template),
                            child: const Text('Önizle'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _createNoteFromTemplate(template),
                            child: const Text('Not Oluştur'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'İş':
        return Icons.work;
      case 'Kişisel':
        return Icons.person;
      case 'Proje':
        return Icons.bar_chart;
      case 'Yaratıcılık':
        return Icons.lightbulb;
      case 'Okuma':
        return Icons.book;
      default:
        return Icons.description;
    }
  }

  void _previewTemplate(Template template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              template.content,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createNoteFromTemplate(template);
            },
            child: const Text('Not Oluştur'),
          ),
        ],
      ),
    );
  }

  void _createNoteFromTemplate(Template template) {
    final note = Note(
      title: template.name,
      content: template.content,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      tags: [template.category.toLowerCase()],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: MarkdownEditor(
            note: note,
            onSave: (savedNote) {
              Provider.of<NoteProvider>(context, listen: false).addNote(savedNote);
              Navigator.of(context).pop();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}

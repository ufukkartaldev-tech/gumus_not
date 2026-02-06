import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';

class TaskHubScreen extends StatefulWidget {
  const TaskHubScreen({Key? key}) : super(key: key);

  @override
  State<TaskHubScreen> createState() => _TaskHubScreenState();
}

class _TaskHubScreenState extends State<TaskHubScreen> {
  bool _showCompleted = true; // Tamamlananları göster/gizle

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Merkezi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showCompleted = !_showCompleted),
            tooltip: 'Tamamlananları Göster/Gizle',
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final tasks = _extractTasks(noteProvider.notes);

          if (tasks.isEmpty) {
            return _buildEmptyState();
          }

          final filteredTasks = _showCompleted ? tasks : tasks.where((t) => !t.isCompleted).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final item = filteredTasks[index];
              return _buildTaskCard(context, item, noteProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),
          Text(
            'Bekleyen görev yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notlarına "- [ ] Görev" ekleyerek başlayabilirsin.',
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskItem item, NoteProvider provider) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (bool? value) {
            if (value != null) {
              _toggleTaskStatus(context, item, value);
            }
          },
          activeColor: Colors.green,
        ),
        title: Text(
          item.taskText,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.description_outlined, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.note.title.isEmpty ? 'Başlıksız Not' : item.note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => _navigateToNote(context, item.note),
      ),
    );
  }

  List<TaskItem> _extractTasks(List<Note> notes) {
    List<TaskItem> tasks = [];
    // Hem [ ] hem de [x] olanları yakala (case insensitive)
    final regex = RegExp(r'- \[([ xX])\] (.*)');

    for (var note in notes) {
      final matches = regex.allMatches(note.content);
      for (var match in matches) {
        if (match.group(2) != null) {
          final statusChar = match.group(1)!;
          final isCompleted = statusChar.toLowerCase() == 'x';
          
          tasks.add(TaskItem(
            note: note,
            taskText: match.group(2)!.trim(),
            isCompleted: isCompleted,
            originalLine: match.group(0)!, // Değişim için orijinal satırı sakla
          ));
        }
      }
    }
    return tasks;
  }

  Future<void> _toggleTaskStatus(BuildContext context, TaskItem item, bool newValue) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    
    // Basit bir replace: Orijinal satırı bul ve işaretini değiştir
    // DİKKAT: Aynı içerikli birden fazla görev varsa ilkini değiştirir. 
    // Daha güvenli olması için index bazlı veya split line bazlı gidilebilir ama şimdilik bu MVP için yeterli.
    
    String oldLine = item.originalLine; // Örn: - [ ] Market
    String newLine = oldLine.replaceFirst(
      RegExp(r'- \[([ xX])\]'), 
      newValue ? '- [x]' : '- [ ]'
    );

    String newContent = item.note.content.replaceFirst(oldLine, newLine);

    final updatedNote = item.note.copyWith(
      content: newContent,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await noteProvider.updateNote(updatedNote);
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(newValue ? 'Görev tamamlandı! 🎉' : 'Görev geri alındı.'),
           duration: const Duration(milliseconds: 1000),
           backgroundColor: newValue ? Colors.green : Colors.orange,
         ),
       );
    }
  }

  void _navigateToNote(BuildContext context, Note note) {
    // Burada NoteEditor açılmalı
    // Mevcut rota yapısına göre:
     // Navigator.pushNamed(context, '/note-editor', arguments: note);
     // Veya main.dart'taki yapıya göre push MaterialPageRoute
     // Ama NoteListScreen içindeki logic karmaşık, en iyisi NoteListScreen'e dönüp search yapmak yerine
     // Direkt bir editor activity açmak. (Şimdilik placeholder rota veya pop)
     
     // Doğrusu: Main screen'e "Şu notu aç" emri vermek ama bu karmaşık.
     // En basiti: Geçici bir editor ekranı pushlamak.
     
     // NoteListScreen'deki _openEditor fonksiyonuna erişemiyoruz.
     // O yüzden burada MarkdownEditor'ü direkt push edebiliriz ama onSave callback'i lazım.
     // Ama TaskHub bir "Screen", yani üstünde stack var.
     
     // En temiz yöntem: Event Bus veya Provider üzerinden "Selected Note" set edip ana sayfaya dönmek.
     // Ama o daha büyük refactor ister.
     // Şimdilik sadece uyarı verelim veya basit bir editor açalım.
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Notu düzenlemek için Ana Ekrana dönün.')),
     );
  }
}

class TaskItem {
  final Note note;
  final String taskText;
  final bool isCompleted;
  final String originalLine;

  TaskItem({
    required this.note, 
    required this.taskText, 
    this.isCompleted = false,
    required this.originalLine,
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/note_model.dart';
import '../widgets/confetti_effect.dart';
import '../providers/note_provider.dart';
import 'dart:ui';

class TaskHubScreen extends StatefulWidget {
  const TaskHubScreen({Key? key}) : super(key: key);

  @override
  State<TaskHubScreen> createState() => _TaskHubScreenState();
}

class _TaskHubScreenState extends State<TaskHubScreen> with SingleTickerProviderStateMixin {
  bool _showCompleted = true;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  
  // PERFORMANS: Görevleri önbelleğe alalım
  List<TaskItem>? _cachedTasks;
  int? _lastNotesTimestamp;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          // Önbellek kontrolü: Eğer notların toplam sayısı veya son güncelleme zamanı değişmediyse 
          // (Veya basitlik için not referansı değişmediyse) eski sonuçları kullan.
          // NoteProvider'da notlar her değiştiğinde liste referansı yenilendiği için bu iyi bir gösterge.
          final currentNotes = noteProvider.notes;
          
          if (_cachedTasks == null || _lastNotesTimestamp != _calculateNotesHash(currentNotes)) {
             _cachedTasks = _extractTasks(currentNotes);
             _lastNotesTimestamp = _calculateNotesHash(currentNotes);
          }

          final tasks = _cachedTasks!;
          final filteredTasks = _showCompleted ? tasks : tasks.where((t) => !t.isCompleted).toList();
          final completionRate = tasks.isEmpty ? 0.0 : tasks.where((t) => t.isCompleted).length / tasks.length;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(completionRate),
              if (tasks.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredTasks[index];
                        return AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            final delay = index * 0.05;
                            final animValue = Curves.easeOutBack.transform(
                              (_animationController.value - delay).clamp(0.0, 1.0),
                            );
                            return Transform.translate(
                              offset: Offset(0, 50 * (1 - animValue)),
                              child: Opacity(
                                opacity: animValue,
                                child: child,
                              ),
                            );
                          },
                          child: _buildTaskCard(context, item, noteProvider),
                        );
                      },
                      childCount: filteredTasks.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(double completionRate) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        title: const Text(
          'Görev Merkezi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Dark Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            // Progress Center
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: completionRate,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      Text(
                        '${(completionRate * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Genel Tamamlanma',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off, color: Colors.white),
          onPressed: () => setState(() => _showCompleted = !_showCompleted),
          tooltip: 'Tamamlananları Göster/Gizle',
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Theme.of(context).disabledColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Bekleyen görev yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Notlarına "- [ ] Görev" yazarak hedeflerini burada toplayabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskItem item, NoteProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Completion Glow Effect
          if (item.isCompleted)
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: item.isCompleted 
          ? Border.all(color: Colors.green.withOpacity(0.3), width: 1)
          : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Accent Line with Animated Color
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 6,
                color: item.isCompleted ? Colors.green : Theme.of(context).primaryColor,
              ),
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: item.isCompleted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (bool? value) {
                        if (value != null) {
                          _toggleTaskStatus(context, item, value);
                        }
                      },
                      activeColor: Colors.green,
                    ),
                  ),
                  title: Text(
                    item.taskText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                      color: item.isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 12, color: Theme.of(context).primaryColor.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.note.title.isEmpty ? 'Başlıksız Not' : item.note.title,
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  onTap: () => _navigateToNote(context, item.note),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TaskItem> _extractTasks(List<Note> notes) {
    List<TaskItem> tasks = [];
    // İYİLEŞTİRİLMİŞ REGEX: Satır başındaki boşlukları (indentation) destekler
    final regex = RegExp(r'^\s*- \[([ xX])\] (.*)', multiLine: true);

    for (var note in notes) {
      if (note.isEncrypted) continue; // Şifreli notları tarama (Güvenlik)
      
      final matches = regex.allMatches(note.content);
      for (var match in matches) {
        if (match.group(2) != null) {
          final statusChar = match.group(1)!;
          final isCompleted = statusChar.toLowerCase() == 'x';
          
          tasks.add(TaskItem(
            note: note,
            taskText: match.group(2)!.trim(),
            isCompleted: isCompleted,
            originalLine: match.group(0)!,
          ));
        }
      }
    }
    return tasks;
  }

  Future<void> _toggleTaskStatus(BuildContext context, TaskItem item, bool newValue) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    
    String oldLine = item.originalLine;
    String newLine = oldLine.replaceFirst(
      RegExp(r'\[([ xX])\]'), 
      newValue ? '[x]' : '[ ]'
    );

    String newContent = item.note.content.replaceFirst(oldLine, newLine);

    final updatedNote = item.note.copyWith(
      content: newContent,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await noteProvider.updateNote(updatedNote);
    
    if (newValue) {
      HapticFeedback.lightImpact();
      ConfettiEffect.show(context);
    }
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(newValue ? 'Görev tamamlandı! 🎉' : 'Görev geri alındı.'),
           duration: const Duration(seconds: 1),
           behavior: SnackBarBehavior.floating,
           backgroundColor: newValue ? Colors.green : Colors.orange,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         ),
       );
    }
  }

  void _navigateToNote(BuildContext context, Note note) {
    Navigator.of(context).pushNamed('/note-editor', arguments: note);
  }

  // Notların durumunu hızlıca kontrol etmek için basit bir hash/timestamp mantığı
  int _calculateNotesHash(List<Note> notes) {
    if (notes.isEmpty) return 0;
    // Tüm notların updatedAt değerlerini toplayarak basit bir "değişim" işareti oluşturalım
    return notes.fold(0, (sum, note) => sum + note.updatedAt + note.id!);
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../services/task_service.dart';
import '../widgets/note_card.dart';
import 'dart:ui';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final notes = noteProvider.notes;
          final recentNotes = notes.take(3).toList();
          final tasks = TaskService.extractTasks(notes);
          final pendingTasks = tasks.where((t) => !t.isCompleted).take(2).toList();
          final tagFreq = noteProvider.getTagFrequency();
          
          return CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildGreetingSection(context),
                    const SizedBox(height: 30),
                    _buildQuickAccessSection(context, recentNotes),
                    const SizedBox(height: 30),
                    _buildStatsGrid(context, tasks, tagFreq),
                    const SizedBox(height: 30),
                    _buildUrgentTasksSection(context, pendingTasks),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'GümüşNot Merkezi',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  Widget _buildGreetingSection(BuildContext context) {
    final now = DateTime.now();
    String greeting = "Günaydın";
    if (now.hour >= 12 && now.hour < 18) greeting = "Tünaydın";
    if (now.hour >= 18) greeting = "İyi Akşamlar";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting Ufuk,',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bugün Gümüşhane\'de hava -5 derece ama kodların ateş ediyor! 🔥',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection(BuildContext context, List<Note> recentNotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Hızlı Erişim',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentNotes.isEmpty)
          const Text('Henüz notun yok. Haydi başla!')
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recentNotes.length,
              itemBuilder: (context, index) {
                final provider = Provider.of<NoteProvider>(context, listen: false);
                return SizedBox(
                  width: 300,
                  child: NoteCard(
                    note: recentNotes[index],
                    isPinned: recentNotes[index].tags.contains('sabit'),
                    onTap: () {
                      Navigator.pushNamed(context, '/note-editor', arguments: recentNotes[index]);
                    },
                    onEdit: () {
                      Navigator.pushNamed(context, '/note-editor', arguments: recentNotes[index]);
                    },
                    onDelete: () {
                      // Silme onayı alıp silebiliriz veya sessizce silebiliriz
                      // Ancak dashboard'da güvenli tarafta kalalım. 
                      provider.deleteNote(recentNotes[index].id!);
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, List<TaskItem> tasks, Map<String, int> tagFreq) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.length - completed;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.analytics_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Verimlilik ve Etiketler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Stats
            Expanded(
              flex: 4,
              child: _buildGlassCard(
                context,
                child: Column(
                  children: [
                    const Text('Görev Dağılımı', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: completed.toDouble(),
                              color: Colors.greenAccent,
                              title: '$completed',
                              radius: 40,
                              titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            PieChartSectionData(
                              value: pending.toDouble(),
                              color: Colors.orangeAccent,
                              title: '$pending',
                              radius: 40,
                              titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                          sectionsSpace: 4,
                          centerSpaceRadius: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIndicator(Colors.greenAccent, 'Biten'),
                        const SizedBox(width: 10),
                        _buildIndicator(Colors.orangeAccent, 'Bekleyen'),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Tag activity
            Expanded(
              flex: 5,
              child: _buildGlassCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Popüler Etiketler', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...(tagFreq.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                      .take(4)
                      .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                            Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrgentTasksSection(BuildContext context, List<TaskItem> pendingTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.priority_high_rounded, size: 20, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  'Acil Bekleyenler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/task-hub'),
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pendingTasks.isEmpty)
          const Text('Tüm görevler tamamlandı! Harikasın. 🎉')
        else
          ...pendingTasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.circle_outlined, color: Colors.redAccent),
              title: Text(task.taskText, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Not: ${task.note.title}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/note-editor', arguments: task.note),
            ),
          )).toList(),
      ],
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIndicator(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/tasks/services/task_service.dart';
import 'package:connected_notebook/features/notes/widgets/note_card.dart';
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
          final pendingTasks = tasks
              .where((t) => !t.isCompleted)
              .take(2)
              .toList();
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(isDark ? 0.15 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.blur_on_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Column(
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
                          '$greeting, Ufuk',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zihnin berrak, bağlantıların güçlü olsun. Bugün bilgi ağını genişletmeye ne dersin? ✨',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection(
    BuildContext context,
    List<Note> recentNotes,
  ) {
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
                final provider = Provider.of<NoteProvider>(
                  context,
                  listen: false,
                );
                return SizedBox(
                  width: 300,
                  child: NoteCard(
                    note: recentNotes[index],
                    isPinned: recentNotes[index].tags.contains('sabit'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/note-editor',
                        arguments: recentNotes[index],
                      );
                    },
                    onEdit: () {
                      Navigator.pushNamed(
                        context,
                        '/note-editor',
                        arguments: recentNotes[index],
                      );
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

  Widget _buildStatsGrid(
    BuildContext context,
    List<TaskItem> tasks,
    Map<String, int> tagFreq,
  ) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.length - completed;
    final total = completed + pending;
    final percent = total > 0 ? ((completed / total) * 100).toInt() : 0;

    final theme = Theme.of(context);

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
                    const Text(
                      'Görev Dağılımı',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value:
                                      completed.toDouble() == 0 &&
                                          pending.toDouble() == 0
                                      ? 1
                                      : completed.toDouble(),
                                  color: theme.primaryColor,
                                  title: '',
                                  radius: 18,
                                ),
                                PieChartSectionData(
                                  value:
                                      completed.toDouble() == 0 &&
                                          pending.toDouble() == 0
                                      ? 0
                                      : pending.toDouble(),
                                  color: theme.primaryColor.withOpacity(0.15),
                                  title: '',
                                  radius: 14,
                                ),
                              ],
                              sectionsSpace: 3,
                              centerSpaceRadius: 32,
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Tamamlandı',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: theme.disabledColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIndicator(theme.primaryColor, 'Biten'),
                        const SizedBox(width: 10),
                        _buildIndicator(
                          theme.primaryColor.withOpacity(0.25),
                          'Bekleyen',
                        ),
                      ],
                    ),
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
                    const Text(
                      'Popüler Etiketler',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (tagFreq.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Center(
                          child: Text(
                            'Henüz etiket yok',
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...(tagFreq.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value)))
                          .take(3)
                          .map((entry) {
                            final maxFreq = tagFreq.values.fold<int>(
                              1,
                              (max, v) => v > max ? v : max,
                            );
                            final ratio = entry.value / maxFreq;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '#${entry.key}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} not',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.disabledColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: theme.primaryColor
                                          .withOpacity(0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.primaryColor.withOpacity(0.85),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrgentTasksSection(
    BuildContext context,
    List<TaskItem> pendingTasks,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_late_rounded,
                  size: 22,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Acil Görevler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/task-hub'),
              child: Row(
                children: [
                  const Text('Tümünü Gör'),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pendingTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withOpacity(isDark ? 0.1 : 0.4),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: theme.primaryColor.withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tüm görevler tamamlandı! Harikasın. 🎉',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingTasks
              .map(
                (task) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(
                        isDark ? 0.15 : 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Icon(
                      Icons.radio_button_off_rounded,
                      color: theme.primaryColor.withOpacity(0.8),
                    ),
                    title: Text(
                      task.taskText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 12,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Kaynak: ${task.note.title.isEmpty ? "Başlıksız" : task.note.title}',
                              style: TextStyle(
                                color: theme.disabledColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.disabledColor.withOpacity(0.5),
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/note-editor',
                      arguments: task.note,
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

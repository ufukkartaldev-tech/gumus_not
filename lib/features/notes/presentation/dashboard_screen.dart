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
                    const SizedBox(height: 12),
                    _buildGreetingSection(context),
                    const SizedBox(height: 28),
                    _buildQuickAccessSection(context, recentNotes),
                    const SizedBox(height: 28),
                    _buildStatsGrid(context, tasks, tagFreq),
                    const SizedBox(height: 28),
                    _buildUrgentTasksSection(context, pendingTasks),
                    const SizedBox(height: 32),
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
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'GümüşNot Merkezi',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.5,
          color: theme.colorScheme.onSurface.withOpacity(0.9),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined),
          color: theme.colorScheme.onSurface.withOpacity(0.7),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? theme.primaryColor.withOpacity(0.08)
                : theme.primaryColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -40,
                bottom: -40,
                child: Icon(
                  Icons.blur_on_rounded,
                  size: 140,
                  color: theme.primaryColor.withOpacity(isDark ? 0.06 : 0.03),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, Ufuk',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Zihnin berrak, bağlantıların güçlü olsun. Bugün bilgi ağını genişletmeye ne dersin?',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(
                        isDark ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection(
    BuildContext context,
    List<Note> recentNotes,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 20,
              color: theme.primaryColor.withOpacity(0.8),
            ),
            const SizedBox(width: 12),
            Text(
              'Hızlı Erişim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentNotes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color:
                  theme.cardTheme.color?.withOpacity(0.5) ??
                  theme.cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.12),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.note_add_outlined,
                    size: 28,
                    color: theme.primaryColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Henüz hiç not yok',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Düşüncelerini ve fikirlerini kaydetmeye başla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.disabledColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          )
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
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 20,
              color: theme.primaryColor.withOpacity(0.8),
            ),
            const SizedBox(width: 12),
            Text(
              'Verimlilik ve Etiketler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
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
                    Text(
                      'Görev Dağılımı',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
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
                                  radius: 8,
                                ),
                                PieChartSectionData(
                                  value:
                                      completed.toDouble() == 0 &&
                                          pending.toDouble() == 0
                                      ? 0
                                      : pending.toDouble(),
                                  color: theme.primaryColor.withOpacity(0.12),
                                  title: '',
                                  radius: 8,
                                ),
                              ],
                              sectionsSpace: 0,
                              centerSpaceRadius: 38,
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.9),
                                    fontFamily: 'Inter',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Biten',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: theme.disabledColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
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
                        _buildIndicator(context, theme.primaryColor, 'Biten'),
                        const SizedBox(width: 14),
                        _buildIndicator(
                          context,
                          theme.primaryColor.withOpacity(0.3),
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
                    Text(
                      'Popüler Etiketler',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (tagFreq.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.label_off_outlined,
                                size: 32,
                                color: theme.primaryColor.withOpacity(0.4),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Henüz etiket yok',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Notlarına #etiket ekle.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} not',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.disabledColor
                                              .withOpacity(0.8),
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
                                          .withOpacity(0.06),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.primaryColor.withOpacity(0.85),
                                      ),
                                      minHeight: 5,
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
                  Icons.assignment_late_outlined,
                  size: 20,
                  color: theme.primaryColor.withOpacity(0.8),
                ),
                const SizedBox(width: 12),
                Text(
                  'Acil Görevler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/task-hub'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.primaryColor.withOpacity(0.9),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  theme.cardTheme.color?.withOpacity(0.5) ??
                  theme.cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.12),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 28,
                    color: Colors.green.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tüm görevler tamamlandı!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün harika bir verimlilik gösterdin. 🎉',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.disabledColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingTasks
              .map(
                (task) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.grey.withOpacity(0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.circle_outlined,
                        size: 18,
                        color: theme.primaryColor.withOpacity(0.8),
                      ),
                    ),
                    title: Text(
                      task.taskText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 12,
                            color: theme.disabledColor.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Kaynak: ${task.note.title.isEmpty ? "Başlıksız" : task.note.title}',
                              style: TextStyle(
                                color: theme.disabledColor.withOpacity(0.8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withOpacity(0.8) ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.grey.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIndicator(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

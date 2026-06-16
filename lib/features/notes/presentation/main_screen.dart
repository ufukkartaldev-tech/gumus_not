import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/presentation/dashboard_screen.dart';
import 'package:connected_notebook/features/notes/presentation/note_list_screen.dart';
import 'package:connected_notebook/features/tasks/presentation/task_hub_screen.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';
import 'package:connected_notebook/shared/utils/sharing_service.dart';
import 'package:connected_notebook/features/home_widget/services/widget_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final SharingService _sharingService = SharingService();
  final WidgetService _widgetService = WidgetService();

  final List<Widget> _screens = [
    const DashboardScreen(),
    const NoteListScreen(),
    const TaskHubScreen(),
    const GraphViewScreen(),
    const WidgetScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Paylaşım servisini başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharingService.initialize(context);

      if (!kIsWeb) {
        _widgetService.startPeriodicUpdates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color:
                theme.cardTheme.color?.withOpacity(0.95) ??
                theme.cardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.space_dashboard_outlined, 'Merkez'),
              _buildNavItem(1, Icons.article_outlined, 'Notlar'),
              _buildNavItem(2, Icons.check_circle_outline_rounded, 'Görevler'),
              _buildNavItem(3, Icons.hub_outlined, 'Zihin'),
              _buildNavItem(4, Icons.widgets_outlined, 'Widget'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(20),
        highlightColor: Colors.transparent,
        splashColor: theme.primaryColor.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active indicator background or dot
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: isSelected ? 42 : 0,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(isDark ? 0.16 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  Icon(
                    icon,
                    color: isSelected
                        ? theme.primaryColor
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

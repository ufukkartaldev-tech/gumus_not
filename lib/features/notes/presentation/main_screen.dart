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
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() => _selectedIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(
                context,
              ).disabledColor.withOpacity(0.6),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Merkez',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notes_rounded),
                  activeIcon: Icon(Icons.notes_rounded),
                  label: 'Notlar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.task_alt_rounded),
                  activeIcon: Icon(Icons.task_alt_rounded),
                  label: 'Görevler',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.hub_rounded),
                  activeIcon: Icon(Icons.hub_rounded),
                  label: 'Zihin',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.widgets_rounded),
                  activeIcon: Icon(Icons.widgets_rounded),
                  label: 'Widget',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

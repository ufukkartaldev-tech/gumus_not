import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'note_list_screen.dart';
import 'task_hub_screen.dart';
import 'graph_view_screen.dart';
import 'widget_screen.dart';
import '../services/sharing_service.dart';
import '../services/widget_service.dart';

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
      _widgetService.startPeriodicUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).cardTheme.color,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
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
                label: 'Zihin Haritası',
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
    );
  }
}

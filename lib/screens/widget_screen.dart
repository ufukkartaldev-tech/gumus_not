import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../services/widget_service.dart';
import '../services/database_service.dart';
import '../models/note_model.dart';

class WidgetScreen extends StatefulWidget {
  const WidgetScreen({Key? key}) : super(key: key);

  @override
  State<WidgetScreen> createState() => _WidgetScreenState();
}

class _WidgetScreenState extends State<WidgetScreen> {
  final WidgetService _widgetService = WidgetService();
  bool _isLoading = false;
  Map<String, dynamic>? _widgetData;
  Map<String, dynamic>? _quickNoteData;

  @override
  void initState() {
    super.initState();
    _loadWidgetData();
  }

  Future<void> _loadWidgetData() async {
    setState(() => _isLoading = true);
    
    try {
      final widgetData = await _widgetService.getWidgetData();
      final quickNoteData = await DatabaseService.getDatabaseStats();
      
      setState(() {
        _widgetData = widgetData;
        _quickNoteData = quickNoteData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Widget verisi yüklenemedi: $e')),
      );
    }
  }

  Future<void> _updateWidgets() async {
    setState(() => _isLoading = true);
    
    try {
      await _widgetService.updateWidget();
      await _widgetService.updateQuickNoteWidget();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Widget\'lar başarıyla güncellendi')),
      );
      
      _loadWidgetData();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Widget güncellenemedi: $e')),
      );
    }
  }

  String _getDailyQuote() {
    final quotes = [
      "Bilgi, gücün temelidir.",
      "Not almak, düşünmek için yazmaktır.",
      "Küçük adımlar, büyük değişimler yaratır.",
      "Başarı, iyi alışkanlıkların birikimidir.",
      "Bugün yazdığın, yarının bilgisidir.",
    ];
    
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _updateWidgets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStats(),
                  const SizedBox(height: 24),
                  _buildQuickNoteWidget(),
                  const SizedBox(height: 24),
                  _buildRecentNotesWidget(),
                  const SizedBox(height: 24),
                  _buildTasksWidget(),
                  const SizedBox(height: 24),
                  _buildWidgetConfiguration(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Hızlı İstatistikler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Toplam Not',
                    value: '${_quickNoteData?['totalNotes'] ?? 0}',
                    icon: Icons.note,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Bekleyen Görev',
                    value: '${_quickNoteData?['totalTasks'] ?? 0}',
                    icon: Icons.task,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNoteWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Hızlı Not Widget\'ı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 "${_getDailyQuote()}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Text('Son güncelleme: ${DateTime.now().toString().substring(0, 19)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _updateWidgets,
              icon: const Icon(Icons.update),
              label: const Text('Widget\'ı Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotesWidget() {
    final recentNotes = _widgetData?['recentNotes'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📝 Son Notlar Widget\'ı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (recentNotes.isEmpty)
              const Text('Henüz not yok')
            else
              ...recentNotes.take(3).map((noteData) {
                final note = Note.fromMap(noteData);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.note),
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksWidget() {
    final pendingTasks = _widgetData?['pendingTasks'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ Görev Listesi Widget\'ı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (pendingTasks.isEmpty)
              const Text('Bekleyen görev yok')
            else
              ...pendingTasks.take(5).map((taskData) {
                final task = Note.fromMap(taskData);
                return CheckboxListTile(
                  dense: true,
                  value: false,
                  onChanged: (bool? value) {
                    // Widget'tan görev tamamlama
                  },
                  title: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetConfiguration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Widget Konfigürasyonu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Widget ayarları yakında eklenecek...'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Widget konfigürasyon ekranı
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Widget Ayarları'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Widget kurulum talimatları
                      _showWidgetInstructions();
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Kurulum Yardım'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWidgetInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Widget Kurulumu'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Android:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Ana ekrana uzun basın\n2. "Widget" seçin\n3. "GümüşNot" widget\'ını bulun\n4. Ekran sürükleyin'),
              SizedBox(height: 16),
              Text(
                'iOS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Ana ekrana sağdan kaydırın\n2. "+" butonuna basın\n3. "GümüşNot" widget\'ını arayın\n4. Boyut seçin ve ekleyin'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/database_service.dart';

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  final DatabaseService _dbService = DatabaseService();

  // Widget'ı güncellemek için ana fonksiyon
  Future<void> updateWidget() async {
    try {
      // Son notları ve görevleri getir
      final recentNotes = await _dbService.getRecentNotes(limit: 3);
      final pendingTasks = await _dbService.getPendingTasks(limit: 5);

      // Widget verisini hazırla
      final widgetData = {
        'recentNotes': recentNotes.map((note) => note.toMap()).toList(),
        'pendingTasks': pendingTasks.map((task) => task.toMap()).toList(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      // Widget'ı güncelle
      await HomeWidget.saveWidgetData('widget_data', widgetData);
      await HomeWidget.updateWidget(name: 'GumusNotWidget');
      
      print('✅ Widget başarıyla güncellendi');
    } catch (e) {
      print('❌ Widget güncelleme hatası: $e');
    }
  }

  // Hızlı not widget'ı için
  Future<void> updateQuickNoteWidget() async {
    try {
      final stats = await _dbService.getDatabaseStats();
      
      final quickNoteData = {
        'totalNotes': stats['totalNotes'] ?? 0,
        'totalTasks': stats['totalTasks'] ?? 0,
        'lastNoteDate': stats['lastNoteDate'],
        'quote': _getDailyQuote(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      await HomeWidget.saveWidgetData('quick_note_data', quickNoteData);
      await HomeWidget.updateWidget(name: 'QuickNoteWidget');
      
      print('✅ Hızlı not widget\'ı güncellendi');
    } catch (e) {
      print('❌ Hızlı not widget güncelleme hatası: $e');
    }
  }

  // Günlük motivasyon alıntıları
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

  // Widget konfigürasyonu
  Future<void> configureWidget({
    required String widgetType,
    required int refreshInterval,
    required bool showTasks,
    required bool showNotes,
  }) async {
    try {
      final config = {
        'widgetType': widgetType, // 'quick_note', 'task_list', 'recent_notes'
        'refreshInterval': refreshInterval, // dakika cinsinden
        'showTasks': showTasks,
        'showNotes': showNotes,
        'lastConfigured': DateTime.now().millisecondsSinceEpoch,
      };

      await HomeWidget.saveWidgetData('widget_config', config);
      print('✅ Widget konfigürasyonu kaydedildi');
    } catch (e) {
      print('❌ Widget konfigürasyon hatası: $e');
    }
  }

  // Widget verisi getir
  Future<Map<String, dynamic>?> getWidgetData() async {
    try {
      return await HomeWidget.getWidgetData('widget_data');
    } catch (e) {
      print('❌ Widget verisi okuma hatası: $e');
      return null;
    }
  }

  // Widget periyodik güncelleme
  void startPeriodicUpdates() {
    // Her 30 dakikada bir widget'ı güncelle
    Stream.periodic(const Duration(minutes: 30)).listen((_) {
      updateWidget();
      updateQuickNoteWidget();
    });
  }
}

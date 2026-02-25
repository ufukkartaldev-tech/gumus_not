import 'dart:io';

const Map<String, String> fileMapping = {
  // Core Database
  'lib/services/database_service.dart': 'lib/core/database/database_service.dart',
  
  // Core Security
  'lib/services/biometric_service.dart': 'lib/core/security/biometric_service.dart',
  'lib/services/encryption_service.dart': 'lib/core/security/encryption_service.dart',
  
  // Core Theme
  'lib/themes/app_theme.dart': 'lib/core/theme/app_theme.dart',
  'lib/providers/theme_provider.dart': 'lib/core/theme/theme_provider.dart',

  // Shared Utils / Services
  'lib/services/image_service.dart': 'lib/shared/utils/image_service.dart',
  'lib/services/sharing_service.dart': 'lib/shared/utils/sharing_service.dart',

  // Features - Backup
  'lib/screens/backup_screen.dart': 'lib/features/backup/presentation/backup_screen.dart',
  'lib/services/backup_share_service.dart': 'lib/features/backup/services/backup_share_service.dart',

  // Features - Notes
  'lib/models/note_model.dart': 'lib/features/notes/models/note_model.dart',
  'lib/models/note_template.dart': 'lib/features/notes/models/note_template.dart',
  'lib/providers/note_provider.dart': 'lib/features/notes/providers/note_provider.dart',
  'lib/services/template_service.dart': 'lib/features/notes/services/template_service.dart',
  
  'lib/screens/main_screen.dart': 'lib/features/notes/presentation/main_screen.dart',
  'lib/screens/note_list_screen.dart': 'lib/features/notes/presentation/note_list_screen.dart',
  'lib/screens/private_vault_screen.dart': 'lib/features/notes/presentation/private_vault_screen.dart',
  'lib/screens/template_selection_screen.dart': 'lib/features/notes/presentation/template_selection_screen.dart',
  'lib/screens/drawing_screen.dart': 'lib/features/notes/presentation/drawing_screen.dart',
  'lib/screens/tag_management_screen.dart': 'lib/features/notes/presentation/tag_management_screen.dart',
  'lib/screens/dashboard_screen.dart': 'lib/features/notes/presentation/dashboard_screen.dart',
  
  'lib/widgets/note_card.dart': 'lib/features/notes/widgets/note_card.dart',
  'lib/widgets/custom_widgets.dart': 'lib/features/notes/widgets/custom_widgets.dart',
  'lib/widgets/markdown_editor.dart': 'lib/features/notes/widgets/markdown_editor.dart',
  'lib/widgets/math_markdown_renderer.dart': 'lib/features/notes/widgets/math_markdown_renderer.dart',
  'lib/widgets/tag_cloud_widget.dart': 'lib/features/notes/widgets/tag_cloud_widget.dart',
  'lib/widgets/note_template_manager.dart': 'lib/features/notes/widgets/note_template_manager.dart',

  // Features - Tasks
  'lib/screens/task_hub_screen.dart': 'lib/features/tasks/presentation/task_hub_screen.dart',
  'lib/services/task_service.dart': 'lib/features/tasks/services/task_service.dart',

  // Features - Export
  'lib/screens/batch_export_screen.dart': 'lib/features/export/presentation/batch_export_screen.dart',
  'lib/screens/import_export_screen.dart': 'lib/features/export/presentation/import_export_screen.dart',
  'lib/screens/latex_export_screen.dart': 'lib/features/export/presentation/latex_export_screen.dart',
  
  'lib/services/latex_export_service.dart': 'lib/features/export/services/latex_export_service.dart',
  'lib/services/pdf_export_service.dart': 'lib/features/export/services/pdf_export_service.dart',
  'lib/services/pdf_service.dart': 'lib/features/export/services/pdf_service.dart',

  // Features - Search
  'lib/screens/advanced_search_screen.dart': 'lib/features/search/presentation/advanced_search_screen.dart',
  'lib/services/search_service.dart': 'lib/features/search/services/search_service.dart',

  // Features - Settings
  'lib/screens/settings_screen.dart': 'lib/features/settings/presentation/settings_screen.dart',
  'lib/screens/about_screen.dart': 'lib/features/settings/presentation/about_screen.dart',

  // Features - Graph
  'lib/screens/graph_view_screen.dart': 'lib/features/graph/presentation/graph_view_screen.dart',

  // Features - Tools (Other small widgets)
  'lib/screens/sql_query_console.dart': 'lib/features/tools/presentation/sql_query_console.dart',
  'lib/widgets/pomodoro_timer.dart': 'lib/features/tools/widgets/pomodoro_timer.dart',
  'lib/widgets/cross_reference_tracker.dart': 'lib/features/tools/widgets/cross_reference_tracker.dart',
  'lib/widgets/command_palette.dart': 'lib/features/tools/widgets/command_palette.dart',
  'lib/widgets/dashboard_stats.dart': 'lib/features/tools/widgets/dashboard_stats.dart',
  'lib/widgets/confetti_effect.dart': 'lib/features/tools/widgets/confetti_effect.dart',
  'lib/widgets/activity_heatmap.dart': 'lib/features/tools/widgets/activity_heatmap.dart',
  'lib/widgets/tag_manager_widget.dart': 'lib/features/tools/widgets/tag_manager_widget.dart',

  // Features - Widgets (Homescreen widgets)
  'lib/screens/widget_screen.dart': 'lib/features/home_widget/presentation/widget_screen.dart',
  'lib/services/widget_service.dart': 'lib/features/home_widget/services/widget_service.dart',

  // Splash
  'lib/screens/splash_screen.dart': 'lib/features/splash/presentation/splash_screen.dart',
  
  // Test mappings
  'test/models/note_model_test.dart': 'test/features/notes/models/note_model_test.dart',
  'test/models/note_template_test.dart': 'test/features/notes/models/note_template_test.dart',
  'test/services/database_service_test.dart': 'test/core/database/database_service_test.dart',
  'test/services/encryption_service_test.dart': 'test/core/security/encryption_service_test.dart',
  'test/services/backup_share_service_test.dart': 'test/features/backup/services/backup_share_service_test.dart',
  'test/services/search_service_test.dart': 'test/features/search/services/search_service_test.dart',
  'test/services/template_service_test.dart': 'test/features/notes/services/template_service_test.dart',
  'test/services/task_service_test.dart': 'test/features/tasks/services/task_service_test.dart',
  'test/services/image_service_test.dart': 'test/shared/utils/image_service_test.dart',
  'test/services/sharing_service_test.dart': 'test/shared/utils/sharing_service_test.dart',
};

String getNewLibraryPath(String newPath) {
    if(newPath.startsWith('lib/')) {
        return newPath.replaceFirst('lib/', '');
    }
    return newPath;
}

void main() async {
  print('SOLID Migration Script Started...');
  
  // 1. Dosyaları Taşıma
  for (var entry in fileMapping.entries) {
    var oldPath = entry.key;
    var newPath = entry.value;

    var oldFile = File(oldPath);
    if (await oldFile.exists()) {
      var newFile = File(newPath);
      await newFile.parent.create(recursive: true);
      await oldFile.copy(newPath);
      print('Copied: $oldPath -> $newPath');
    } else {
      print('Not Found: $oldPath');
    }
  }

  // 2. Tüm taşınan dosyalardaki importları güncelleme
  // "import '../models/..." => "import 'package:connected_notebook/features/..." vb.
  // En sağlam yöntem, her dosyanın içindeki tüm importları tarayıp eski dosya yollarıyla eşleşenleri bulup package import'a çevirmek.
  
  List<File> allNewFiles = [];
  Directory('lib').listSync(recursive: true).forEach((f) {
      if(f is File && f.path.endsWith('.dart')) allNewFiles.add(f);
  });
  Directory('test').listSync(recursive: true).forEach((f) {
      if(f is File && f.path.endsWith('.dart')) allNewFiles.add(f);
  });
  
  for (var file in allNewFiles) {
    String content = await file.readAsString();
    String newContent = content;

    // Tüm importlara tek tek bakalım
    // Relative imports can be like: import '../models/note_model.dart';
    // or import 'package:connected_notebook/services/database_service.dart';
    
    // Reverse mapping
    fileMapping.forEach((oldPath, newPath) {
        String oldLibPath = oldPath.replaceFirst('lib/', '');
        String newPackageImport = 'package:connected_notebook/' + newPath.replaceFirst('lib/', '');
        
        // Eskiden relative idi diye, regex kullanmak çok riskli. Sadece isim eşleme yapalım
        String oldFileName = oldPath.split('/').last;
        String newPackageImportStr = "import '$newPackageImport';";
        
        // Relative importları ve package: importları bul ve değiştir
        // import '../models/note_model.dart'; 
        // to import 'package:connected_notebook/features/notes/models/note_model.dart';
        // En basit yöntem: if the line contains oldFileName and is an import line, try to replace it carefully.
    });
    
    // A better approach: RegExp to find ALL import statements and compute their absolute old path, then replace with absolute new package import.
    // Replace hardcoded "import 'package:connected_notebook/models/note_model.dart';" with new imports
    fileMapping.forEach((oldPath, newPath) {
        if (!oldPath.startsWith('lib/')) return;
        
        String oldLibPath = oldPath.replaceFirst('lib/', '');
        String newPackageImport = 'package:connected_notebook/' + newPath.replaceFirst('lib/', '');
        
        // Match package:
        newContent = newContent.replaceAll(
          "import 'package:connected_notebook/$oldLibPath';",
          "import '$newPackageImport';"
        );
        newContent = newContent.replaceAll(
          'import "package:connected_notebook/$oldLibPath";',
          "import '$newPackageImport';"
        );
        
        // Match relative using just filename if they are unique
        // Wait, filename might not be unique. But in this project, they almost are.
        // E.g. note_model.dart is only one.
        String fileName = oldPath.split('/').last;
        RegExp rx = RegExp("import\\s+['\"]([^'\"]*$fileName)['\"]\\s*;");
        // Replace all relative imports that end with fileName
        newContent = newContent.replaceAllMapped(rx, (m) {
            return "import '$newPackageImport';";
        });
    });
    
    if (content != newContent) {
        await file.writeAsString(newContent);
        print('Updated imports in: \${file.path}');
    }
  }
  
  // Remove old directories
  // Warning: Do this carefully in next step if everything is fine.
  print('Done.');
}

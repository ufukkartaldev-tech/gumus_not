import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShortcutManager extends ChangeNotifier {
  bool _isVimModeEnabled = false;
  
  // Action Name -> Shortcut String representation
  Map<String, String> _customShortcuts = {
    'command_palette': 'meta+k', // Command+K or Ctrl+K
    'new_note': 'meta+n',
    'search_notes': 'meta+f',
  };

  bool get isVimModeEnabled => _isVimModeEnabled;
  Map<String, String> get customShortcuts => _customShortcuts;

  AppShortcutManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isVimModeEnabled = prefs.getBool('vim_mode_enabled') ?? false;
    
    final shortcutsJson = prefs.getString('custom_shortcuts');
    if (shortcutsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(shortcutsJson);
        decoded.forEach((key, value) {
          _customShortcuts[key] = value.toString();
        });
      } catch (e) {
        debugPrint('Error parsing custom shortcuts: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setVimMode(bool enabled) async {
    _isVimModeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vim_mode_enabled', enabled);
    notifyListeners();
  }

  Future<void> updateShortcut(String action, String shortcutStr) async {
    _customShortcuts[action] = shortcutStr;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_shortcuts', jsonEncode(_customShortcuts));
    notifyListeners();
  }
}

class CommandPaletteIntent extends Intent {
  const CommandPaletteIntent();
}

class NewNoteIntent extends Intent {
  const NewNoteIntent();
}

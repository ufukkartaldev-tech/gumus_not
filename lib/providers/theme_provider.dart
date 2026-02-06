import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _themeColorKey = 'theme_color';
  
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeColor _selectedColor = AppThemeColor.indigo; // Default
  
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  AppThemeColor get selectedColor => _selectedColor;
  bool get isInitialized => _isInitialized;

  ThemeData get lightTheme => AppTheme.getTheme(
    mode: ThemeMode.light, 
    color: _selectedColor
  );
  
  ThemeData get darkTheme => AppTheme.getTheme(
    mode: ThemeMode.dark, 
    color: _selectedColor
  );

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Mode
    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString().split('.').last == savedMode,
        orElse: () => ThemeMode.system
      );
    }
    
    // Load Color
    final savedColor = prefs.getString(_themeColorKey);
    if (savedColor != null) {
      _selectedColor = AppThemeColor.values.firstWhere(
        (e) => e.name == savedColor,
        orElse: () => AppThemeColor.indigo
      );
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString().split('.').last);
  }
  
  Future<void> setThemeColor(AppThemeColor color) async {
    if (_selectedColor == color) return;
    
    _selectedColor = color;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, color.name);
  }
}

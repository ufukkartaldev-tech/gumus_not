import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _themeColorKey = 'theme_color';
  static const String _presetThemeKey = 'preset_theme';
  
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeColor _selectedColor = AppThemeColor.indigo;
  PresetTheme? _selectedPresetTheme;
  
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  AppThemeColor get selectedColor => _selectedColor;
  PresetTheme? get selectedPresetTheme => _selectedPresetTheme;
  bool get isInitialized => _isInitialized;
  
  bool get isUsingPresetTheme => _selectedPresetTheme != null;

  ThemeData get currentTheme {
    if (_selectedPresetTheme != null) {
      return AppTheme.getPresetTheme(_selectedPresetTheme!);
    }
    
    return AppTheme.getTheme(
      mode: _themeMode, 
      color: _selectedColor
    );
  }

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
    
    // Load Preset Theme
    final savedPreset = prefs.getString(_presetThemeKey);
    if (savedPreset != null) {
      _selectedPresetTheme = PresetTheme.values.firstWhere(
        (e) => e.name == savedPreset,
        orElse: () => PresetTheme.dracula
      );
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    // When changing theme mode, clear preset theme to use custom colors
    _selectedPresetTheme = null;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString().split('.').last);
    await prefs.remove(_presetThemeKey); // Clear preset theme
  }
  
  Future<void> setThemeColor(AppThemeColor color) async {
    if (_selectedColor == color) return;
    
    _selectedColor = color;
    // When changing color, clear preset theme to use custom colors
    _selectedPresetTheme = null;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, color.name);
    await prefs.remove(_presetThemeKey); // Clear preset theme
  }

  Future<void> setPresetTheme(PresetTheme preset) async {
    if (_selectedPresetTheme == preset) return;
    
    _selectedPresetTheme = preset;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetThemeKey, preset.name);
  }

  Future<void> clearPresetTheme() async {
    if (_selectedPresetTheme == null) return;
    
    _selectedPresetTheme = null;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_presetThemeKey);
  }

  String get currentThemeName {
    if (_selectedPresetTheme != null) {
      return _selectedPresetTheme!.name;
    }
    
    final modeName = _themeMode == ThemeMode.dark ? 'Dark' : 
                    _themeMode == ThemeMode.light ? 'Light' : 'System';
    return '$modeName (${_selectedColor.label})';
  }

  String get currentThemeDescription {
    if (_selectedPresetTheme != null) {
      return _selectedPresetTheme!.description;
    }
    
    final modeName = _themeMode == ThemeMode.dark ? 'Karanlık' : 
                    _themeMode == ThemeMode.light ? 'Açık' : 'Sistem';
    return 'Özel $modeName tema - ${_selectedColor.label} vurgu';
  }

  // Get theme preview colors for UI
  Map<String, Color> getThemePreviewColors() {
    if (_selectedPresetTheme != null) {
      switch (_selectedPresetTheme!) {
        case PresetTheme.dracula:
          return {
            'background': AppTheme.draculaBackground,
            'surface': AppTheme.draculaSurface,
            'primary': AppTheme.draculaPink,
            'text': AppTheme.draculaTextPrimary,
          };
        case PresetTheme.nord:
          return {
            'background': AppTheme.nordBackground,
            'surface': AppTheme.nordSurface,
            'primary': AppTheme.nordBlue,
            'text': AppTheme.nordTextPrimary,
          };
        case PresetTheme.solarized:
          return {
            'background': AppTheme.solarizedBackground,
            'surface': AppTheme.solarizedSurface,
            'primary': AppTheme.solarizedBlue,
            'text': AppTheme.solarizedTextPrimary,
          };
        case PresetTheme.gruvbox:
          return {
            'background': AppTheme.gruvboxBackground,
            'surface': AppTheme.gruvboxSurface,
            'primary': AppTheme.gruvboxGreen,
            'text': AppTheme.gruvboxTextPrimary,
          };
        case PresetTheme.github:
          return {
            'background': AppTheme.githubBackground,
            'surface': AppTheme.githubSurface,
            'primary': AppTheme.githubBlue,
            'text': AppTheme.githubTextPrimary,
          };
        case PresetTheme.vscode:
          return {
            'background': AppTheme.vscodeBackground,
            'surface': AppTheme.vscodeSurface,
            'primary': AppTheme.vscodeBlue,
            'text': AppTheme.vscodeTextPrimary,
          };
        case PresetTheme.monokai:
          return {
            'background': AppTheme.monokaiBackground,
            'surface': AppTheme.monokaiSurface,
            'primary': AppTheme.monokaiPink,
            'text': AppTheme.monokaiTextPrimary,
          };
        case PresetTheme.oneDark:
          return {
            'background': AppTheme.oneDarkBackground,
            'surface': AppTheme.oneDarkSurface,
            'primary': AppTheme.oneDarkBlue,
            'text': AppTheme.oneDarkTextPrimary,
          };
      }
    }
    
    final isDark = _themeMode == ThemeMode.dark || 
                   (_themeMode == ThemeMode.system && 
                    WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    
    return {
      'background': isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      'surface': isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      'primary': _selectedColor.color,
      'text': isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
    };
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

/// Theme selection screen with preset themes and custom options
class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema Seçimi'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentThemeInfo(),
            const SizedBox(height: 24),
            _buildPresetThemesSection(),
            const SizedBox(height: 24),
            _buildCustomThemesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentThemeInfo() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final previewColors = themeProvider.getThemePreviewColors();
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mevcut Tema',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  themeProvider.currentThemeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  themeProvider.currentThemeDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                _buildColorPreview(previewColors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPreview(Map<String, Color> colors) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: colors['background'],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: colors['surface'],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: colors['primary'],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: colors['text'],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetThemesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.style,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Hazır Temalar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: PresetTheme.values.length,
          itemBuilder: (context, index) {
            final preset = PresetTheme.values[index];
            return _buildPresetThemeCard(preset);
          },
        ),
      ],
    );
  }

  Widget _buildPresetThemeCard(PresetTheme preset) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isSelected = themeProvider.selectedPresetTheme == preset;
        final previewColors = _getPresetThemeColors(preset);
        
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected 
                ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => _selectPresetTheme(preset),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        preset.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  _buildMiniColorPreview(previewColors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniColorPreview(Map<String, Color> colors) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: colors['background'],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(color: colors['primary']),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: colors['text'],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomThemesSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Özel Tema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema Modu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildThemeModeOption(ThemeMode.light, 'Açık', Icons.light_mode),
                        const SizedBox(width: 8),
                        _buildThemeModeOption(ThemeMode.dark, 'Karanlık', Icons.dark_mode),
                        const SizedBox(width: 8),
                        _buildThemeModeOption(ThemeMode.system, 'Sistem', Icons.settings_brightness),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vurgu Rengi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppThemeColor.values.map((color) {
                        return _buildColorOption(color);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeModeOption(ThemeMode mode, String label, IconData icon) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isSelected = themeProvider.themeMode == mode && !themeProvider.isUsingPresetTheme;
        
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              themeProvider.clearPresetTheme();
              themeProvider.setThemeMode(mode);
            }
          },
        );
      },
    );
  }

  Widget _buildColorOption(AppThemeColor color) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isSelected = themeProvider.selectedColor == color && !themeProvider.isUsingPresetTheme;
        
        return GestureDetector(
          onTap: () {
            themeProvider.clearPresetTheme();
            themeProvider.setThemeColor(color);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.color,
              borderRadius: BorderRadius.circular(20),
              border: isSelected 
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      },
    );
  }

  Map<String, Color> _getPresetThemeColors(PresetTheme preset) {
    switch (preset) {
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

  void _selectPresetTheme(PresetTheme preset) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setPresetTheme(preset);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${preset.name} teması uygulandı'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

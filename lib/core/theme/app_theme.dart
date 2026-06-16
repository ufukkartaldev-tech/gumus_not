import 'package:flutter/material.dart';

enum AppThemeColor {
  indigo(Color(0xFF6366F1), 'İndigo'),
  blue(Color(0xFF3B82F6), 'Mavi'),
  teal(Color(0xFF14B8A6), 'Turkuaz'),
  green(Color(0xFF10B981), 'Yeşil'),
  orange(Color(0xFFF97316), 'Turuncu'),
  pink(Color(0xFFEC4899), 'Pembe'),
  purple(Color(0xFFA855F7), 'Mor'),
  red(Color(0xFFEF4444), 'Kırmızı');

  final Color color;
  final String label;
  const AppThemeColor(this.color, this.label);
}

enum PresetTheme {
  dracula('Dracula', 'Karanlık ve profesyonel'),
  nord('Nord', 'Nordik ve sakin'),
  solarized('Solarized', 'Göz dostu ve sıcak'),
  gruvbox('Gruvbox', 'Retro ve rahat'),
  github('GitHub', 'Temiz ve modern'),
  vscode('VS Code', 'Geliştirici dostu'),
  monokai('Monokai', 'Klasik dark'),
  oneDark('One Dark', 'Popüler syntax');

  final String name;
  final String description;
  const PresetTheme(this.name, this.description);
}

class AppTheme {
  // DRACULA Theme Colors
  static const Color draculaBackground = Color(0xFF282A36);
  static const Color draculaSurface = Color(0xFF1E1F29);
  static const Color draculaBorder = Color(0xFF44475A);
  static const Color draculaTextPrimary = Color(0xFFF8F8F2);
  static const Color draculaTextSecondary = Color(0xFF6272A4);
  static const Color draculaPink = Color(0xFFFF79C6);
  static const Color draculaPurple = Color(0xFFBD93F9);
  static const Color draculaBlue = Color(0xFF8BE9FD);
  static const Color draculaGreen = Color(0xFF50FA7B);
  static const Color draculaYellow = Color(0xFFF1FA8C);
  static const Color draculaOrange = Color(0xFFFFB86C);
  static const Color draculaRed = Color(0xFFFF5555);
  static const Color draculaCyan = Color(0xFF8BE9FD);

  // NORD Theme Colors
  static const Color nordBackground = Color(0xFF2E3440);
  static const Color nordSurface = Color(0xFF3B4252);
  static const Color nordBorder = Color(0xFF434C5E);
  static const Color nordTextPrimary = Color(0xFFD8DEE9);
  static const Color nordTextSecondary = Color(0xFF4C566A);
  static const Color nordBlue = Color(0xFF5E81AC);
  static const Color nordCyan = Color(0xFF88C0D0);
  static const Color nordGreen = Color(0xFFA3BE8C);
  static const Color nordYellow = Color(0xFFEBCB8B);
  static const Color nordRed = Color(0xFFBF616A);
  static const Color nordPurple = Color(0xFFB48EAD);
  static const Color nordOrange = Color(0xFFD08770);

  // SOLARIZED Theme Colors
  static const Color solarizedBackground = Color(0xFF002B36);
  static const Color solarizedSurface = Color(0xFF073642);
  static const Color solarizedBorder = Color(0xFF657B83);
  static const Color solarizedTextPrimary = Color(0xFFFDF6E3);
  static const Color solarizedTextSecondary = Color(0xFF93A1A1);
  static const Color solarizedYellow = Color(0xFFB58900);
  static const Color solarizedOrange = Color(0xFFCB4B16);
  static const Color solarizedRed = Color(0xFFDC322F);
  static const Color solarizedMagenta = Color(0xFFD33682);
  static const Color solarizedViolet = Color(0xFF6C71C4);
  static const Color solarizedBlue = Color(0xFF268BD2);
  static const Color solarizedCyan = Color(0xFF2AA198);
  static const Color solarizedGreen = Color(0xFF859900);

  // GRUVBOX Theme Colors
  static const Color gruvboxBackground = Color(0xFF282828);
  static const Color gruvboxSurface = Color(0xFF3C3836);
  static const Color gruvboxBorder = Color(0xFF504945);
  static const Color gruvboxTextPrimary = Color(0xFFEBDBB2);
  static const Color gruvboxTextSecondary = Color(0xFF928374);
  static const Color gruvboxRed = Color(0xFFCC241D);
  static const Color gruvboxGreen = Color(0xFF98971A);
  static const Color gruvboxYellow = Color(0xFFD79921);
  static const Color gruvboxBlue = Color(0xFF458588);
  static const Color gruvboxPurple = Color(0xFFB16286);
  static const Color gruvboxOrange = Color(0xFFD65D0E);
  static const Color gruvboxAqua = Color(0xFF689D6A);

  // GITHUB Theme Colors
  static const Color githubBackground = Color(0xFF0D1117);
  static const Color githubSurface = Color(0xFF161B22);
  static const Color githubBorder = Color(0xFF30363D);
  static const Color githubTextPrimary = Color(0xFFF0F6FC);
  static const Color githubTextSecondary = Color(0xFF8B949E);
  static const Color githubBlue = Color(0xFF58A6FF);
  static const Color githubGreen = Color(0xFF3FB950);
  static const Color githubYellow = Color(0xFFD29922);
  static const Color githubOrange = Color(0xFFFB850F);
  static const Color githubRed = Color(0xFFF85149);
  static const Color githubPurple = Color(0xFFA371F7);

  // VS CODE Theme Colors
  static const Color vscodeBackground = Color(0xFF1E1E1E);
  static const Color vscodeSurface = Color(0xFF252526);
  static const Color vscodeBorder = Color(0xFF333333);
  static const Color vscodeTextPrimary = Color(0xFFFFFFFF);
  static const Color vscodeTextSecondary = Color(0xFF969696);
  static const Color vscodeBlue = Color(0xFF569CD6);
  static const Color vscodeGreen = Color(0xFF4EC9B0);
  static const Color vscodeYellow = Color(0xFFDCDCAA);
  static const Color vscodeRed = Color(0xFFF44747);
  static const Color vscodePurple = Color(0xFFC586C0);
  static const Color vscodeOrange = Color(0xFFCE9178);

  // MONOKAI Theme Colors
  static const Color monokaiBackground = Color(0xFF272822);
  static const Color monokaiSurface = Color(0xFF1E1F1C);
  static const Color monokaiBorder = Color(0xFF49483E);
  static const Color monokaiTextPrimary = Color(0xFFF8F8F2);
  static const Color monokaiTextSecondary = Color(0xFF75715E);
  static const Color monokaiPink = Color(0xFFF92672);
  static const Color monokaiGreen = Color(0xFFA6E22E);
  static const Color monokaiYellow = Color(0xFFE6DB74);
  static const Color monokaiBlue = Color(0xFF66D9EF);
  static const Color monokaiOrange = Color(0xFFFD971F);
  static const Color monokaiPurple = Color(0xFFAE81FF);

  // ONE DARK Theme Colors
  static const Color oneDarkBackground = Color(0xFF21252B);
  static const Color oneDarkSurface = Color(0xFF282C34);
  static const Color oneDarkBorder = Color(0xFF3E4451);
  static const Color oneDarkTextPrimary = Color(0xFFABB2BF);
  static const Color oneDarkTextSecondary = Color(0xFF5C6370);
  static const Color oneDarkRed = Color(0xFFE06C75);
  static const Color oneDarkOrange = Color(0xFFD19A66);
  static const Color oneDarkYellow = Color(0xFFE5C07B);
  static const Color oneDarkGreen = Color(0xFF98C379);
  static const Color oneDarkCyan = Color(0xFF56B6C2);
  static const Color oneDarkBlue = Color(0xFF61AFEF);
  static const Color oneDarkPurple = Color(0xFFC678DD);

  // Default Theme Colors (for backward compatibility)
  static const Color darkBackground = Color(0xFF0A0B10);
  static const Color darkSurface = Color(0xFF131620);
  static const Color darkSurfaceHighlight = Color(0xFF1A1E2C);
  static const Color darkBorder = Color(0xFF222736);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData getPresetTheme(PresetTheme preset) {
    switch (preset) {
      case PresetTheme.dracula:
        return _buildDraculaTheme();
      case PresetTheme.nord:
        return _buildNordTheme();
      case PresetTheme.solarized:
        return _buildSolarizedTheme();
      case PresetTheme.gruvbox:
        return _buildGruvboxTheme();
      case PresetTheme.github:
        return _buildGithubTheme();
      case PresetTheme.vscode:
        return _buildVSCodeTheme();
      case PresetTheme.monokai:
        return _buildMonokaiTheme();
      case PresetTheme.oneDark:
        return _buildOneDarkTheme();
    }
  }

  static ThemeData _buildDraculaTheme() {
    return _buildThemeData(
      background: draculaBackground,
      surface: draculaSurface,
      border: draculaBorder,
      textPrimary: draculaTextPrimary,
      textSecondary: draculaTextSecondary,
      primaryColor: draculaPink,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildNordTheme() {
    return _buildThemeData(
      background: nordBackground,
      surface: nordSurface,
      border: nordBorder,
      textPrimary: nordTextPrimary,
      textSecondary: nordTextSecondary,
      primaryColor: nordBlue,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildSolarizedTheme() {
    return _buildThemeData(
      background: solarizedBackground,
      surface: solarizedSurface,
      border: solarizedBorder,
      textPrimary: solarizedTextPrimary,
      textSecondary: solarizedTextSecondary,
      primaryColor: solarizedBlue,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildGruvboxTheme() {
    return _buildThemeData(
      background: gruvboxBackground,
      surface: gruvboxSurface,
      border: gruvboxBorder,
      textPrimary: gruvboxTextPrimary,
      textSecondary: gruvboxTextSecondary,
      primaryColor: gruvboxGreen,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildGithubTheme() {
    return _buildThemeData(
      background: githubBackground,
      surface: githubSurface,
      border: githubBorder,
      textPrimary: githubTextPrimary,
      textSecondary: githubTextSecondary,
      primaryColor: githubBlue,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildVSCodeTheme() {
    return _buildThemeData(
      background: vscodeBackground,
      surface: vscodeSurface,
      border: vscodeBorder,
      textPrimary: vscodeTextPrimary,
      textSecondary: vscodeTextSecondary,
      primaryColor: vscodeBlue,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildMonokaiTheme() {
    return _buildThemeData(
      background: monokaiBackground,
      surface: monokaiSurface,
      border: monokaiBorder,
      textPrimary: monokaiTextPrimary,
      textSecondary: monokaiTextSecondary,
      primaryColor: monokaiPink,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildOneDarkTheme() {
    return _buildThemeData(
      background: oneDarkBackground,
      surface: oneDarkSurface,
      border: oneDarkBorder,
      textPrimary: oneDarkTextPrimary,
      textSecondary: oneDarkTextSecondary,
      primaryColor: oneDarkBlue,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildThemeData({
    required Color background,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Brightness brightness,
  }) {
    final baseTextStyle = TextStyle(
      fontFamily: 'Inter',
      letterSpacing: -0.01,
      color: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        secondaryContainer: surface.withOpacity(0.8),
        outline: border,
      ),

      scaffoldBackgroundColor: background,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: textPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: baseTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: baseTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withOpacity(0.8),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      ),

      textTheme: TextTheme(
        headlineLarge: baseTextStyle.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: baseTextStyle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextStyle.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: baseTextStyle.copyWith(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: baseTextStyle.copyWith(
          fontSize: 12,
          color: textSecondary.withOpacity(0.7),
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: textSecondary, size: 22),
    );
  }

  static ThemeData getTheme({
    required ThemeMode mode,
    required AppThemeColor color,
  }) {
    final isDark = mode == ThemeMode.dark;
    final primaryColor = color.color;

    final background = isDark ? darkBackground : lightBackground;
    final surface = isDark ? darkSurface : lightSurface;
    final border = isDark ? darkBorder : lightBorder;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    // Define a base text style for consistency
    final baseTextStyle = TextStyle(
      fontFamily: 'Inter',
      letterSpacing: -0.01, // Modern tight tracking
      color: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: isDark ? Brightness.dark : Brightness.light,

      // Sophisticated Color Scheme
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryColor, // Could use a variation if needed
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        secondaryContainer: isDark ? darkSurfaceHighlight : Color(0xFFF9FAFB),
        outline: border,
      ),

      scaffoldBackgroundColor: background,

      // Modern AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0, // Keep flat when scrolling
        backgroundColor: background,
        foregroundColor: textPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: baseTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      // Premium Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 2, // Soft shadow in light, flat in dark
        shadowColor: Colors.black.withOpacity(0.05),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Softer corners
          side: isDark ? BorderSide(color: border, width: 1) : BorderSide.none,
        ),
      ),

      // Modern Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4), // Colored shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: baseTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Clean Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurfaceHighlight : Color(0xFFF9FAFB),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.transparent), // Cleaner look
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      ),

      // Refined Typography
      textTheme: TextTheme(
        headlineLarge: baseTextStyle.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: baseTextStyle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextStyle.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: baseTextStyle.copyWith(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: baseTextStyle.copyWith(
          fontSize: 12,
          color: textSecondary.withOpacity(0.7),
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: textSecondary, size: 22),
    );
  }

  // Backward compatibility
  static ThemeData get lightTheme =>
      getTheme(mode: ThemeMode.light, color: AppThemeColor.indigo);
  static ThemeData get darkTheme =>
      getTheme(mode: ThemeMode.dark, color: AppThemeColor.indigo);
}

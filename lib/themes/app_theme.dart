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

class AppTheme {
  // Premium Color Palette
  
  // DARK MODE (Midnight Professional)
  static const Color darkBackground = Color(0xFF0B0E14); // Deepest rich blue-black
  static const Color darkSurface = Color(0xFF151922);    // Slightly lighter rich gray-blue
  static const Color darkSurfaceHighlight = Color(0xFF1F2430); // Lighter for hover/active
  static const Color darkBorder = Color(0xFF2A303C);     // Subtle cool border
  static const Color darkTextPrimary = Color(0xFFF8F9FA); // Crisp white
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // Cool gray
  
  // LIGHT MODE (Clean Slate)
  static const Color lightBackground = Color(0xFFF3F4F6); // Cool gray background
  static const Color lightSurface = Color(0xFFFFFFFF);    // Pure white surface
  static const Color lightBorder = Color(0xFFE5E7EB);     // Subtle border
  static const Color lightTextPrimary = Color(0xFF111827); // Nearly black
  static const Color lightTextSecondary = Color(0xFF6B7280); // Mid gray

  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData getTheme({
    required ThemeMode mode, 
    required AppThemeColor color
  }) {
    final isDark = mode == ThemeMode.dark;
    final primaryColor = color.color; // The accent color selected by user
    
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
        surfaceContainerHighest: isDark ? darkSurfaceHighlight : Color(0xFFF9FAFB),
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
          textStyle: baseTextStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        headlineLarge: baseTextStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: baseTextStyle.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
        titleLarge: baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: baseTextStyle.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: baseTextStyle.copyWith(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall: baseTextStyle.copyWith(fontSize: 12, color: textSecondary.withOpacity(0.7)),
      ),
      
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      
      iconTheme: IconThemeData(
        color: textSecondary,
        size: 22,
      ),
    );
  }

  // Backward compatibility
  static ThemeData get lightTheme => getTheme(mode: ThemeMode.light, color: AppThemeColor.indigo);
  static ThemeData get darkTheme => getTheme(mode: ThemeMode.dark, color: AppThemeColor.indigo);
}

import 'package:flutter/material.dart';

/// Constants for graph physics and rendering
/// Eliminates magic numbers from the codebase
class GraphConstants {
  // Physics constants
  static const double repulsionForce = 1500.0;
  static const double attractionForce = 0.15;
  static const double damping = 0.8;
  static const double centerForce = 0.05;
  static const double movementThreshold = 0.01;
  static const double maxRepulsionDistance = 400.0;
  static const double minDistance = 1.0;

  // Node rendering constants
  static const double baseNodeRadius = 6.0;
  static const double radiusPerConnection = 1.5;
  static const double maxNodeRadius = 25.0;
  static const double nodeGlowRadiusSmall = 6.0;
  static const double nodeGlowRadiusLarge = 12.0;
  static const double nodeGlowOpacity = 0.2;
  static const double labelOffset = 4.0;
  static const double tapRadius = 30.0;

  // Ghost node constants
  static const double ghostOpacity = 0.5;
  static const double ghostLabelOpacity = 0.5;
  static const double realLabelOpacity = 0.9;

  // Text rendering constants
  static const double smallFontSize = 10.0;
  static const double largeFontSize = 12.0;
  static const double connectionThresholdForLargeFont = 15.0;

  // Edge rendering constants
  static const double edgeStrokeWidth = 1.0;
  static const double edgeOpacity = 0.2;

  // Layout constants
  static const double initialSpreadRadius = 200.0;
  static const double ghostSpreadRadius = 100.0;
  static const double canvasSize = 4000.0;
  static const double boundaryMargin = 2000.0;

  // Interactive viewer constants
  static const double minScale = 0.1;
  static const double maxScale = 3.0;

  // Quadtree constants
  static const int quadtreeMaxNodesPerCell = 8;
  static const int quadtreeMaxDepth = 8;

  // Performance constants
  static const int physicsFps = 60;
  static const Duration physicsFrameDuration = Duration(
    milliseconds: 16,
  ); // ~60 FPS
  static const int maxNodesForDirectCalculation = 100;

  // Colors
  static const Color backgroundColor = Color(0xFF1E1E1E);
  static const Color edgeColor = Colors.grey;
  static const Color ghostNodeColor = Colors.grey;
  static const Color labelColor = Colors.white;
  static const Shadow labelShadow = Shadow(blurRadius: 2, color: Colors.black);

  // Font weights
  static const FontWeight normalFontWeight = FontWeight.normal;
  static const FontWeight boldFontWeight = FontWeight.bold;

  /// Calculate node radius based on connection count
  static double calculateNodeRadius(int connectionCount) {
    final calculatedRadius =
        baseNodeRadius + (connectionCount * radiusPerConnection);
    return calculatedRadius.clamp(baseNodeRadius, maxNodeRadius);
  }

  /// Calculate font size based on node radius
  static double calculateFontSize(double radius) {
    return radius > connectionThresholdForLargeFont
        ? largeFontSize
        : smallFontSize;
  }

  /// Calculate font weight based on node radius
  static FontWeight calculateFontWeight(double radius) {
    return radius > connectionThresholdForLargeFont
        ? boldFontWeight
        : normalFontWeight;
  }

  /// Get edge paint with configured constants
  static Paint getEdgePaint() {
    return Paint()
      ..color = edgeColor.withOpacity(edgeOpacity)
      ..strokeWidth = edgeStrokeWidth;
  }

  /// Get node paint with color
  static Paint getNodePaint(Color color) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.fill;
  }

  /// Get glow paint for node
  static Paint getGlowPaint(Color color, double radius) {
    final glowRadius = radius > connectionThresholdForLargeFont
        ? nodeGlowRadiusLarge
        : nodeGlowRadiusSmall;

    return Paint()
      ..color = color.withOpacity(nodeGlowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
  }

  /// Get text style for node label
  static TextStyle getLabelStyle({
    required bool isGhost,
    required double radius,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final dynamicLabelColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dynamicLabelShadow = isDark
        ? const Shadow(blurRadius: 2, color: Colors.black87)
        : Shadow(blurRadius: 4, color: Colors.white.withOpacity(0.9));

    return TextStyle(
      color: dynamicLabelColor.withOpacity(
        isGhost ? ghostLabelOpacity : realLabelOpacity,
      ),
      fontSize: calculateFontSize(radius),
      fontWeight: calculateFontWeight(radius),
      shadows: [dynamicLabelShadow],
    );
  }
}

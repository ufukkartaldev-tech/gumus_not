import 'package:flutter/material.dart';
import '../models/graph_models.dart';
import '../constants/graph_constants.dart';

/// Custom painter for graph rendering
/// Separates rendering logic from UI and physics
class GraphCustomPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final ThemeData theme;
  final bool showPerformanceOverlay;
  final Map<String, dynamic>? performanceStats;

  GraphCustomPainter({
    required this.nodes,
    required this.edges,
    required this.theme,
    this.showPerformanceOverlay = false,
    this.performanceStats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
    _paintNodes(canvas);

    if (showPerformanceOverlay) {
      _paintPerformanceOverlay(canvas, size);
    }
  }

  void _paintEdges(Canvas canvas) {
    final edgePaint = GraphConstants.getEdgePaint();

    for (final edge in edges) {
      canvas.drawLine(edge.source.position, edge.target.position, edgePaint);
    }
  }

  void _paintNodes(Canvas canvas) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      _paintNode(canvas, node, textPainter);
    }
  }

  void _paintNode(Canvas canvas, GraphNode node, TextPainter textPainter) {
    final radius = GraphConstants.calculateNodeRadius(node.connectionCount);
    final nodeColor = node.isGhost
        ? GraphConstants.ghostNodeColor.withOpacity(GraphConstants.ghostOpacity)
        : theme.primaryColor;

    // Paint glow for real nodes
    if (!node.isGhost) {
      final glowPaint = GraphConstants.getGlowPaint(nodeColor, radius);
      canvas.drawCircle(node.position, radius + 5, glowPaint);
    }

    // Paint node
    final nodePaint = GraphConstants.getNodePaint(nodeColor);
    canvas.drawCircle(node.position, radius, nodePaint);

    // Paint label
    _paintNodeLabel(canvas, node, radius, textPainter);
  }

  void _paintNodeLabel(
    Canvas canvas,
    GraphNode node,
    double radius,
    TextPainter textPainter,
  ) {
    final textStyle = GraphConstants.getLabelStyle(
      isGhost: node.isGhost,
      radius: radius,
      theme: theme,
    );

    textPainter.text = TextSpan(text: node.label, style: textStyle);

    textPainter.layout();

    final labelPosition =
        node.position +
        Offset(-textPainter.width / 2, radius + GraphConstants.labelOffset);

    textPainter.paint(canvas, labelPosition);
  }

  void _paintPerformanceOverlay(Canvas canvas, Size size) {
    if (performanceStats == null) return;

    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      backgroundColor: Colors.black54,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final statsText =
        '''
Nodes: ${performanceStats!['nodeCount'] ?? 0}
Edges: ${performanceStats!['edgeCount'] ?? 0}
FPS: ${performanceStats!['fps']?.toStringAsFixed(1) ?? 'N/A'}
Frame: ${performanceStats!['averageFrameTime']?.toStringAsFixed(1) ?? 'N/A'}ms
Quadtree: ${performanceStats!['leafCount'] ?? 0} leaves
''';

    textPainter.text = TextSpan(text: statsText, style: textStyle);
    textPainter.layout();

    final overlayPosition = Offset(10, 10);
    textPainter.paint(canvas, overlayPosition);
  }

  @override
  bool shouldRepaint(covariant GraphCustomPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        edges != oldDelegate.edges ||
        theme != oldDelegate.theme ||
        showPerformanceOverlay != oldDelegate.showPerformanceOverlay;
  }

  /// Find node at position (for tap detection)
  GraphNode? findNodeAtPosition(Offset position, double maxDistance) {
    GraphNode? closestNode;
    double closestDistance = maxDistance;

    for (final node in nodes) {
      final distance = (node.position - position).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestNode = node;
      }
    }

    return closestNode;
  }

  /// Get bounding box of all nodes
  Rect getBoundingBox() {
    if (nodes.isEmpty) {
      return Rect.zero;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes) {
      minX = node.position.dx < minX ? node.position.dx : minX;
      minY = node.position.dy < minY ? node.position.dy : minY;
      maxX = node.position.dx > maxX ? node.position.dx : maxX;
      maxY = node.position.dy > maxY ? node.position.dy : maxY;
    }

    // Add padding
    const padding = 50.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }
}

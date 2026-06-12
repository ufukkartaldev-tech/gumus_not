import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' hide Character, Colors;
import '../models/graph_models.dart';
import '../rendering/graph_custom_painter.dart';
import '../constants/graph_constants.dart';

/// Handles user interactions with the graph
class GraphInteractionHandler {
  final TransformationController transformationController;
  final GraphCustomPainter painter;
  final Function(GraphNode) onNodeTap;
  final Function()? onGraphTap;
  
  GraphInteractionHandler({
    required this.transformationController,
    required this.painter,
    required this.onNodeTap,
    this.onGraphTap,
  });
  
  /// Handle tap on the graph
  void handleTap(TapUpDetails details, BuildContext context) {
    final localPosition = _getLocalPosition(details, context);
    final graphSpacePosition = _transformToGraphSpace(localPosition);
    
    // Check if a node was tapped
    final tappedNode = painter.findNodeAtPosition(
      graphSpacePosition,
      GraphConstants.tapRadius,
    );
    
    if (tappedNode != null) {
      onNodeTap(tappedNode);
    } else if (onGraphTap != null) {
      onGraphTap!();
    }
  }
  
  /// Handle double tap (zoom to fit)
  void handleDoubleTap() {
    final boundingBox = painter.getBoundingBox();
    if (boundingBox != Rect.zero) {
      _zoomToBoundingBox(boundingBox);
    }
  }
  
  /// Handle pinch/zoom gestures
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // Scale is handled by InteractiveViewer
    // This method can be extended for custom scale handling
  }
  
  /// Handle pan gestures
  void handlePanUpdate(DragUpdateDetails details) {
    // Pan is handled by InteractiveViewer
    // This method can be extended for custom pan handling
  }
  
  /// Reset view to center
  void resetView() {
    transformationController.value = Matrix4.identity();
  }
  
  /// Zoom to fit all nodes
  void zoomToFit() {
    final boundingBox = painter.getBoundingBox();
    if (boundingBox != Rect.zero) {
      _zoomToBoundingBox(boundingBox);
    }
  }
  
  /// Zoom to a specific node
  void zoomToNode(GraphNode node) {
    final nodeRect = Rect.fromCircle(
      center: node.position,
      radius: GraphConstants.maxNodeRadius * 2,
    );
    _zoomToBoundingBox(nodeRect);
  }
  
  /// Get local position from global tap details
  Offset _getLocalPosition(TapUpDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    return box.globalToLocal(details.globalPosition);
  }
  
  /// Transform local position to graph space
  Offset _transformToGraphSpace(Offset localPosition) {
    final inverseTransform = Matrix4.inverted(transformationController.value);
    final transformed = inverseTransform.transform3(
      Vector3(localPosition.dx, localPosition.dy, 0),
    );
    return Offset(transformed.x, transformed.y);
  }
  
  /// Zoom to a bounding box
  void _zoomToBoundingBox(Rect boundingBox) {
    final screenWidth = 800.0; // Default, will be updated by widget
    final screenHeight = 600.0; // Default, will be updated by widget
    
    final scaleX = screenWidth / boundingBox.width;
    final scaleY = screenHeight / boundingBox.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.8; // 80% padding
    
    final translateX = (screenWidth / 2) - (boundingBox.center.dx * scale);
    final translateY = (screenHeight / 2) - (boundingBox.center.dy * scale);
    
    final matrix = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
    
    transformationController.value = matrix;
  }
  
  /// Get current scale factor
  double getCurrentScale() {
    final matrix = transformationController.value;
    // Extract scale from matrix (simplified)
    return matrix.getMaxScaleOnAxis();
  }
  
  /// Get current translation
  Offset getCurrentTranslation() {
    final matrix = transformationController.value;
    return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
  }
  
  /// Check if view is at default position
  bool isAtDefaultPosition() {
    return transformationController.value == Matrix4.identity();
  }
  
  /// Animate to a specific transformation
  Future<void> animateTo(Matrix4 targetMatrix, {Duration duration = const Duration(milliseconds: 500)}) async {
    final animationController = AnimationController(
      duration: duration,
      vsync: TickerProviderImpl(),
    );
    
    final animation = Matrix4Tween(
      begin: transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    ));
    
    animation.addListener(() {
      transformationController.value = animation.value;
    });
    
    await animationController.forward();
    animationController.dispose();
  }
}

/// Simple ticker provider for animations
class TickerProviderImpl extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}
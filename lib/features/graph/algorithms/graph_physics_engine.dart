import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/graph_models.dart';
import 'quadtree.dart';
import '../constants/graph_constants.dart';

/// Message types for isolate communication
enum PhysicsMessageType {
  initialize,
  updatePhysics,
  stop,
  dispose,
}

/// Message sent to physics isolate
class PhysicsMessage {
  final PhysicsMessageType type;
  final List<GraphNode>? nodes;
  final List<GraphEdge>? edges;
  final Size? screenSize;
  final SendPort? responsePort;

  PhysicsMessage({
    required this.type,
    this.nodes,
    this.edges,
    this.screenSize,
    this.responsePort,
  });
}

/// Response from physics isolate
class PhysicsResponse {
  final List<GraphNode> nodes;
  final bool hasMovement;
  final Map<String, dynamic>? stats;

  PhysicsResponse({
    required this.nodes,
    required this.hasMovement,
    this.stats,
  });
}

/// Graph physics engine that runs in a separate isolate
class GraphPhysicsEngine {
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  SendPort? _isolateSendPort;
  Isolate? _physicsIsolate;
  Future<void>? _startingFuture;
  bool _isRunning = false;
  bool _isInitialized = false;

  // Performance monitoring
  final List<double> _frameTimes = [];
  static const int _maxFrameTimeSamples = 60;

  /// Start the physics engine in a separate isolate and wait until its
  /// [SendPort] handshake completes.
  Future<void> start() async {
    if (_isRunning && _isolateSendPort != null) return;
    if (_startingFuture != null) {
      await _startingFuture;
      return;
    }

    final completer = Completer<void>();
    _startingFuture = completer.future;

    final receivePort = ReceivePort();
    _receivePort = receivePort;

    final handshakeCompleter = Completer<SendPort>();
    _receiveSubscription = receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete(message);
        }
      }
    });

    try {
      _physicsIsolate = await Isolate.spawn(
        _physicsIsolateEntry,
        receivePort.sendPort,
        debugName: 'GraphPhysicsIsolate',
      );

      await handshakeCompleter.future;
      _isRunning = true;
      completer.complete();
    } catch (e, st) {
      debugPrint('Failed to start physics isolate: $e');
      await _receiveSubscription?.cancel();
      _receiveSubscription = null;
      receivePort.close();
      _receivePort = null;
      _isolateSendPort = null;
      _physicsIsolate?.kill(priority: Isolate.immediate);
      _physicsIsolate = null;
      _isRunning = false;
      completer.completeError(e, st);
      rethrow;
    } finally {
      _startingFuture = null;
    }
  }

  /// Stop the physics engine
  Future<void> stop() async {
    if (!_isRunning) return;

    final responsePort = ReceivePort();
    try {
      _sendMessage(
        PhysicsMessage(
          type: PhysicsMessageType.stop,
          responsePort: responsePort.sendPort,
        ),
      );
      await responsePort.first.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () => true,
      );
    } finally {
      responsePort.close();
    }

    await _teardownIsolate();
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isRunning && _isolateSendPort != null) {
      final responsePort = ReceivePort();
      try {
        _sendMessage(
          PhysicsMessage(
            type: PhysicsMessageType.dispose,
            responsePort: responsePort.sendPort,
          ),
        );
        await responsePort.first.timeout(
          const Duration(milliseconds: 250),
          onTimeout: () => true,
        );
      } finally {
        responsePort.close();
      }
    }

    await _teardownIsolate();
  }

  Future<void> _teardownIsolate() async {
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolateSendPort = null;
    _physicsIsolate?.kill(priority: Isolate.immediate);
    _physicsIsolate = null;
    _isRunning = false;
    _isInitialized = false;
  }

  /// Initialize physics with nodes and edges
  Future<void> initialize({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Size screenSize,
  }) async {
    if (!_isRunning || _isolateSendPort == null) {
      await start();
    }

    final responsePort = ReceivePort();
    try {
      _sendMessage(
        PhysicsMessage(
          type: PhysicsMessageType.initialize,
          nodes: nodes,
          edges: edges,
          screenSize: screenSize,
          responsePort: responsePort.sendPort,
        ),
      );

      // Wait for initialization confirmation
      await responsePort.first;
      _isInitialized = true;
    } finally {
      responsePort.close();
    }
  }

  /// Update physics and get new node positions
  Future<PhysicsResponse> updatePhysics({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Size screenSize,
  }) async {
    if (!_isInitialized || !_isRunning || _isolateSendPort == null) {
      await initialize(nodes: nodes, edges: edges, screenSize: screenSize);
    }

    final stopwatch = Stopwatch()..start();

    final responsePort = ReceivePort();
    try {
      _sendMessage(
        PhysicsMessage(
          type: PhysicsMessageType.updatePhysics,
          nodes: nodes,
          edges: edges,
          screenSize: screenSize,
          responsePort: responsePort.sendPort,
        ),
      );

      // Wait for response from isolate
      final response = await responsePort.first as PhysicsResponse;

      stopwatch.stop();
      _recordFrameTime(stopwatch.elapsedMicroseconds / 1000.0);

      return response;
    } finally {
      responsePort.close();
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_frameTimes.isEmpty) {
      return {
        'averageFrameTime': 0.0,
        'minFrameTime': 0.0,
        'maxFrameTime': 0.0,
        'frameCount': 0,
      };
    }

    final average = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final min = _frameTimes.reduce((a, b) => a < b ? a : b);
    final max = _frameTimes.reduce((a, b) => a > b ? a : b);

    return {
      'averageFrameTime': average,
      'minFrameTime': min,
      'maxFrameTime': max,
      'frameCount': _frameTimes.length,
      'fps': average > 0 ? 1000.0 / average : 60.0,
    };
  }

  // Private methods

  void _sendMessage(PhysicsMessage message) {
    _isolateSendPort?.send(message);
  }

  void _recordFrameTime(double frameTime) {
    _frameTimes.add(frameTime);
    if (_frameTimes.length > _maxFrameTimeSamples) {
      _frameTimes.removeAt(0);
    }
  }
}

/// Physics isolate entry point
void _physicsIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  GraphPhysicsIsolate? physicsIsolate;

  receivePort.listen((dynamic message) {
    if (message is PhysicsMessage) {
      physicsIsolate = _handlePhysicsMessage(
        message,
        physicsIsolate,
        receivePort,
      );
    }
  });
}

GraphPhysicsIsolate? _handlePhysicsMessage(
  PhysicsMessage message,
  GraphPhysicsIsolate? physicsIsolate,
  ReceivePort receivePort,
) {
  switch (message.type) {
    case PhysicsMessageType.initialize:
      final nextIsolate = GraphPhysicsIsolate()
        ..initialize(
          nodes: message.nodes!,
          edges: message.edges!,
          screenSize: message.screenSize!,
        );
      message.responsePort?.send(true);
      return nextIsolate;

    case PhysicsMessageType.updatePhysics:
      final activeIsolate = physicsIsolate ??
          (GraphPhysicsIsolate()
            ..initialize(
              nodes: message.nodes!,
              edges: message.edges!,
              screenSize: message.screenSize!,
            ));
      final response = activeIsolate.updatePhysics(
        nodes: message.nodes!,
        edges: message.edges!,
        screenSize: message.screenSize!,
      );
      message.responsePort?.send(response);
      return activeIsolate;

    case PhysicsMessageType.stop:
      physicsIsolate?.stop();
      message.responsePort?.send(true);
      return physicsIsolate;

    case PhysicsMessageType.dispose:
      physicsIsolate?.dispose();
      message.responsePort?.send(true);
      receivePort.close();
      return null;
  }
}

/// Physics calculations running in isolate
class GraphPhysicsIsolate {
  late GraphSpatialIndex _spatialIndex;
  late Rect _screenBounds;
  bool _isRunning = true;

  void initialize({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Size screenSize,
  }) {
    _isRunning = true;
    _screenBounds = _computeSpatialBounds(nodes, screenSize);

    _spatialIndex = GraphSpatialIndex(
      bounds: _screenBounds,
      maxRepulsionDistance: GraphConstants.maxRepulsionDistance,
      maxNodesPerCell: GraphConstants.quadtreeMaxNodesPerCell,
    );

    _spatialIndex.rebuild(nodes);
  }

  PhysicsResponse updatePhysics({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Size screenSize,
  }) {
    if (!_isRunning) {
      return PhysicsResponse(nodes: nodes, hasMovement: false);
    }

    // Expand spatial bounds to encompass both viewport and current node spread
    final newBounds = _computeSpatialBounds(nodes, screenSize);
    if (newBounds != _screenBounds) {
      _screenBounds = newBounds;
      _spatialIndex.updateBounds(_screenBounds);
    }

    // Rebuild spatial index with current node positions BEFORE querying
    _spatialIndex.rebuild(nodes);

    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    bool hasSignificantMovement = false;

    // Choose calculation method based on node count
    final Map<GraphNode, Offset> repulsionForces;
    if (nodes.length <= GraphConstants.maxNodesForDirectCalculation) {
      // Direct calculation for small graphs
      repulsionForces = _calculateRepulsionForcesDirect(nodes);
    } else {
      // Quadtree optimization for large graphs
      repulsionForces = _spatialIndex.calculateRepulsionForces(
        nodes,
        GraphConstants.repulsionForce,
      );
    }

    // Index live nodes by ID so edge endpoints always resolve current positions
    final nodeById = <String, GraphNode>{
      for (final node in nodes) node.id: node,
    };

    // Accumulate symmetric Hooke's spring attraction forces along edges
    final attractionForces = <String, Offset>{
      for (final node in nodes) node.id: Offset.zero,
    };
    for (final edge in edges) {
      final sourceNode = nodeById[edge.source.id];
      final targetNode = nodeById[edge.target.id];
      if (sourceNode == null ||
          targetNode == null ||
          sourceNode.id == targetNode.id) {
        continue;
      }

      final springVector =
          (targetNode.position - sourceNode.position) *
          (GraphConstants.attractionForce * edge.weight);
      attractionForces[sourceNode.id] =
          attractionForces[sourceNode.id]! + springVector;
      attractionForces[targetNode.id] =
          attractionForces[targetNode.id]! - springVector;
    }

    // Apply all forces
    for (final node in nodes) {
      var totalForce = repulsionForces[node] ?? Offset.zero;
      totalForce += attractionForces[node.id] ?? Offset.zero;

      // Center gravity force
      final deltaToCenter = center - node.position;
      totalForce += deltaToCenter * GraphConstants.centerForce;

      // Apply force to velocity
      node.velocity += totalForce;

      // Update position if movement is significant
      if (node.velocity.distance > GraphConstants.movementThreshold) {
        node.position += node.velocity;
        node.velocity *= GraphConstants.damping;
        hasSignificantMovement = true;
      } else {
        node.velocity = Offset.zero;
      }
    }

    // Rebuild index with updated positions for accurate spatial stats
    _spatialIndex.rebuild(nodes);

    // Get performance stats
    final stats = _spatialIndex.getStats();
    stats.addAll({
      'nodeCount': nodes.length,
      'edgeCount': edges.length,
      'hasMovement': hasSignificantMovement,
    });

    return PhysicsResponse(
      nodes: nodes,
      hasMovement: hasSignificantMovement,
      stats: stats,
    );
  }

  Rect _computeSpatialBounds(List<GraphNode> nodes, Size screenSize) {
    double minX = 0.0;
    double minY = 0.0;
    double maxX = math.max(1.0, screenSize.width);
    double maxY = math.max(1.0, screenSize.height);

    for (final node in nodes) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
      if (node.position.dx > maxX) maxX = node.position.dx;
      if (node.position.dy > maxY) maxY = node.position.dy;
    }

    const margin = GraphConstants.maxRepulsionDistance;
    return Rect.fromLTRB(
      minX - margin,
      minY - margin,
      maxX + margin,
      maxY + margin,
    );
  }

  /// Direct repulsion force calculation (O(n²))
  /// Used for small graphs where overhead of quadtree isn't worth it
  Map<GraphNode, Offset> _calculateRepulsionForcesDirect(List<GraphNode> nodes) {
    final forces = <GraphNode, Offset>{};

    // Initialize forces to zero
    for (final node in nodes) {
      forces[node] = Offset.zero;
    }

    // Calculate repulsion between all pairs
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final nodeA = nodes[i];
        final nodeB = nodes[j];

        final delta = nodeA.position - nodeB.position;
        double distance = delta.distance;
        if (distance < GraphConstants.minDistance) {
          distance = GraphConstants.minDistance;
        }

        // Skip if too far away
        if (distance > GraphConstants.maxRepulsionDistance) continue;

        final force =
            GraphConstants.repulsionForce / (distance * distance * 0.5);
        final offset = delta / distance * force;

        forces[nodeA] = forces[nodeA]! + offset;
        forces[nodeB] = forces[nodeB]! - offset;
      }
    }

    return forces;
  }

  void stop() {
    _isRunning = false;
  }

  void dispose() {
    _isRunning = false;
    _spatialIndex.clear();
  }
}

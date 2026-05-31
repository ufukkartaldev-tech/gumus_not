import 'dart:math';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:connected_notebook/features/graph/algorithms/quadtree.dart';
import 'package:connected_notebook/features/graph/constants/graph_constants.dart';

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
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _isolateSendPort;
  Isolate? _physicsIsolate;
  bool _isRunning = false;
  bool _isInitialized = false;
  
  // Performance monitoring
  final List<double> _frameTimes = [];
  static const int _maxFrameTimeSamples = 60;
  
  /// Start the physics engine in a separate isolate
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      _physicsIsolate = await Isolate.spawn(
        _physicsIsolateEntry,
        _receivePort.sendPort,
        debugName: 'GraphPhysicsIsolate',
      );
      
      // Listen for messages from isolate
      _receivePort.listen(_handleIsolateMessage);
      
      _isRunning = true;
    } catch (e) {
      print('Failed to start physics isolate: $e');
      rethrow;
    }
  }
  
  /// Stop the physics engine
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _sendMessage(PhysicsMessage(type: PhysicsMessageType.stop));
    await Future.delayed(const Duration(milliseconds: 100));
    
    _isRunning = false;
    _isInitialized = false;
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    if (_isRunning) {
      _sendMessage(PhysicsMessage(type: PhysicsMessageType.dispose));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _receivePort.close();
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
    if (!_isRunning) {
      await start();
    }
    
    final responsePort = ReceivePort();
    _sendMessage(PhysicsMessage(
      type: PhysicsMessageType.initialize,
      nodes: nodes,
      edges: edges,
      screenSize: screenSize,
      responsePort: responsePort.sendPort,
    ));
    
    // Wait for initialization confirmation
    await responsePort.first;
    _isInitialized = true;
  }
  
  /// Update physics and get new node positions
  Future<PhysicsResponse> updatePhysics({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required Size screenSize,
  }) async {
    if (!_isInitialized) {
      await initialize(nodes: nodes, edges: edges, screenSize: screenSize);
    }
    
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    final responsePort = ReceivePort();
    _sendMessage(PhysicsMessage(
      type: PhysicsMessageType.updatePhysics,
      nodes: nodes,
      edges: edges,
      screenSize: screenSize,
      responsePort: responsePort.sendPort,
    ));
    
    // Wait for response from isolate
    final response = await responsePort.first as PhysicsResponse;
    
    // Track performance
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final frameTime = (endTime - startTime).toDouble();
    _recordFrameTime(frameTime);
    
    return response;
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
      'fps': 1000 / average,
    };
  }
  
  // Private methods
  
  void _sendMessage(PhysicsMessage message) {
    if (_isolateSendPort != null) {
      _isolateSendPort!.send(message);
    }
  }
  
  void _handleIsolateMessage(dynamic message) {
    if (message is SendPort) {
      // First message from isolate is its SendPort
      _isolateSendPort = message;
    }
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
      _handlePhysicsMessage(message, physicsIsolate);
    }
  });
}

void _handlePhysicsMessage(
  PhysicsMessage message,
  GraphPhysicsIsolate? physicsIsolate,
) {
  switch (message.type) {
    case PhysicsMessageType.initialize:
      physicsIsolate = GraphPhysicsIsolate();
      physicsIsolate.initialize(
        nodes: message.nodes!,
        edges: message.edges!,
        screenSize: message.screenSize!,
      );
      message.responsePort?.send(true);
      break;
      
    case PhysicsMessageType.updatePhysics:
      if (physicsIsolate != null) {
        final response = physicsIsolate.updatePhysics(
          nodes: message.nodes!,
          edges: message.edges!,
          screenSize: message.screenSize!,
        );
        message.responsePort?.send(response);
      }
      break;
      
    case PhysicsMessageType.stop:
      physicsIsolate?.stop();
      message.responsePort?.send(true);
      break;
      
    case PhysicsMessageType.dispose:
      physicsIsolate?.dispose();
      message.responsePort?.send(true);
      break;
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
    _screenBounds = Rect.fromLTWH(
      0,
      0,
      screenSize.width,
      screenSize.height,
    );
    
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
    
    // Update screen bounds if changed
    final newBounds = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    if (newBounds != _screenBounds) {
      _screenBounds = newBounds;
      _spatialIndex.updateBounds(_screenBounds);
    }
    
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
    
    // Update spatial index
    _spatialIndex.rebuild(nodes);
    
    // Apply all forces
    for (final node in nodes) {
      var totalForce = repulsionForces[node] ?? Offset.zero;
      
      // Attraction forces (edges)
      for (final edge in edges) {
        if (edge.source.id == node.id) {
          final delta = edge.target.position - node.position;
          totalForce += delta * GraphConstants.attractionForce;
        } else if (edge.target.id == node.id) {
          final delta = edge.source.position - node.position;
          totalForce -= delta * GraphConstants.attractionForce;
        }
      }
      
      // Center force
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
        
        final force = (GraphConstants.repulsionForce / (distance * distance * 0.5));
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
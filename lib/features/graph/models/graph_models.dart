import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

/// Graph node model
class GraphNode {
  final String id;
  final String label;
  final bool isGhost;
  int connectionCount;
  Offset position;
  Offset velocity;
  final int? noteId; // Reference to actual note ID

  GraphNode({
    required this.id,
    required this.label,
    this.isGhost = false,
    this.connectionCount = 0,
    required this.position,
    this.noteId,
  }) : velocity = Offset.zero;

  /// Create a copy of this node with updated values
  GraphNode copyWith({
    String? id,
    String? label,
    bool? isGhost,
    int? connectionCount,
    Offset? position,
    Offset? velocity,
    int? noteId,
  }) {
    return GraphNode(
      id: id ?? this.id,
      label: label ?? this.label,
      isGhost: isGhost ?? this.isGhost,
      connectionCount: connectionCount ?? this.connectionCount,
      position: position ?? this.position,
      noteId: noteId ?? this.noteId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GraphNode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GraphNode(id: $id, label: $label, connections: $connectionCount)';
  }
}

/// Graph edge model
class GraphEdge {
  final GraphNode source;
  final GraphNode target;
  final String? label;
  final double weight;

  GraphEdge(this.source, this.target, {this.label, this.weight = 1.0});

  /// Create a copy of this edge with updated values
  GraphEdge copyWith({
    GraphNode? source,
    GraphNode? target,
    String? label,
    double? weight,
  }) {
    return GraphEdge(
      source ?? this.source,
      target ?? this.target,
      label: label ?? this.label,
      weight: weight ?? this.weight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GraphEdge &&
        other.source == source &&
        other.target == target;
  }

  @override
  int get hashCode => Object.hash(source, target);

  @override
  String toString() {
    return 'GraphEdge(${source.label} -> ${target.label})';
  }
}

/// Graph controller for state management
class GraphController extends ChangeNotifier {
  List<GraphNode> nodes = [];
  List<GraphEdge> edges = [];
  bool isPhysicsRunning = false;
  bool showPerformanceOverlay = false;
  Map<String, dynamic>? performanceStats;

  /// Update nodes and edges
  void updateGraph({
    required List<GraphNode> newNodes,
    required List<GraphEdge> newEdges,
  }) {
    nodes = newNodes;
    edges = newEdges;
    notifyListeners();
  }

  /// Update physics state
  void setPhysicsRunning(bool running) {
    if (isPhysicsRunning != running) {
      isPhysicsRunning = running;
      notifyListeners();
    }
  }

  /// Toggle performance overlay
  void togglePerformanceOverlay() {
    showPerformanceOverlay = !showPerformanceOverlay;
    notifyListeners();
  }

  /// Update performance statistics
  void updatePerformanceStats(Map<String, dynamic> stats) {
    performanceStats = stats;
    if (showPerformanceOverlay) {
      notifyListeners();
    }
  }

  /// Find node by ID
  GraphNode? findNodeById(String id) {
    return nodes.firstWhereOrNull((node) => node.id == id);
  }

  /// Find node by note ID
  GraphNode? findNodeByNoteId(int noteId) {
    return nodes.firstWhereOrNull((node) => node.noteId == noteId);
  }

  /// Get edges connected to a node
  List<GraphEdge> getEdgesForNode(GraphNode node) {
    return edges.where((edge) => edge.source == node || edge.target == node).toList();
  }

  /// Get connected nodes (neighbors)
  List<GraphNode> getNeighbors(GraphNode node) {
    final neighbors = <GraphNode>{};
    for (final edge in edges) {
      if (edge.source == node) {
        neighbors.add(edge.target);
      } else if (edge.target == node) {
        neighbors.add(edge.source);
      }
    }
    return neighbors.toList();
  }

  /// Calculate graph statistics
  Map<String, dynamic> getGraphStats() {
    if (nodes.isEmpty) {
      return {
        'nodeCount': 0,
        'edgeCount': 0,
        'averageConnections': 0.0,
        'ghostCount': 0,
        'realCount': 0,
      };
    }

    final ghostCount = nodes.where((node) => node.isGhost).length;
    final realCount = nodes.length - ghostCount;
    final totalConnections = nodes.fold(0, (sum, node) => sum + node.connectionCount);
    final averageConnections = totalConnections / nodes.length;

    return {
      'nodeCount': nodes.length,
      'edgeCount': edges.length,
      'averageConnections': averageConnections,
      'ghostCount': ghostCount,
      'realCount': realCount,
      'density': edges.length / (nodes.length * (nodes.length - 1) / 2),
    };
  }

  /// Clear all data
  void clear() {
    nodes.clear();
    edges.clear();
    isPhysicsRunning = false;
    showPerformanceOverlay = false;
    performanceStats = null;
    notifyListeners();
  }
}
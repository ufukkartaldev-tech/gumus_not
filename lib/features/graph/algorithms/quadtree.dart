import 'dart:math';
import 'package:flutter/material.dart';
import '../models/graph_models.dart';

/// Quadtree node for spatial partitioning
/// Used to optimize O(n²) repulsion force calculations to O(n log n)
class QuadtreeNode {
  final Rect bounds;
  final List<QuadtreeNode> children = [];
  final List<GraphNode> nodes = [];
  final int maxNodesPerCell;
  final int maxDepth;
  bool isDivided = false;
  
  QuadtreeNode({
    required this.bounds,
    this.maxNodesPerCell = 4,
    this.maxDepth = 8,
  });
  
  /// Insert a node into the quadtree
  bool insert(GraphNode node) {
    // Check if node is within bounds
    if (!bounds.contains(node.position)) {
      return false;
    }
    
    // If not divided and under capacity, add to this node
    if (!isDivided && nodes.length < maxNodesPerCell) {
      nodes.add(node);
      return true;
    }
    
    // If not divided but at capacity, subdivide
    if (!isDivided) {
      _subdivide();
    }
    
    // Try to insert into children
    for (final child in children) {
      if (child.insert(node)) {
        return true;
      }
    }
    
    // Should never reach here if bounds check passed
    return false;
  }
  
  /// Subdivide this node into 4 children
  void _subdivide() {
    if (isDivided) return;
    
    final halfWidth = bounds.width / 2;
    final halfHeight = bounds.height / 2;
    final x = bounds.left;
    final y = bounds.top;
    
    children.addAll([
      QuadtreeNode(
        bounds: Rect.fromLTWH(x, y, halfWidth, halfHeight),
        maxNodesPerCell: maxNodesPerCell,
        maxDepth: maxDepth - 1,
      ),
      QuadtreeNode(
        bounds: Rect.fromLTWH(x + halfWidth, y, halfWidth, halfHeight),
        maxNodesPerCell: maxNodesPerCell,
        maxDepth: maxDepth - 1,
      ),
      QuadtreeNode(
        bounds: Rect.fromLTWH(x, y + halfHeight, halfWidth, halfHeight),
        maxNodesPerCell: maxNodesPerCell,
        maxDepth: maxDepth - 1,
      ),
      QuadtreeNode(
        bounds: Rect.fromLTWH(x + halfWidth, y + halfHeight, halfWidth, halfHeight),
        maxNodesPerCell: maxNodesPerCell,
        maxDepth: maxDepth - 1,
      ),
    ]);
    
    // Move existing nodes to children
    for (final node in nodes) {
      for (final child in children) {
        if (child.insert(node)) {
          break;
        }
      }
    }
    nodes.clear();
    
    isDivided = true;
  }
  
  /// Query nodes within a radius of a point
  List<GraphNode> query(Rect area) {
    final result = <GraphNode>[];
    
    // If this node doesn't intersect the query area, return empty
    if (!bounds.overlaps(area)) {
      return result;
    }
    
    // Add nodes from this cell
    for (final node in nodes) {
      if (area.contains(node.position)) {
        result.add(node);
      }
    }
    
    // Query children if divided
    if (isDivided) {
      for (final child in children) {
        result.addAll(child.query(area));
      }
    }
    
    return result;
  }
  
  /// Query nodes within a radius of a point (circular query)
  List<GraphNode> queryRadius(Offset center, double radius) {
    final queryRect = Rect.fromCircle(center: center, radius: radius);
    return query(queryRect);
  }
  
  /// Clear all nodes from the quadtree
  void clear() {
    nodes.clear();
    for (final child in children) {
      child.clear();
    }
    children.clear();
    isDivided = false;
  }
  
  /// Rebuild the quadtree with new nodes
  void rebuild(List<GraphNode> allNodes) {
    clear();
    for (final node in allNodes) {
      insert(node);
    }
  }
  
  /// Get all nodes in the quadtree (for debugging)
  List<GraphNode> getAllNodes() {
    final allNodes = <GraphNode>[];
    allNodes.addAll(nodes);
    for (final child in children) {
      allNodes.addAll(child.getAllNodes());
    }
    return allNodes;
  }
  
  /// Get statistics about the quadtree
  Map<String, dynamic> getStats() {
    int totalNodes = nodes.length;
    int leafCount = isDivided ? 0 : 1;
    int maxDepth = 0;
    
    for (final child in children) {
      final childStats = child.getStats();
      totalNodes += childStats['totalNodes'] as int;
      leafCount += childStats['leafCount'] as int;
      maxDepth = max(maxDepth, childStats['maxDepth'] as int + 1);
    }
    
    return {
      'totalNodes': totalNodes,
      'leafCount': leafCount,
      'maxDepth': maxDepth,
      'bounds': bounds,
      'isDivided': isDivided,
    };
  }
}

/// Quadtree-based spatial index for graph nodes
class GraphSpatialIndex {
  late QuadtreeNode _quadtree;
  final double _maxRepulsionDistance;
  
  GraphSpatialIndex({
    required Rect bounds,
    double maxRepulsionDistance = 400.0,
    int maxNodesPerCell = 8,
  }) : _maxRepulsionDistance = maxRepulsionDistance {
    _quadtree = QuadtreeNode(
      bounds: bounds,
      maxNodesPerCell: maxNodesPerCell,
    );
  }
  
  /// Update bounds (when screen size changes)
  void updateBounds(Rect bounds) {
    _quadtree = QuadtreeNode(
      bounds: bounds,
      maxNodesPerCell: _quadtree.maxNodesPerCell,
    );
  }
  
  /// Rebuild index with current nodes
  void rebuild(List<GraphNode> nodes) {
    _quadtree.rebuild(nodes);
  }
  
  /// Get nearby nodes for repulsion force calculation
  /// Returns a map of node -> list of nearby nodes
  Map<GraphNode, List<GraphNode>> getNearbyNodes(List<GraphNode> allNodes) {
    final nearbyMap = <GraphNode, List<GraphNode>>{};
    
    // Rebuild quadtree if empty
    if (_quadtree.getAllNodes().isEmpty) {
      _quadtree.rebuild(allNodes);
    }
    
    for (final node in allNodes) {
      final queryArea = Rect.fromCircle(
        center: node.position,
        radius: _maxRepulsionDistance,
      );
      
      final nearby = _quadtree.query(queryArea);
      // Remove self from nearby list
      nearby.removeWhere((n) => n.id == node.id);
      
      if (nearby.isNotEmpty) {
        nearbyMap[node] = nearby;
      }
    }
    
    return nearbyMap;
  }
  
  /// Optimized repulsion force calculation using quadtree
  /// Complexity: O(n log n) instead of O(n²)
  Map<GraphNode, Offset> calculateRepulsionForces(
    List<GraphNode> nodes,
    double repulsionForce,
  ) {
    final forces = <GraphNode, Offset>{};
    
    // Initialize forces to zero
    for (final node in nodes) {
      forces[node] = Offset.zero;
    }
    
    // Get nearby nodes using quadtree
    final nearbyMap = getNearbyNodes(nodes);
    
    // Calculate forces only for nearby nodes
    for (final entry in nearbyMap.entries) {
      final node = entry.key;
      final nearbyNodes = entry.value;
      
      var totalForce = Offset.zero;
      
      for (final other in nearbyNodes) {
        final delta = node.position - other.position;
        double distance = delta.distance;
        if (distance < 1) distance = 1;
        
        // Only calculate force if within max distance
        if (distance <= _maxRepulsionDistance) {
          final force = (repulsionForce / (distance * distance * 0.5));
          final offset = delta / distance * force;
          totalForce += offset;
          
          // Apply opposite force to other node
          forces[other] = forces[other]! - offset;
        }
      }
      
      forces[node] = forces[node]! + totalForce;
    }
    
    return forces;
  }
  
  /// Get statistics
  Map<String, dynamic> getStats() {
    return _quadtree.getStats();
  }
  
  /// Clear the index
  void clear() {
    _quadtree.clear();
  }
}
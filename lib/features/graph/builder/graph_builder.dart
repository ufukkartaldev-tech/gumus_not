import 'dart:math';
import 'package:collection/collection.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/graph/models/graph_models.dart';
import 'package:connected_notebook/features/graph/constants/graph_constants.dart';

/// Builds graph from notes with backlinks
class GraphBuilder {
  final Random _random = Random();
  
  /// Build graph from notes
  GraphData buildFromNotes(List<Note> notes, Size screenSize) {
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    final nodeMap = <String, GraphNode>{};
    final edges = <GraphEdge>[];
    
    // 1. Create real nodes from notes
    _createRealNodes(notes, center, nodeMap);
    
    // 2. Create edges and ghost nodes from backlinks
    _createEdgesAndGhosts(notes, nodeMap, edges, center);
    
    // 3. Calculate connection counts
    _calculateConnectionCounts(nodeMap.values.toList(), edges);
    
    return GraphData(
      nodes: nodeMap.values.toList(),
      edges: edges,
    );
  }
  
  /// Create real nodes from notes
  void _createRealNodes(
    List<Note> notes,
    Offset center,
    Map<String, GraphNode> nodeMap,
  ) {
    for (final note in notes) {
      final initialPos = center + Offset(
        (_random.nextDouble() - 0.5) * GraphConstants.initialSpreadRadius,
        (_random.nextDouble() - 0.5) * GraphConstants.initialSpreadRadius,
      );
      
      final noteId = note.id.toString();
      nodeMap[noteId] = GraphNode(
        id: noteId,
        label: note.title.isNotEmpty ? note.title : 'Adsız',
        position: initialPos,
        noteId: note.id,
      );
    }
  }
  
  /// Create edges and ghost nodes from backlinks
  void _createEdgesAndGhosts(
    List<Note> notes,
    Map<String, GraphNode> nodeMap,
    List<GraphEdge> edges,
    Offset center,
  ) {
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');
    
    for (final note in notes) {
      final sourceNode = nodeMap[note.id.toString()];
      if (sourceNode == null) continue;
      
      final matches = linkRegex.allMatches(note.content);
      for (final match in matches) {
        final targetTitle = match.group(1);
        if (targetTitle == null || targetTitle.isEmpty) continue;
        
        // Try to find target note
        final targetNote = notes.firstWhereOrNull(
          (n) => n.title.toLowerCase() == targetTitle.toLowerCase(),
        );
        
        if (targetNote != null) {
          // Real connection
          _createRealConnection(
            sourceNode,
            targetNote,
            nodeMap,
            edges,
            targetTitle,
          );
        } else {
          // Ghost connection
          _createGhostConnection(
            sourceNode,
            targetTitle,
            nodeMap,
            edges,
            center,
          );
        }
      }
    }
  }
  
  /// Create connection between real nodes
  void _createRealConnection(
    GraphNode sourceNode,
    Note targetNote,
    Map<String, GraphNode> nodeMap,
    List<GraphEdge> edges,
    String linkText,
  ) {
    final targetNode = nodeMap[targetNote.id.toString()];
    if (targetNode != null && targetNode.id != sourceNode.id) {
      // Check if edge already exists
      final existingEdge = edges.firstWhereOrNull(
        (edge) => edge.source == sourceNode && edge.target == targetNode,
      );
      
      if (existingEdge == null) {
        edges.add(GraphEdge(sourceNode, targetNode, label: linkText));
      }
    }
  }
  
  /// Create connection to ghost node
  void _createGhostConnection(
    GraphNode sourceNode,
    String targetTitle,
    Map<String, GraphNode> nodeMap,
    List<GraphEdge> edges,
    Offset center,
  ) {
    final ghostId = 'ghost_${targetTitle.hashCode}';
    var ghostNode = nodeMap[ghostId];
    
    if (ghostNode == null) {
      // Create ghost node near source
      final ghostPos = sourceNode.position + Offset(
        (_random.nextDouble() - 0.5) * GraphConstants.ghostSpreadRadius,
        (_random.nextDouble() - 0.5) * GraphConstants.ghostSpreadRadius,
      );
      
      ghostNode = GraphNode(
        id: ghostId,
        label: targetTitle,
        isGhost: true,
        position: ghostPos,
      );
      nodeMap[ghostId] = ghostNode;
    }
    
    // Check if edge already exists
    final existingEdge = edges.firstWhereOrNull(
      (edge) => edge.source == sourceNode && edge.target == ghostNode,
    );
    
    if (existingEdge == null) {
      edges.add(GraphEdge(sourceNode, ghostNode!, label: targetTitle));
    }
  }
  
  /// Calculate connection counts for each node
  void _calculateConnectionCounts(List<GraphNode> nodes, List<GraphEdge> edges) {
    // Reset counts
    for (final node in nodes) {
      node.connectionCount = 0;
    }
    
    // Count connections
    for (final edge in edges) {
      edge.source.connectionCount++;
      edge.target.connectionCount++;
    }
  }
  
  /// Update graph with new notes (incremental update)
  GraphData updateGraph(
    GraphData existingGraph,
    List<Note> updatedNotes,
    Size screenSize,
  ) {
    // For simplicity, rebuild entire graph
    // In production, you might want incremental updates
    return buildFromNotes(updatedNotes, screenSize);
  }
  
  /// Filter graph by search query
  GraphData filterGraph(GraphData graph, String query) {
    if (query.isEmpty) return graph;
    
    final normalizedQuery = query.toLowerCase();
    
    // Find nodes matching query
    final matchingNodes = graph.nodes.where((node) {
      return node.label.toLowerCase().contains(normalizedQuery) ||
             (!node.isGhost && node.noteId != null);
    }).toSet();
    
    // Find edges connected to matching nodes
    final matchingEdges = graph.edges.where((edge) {
      return matchingNodes.contains(edge.source) ||
             matchingNodes.contains(edge.target);
    }).toList();
    
    // Add nodes from matching edges
    for (final edge in matchingEdges) {
      matchingNodes.add(edge.source);
      matchingNodes.add(edge.target);
    }
    
    return GraphData(
      nodes: matchingNodes.toList(),
      edges: matchingEdges,
    );
  }
  
  /// Get subgraph around a specific node
  GraphData getSubgraph(GraphData graph, GraphNode centerNode, int depth) {
    if (depth <= 0) {
      return GraphData(nodes: [centerNode], edges: []);
    }
    
    final visitedNodes = <GraphNode>{centerNode};
    final visitedEdges = <GraphEdge>{};
    
    _exploreSubgraph(centerNode, graph.edges, visitedNodes, visitedEdges, depth);
    
    return GraphData(
      nodes: visitedNodes.toList(),
      edges: visitedEdges.toList(),
    );
  }
  
  void _exploreSubgraph(
    GraphNode currentNode,
    List<GraphEdge> allEdges,
    Set<GraphNode> visitedNodes,
    Set<GraphEdge> visitedEdges,
    int remainingDepth,
  ) {
    if (remainingDepth <= 0) return;
    
    final connectedEdges = allEdges.where((edge) {
      return edge.source == currentNode || edge.target == currentNode;
    });
    
    for (final edge in connectedEdges) {
      visitedEdges.add(edge);
      
      final neighbor = edge.source == currentNode ? edge.target : edge.source;
      if (!visitedNodes.contains(neighbor)) {
        visitedNodes.add(neighbor);
        _exploreSubgraph(
          neighbor,
          allEdges,
          visitedNodes,
          visitedEdges,
          remainingDepth - 1,
        );
      }
    }
  }
}

/// Graph data container
class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  
  GraphData({
    required this.nodes,
    required this.edges,
  });
  
  /// Get statistics
  Map<String, dynamic> get stats {
    final ghostCount = nodes.where((node) => node.isGhost).length;
    final realCount = nodes.length - ghostCount;
    
    return {
      'totalNodes': nodes.length,
      'realNodes': realCount,
      'ghostNodes': ghostCount,
      'totalEdges': edges.length,
      'averageDegree': nodes.isEmpty ? 0 : 
          edges.length * 2 / nodes.length,
    };
  }
  
  /// Check if graph is empty
  bool get isEmpty => nodes.isEmpty;
  
  /// Get bounding box
  Rect get boundingBox {
    if (nodes.isEmpty) return Rect.zero;
    
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
    
    const padding = 50.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:connected_notebook/features/graph/algorithms/quadtree.dart';
import 'package:connected_notebook/features/graph/models/graph_models.dart';

void main() {
  group('Quadtree Tests', () {
    late QuadtreeNode quadtree;
    late Rect bounds;
    
    setUp(() {
      bounds = Rect.fromLTRB(0, 0, 1000, 1000);
      quadtree = QuadtreeNode(bounds: bounds);
    });
    
    test('Insert nodes within bounds', () {
      final node1 = GraphNode(
        id: '1',
        label: 'Node 1',
        position: Offset(100, 100),
      );
      final node2 = GraphNode(
        id: '2',
        label: 'Node 2',
        position: Offset(200, 200),
      );
      
      expect(quadtree.insert(node1), isTrue);
      expect(quadtree.insert(node2), isTrue);
      
      final allNodes = quadtree.getAllNodes();
      expect(allNodes, hasLength(2));
    });
    
    test('Reject nodes outside bounds', () {
      final node = GraphNode(
        id: '1',
        label: 'Node',
        position: Offset(1500, 1500), // Outside bounds
      );
      
      expect(quadtree.insert(node), isFalse);
      expect(quadtree.getAllNodes(), isEmpty);
    });
    
    test('Subdivide when capacity exceeded', () {
      // Insert more nodes than max capacity (default is 4)
      for (int i = 0; i < 5; i++) {
        final node = GraphNode(
          id: '$i',
          label: 'Node $i',
          position: Offset(i * 50.0, i * 50.0),
        );
        quadtree.insert(node);
      }
      
      expect(quadtree.isDivided, isTrue);
      expect(quadtree.children, hasLength(4));
    });
    
    test('Query nodes within area', () {
      // Add nodes at specific positions
      final nodes = [
        GraphNode(id: '1', label: 'Node 1', position: Offset(100, 100)),
        GraphNode(id: '2', label: 'Node 2', position: Offset(200, 200)),
        GraphNode(id: '3', label: 'Node 3', position: Offset(300, 300)),
        GraphNode(id: '4', label: 'Node 4', position: Offset(400, 400)),
      ];
      
      for (final node in nodes) {
        quadtree.insert(node);
      }
      
      // Query top-left quadrant
      final queryArea = Rect.fromLTRB(0, 0, 250, 250);
      final result = quadtree.query(queryArea);
      
      expect(result, hasLength(2));
      expect(result.map((n) => n.id), contains('1'));
      expect(result.map((n) => n.id), contains('2'));
    });
    
    test('Query nodes within radius', () {
      final center = Offset(500, 500);
      final radius = 100.0;
      
      final nodes = [
        GraphNode(id: '1', label: 'Near', position: Offset(550, 550)), // Within radius
        GraphNode(id: '2', label: 'Far', position: Offset(700, 700)), // Outside radius
      ];
      
      for (final node in nodes) {
        quadtree.insert(node);
      }
      
      final result = quadtree.queryRadius(center, radius);
      
      expect(result, hasLength(1));
      expect(result.first.id, '1');
    });
    
    test('Clear removes all nodes', () {
      for (int i = 0; i < 3; i++) {
        quadtree.insert(GraphNode(
          id: '$i',
          label: 'Node $i',
          position: Offset(i * 100.0, i * 100.0),
        ));
      }
      
      expect(quadtree.getAllNodes(), hasLength(3));
      
      quadtree.clear();
      
      expect(quadtree.getAllNodes(), isEmpty);
      expect(quadtree.isDivided, isFalse);
      expect(quadtree.children, isEmpty);
    });
    
    test('Rebuild with new nodes', () {
      final initialNodes = [
        GraphNode(id: '1', label: 'Old', position: Offset(100, 100)),
      ];
      
      for (final node in initialNodes) {
        quadtree.insert(node);
      }
      
      final newNodes = [
        GraphNode(id: '2', label: 'New 1', position: Offset(200, 200)),
        GraphNode(id: '3', label: 'New 2', position: Offset(300, 300)),
      ];
      
      quadtree.rebuild(newNodes);
      
      final allNodes = quadtree.getAllNodes();
      expect(allNodes, hasLength(2));
      expect(allNodes.map((n) => n.id), contains('2'));
      expect(allNodes.map((n) => n.id), contains('3'));
      expect(allNodes.map((n) => n.id), isNot(contains('1')));
    });
    
    test('Get statistics', () {
      for (int i = 0; i < 10; i++) {
        quadtree.insert(GraphNode(
          id: '$i',
          label: 'Node $i',
          position: Offset(i * 50.0, i * 50.0),
        ));
      }
      
      final stats = quadtree.getStats();
      
      expect(stats['totalNodes'], 10);
      expect(stats['bounds'], bounds);
      expect(stats['isDivided'], isTrue);
    });
  });
  
  group('GraphSpatialIndex Tests', () {
    late GraphSpatialIndex spatialIndex;
    late Rect bounds;
    
    setUp(() {
      bounds = Rect.fromLTRB(0, 0, 1000, 1000);
      spatialIndex = GraphSpatialIndex(bounds: bounds);
    });
    
    test('Calculate repulsion forces with quadtree', () {
      final nodes = [
        GraphNode(id: '1', label: 'Node 1', position: Offset(100, 100)),
        GraphNode(id: '2', label: 'Node 2', position: Offset(120, 120)), // Close
        GraphNode(id: '3', label: 'Node 3', position: Offset(500, 500)), // Far
      ];
      
      spatialIndex.rebuild(nodes);
      
      final forces = spatialIndex.calculateRepulsionForces(nodes, 1000.0);
      
      expect(forces, hasLength(3));
      
      // Nodes 1 and 2 should have repulsion forces (they're close)
      final force1 = forces[nodes[0]];
      final force2 = forces[nodes[1]];
      final force3 = forces[nodes[2]];
      
      expect(force1, isNotNull);
      expect(force2, isNotNull);
      expect(force3, isNotNull);
      
      // Force between close nodes should be significant
      expect(force1!.distance, greaterThan(0));
      expect(force2!.distance, greaterThan(0));
      
      // Node 3 is far away, so forces should be minimal
      expect(force3!.distance, lessThan(1.0));
    });
    
    test('Get nearby nodes', () {
      final nodes = [
        GraphNode(id: '1', label: 'Node 1', position: Offset(100, 100)),
        GraphNode(id: '2', label: 'Node 2', position: Offset(150, 150)),
        GraphNode(id: '3', label: 'Node 3', position: Offset(800, 800)),
      ];
      
      spatialIndex.rebuild(nodes);
      
      final nearbyMap = spatialIndex.getNearbyNodes(nodes);
      
      expect(nearbyMap, hasLength(2)); // Node 3 is too far
      
      // Node 1 should have Node 2 as nearby
      expect(nearbyMap[nodes[0]], hasLength(1));
      expect(nearbyMap[nodes[0]]!.first.id, '2');
      
      // Node 2 should have Node 1 as nearby
      expect(nearbyMap[nodes[1]], hasLength(1));
      expect(nearbyMap[nodes[1]]!.first.id, '1');
      
      // Node 3 should have no nearby nodes
      expect(nearbyMap[nodes[2]], isNull);
    });
    
    test('Update bounds', () {
      final newBounds = Rect.fromLTRB(-500, -500, 500, 500);
      spatialIndex.updateBounds(newBounds);
      
      // After updating bounds, the quadtree should be recreated
      final stats = spatialIndex.getStats();
      expect(stats['bounds'], newBounds);
    });
    
    test('Clear index', () {
      final nodes = [
        GraphNode(id: '1', label: 'Node 1', position: Offset(100, 100)),
      ];
      
      spatialIndex.rebuild(nodes);
      
      expect(spatialIndex.getStats()['totalNodes'], 1);
      
      spatialIndex.clear();
      
      expect(spatialIndex.getStats()['totalNodes'], 0);
    });
  });
}
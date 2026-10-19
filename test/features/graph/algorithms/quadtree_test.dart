import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/graph/algorithms/quadtree.dart';
import 'package:connected_notebook/features/graph/models/graph_models.dart';

void main() {
  group('QuadtreeNode Tests', () {
    test('inserts nodes within bounds and rejects nodes outside bounds', () {
      final quadtree = QuadtreeNode(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        maxNodesPerCell: 2,
      );

      final insideNode = GraphNode(
        id: 'node1',
        label: 'Node 1',
        position: const Offset(50, 50),
      );

      final outsideNode = GraphNode(
        id: 'node2',
        label: 'Node 2',
        position: const Offset(150, 150),
      );

      expect(quadtree.insert(insideNode), isTrue);
      expect(quadtree.insert(outsideNode), isFalse);
      expect(quadtree.getAllNodes(), contains(insideNode));
      expect(quadtree.getAllNodes(), isNot(contains(outsideNode)));
    });

    test('subdivides into 4 children when capacity is exceeded', () {
      final quadtree = QuadtreeNode(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        maxNodesPerCell: 2,
        maxDepth: 3,
      );

      final n1 = GraphNode(id: '1', label: '1', position: const Offset(10, 10));
      final n2 = GraphNode(id: '2', label: '2', position: const Offset(20, 20));
      final n3 = GraphNode(id: '3', label: '3', position: const Offset(80, 80));

      expect(quadtree.insert(n1), isTrue);
      expect(quadtree.insert(n2), isTrue);
      expect(quadtree.isDivided, isFalse);

      // Inserting 3rd node triggers subdivision
      expect(quadtree.insert(n3), isTrue);
      expect(quadtree.isDivided, isTrue);
      expect(quadtree.children.length, equals(4));

      final all = quadtree.getAllNodes();
      expect(all.length, equals(3));
      expect(all.map((n) => n.id), containsAll(['1', '2', '3']));
    });

    test('query and queryRadius return only nodes inside specified region', () {
      final quadtree = QuadtreeNode(
        bounds: const Rect.fromLTWH(0, 0, 500, 500),
        maxNodesPerCell: 4,
      );

      final n1 = GraphNode(id: '1', label: 'Near', position: const Offset(50, 50));
      final n2 = GraphNode(id: '2', label: 'Also Near', position: const Offset(60, 55));
      final n3 = GraphNode(id: '3', label: 'Far', position: const Offset(400, 400));

      quadtree.insert(n1);
      quadtree.insert(n2);
      quadtree.insert(n3);

      final areaResult = quadtree.query(const Rect.fromLTWH(0, 0, 100, 100));
      expect(areaResult.map((n) => n.id), containsAll(['1', '2']));
      expect(areaResult.map((n) => n.id), isNot(contains('3')));

      final radiusResult = quadtree.queryRadius(const Offset(50, 50), 30);
      expect(radiusResult.map((n) => n.id), containsAll(['1', '2']));
      expect(radiusResult.map((n) => n.id), isNot(contains('3')));
    });

    test('clear and rebuild work correctly', () {
      final quadtree = QuadtreeNode(
        bounds: const Rect.fromLTWH(0, 0, 200, 200),
        maxNodesPerCell: 2,
      );

      final n1 = GraphNode(id: '1', label: '1', position: const Offset(30, 30));
      final n2 = GraphNode(id: '2', label: '2', position: const Offset(60, 60));
      quadtree.insert(n1);
      quadtree.insert(n2);

      expect(quadtree.getAllNodes().length, equals(2));

      quadtree.clear();
      expect(quadtree.getAllNodes(), isEmpty);
      expect(quadtree.isDivided, isFalse);

      final n3 = GraphNode(id: '3', label: '3', position: const Offset(100, 100));
      quadtree.rebuild([n1, n3]);
      expect(quadtree.getAllNodes().map((n) => n.id), containsAll(['1', '3']));
    });
  });

  group('GraphSpatialIndex Tests', () {
    test('getNearbyNodes excludes self and returns neighbors within radius', () {
      final spatialIndex = GraphSpatialIndex(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        maxRepulsionDistance: 100,
      );

      final nodeA = GraphNode(id: 'A', label: 'A', position: const Offset(100, 100));
      final nodeB = GraphNode(id: 'B', label: 'B', position: const Offset(120, 100)); // distance 20
      final nodeC = GraphNode(id: 'C', label: 'C', position: const Offset(500, 500)); // distance ~565

      final allNodes = [nodeA, nodeB, nodeC];
      spatialIndex.rebuild(allNodes);

      final nearbyMap = spatialIndex.getNearbyNodes(allNodes);

      // Node A should only see Node B
      final nearbyA = nearbyMap[nodeA];
      expect(nearbyA, isNotNull);
      expect(nearbyA!.map((n) => n.id), contains('B'));
      expect(nearbyA.map((n) => n.id), isNot(contains('A')));
      expect(nearbyA.map((n) => n.id), isNot(contains('C')));

      // Node C is isolated
      expect(nearbyMap.containsKey(nodeC), isFalse);
    });

    test('calculateRepulsionForces generates opposite repulsion vectors', () {
      final spatialIndex = GraphSpatialIndex(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        maxRepulsionDistance: 150,
      );

      // Place nodeA to the left of nodeB along the X axis
      final nodeA = GraphNode(id: 'A', label: 'A', position: const Offset(100, 200));
      final nodeB = GraphNode(id: 'B', label: 'B', position: const Offset(150, 200));

      final nodes = [nodeA, nodeB];
      final forces = spatialIndex.calculateRepulsionForces(nodes, 100.0);

      final forceA = forces[nodeA]!;
      final forceB = forces[nodeB]!;

      // Force on A should push left (negative dx), force on B should push right (positive dx)
      expect(forceA.dx, lessThan(0));
      expect(forceB.dx, greaterThan(0));
      expect(forceA.dy, closeTo(0, 0.001));
      expect(forceB.dy, closeTo(0, 0.001));
      // Magnitudes should balance
      expect(forceA.dx.abs(), closeTo(forceB.dx.abs(), 0.01));
    });
  });
}

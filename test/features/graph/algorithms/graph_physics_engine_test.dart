import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/graph/algorithms/graph_physics_engine.dart';
import 'package:connected_notebook/features/graph/models/graph_models.dart';

void main() {
  group('GraphPhysicsIsolate force symmetry & edge resolution (SRS 10.1)', () {
    test('applies symmetric Hooke spring attraction to both source and target', () {
      const screenSize = Size(1000, 1000);
      // Place two connected nodes symmetrically around center (500, 500)
      // at distance 500 (> maxRepulsionDistance = 400 so Coulomb repulsion is 0).
      final nodeA = GraphNode(
        id: '1',
        label: 'Not A',
        position: const Offset(250, 500),
      );
      final nodeB = GraphNode(
        id: '2',
        label: 'Not B',
        position: const Offset(750, 500),
      );
      final edge = GraphEdge(nodeA, nodeB);

      final isolatePhysics = GraphPhysicsIsolate()
        ..initialize(
          nodes: [nodeA, nodeB],
          edges: [edge],
          screenSize: screenSize,
        );

      final response = isolatePhysics.updatePhysics(
        nodes: [nodeA, nodeB],
        edges: [edge],
        screenSize: screenSize,
      );

      expect(response.hasMovement, isTrue);
      final updatedA = response.nodes.firstWhere((n) => n.id == '1');
      final updatedB = response.nodes.firstWhere((n) => n.id == '2');

      // Node A must move right (+X) and Node B must move left (-X) by equal magnitude.
      final deltaA = updatedA.position.dx - 250.0;
      final deltaB = 750.0 - updatedB.position.dx;
      expect(deltaA, greaterThan(0));
      expect(deltaB, greaterThan(0));
      expect(deltaA, closeTo(deltaB, 1e-6));
      expect((updatedB.position - updatedA.position).distance, lessThan(500.0));
    });

    test('resolves live node coordinates by ID even when GraphEdge holds stale snapshots', () {
      const screenSize = Size(1000, 1000);
      final staleA = GraphNode(
        id: 'a',
        label: 'A',
        position: const Offset(500, 500),
      );
      final staleB = GraphNode(
        id: 'b',
        label: 'B',
        position: const Offset(500, 500),
      );
      // Edge points to stale snapshots at identical position (zero delta if not resolved by ID).
      final staleEdge = GraphEdge(staleA, staleB);

      final liveA = GraphNode(
        id: 'a',
        label: 'A',
        position: const Offset(200, 500),
      );
      final liveB = GraphNode(
        id: 'b',
        label: 'B',
        position: const Offset(800, 500),
      );

      final isolatePhysics = GraphPhysicsIsolate()
        ..initialize(
          nodes: [liveA, liveB],
          edges: [staleEdge],
          screenSize: screenSize,
        );

      final response = isolatePhysics.updatePhysics(
        nodes: [liveA, liveB],
        edges: [staleEdge],
        screenSize: screenSize,
      );

      final updatedA = response.nodes.firstWhere((n) => n.id == 'a');
      final updatedB = response.nodes.firstWhere((n) => n.id == 'b');
      // With center force alone (0.05 * 300 = 15), dx would be 215.
      // With spring attraction resolved from live nodes (0.15 * 600 = 90), dx is 305.
      expect(updatedA.position.dx, closeTo(305.0, 1e-3));
      expect(updatedB.position.dx, closeTo(695.0, 1e-3));
    });
  });

  group('GraphPhysicsEngine Isolate lifecycle & Quadtree scaling (SRS 10.1)', () {
    test('initializes isolate handshake, updates frames, restarts cleanly after stop, and disposes', () async {
      final engine = GraphPhysicsEngine();
      addTearDown(engine.dispose);

      const screenSize = Size(800, 600);
      final n1 = GraphNode(
        id: '1',
        label: 'Kök Not',
        position: const Offset(150, 300),
      );
      final n2 = GraphNode(
        id: '2',
        label: 'Bağlı Not',
        position: const Offset(650, 300),
      );
      final edges = [GraphEdge(n1, n2)];

      await engine.initialize(
        nodes: [n1, n2],
        edges: edges,
        screenSize: screenSize,
      );

      final firstFrame = await engine.updatePhysics(
        nodes: [n1, n2],
        edges: edges,
        screenSize: screenSize,
      );

      expect(firstFrame.hasMovement, isTrue);
      expect(firstFrame.nodes, hasLength(2));
      expect(firstFrame.stats?['nodeCount'], 2);
      expect(engine.getPerformanceStats()['frameCount'], 1);

      // Stopping and calling updatePhysics again should transparently restart the isolate.
      await engine.stop();

      final restartedFrame = await engine.updatePhysics(
        nodes: firstFrame.nodes,
        edges: edges,
        screenSize: screenSize,
      );

      expect(restartedFrame.nodes, hasLength(2));
      expect(engine.getPerformanceStats()['frameCount'], 2);
    });

    test('handles >100 nodes via Quadtree including out-of-viewport coordinates', () async {
      final engine = GraphPhysicsEngine();
      addTearDown(engine.dispose);

      const screenSize = Size(800, 600);
      final nodes = List<GraphNode>.generate(
        120,
        (i) => GraphNode(
          id: 'n_$i',
          label: 'Not $i',
          // Spread across negative and >800 coordinates to exercise dynamic bounds
          position: Offset(-200.0 + (i * 12.0), -100.0 + ((i % 15) * 60.0)),
        ),
      );
      final edges = <GraphEdge>[
        for (int i = 0; i < 60; i++) GraphEdge(nodes[i], nodes[i + 60]),
      ];

      final response = await engine.updatePhysics(
        nodes: nodes,
        edges: edges,
        screenSize: screenSize,
      );

      expect(response.nodes, hasLength(120));
      expect(response.hasMovement, isTrue);
      expect(response.stats?['totalNodes'], 120);
    });
  });
}

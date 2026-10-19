import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/graph/builder/graph_builder.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() {
  group('GraphBuilder Tests', () {
    late GraphBuilder builder;

    Note createNote({
      required int id,
      required String title,
      required String content,
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        createdAt: 1000,
        updatedAt: 1000,
      );
    }

    setUp(() {
      builder = GraphBuilder();
    });

    test('buildFromNotes creates real nodes with correct titles and ids', () {
      final notes = [
        createNote(id: 1, title: 'Flutter Rehberi', content: 'İçerik 1'),
        createNote(id: 2, title: 'Dart Temelleri', content: 'İçerik 2'),
      ];

      final graph = builder.buildFromNotes(notes, const Size(800, 600));

      expect(graph.nodes.length, equals(2));
      expect(graph.nodes.any((n) => n.id == '1' && n.label == 'Flutter Rehberi'), isTrue);
      expect(graph.nodes.any((n) => n.id == '2' && n.label == 'Dart Temelleri'), isTrue);
      expect(graph.nodes.every((n) => !n.isGhost), isTrue);
    });

    test('creates directed edges between notes when wikilinks match existing notes', () {
      final notes = [
        createNote(id: 1, title: 'Ana Not', content: 'Bu not [[Hedef Not]] bağlantısına sahiptir.'),
        createNote(id: 2, title: 'Hedef Not', content: 'Hedef notun içeriği.'),
      ];

      final graph = builder.buildFromNotes(notes, const Size(800, 600));

      expect(graph.edges.length, equals(1));
      final edge = graph.edges.first;
      expect(edge.source.id, equals('1'));
      expect(edge.target.id, equals('2'));
      expect(edge.label, equals('Hedef Not'));

      // Connection counts should be incremented
      final sourceNode = graph.nodes.firstWhere((n) => n.id == '1');
      final targetNode = graph.nodes.firstWhere((n) => n.id == '2');
      expect(sourceNode.connectionCount, equals(1));
      expect(targetNode.connectionCount, equals(1));
    });

    test('creates ghost node when wikilink refers to non-existent note', () {
      final notes = [
        createNote(id: 1, title: 'Tek Not', content: 'Burada henüz yazılmamış [[Gelecek Not]] var.'),
      ];

      final graph = builder.buildFromNotes(notes, const Size(800, 600));

      // 1 real note + 1 ghost note
      expect(graph.nodes.length, equals(2));
      final ghostNode = graph.nodes.firstWhere((n) => n.isGhost);
      expect(ghostNode.label, equals('Gelecek Not'));
      expect(ghostNode.isGhost, isTrue);

      expect(graph.edges.length, equals(1));
      expect(graph.edges.first.target, equals(ghostNode));
    });

    test('does not duplicate edges for repeated links between the same nodes', () {
      final notes = [
        createNote(id: 1, title: 'Kaynak', content: '[[Hedef]] ve tekrar [[Hedef]] linki.'),
        createNote(id: 2, title: 'Hedef', content: 'İçerik.'),
      ];

      final graph = builder.buildFromNotes(notes, const Size(800, 600));
      expect(graph.edges.length, equals(1));
    });

    test('filterGraph filters matching nodes and retains connecting edges', () {
      final notes = [
        createNote(id: 1, title: 'Algoritmalar', content: 'Veri yapıları.'),
        createNote(id: 2, title: 'Yemek Tarifleri', content: 'Makarna tarifi.'),
      ];

      final graph = builder.buildFromNotes(notes, const Size(800, 600));
      final filtered = builder.filterGraph(graph, 'Algo');

      expect(filtered.nodes.any((n) => n.label.contains('Algo')), isTrue);
    });
  });
}

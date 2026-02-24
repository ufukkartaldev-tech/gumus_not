import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:vector_math/vector_math_64.dart' hide Character, Colors;
import '../models/note_model.dart';
import '../providers/note_provider.dart';

// --- GRAF MODELLERİ ---

class GraphNode {
  final String id;
  final String label;
  final bool isGhost;
  int connectionCount;
  Offset position;
  Offset velocity;

  GraphNode({
    required this.id,
    required this.label,
    this.isGhost = false,
    this.connectionCount = 0,
    required this.position,
  }) : velocity = Offset.zero;
}

class GraphEdge {
  final GraphNode source;
  final GraphNode target;

  GraphEdge(this.source, this.target);
}

class GraphController extends ChangeNotifier {
  List<GraphNode> nodes = [];
  List<GraphEdge> edges = [];
  
  // Fizik Sabitleri
  final double _repulsionForce = 1500.0;
  final double _attractionForce = 0.15;
  final double _damping = 0.8;
  final double _centerForce = 0.05;
  final double _movementThreshold = 0.01;

  void updatePhysics(Size screenSize) {
    if (nodes.isEmpty) return;
    
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    bool hasSignificantMovement = false;

    // 1. İtme Kuvveti
    for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
            final nodeA = nodes[i];
            final nodeB = nodes[j];
            var delta = nodeA.position - nodeB.position;
            double distance = delta.distance;
            if (distance < 1) distance = 1;

            if(distance > 400) continue;

            final force = (_repulsionForce / (distance * distance * 0.5)); 
            final offset = delta / distance * force;
            
            nodeA.velocity += offset;
            nodeB.velocity -= offset;
        }
    }

    // 2. Çekme Kuvveti
    for (var edge in edges) {
        final delta = edge.target.position - edge.source.position;
        final force = delta * _attractionForce;
        edge.source.velocity += force;
        edge.target.velocity -= force;
    }

    // 3. Merkeze Çekim
    for (var node in nodes) {
        final delta = center - node.position;
        node.velocity += delta * _centerForce;
    }

    // 4. Pozisyonu Güncelle
    for (var node in nodes) {
        if (node.velocity.distance > _movementThreshold) {
            node.position += node.velocity;
            node.velocity *= _damping;
            hasSignificantMovement = true;
        } else {
            node.velocity = Offset.zero;
        }
    }

    if (hasSignificantMovement) {
      notifyListeners(); // Sadece fizik değişiminde tetikle (SetState yerine)
    }
  }

  void stop() {
    for (var n in nodes) n.velocity = Offset.zero;
    notifyListeners();
  }
}

// --- EKRAN ---

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({Key? key}) : super(key: key);

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> with SingleTickerProviderStateMixin {
  final GraphController _graphController = GraphController();
  late AnimationController _physicsLoop;
  final TransformationController _transformationController = TransformationController();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _physicsLoop = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _physicsLoop.addListener(() {
      _graphController.updatePhysics(MediaQuery.of(context).size);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGraph();
    });
  }

  @override
  void dispose() {
    _physicsLoop.dispose();
    _transformationController.dispose();
    _graphController.dispose();
    super.dispose();
  }

  void _initializeGraph() {
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    Map<String, GraphNode> nodeMap = {};
    List<GraphEdge> edges = [];

    // 1. Gerçek Düğümleri Oluştur
    for (var note in notes) {
      final initialPos = center + Offset((_random.nextDouble() - 0.5) * 200, (_random.nextDouble() - 0.5) * 200);
      final noteId = note.id.toString();
      nodeMap[noteId] = GraphNode(
        id: noteId,
        label: note.title.isNotEmpty ? note.title : 'Adsız',
        position: initialPos,
      );
    }

    // 2. Bağlantıları ve Hayalet Düğümleri Analiz Et
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');
    for (var note in notes) {
      final sourceNode = nodeMap[note.id.toString()];
      if (sourceNode == null) continue;

      final matches = linkRegex.allMatches(note.content);
      for (var match in matches) {
        final targetTitle = match.group(1);
        if (targetTitle == null || targetTitle.isEmpty) continue;

        // Hedef notu bulmaya çalış
        final targetNote = notes.firstWhereOrNull((n) => n.title.toLowerCase() == targetTitle.toLowerCase());

        if (targetNote != null) {
          // GERÇEK BAĞLANTI
          final targetNode = nodeMap[targetNote.id.toString()];
          if (targetNode != null && targetNode.id != sourceNode.id) {
            edges.add(GraphEdge(sourceNode, targetNode));
            sourceNode.connectionCount++;
            targetNode.connectionCount++;
          }
        } else {
          // HAYALET BAĞLANTI (HAYALET NODE OLUŞTUR)
          final ghostId = 'ghost_$targetTitle';
          var ghostNode = nodeMap[ghostId];
          
          if (ghostNode == null) {
            final ghostPos = sourceNode.position + Offset((_random.nextDouble() - 0.5) * 100, (_random.nextDouble() - 0.5) * 100);
            ghostNode = GraphNode(
              id: ghostId,
              label: targetTitle,
              isGhost: true,
              position: ghostPos,
            );
            nodeMap[ghostId] = ghostNode;
          }
          
          edges.add(GraphEdge(sourceNode, ghostNode));
          sourceNode.connectionCount++;
          ghostNode.connectionCount++;
        }
      }
    }

    _graphController.nodes = nodeMap.values.toList();
    _graphController.edges = edges;
    _graphController.notifyListeners();
  }

  void _onTap(TapUpDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);
    final inverseTransform = Matrix4.inverted(_transformationController.value);
    final transformedTapPos = inverseTransform.transform3(Vector3(localOffset.dx, localOffset.dy, 0));
    final graphSpaceTap = Offset(transformedTapPos.x, transformedTapPos.y);

    GraphNode? clickedNode;
    double minDistance = 30.0;

    for (var node in _graphController.nodes) {
      double dist = (node.position - graphSpaceTap).distance;
      if (dist < minDistance) {
        minDistance = dist;
        clickedNode = node;
      }
    }

    if (clickedNode != null) {
      if (clickedNode.isGhost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${clickedNode.label}" henüz oluşturulmamış bir hayalet nottur.')),
        );
        return;
      }

      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final note = noteProvider.getNoteById(int.parse(clickedNode.id));
      if (note != null) {
        _graphController.stop();
        Navigator.of(context).pushNamed('/note-editor', arguments: note);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Uzay Siyahı
      appBar: AppBar(
        title: const Text('Bağlantı Grafiği', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTapUp: _onTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(2000),
          minScale: 0.1,
          maxScale: 3.0,
          child: AnimatedBuilder(
            animation: _graphController,
            builder: (context, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: GraphPainter(_graphController.nodes, _graphController.edges, Theme.of(context)),
                  size: const Size(4000, 4000),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: const Icon(Icons.center_focus_strong, color: Colors.white),
        onPressed: () {
            // Merkeze resetle
            _transformationController.value = Matrix4.identity();
        },
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final ThemeData theme;

  GraphPainter(this.nodes, this.edges, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Bağlantıları Çiz
    final edgePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    for (var edge in edges) {
      canvas.drawLine(edge.source.position, edge.target.position, edgePaint);
    }

    // 2. Düğümleri Çiz
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var node in nodes) {
      // DYNAMİC RADIUS: Bağlantı sayısına göre (Hub tespiti)
      // Radius = Base (6) + connections * 1.5 (Max limit 25)
      double radius = min(6.0 + (node.connectionCount * 1.5), 25.0);

      // GHOST STYLE: Hayalet notlar için gri ve şeffaf
      Color nodeColor = node.isGhost 
        ? Colors.grey.withOpacity(0.5) 
        : theme.primaryColor;

      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      // Glow Efekti (Gerçek notlar için daha güçlü)
      if (!node.isGhost) {
        final glowPaint = Paint()
          ..color = nodeColor.withOpacity(0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius > 15 ? 12 : 6);
        canvas.drawCircle(node.position, radius + 5, glowPaint);
      }

      // Ana Daire
      canvas.drawCircle(node.position, radius, nodePaint);
      
      // Hayaletler için kesikli çerçeve opsiyonel ama şimdilik opacity yeterli

      // Metin Etiketi (Hub'larda daha büyük, hayaletlerde daha silik)
      textPainter.text = TextSpan(
        text: node.label,
        style: TextStyle(
          color: Colors.white.withOpacity(node.isGhost ? 0.5 : 0.9),
          fontSize: radius > 15 ? 12 : 10,
          fontWeight: radius > 15 ? FontWeight.bold : FontWeight.normal,
          shadows: [const Shadow(blurRadius: 2, color: Colors.black)],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, node.position + Offset(-textPainter.width / 2, radius + 4));
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}

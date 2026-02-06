import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/note_provider.dart';

// --- GRAF MODELLERİ ---

class GraphNode {
  final String id;
  final String label;
  int connectionCount;
  Offset position;
  Offset velocity;

  GraphNode({
    required this.id,
    required this.label,
    this.connectionCount = 0,
    required this.position,
  }) : velocity = Offset.zero;
}

class GraphEdge {
  final GraphNode source;
  final GraphNode target;

  GraphEdge(this.source, this.target);
}

// --- EKRAN ---

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({Key? key}) : super(key: key);

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> with SingleTickerProviderStateMixin {
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  late AnimationController _controller;
  final Random _random = Random();
  final TransformationController _transformationController = TransformationController();

  // Fizik Sabitleri
  final double _repulsionForce = 2000.0; // İtme Gücü
  final double _attractionForce = 0.05; // Çekme Gücü (Yay)
  final double _damping = 0.9; // Sürtünme (Hız kesici)
  final double _centerForce = 0.02; // Merkeze çekim

  @override
  void initState() {
    super.initState();
    // Animasyon döngüsü (Fizik motorunu saniyede 60 kare çalıştırır)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Sonsuz döngü için placeholder
    )..repeat();
    
    _controller.addListener(_updatePhysics);

    // İlk açılışta veriyi hazırla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGraph();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _initializeGraph() {
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    Map<String, GraphNode> nodeMap = {};
    List<GraphEdge> edges = [];

    // 1. Düğümleri (Node) Oluştur
    for (var note in notes) {
      // Rastgele başlangıç pozisyonu (Merkeze yakın)
      final initialPos = center + Offset(
        (_random.nextDouble() - 0.5) * 100,
        (_random.nextDouble() - 0.5) * 100,
      );

      // Başlık boşsa ID kullan
      String label = note.title.isNotEmpty ? note.title : 'Not ${note.id}';
      
      // Node'u kaydet
      // Not ID'si string değilse (veritabanı int id verebilir), id.toString() kullan.
      // Note modelinizde id int? olabilir. Kontrol edelim.
      final noteId = note.id.toString(); 
      
      nodeMap[noteId] = GraphNode(
        id: noteId, 
        label: label, 
        position: initialPos
      );
    }

    // 2. Bağlantıları (Edge) Oluştur
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');

    for (var note in notes) {
      final sourceId = note.id.toString();
      final sourceNode = nodeMap[sourceId];
      if (sourceNode == null) continue;

      final matches = linkRegex.allMatches(note.content);
      for (var match in matches) {
        final targetTitle = match.group(1);
        if (targetTitle == null) continue;

        // İsme göre hedef notu bul
        try {
          // Basit eşleştirme (Başlık tam eşleşmeli)
          // Gerçek hayatta daha akıllı arama gerekebilir.
          final targetNote = notes.firstWhere(
            (n) => n.title.toLowerCase() == targetTitle.toLowerCase(),
            orElse: () => Note(title: '', content: '', createdAt: 0, updatedAt: 0) // Dummy
          );

          if (targetNote.title.isNotEmpty) {
            final targetId = targetNote.id.toString();
            final targetNode = nodeMap[targetId];

            if (targetNode != null && sourceId != targetId) {
              edges.add(GraphEdge(sourceNode, targetNode));
              // Bağlantı sayılarını artır (Node büyüklüğü için)
              sourceNode.connectionCount++; // Bu setter değil, basit field ise arttıramam. late final değilse.
              // GraphNode'u final olmayan connectionCount ile güncelleyeyim.
            }
          }
        } catch (e) {
          // Hata yok say
        }
      }
    }

    // Bağlantı sayılarını güncelle (Manuel, çünkü GraphNode immutable değil artık)
    for (var edge in edges) {
       // connectionCount dynamic logic needed mostly for visualization radius
    }

    setState(() {
      _nodes = nodeMap.values.toList();
      _edges = edges;
    });
  }

  void _updatePhysics() {
    if (_nodes.isEmpty) return;
    
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    // 1. İtme Kuvveti (Repulsion) - Her düğüm diğerini iter
    for (int i = 0; i < _nodes.length; i++) {
        for (int j = i + 1; j < _nodes.length; j++) {
            final nodeA = _nodes[i];
            final nodeB = _nodes[j];
            
            var delta = nodeA.position - nodeB.position;
            double distance = delta.distance;
            if (distance < 1) distance = 1; // Sıfıra bölme hatası önlemi

            // Coulomb Yasası benzeri: F = k / d
            // Yön: delta / distance
            final force = (_repulsionForce / (distance * distance * 0.5)); 
            // Çok uzakları hesaplama (Optimizasyon)
            if(distance > 300) continue;

            final offset = delta / distance * force;
            
            nodeA.velocity += offset;
            nodeB.velocity -= offset;
        }
    }

    // 2. Çekme Kuvveti (Attraction) - Bağlı düğümler birbirini çeker
    for (var edge in _edges) {
        final delta = edge.target.position - edge.source.position;
        final distance = delta.distance;
        
        // Yay Yasası: F = k * x
        final force = delta * _attractionForce;
        
        edge.source.velocity += force;
        edge.target.velocity -= force;
    }

    // 3. Merkeze Çekim (Center Gravity) - Sonsuza uçmasınlar
    for (var node in _nodes) {
        final delta = center - node.position;
        node.velocity += delta * _centerForce;
    }

    // 4. Pozisyonu Güncelle ve Hızı Sönümle
    for (var node in _nodes) {
        node.position += node.velocity;
        node.velocity *= _damping; // Sürtünme
    }

    // Eğer hareket çok azaldıysa animasyonu durdur? 
    // Hayır, "canlı" hissi için hep çalışsın (Micro-movements)
    // Ama performans için Threshold konabilir. Şimdilik kalsın.
    
    // Sadece velocity değişti, pozisyon değişti.
    // SetState çağırmaya gerek var mı? 
    // CustomPainter repaint için notify etmeli. 
    // _controller zaten her tick'te build tetikler mi? Hayır, addListener içinde setState lazım.
    if(mounted) setState(() {});
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
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity), // Sonsuz tuval
          minScale: 0.1,
          maxScale: 5.0,
          child: CustomPaint(
            painter: GraphPainter(_nodes, _edges, Theme.of(context)),
            size: Size.infinite,
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
    // 1. Bağlantıları Çiz (En alta)
    final edgePaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      canvas.drawLine(edge.source.position, edge.target.position, edgePaint);
    }

    // 2. Düğümleri Çiz
    final nodePaint = Paint()
      ..color = theme.primaryColor
      ..style = PaintingStyle.fill;
      
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var node in nodes) {
      // Düğüm Çapı (Bağlantı sayısına göre dinamik olabilir ama şimdilik sabit)
      double radius = 6.0;

      // Glow Efekti (Neon)
      final glowPaint = Paint()
        ..color = theme.primaryColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(node.position, radius + 4, glowPaint);

      // Ana Daire
      canvas.drawCircle(node.position, radius, nodePaint);

      // Metin Etiketi (Sadece node'a yakınsak veya zoom seviyesi yüksekse çizilmeli aslında)
      // Şimdilik hep çizelim ama çok küçük olmasın
      textPainter.text = TextSpan(
        text: node.label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 10,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        node.position + Offset(-textPainter.width / 2, radius + 4) // Altına ortala
      );
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return true; // Animasyon olduğu için her karede çiz
  }
}

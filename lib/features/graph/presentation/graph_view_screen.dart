import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/graph/models/graph_models.dart';
import 'package:connected_notebook/features/graph/builder/graph_builder.dart';
import 'package:connected_notebook/features/graph/algorithms/graph_physics_engine.dart';
import 'package:connected_notebook/features/graph/rendering/graph_custom_painter.dart';
import 'package:connected_notebook/features/graph/interaction/graph_interaction_handler.dart';
import 'package:connected_notebook/features/graph/constants/graph_constants.dart';

class GraphViewScreen extends StatefulWidget {
  const GraphViewScreen({Key? key}) : super(key: key);

  @override
  State<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends State<GraphViewScreen> {
  // State management
  final GraphController _graphController = GraphController();
  final TransformationController _transformationController =
      TransformationController();

  // Services
  late GraphBuilder _graphBuilder;
  late GraphPhysicsEngine _physicsEngine;
  late GraphInteractionHandler _interactionHandler;
  GraphCustomPainter? _graphPainter;

  // Animation and timing
  Timer? _physicsTimer;
  bool _isPhysicsActive = true;
  bool _isInitialized = false;

  // Performance monitoring
  Stopwatch _frameStopwatch = Stopwatch();
  double _averageFrameTime = 0.0;
  bool _didSetupDependencies = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGraph();
    });
  }

  @override
  void dispose() {
    _disposeServices();
    super.dispose();
  }

  void _initializeServices() {
    _graphBuilder = GraphBuilder();
    _physicsEngine = GraphPhysicsEngine();

    // Initialize painter with empty data (use fallback theme during initState)
    _graphPainter = GraphCustomPainter(
      nodes: [],
      edges: [],
      theme: ThemeData.dark(),
    );

    _interactionHandler = GraphInteractionHandler(
      transformationController: _transformationController,
      painter: _graphPainter!,
      onNodeTap: _handleNodeTap,
      onGraphTap: _handleGraphTap,
    );
  }

  Future<void> _disposeServices() async {
    _physicsTimer?.cancel();
    await _physicsEngine.dispose();
  }

  Future<void> _initializeGraph() async {
    final notes = Provider.of<NoteProvider>(context, listen: false).notes;
    final screenSize = MediaQuery.of(context).size;

    // Build initial graph
    final graphData = _graphBuilder.buildFromNotes(notes, screenSize);
    _graphController.updateGraph(
      newNodes: graphData.nodes,
      newEdges: graphData.edges,
    );

    // Update painter with new data
    _updatePainter();

    // Initialize physics engine
    await _physicsEngine.initialize(
      nodes: graphData.nodes,
      edges: graphData.edges,
      screenSize: screenSize,
    );

    // Start physics loop
    _startPhysicsLoop();

    _isInitialized = true;
  }

  void _updatePainter() {
    _graphPainter = GraphCustomPainter(
      nodes: _graphController.nodes,
      edges: _graphController.edges,
      theme: Theme.of(context),
      showPerformanceOverlay: _graphController.showPerformanceOverlay,
      performanceStats: _graphController.performanceStats,
    );

    // Update interaction handler
    _interactionHandler = GraphInteractionHandler(
      transformationController: _transformationController,
      painter: _graphPainter!,
      onNodeTap: _handleNodeTap,
      onGraphTap: _handleGraphTap,
    );
  }

  void _startPhysicsLoop() {
    if (!_isPhysicsActive) return;

    _physicsTimer = Timer.periodic(
      GraphConstants.physicsFrameDuration,
      (_) => _updatePhysics(),
    );
  }

  Future<void> _updatePhysics() async {
    if (!_isPhysicsActive || !_isInitialized) return;

    _frameStopwatch.start();

    try {
      final response = await _physicsEngine.updatePhysics(
        nodes: _graphController.nodes,
        edges: _graphController.edges,
        screenSize: MediaQuery.of(context).size,
      );

      if (response.hasMovement) {
        _graphController.updateGraph(
          newNodes: response.nodes,
          newEdges: _graphController.edges,
        );

        // Update performance stats
        if (response.stats != null) {
          final perfStats = _physicsEngine.getPerformanceStats();
          perfStats.addAll(response.stats!);
          _graphController.updatePerformanceStats(perfStats);
        }

        _updatePainter();
      }
    } catch (e) {
      print('Physics update error: $e');
    }

    _frameStopwatch.stop();
    _updateFrameStats();
  }

  void _updateFrameStats() {
    final frameTime = _frameStopwatch.elapsedMilliseconds.toDouble();
    _frameStopwatch.reset();

    // Exponential moving average
    const alpha = 0.1;
    _averageFrameTime = alpha * frameTime + (1 - alpha) * _averageFrameTime;
  }

  void _handleNodeTap(GraphNode node) {
    if (node.isGhost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${node.label}" henüz oluşturulmamış bir hayalet nottur.',
          ),
        ),
      );
      return;
    }

    if (node.noteId != null) {
      _togglePhysics(false);

      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final note = noteProvider.getNoteById(node.noteId!);

      if (note != null) {
        Navigator.of(context).pushNamed('/note-editor', arguments: note);
      }
    }
  }

  void _handleGraphTap() {
    // Handle empty space tap if needed
  }

  void _togglePhysics(bool active) {
    setState(() {
      _isPhysicsActive = active;
    });

    if (active) {
      _startPhysicsLoop();
    } else {
      _physicsTimer?.cancel();
      _physicsTimer = null;
    }

    _graphController.setPhysicsRunning(active);
  }

  void _togglePerformanceOverlay() {
    _graphController.togglePerformanceOverlay();
    _updatePainter();
  }

  void _resetView() {
    _interactionHandler.resetView();
  }

  void _zoomToFit() {
    _interactionHandler.zoomToFit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Bağlantı Grafiği',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        actions: [
          IconButton(
            icon: Icon(
              _isPhysicsActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: theme.iconTheme.color,
            ),
            onPressed: () => _togglePhysics(!_isPhysicsActive),
            tooltip: _isPhysicsActive ? 'Fiziği Durdur' : 'Fiziği Başlat',
          ),
          IconButton(
            icon: Icon(
              Icons.zoom_out_map_rounded,
              color: theme.iconTheme.color,
            ),
            onPressed: _zoomToFit,
            tooltip: 'Tümünü Gör',
          ),
          IconButton(
            icon: Icon(Icons.speed_rounded, color: theme.iconTheme.color),
            onPressed: _togglePerformanceOverlay,
            tooltip: 'Performans Göstergesi',
          ),
        ],
      ),
      body: GestureDetector(
        onTapUp: (details) => _interactionHandler.handleTap(details, context),
        onDoubleTap: _interactionHandler.handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(GraphConstants.boundaryMargin),
          minScale: GraphConstants.minScale,
          maxScale: GraphConstants.maxScale,
          child: AnimatedBuilder(
            animation: _graphController,
            builder: (context, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _graphPainter,
                  size: const Size(
                    GraphConstants.canvasSize,
                    GraphConstants.canvasSize,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: theme.cardTheme.color,
            foregroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.15 : 0.4),
              ),
            ),
            elevation: 4,
            child: Icon(
              _isPhysicsActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            onPressed: () => _togglePhysics(!_isPhysicsActive),
            heroTag: 'physics_toggle',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: theme.cardTheme.color,
            foregroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.15 : 0.4),
              ),
            ),
            elevation: 4,
            child: const Icon(Icons.center_focus_strong_rounded),
            onPressed: _resetView,
            heroTag: 'reset_view',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: theme.cardTheme.color,
            foregroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.15 : 0.4),
              ),
            ),
            elevation: 4,
            child: const Icon(Icons.zoom_out_map_rounded),
            onPressed: _zoomToFit,
            heroTag: 'zoom_fit',
          ),
        ],
      ),
    );
  }
}

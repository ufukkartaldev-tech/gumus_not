import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiEffect {
  static void show(BuildContext context, {Offset? offset}) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final position = offset ?? (renderBox != null ? renderBox.localToGlobal(Offset(size.width / 2, size.height / 2)) : Offset.zero);

    final List<OverlayEntry> entries = [];
    final random = Random();

    for (int i = 0; i < 15; i++) {
      late OverlayEntry entry;
      final color = [Colors.gold, Colors.yellow, Colors.green, Colors.blue, Colors.pink][random.nextInt(5)];
      final angle = random.nextDouble() * 2 * pi;
      final distance = 50.0 + random.nextDouble() * 50.0;
      final duration = Duration(milliseconds: 600 + random.nextInt(400));

      entry = OverlayEntry(
        builder: (context) => _Particle(
          startPosition: position,
          targetPosition: Offset(
            position.dx + cos(angle) * distance,
            position.dy + sin(angle) * distance,
          ),
          color: color,
          duration: duration,
          onComplete: () {
            entry.remove();
          },
        ),
      );

      overlay.insert(entry);
    }
  }
}

class _Particle extends StatefulWidget {
  final Offset startPosition;
  final Offset targetPosition;
  final Color color;
  final Duration duration;
  final VoidCallback onComplete;

  const _Particle({
    required this.startPosition,
    required this.targetPosition,
    required this.color,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_Particle> createState() => _ParticleState();
}

class _ParticleState extends State<_Particle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.targetPosition,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.outSecondary));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({super.key});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  static const int _focusTime = 25 * 60; // 25 minutes
  static const int _breakTime = 5 * 60;  // 5 minutes
  
  int _timeLeft = _focusTime;
  bool _isActive = false;
  bool _isBreak = false;
  Timer? _timer;

  void _toggleTimer() {
    setState(() {
      _isActive = !_isActive;
    });

    if (_isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timeLeft > 0) {
          setState(() {
            _timeLeft--;
          });
        } else {
          _timer?.cancel();
          _showCompletionDialog();
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _timeLeft = _isBreak ? _breakTime : _focusTime;
    });
  }

  void _switchMode() {
    _timer?.cancel();
    setState(() {
      _isBreak = !_isBreak;
      _timeLeft = _isBreak ? _breakTime : _focusTime;
      _isActive = false;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isBreak ? 'Mola Bitti!' : 'Odaklanma Tamamlandı!'),
        content: Text(_isBreak 
          ? 'Hadi tekrar çalışmaya dönelim.' 
          : 'Harika iş! Şimdi kısa bir molayı hak ettin.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchMode();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isBreak ? Colors.green : theme.primaryColor;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      color: theme.cardColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Icon
            Icon(
              _isBreak ? Icons.coffee : Icons.timer,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 12),
            
            // Time Display
            InkWell(
              onTap: _toggleTimer,
              borderRadius: BorderRadius.circular(8),
              child: Text(
                _formatTime(_timeLeft),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Interaction Buttons
            if (_isActive)
              IconButton(
                icon: const Icon(Icons.pause, size: 20),
                onPressed: _toggleTimer,
                tooltip: 'Duraklat',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 20),
                onPressed: _toggleTimer,
                tooltip: 'Başlat',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _resetTimer,
              tooltip: 'Sıfırla',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

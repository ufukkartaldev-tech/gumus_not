import 'package:flutter/material.dart';
import '../models/note_model.dart';
import 'dart:ui';

class DashboardStats extends StatelessWidget {
  final List<Note> notes;

  const DashboardStats({Key? key, required this.notes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalNotes = notes.length;
    // Basit bir regex ile kelime sayımı (boşluklara göre)
    final totalWords = notes.fold<int>(0, (prev, note) => prev + (note.content.trim().isEmpty ? 0 : note.content.trim().split(RegExp(r'\s+')).length));
    final encryptedNotes = notes.where((n) => n.isEncrypted).length;
    
    // Bağlantı sayısı: [[link]] formatındaki her şeyi sayar
    final totalLinks = notes.fold<int>(0, (prev, note) => prev + RegExp(r'\[\[.*?\]\]').allMatches(note.content).length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(context, 'Notlar', '$totalNotes', Icons.description, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(context, 'Kelimeler', _formatNumber(totalWords), Icons.text_fields, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, 'Bağlantılar', '$totalLinks', Icons.link, Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(context, 'Gizli Kasa', '$encryptedNotes', Icons.lock, Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return '$num';
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              // Opsiyonel: Artış ikonu vs. eklenebilir
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.titleLarge?.color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

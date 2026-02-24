import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_template.dart';

class TemplateSelectionScreen extends StatelessWidget {
  const TemplateSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final templates = NoteTemplate.defaultTemplates;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şablonlar'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          // Toplam 6 kart: 1 "Boş" + 5 şablon
          // 3x2 dizilim ile tek ekranda hepsi görünecek şekilde düzenlendi.
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          // Kartları biraz daha dik yaparak 2 satırın çoğu ekranda sığması sağlanır.
          childAspectRatio: 0.85,
          children: [
            _buildTemplateCard(
              context,
              name: 'Boş',
              icon: Icons.note_add_outlined,
              color: Colors.grey,
              content: '',
            ),
            ...templates.take(5).map(
              (template) => _buildTemplateCard(
                context,
                name: template.name,
                icon: template.icon,
                color: template.color,
                content: template.content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, {
    required String name,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, content);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

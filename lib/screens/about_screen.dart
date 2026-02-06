import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hakkında'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Icon(
                  Icons.edit_note_rounded, // Placeholder for the actual image asset
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'GümüşNot',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0.0 (Release)',
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Güvenli, Modern ve Bağlantılı Not Alma Deneyimi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              
              const SizedBox(height: 48),
              
              // Tech Stack Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                   _buildTechChip(context, 'Flutter', Colors.blue),
                   _buildTechChip(context, 'SQLite (FTS5 Ready)', Colors.indigo),
                   _buildTechChip(context, 'AES-256 (Paranoyak Mod)', Colors.green),
                   _buildTechChip(context, 'Force-Directed Graph', Colors.purple),
                ],
              ),
              
              const SizedBox(height: 48),
              
              // Credits
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Geliştirici',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Ufuk Kartal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text(
                      'Gümüşhane Üniversitesi',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Yazılım Mühendisliği 2. Sınıf Öğrencisi',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                       '"Gümüşhane\'den dünyaya, yerel ve güvenli not alma deneyimi."',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tüm Hakları Saklıdır © ${DateTime.now().year}',
                      style: TextStyle(
                        fontSize: 12, 
                        color: Theme.of(context).disabledColor
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTechChip(BuildContext context, String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: color.withOpacity(1.0), fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}

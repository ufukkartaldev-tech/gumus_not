import 'package:flutter/material.dart';
import '../widgets/image_picker_widget.dart';
import '../services/image_service.dart';

/// Demo widget to showcase image support features
class ImageSupportDemo extends StatefulWidget {
  const ImageSupportDemo({Key? key}) : super(key: key);

  @override
  State<ImageSupportDemo> createState() => _ImageSupportDemoState();
}

class _ImageSupportDemoState extends State<ImageSupportDemo> {
  final ImageService _imageService = ImageService();
  String? _selectedImagePath;
  List<String> _allImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllImages();
  }

  Future<void> _loadAllImages() async {
    setState(() => _isLoading = true);
    try {
      final images = await _imageService.getAllImages();
      setState(() {
        _allImages = images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resimler yüklenirken hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resim Desteği Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePickerSection(),
            const SizedBox(height: 24),
            _buildImageGallerySection(),
            const SizedBox(height: 24),
            _buildStatisticsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resim Seçici',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ImagePickerWidget(
              initialImagePath: _selectedImagePath,
              onImageSelected: (imagePath) {
                setState(() {
                  _selectedImagePath = imagePath;
                });
                if (imagePath != null) {
                  _loadAllImages(); // Refresh gallery
                }
              },
              height: 200,
            ),
            if (_selectedImagePath != null) ...[
              const SizedBox(height: 16),
              _buildSelectedImageInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImageInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seçilen Resim Bilgileri',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<double>(
            future: _imageService.getImageFileSize(_selectedImagePath!),
            builder: (context, snapshot) {
              return Text('Boyut: ${snapshot.data?.toStringAsFixed(2) ?? '...'} MB');
            },
          ),
          Text('Dosya Adı: ${_selectedImagePath!.split('/').last}'),
        ],
      ),
    );
  }

  Widget _buildImageGallerySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resim Galerisi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  onPressed: _loadAllImages,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_allImages.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Henüz resim yüklenmemiş',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              _buildImageGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _allImages.length,
      itemBuilder: (context, index) {
        final imagePath = _allImages[index];
        return _buildImageThumbnail(imagePath);
      },
    );
  }

  Widget _buildImageThumbnail(String imagePath) {
    return GestureDetector(
      onTap: () => _showFullImage(imagePath),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İstatistikler',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FutureBuilder<double>(
              future: _imageService.getTotalImagesSize(),
              builder: (context, snapshot) {
                return Column(
                  children: [
                    _buildStatRow('Toplam Resim', _allImages.length.toString()),
                    _buildStatRow(
                      'Toplam Boyut',
                      '${snapshot.data?.toStringAsFixed(2) ?? '...'} MB',
                    ),
                    _buildStatRow(
                      'Ortalama Boyut',
                      _allImages.isNotEmpty
                          ? '${(snapshot.data ?? 0) / _allImages.length} MB'
                          : '0 MB',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imagePath: imagePath),
      ),
    );
  }
}

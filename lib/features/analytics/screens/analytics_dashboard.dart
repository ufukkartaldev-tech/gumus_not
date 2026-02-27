import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import '../widgets/chart_widgets.dart';
import '../../notes/providers/note_action_provider.dart';
import '../../core/di/dependency_injection.dart';

/// Analytics Dashboard with comprehensive charts and statistics
class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnalyticsService _analyticsService;
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _analyticsService = AnalyticsService(context.noteRepository);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _analyticsService.getAnalyticsData();
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analiz verileri yüklenirken hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Paneli'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAnalyticsData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Genel', icon: Icon(Icons.dashboard)),
            Tab(text: 'Yazım', icon: Icon(Icons.edit)),
            Tab(text: 'İçerik', icon: Icon(Icons.article)),
            Tab(text: 'Zaman', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildWritingHabitsTab(),
                    _buildContentAnalysisTab(),
                    _buildTimeAnalysisTab(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Analiz verisi bulunmuyor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Notlarınız analiz edilecek kadar olduğunda burada istatistikler görünecektir',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAnalyticsData,
            child: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final overview = _analyticsData!['overview'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatsGrid(overview),
          const SizedBox(height: 24),
          _buildEngagementChart(),
        ],
      ),
    );
  }

  Widget _buildWritingHabitsTab() {
    final writingHabits = _analyticsData!['writingHabits'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWritingStats(writingHabits),
          const SizedBox(height: 24),
          LineChartWidget(
            data: writingHabits['dailyStats'] ?? [],
            title: 'Son 30 Günlük Not Eğilimi',
            height: 250,
          ),
          const SizedBox(height: 24),
          _buildProductivityInsights(writingHabits),
        ],
      ),
    );
  }

  Widget _buildContentAnalysisTab() {
    final contentAnalysis = _analyticsData!['contentAnalysis'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildContentStats(contentAnalysis),
          const SizedBox(height: 24),
          _buildTopTagsChart(contentAnalysis),
          const SizedBox(height: 24),
          _buildTopFoldersChart(contentAnalysis),
          const SizedBox(height: 24),
          _buildWordCountDistribution(contentAnalysis),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysisTab() {
    final timeAnalysis = _analyticsData!['timeAnalysis'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LineChartWidget(
            data: timeAnalysis['creationTimeline'] ?? [],
            title: 'Not Oluşturma Zaman Çizelgesi',
            height: 250,
          ),
          const SizedBox(height: 24),
          LineChartWidget(
            data: timeAnalysis['updateTimeline'] ?? [],
            title: 'Not Güncelleme Zaman Çizelgesi',
            height: 250,
            lineColor: Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildPeakHoursChart(timeAnalysis),
          const SizedBox(height: 24),
          _buildPeakDaysChart(timeAnalysis),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> overview) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Toplam Not', overview['totalNotes']?.toString() ?? '0', Icons.note),
        _buildStatCard('Toplam Kelime', overview['totalWords']?.toString() ?? '0', Icons.text_fields),
        _buildStatCard('Ortalama Kelime', '${overview['averageWordsPerNote'] ?? 0}', Icons.format_list_numbered),
        _buildStatCard('Benzersiz Etiket', overview['uniqueTags']?.toString() ?? '0', Icons.tag),
        _buildStatCard('Benzersiz Klasör', overview['uniqueFolders']?.toString() ?? '0', Icons.folder),
        _buildStatCard('Şifreli Not', '${overview['encryptedPercentage'] ?? 0}%', Icons.lock),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementChart() {
    final engagement = _analyticsData!['engagement'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Etkileşim Metriği',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (engagement['engagementScore'] ?? 0) / 100,
              backgroundColor: Theme.of(context).colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Etkileşim Skoru: ${engagement['engagementScore'] ?? 0}/100',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEngagementItem(
                    'Son 7 Gün',
                    engagement['recentActivity']?.toString() ?? '0',
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildEngagementItem(
                    'Düzenleme',
                    engagement['totalEdits']?.toString() ?? '0',
                    Icons.edit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildWritingStats(Map<String, dynamic> writingHabits) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yazım Alışkanlıkları',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWritingStat(
                    'Günlük Ortalama',
                    '${writingHabits['dailyAverage'] ?? 0} not',
                  ),
                ),
                Expanded(
                  child: _buildWritingStat(
                    'Haftalık Ortalama',
                    '${writingHabits['weeklyAverage'] ?? 0} not',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildWritingStat(
                    'En Üretken Gün',
                    writingHabits['mostProductiveDay'] ?? '-',
                  ),
                ),
                Expanded(
                  child: _buildWritingStat(
                    'En Üretken Saat',
                    '${writingHabits['mostProductiveHour'] ?? 0}:00',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildWritingStat(
                    'Mevcut Seri',
                    '${writingHabits['writingStreak'] ?? 0} gün',
                  ),
                ),
                Expanded(
                  child: _buildWritingStat(
                    'En Uzun Seri',
                    '${writingHabits['longestStreak'] ?? 0} gün',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWritingStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProductivityInsights(Map<String, dynamic> writingHabits) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verimlilik İçgörüleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              'En üretken gününüz ${writingHabits['mostProductiveDay'] ?? '-'}',
              'Bu günde daha fazla not yazıyorsunuz',
            ),
            _buildInsightItem(
              'En üretken saatiniz ${writingHabits['mostProductiveHour'] ?? 0}:00',
              'Bu saatte daha yaratıcısınız',
            ),
            _buildInsightItem(
              'Mevcut seri: ${writingHabits['writingStreak'] ?? 0} gün',
              writingHabits['writingStreak'] > 5 
                  ? 'Harika bir yazım serisi!'
                  : 'Seri devam ettirin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStats(Map<String, dynamic> contentAnalysis) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İçerik İstatistikleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildContentStat(
                    'Ortalama Kelime',
                    '${contentAnalysis['averageWordCount'] ?? 0}',
                  ),
                ),
                Expanded(
                  child: _buildContentStat(
                    'Medyan Kelime',
                    '${contentAnalysis['medianWordCount'] ?? 0}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildContentStat(
                    'Ortalama Karakter',
                    '${contentAnalysis['averageCharacterCount'] ?? 0}',
                  ),
                ),
                Expanded(
                  child: _buildContentStat(
                    'Medyan Karakter',
                    '${contentAnalysis['medianCharacterCount'] ?? 0}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTopTagsChart(Map<String, dynamic> contentAnalysis) {
    final topTags = contentAnalysis['topTags'] as List<dynamic>? ?? [];
    
    return BarChartWidget(
      data: topTags.map((tag) => {
        'label': tag['tag'],
        'count': tag['count'],
      }).toList(),
      title: 'En Popüler Etiketler',
      height: 200,
      horizontal: true,
    );
  }

  Widget _buildTopFoldersChart(Map<String, dynamic> contentAnalysis) {
    final topFolders = contentAnalysis['topFolders'] as List<dynamic>? ?? [];
    
    return BarChartWidget(
      data: topFolders.map((folder) => {
        'label': folder['folder'],
        'count': folder['count'],
      }).toList(),
      title: 'En Popüler Klasörler',
      height: 200,
      horizontal: true,
    );
  }

  Widget _buildWordCountDistribution(Map<String, dynamic> contentAnalysis) {
    final distribution = contentAnalysis['wordCountDistribution'] as List<dynamic>? ?? [];
    
    return BarChartWidget(
      data: distribution.map((item) => {
        'label': item['range'],
        'count': item['count'],
      }).toList(),
      title: 'Kelime Sayısı Dağılımı',
      height: 200,
    );
  }

  Widget _buildPeakHoursChart(Map<String, dynamic> timeAnalysis) {
    final peakHours = timeAnalysis['peakHours'] as List<dynamic>? ?? [];
    
    return BarChartWidget(
      data: peakHours.map((hour) => {
        'label': '${hour['hour']}:00',
        'count': hour['count'],
      }).toList(),
      title: 'En Yoğun Saatler',
      height: 200,
    );
  }

  Widget _buildPeakDaysChart(Map<String, dynamic> timeAnalysis) {
    final peakDays = timeAnalysis['peakDays'] as List<dynamic>? ?? [];
    
    return PieChartWidget(
      data: peakDays.map((day) => {
        'label': day['day'],
        'count': day['count'],
      }).toList(),
      title: 'Günlük Dağılım',
      height: 200,
    );
  }
}

import 'package:flutter/material.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<DateTime, int> datasets;
  final DateTime? startDate;
  final DateTime? endDate;

  const ActivityHeatmap({
    Key? key,
    required this.datasets,
    this.startDate,
    this.endDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine range: Default to last 365 days or provided range
    final end = endDate ?? DateTime.now();
    final start = startDate ?? end.subtract(const Duration(days: 364));
    
    // Normalize dates to midnight to ensure correct matching
    final normalizedDatasets = <DateTime, int>{};
    datasets.forEach((key, value) {
      final normalizedKey = DateTime(key.year, key.month, key.day);
      normalizedDatasets[normalizedKey] = (normalizedDatasets[normalizedKey] ?? 0) + value;
    });

    final totalDays = end.difference(start).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Üretkenlik Haritası',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Start from right (today)
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(totalWeeks, (weekIndex) {
                return Padding(
                  padding: const EdgeInsets.only(left: 3.0), // Gap between columns
                  child: Column(
                    children: List.generate(7, (dayIndex) {
                      // Calculate the date for this cell
                      // We start from 'start' date. 
                      // weekIndex 0 is the first week starting from 'start'.
                      // But wait, standard GitHub graph starts aligns columns by weeks.
                      // Let's iterate backwards from 'end' for 'reverse: true' visual consistency?
                      // No, simpler to build forward and just scroll to end or reverse children.
                      
                      // Let's stick to standard forward generation relative to 'start' date
                      final dayOffset = (weekIndex * 7) + dayIndex;
                      final currentDate = start.add(Duration(days: dayOffset));
                      
                      if (currentDate.isAfter(end)) {
                        return const SizedBox(width: 12, height: 12);
                      }

                      final normalizedCurrent = DateTime(currentDate.year, currentDate.month, currentDate.day);
                      final count = normalizedDatasets[normalizedCurrent] ?? 0;
                      
                      return Tooltip(
                        message: '${count} katkı\n${_formatDate(currentDate)}',
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(bottom: 3.0), // Gap between rows
                          decoration: BoxDecoration(
                            color: _getColorForCount(count, Theme.of(context)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Az', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),
              _buildLegendBox(0, context),
              _buildLegendBox(2, context),
              _buildLegendBox(4, context),
              _buildLegendBox(6, context),
              _buildLegendBox(8, context),
              const SizedBox(width: 4),
              Text('Çok', style: Theme.of(context).textTheme.bodySmall),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendBox(int level, BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _getColorForCount(level, Theme.of(context)),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForCount(int count, ThemeData theme) {
    final baseColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final emptyColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    if (count == 0) return emptyColor;
    if (count <= 2) return baseColor.withOpacity(0.2);
    if (count <= 4) return baseColor.withOpacity(0.4);
    if (count <= 6) return baseColor.withOpacity(0.6);
    if (count <= 8) return baseColor.withOpacity(0.8);
    return baseColor;
  }

  String _formatDate(DateTime date) {
    final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

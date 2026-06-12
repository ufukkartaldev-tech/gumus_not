import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Widget for displaying a line chart
/// Follows Single Responsibility Principle: Only handles line chart display
class LineChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color? lineColor;
  final bool showGrid;
  final bool showDots;
  final double? height;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.lineColor,
    this.showGrid = true,
    this.showDots = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height ?? 200,
              child: LineChart(
                LineChartData(
                  gridData: showGrid ? _buildGridData(context) : const FlGridData(show: false),
                  titlesData: _buildTitlesData(),
                  borderData: _buildBorderData(),
                  lineBarsData: [_buildLineBarData(context)],
                  lineTouchData: _buildTouchData(),
                  minX: 0,
                  maxX: data.length > 1 ? (data.length - 1).toDouble() : 1,
                  minY: 0,
                  maxY: _getMaxY(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Card(
      child: Container(
        height: height ?? 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Veri bulunmuyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlGridData _buildGridData(BuildContext context) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          strokeWidth: 1,
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          strokeWidth: 1,
        );
      },
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: _getBottomInterval(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < data.length) {
              final label = _getBottomLabel(data[index]);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const Text('');
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8,
              child: Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }

  double _getBottomInterval() {
    if (data.length <= 7) return 1;
    if (data.length <= 14) return 2;
    return (data.length / 7).ceilToDouble();
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.transparent),
    );
  }

  LineChartBarData _buildLineBarData(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['count'] ?? 0).toDouble()));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      gradient: LinearGradient(
        colors: [
          lineColor ?? Theme.of(context).colorScheme.primary,
          (lineColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.8),
        ],
      ),
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: showDots ? const FlDotData(show: true) : const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            (lineColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.3),
            (lineColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => Colors.black87,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            if (index >= 0 && index < data.length) {
              final value = data[index]['count'] ?? 0;
              final label = _getTooltipLabel(data[index]);
              return LineTooltipItem(
                '$label: $value',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }
            return null;
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    );
  }

  double _getMaxY() {
    if (data.isEmpty) return 10;
    final maxValue = data
        .map((d) => (d['count'] ?? 0) as num)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    return maxValue == 0 ? 10 : (maxValue * 1.2).ceilToDouble();
  }

  String _getBottomLabel(Map<String, dynamic> item) {
    if (item.containsKey('date')) {
      final dateStr = item['date'];
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        return '${date.day}/${date.month}';
      }
    }
    return '';
  }

  String _getTooltipLabel(Map<String, dynamic> item) {
    if (item.containsKey('date')) {
      final dateStr = item['date'];
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
    return 'Değer';
  }
}

/// Widget for displaying a bar chart
class BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color? barColor;
  final bool showGrid;
  final double? height;
  final bool horizontal;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.barColor,
    this.showGrid = true,
    this.height,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height ?? 200,
              child: horizontal ? _buildHorizontalBarChart(context) : _buildVerticalBarChart(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Card(
      child: Container(
        height: height ?? 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Veri bulunmuyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalBarChart(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: _buildBarTouchData(),
        titlesData: _buildBarTitlesData(),
        borderData: _buildBorderData(),
        barGroups: _buildBarGroups(context),
        gridData: showGrid ? _buildGridData(context) : const FlGridData(show: false),
      ),
    );
  }

  Widget _buildHorizontalBarChart(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: _buildBarTouchData(),
        titlesData: _buildHorizontalBarTitlesData(),
        borderData: _buildBorderData(),
        barGroups: _buildBarGroups(context),
        gridData: showGrid ? _buildGridData(context) : const FlGridData(show: false),
      ),
    );
  }

  FlGridData _buildGridData(BuildContext context) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          strokeWidth: 1,
        );
      },
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.transparent),
    );
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => Colors.black87,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final label = data[groupIndex]['label'] ?? 'Item ${groupIndex + 1}';
          final value = rod.toY.round();
          return BarTooltipItem(
            '$label: $value',
            const TextStyle(color: Colors.white, fontSize: 12),
          );
        },
      ),
      handleBuiltInTouches: true,
    );
  }

  FlTitlesData _buildBarTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < data.length) {
              final label = data[index]['label'] ?? '';
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  label.length > 10 ? label.substring(0, 10) : label,
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const Text('');
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8,
              child: Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }

  FlTitlesData _buildHorizontalBarTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < data.length) {
              final label = data[index]['label'] ?? '';
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  label.length > 8 ? label.substring(0, 8) : label,
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const Text('');
          },
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(BuildContext context) {
    return List.generate(data.length, (index) {
      final value = (data[index]['count'] ?? 0).toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: barColor ?? Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  double _getMaxY() {
    if (data.isEmpty) return 10;
    final maxValue = data
        .map((d) => (d['count'] ?? 0) as num)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    return maxValue == 0 ? 10 : (maxValue * 1.2).ceilToDouble();
  }
}

/// Widget for displaying a pie chart
class PieChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final List<Color>? colors;
  final double? height;

  const PieChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.colors,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyChart(context);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height ?? 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: _buildLegend(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Card(
      child: Container(
        height: height ?? 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Veri bulunmuyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(BuildContext context) {
    final total = data.fold<num>(0, (sum, item) => sum + (item['count'] as num? ?? 0));
    final chartColors = colors ?? [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
    ];

    return List.generate(data.length, (i) {
      final value = (data[i]['count'] as num? ?? 0).toDouble();
      final percentage = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0';

      return PieChartSectionData(
        color: chartColors[i % chartColors.length],
        value: value,
        title: '$percentage%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildLegend(BuildContext context) {
    final chartColors = colors ?? [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, i) {
        final label = data[i]['label'] ?? 'Item ${i + 1}';
        final count = data[i]['count'] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: chartColors[i % chartColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label ($count)',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

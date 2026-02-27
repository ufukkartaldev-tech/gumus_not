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
    Key? key,
    required this.data,
    required this.title,
    this.lineColor,
    this.showGrid = true,
    this.showDots = true,
    this.height,
  }) : super(key: key);

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
                  gridData: showGrid ? _buildGridData(context) : FlGridData(show: false),
                  titlesData: _buildTitlesData(),
                  borderData: _buildBorderData(),
                  lineBarsData: [_buildLineBarData()],
                  lineTouchData: _buildTouchData(),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
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
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < data.length) {
              final label = _getBottomLabel(data[index]);
              return SideTitleWidget(
                axisSide: meta.axisSide,
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

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.transparent),
    );
  }

  LineChartBarData _buildLineBarData() {
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
      dotData: showDots ? FlDotData(show: true) : FlDotData(show: false),
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
        tooltipBgColor: Colors.black87,
        tooltipRoundedRadius: 8,
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
    final maxValue = data.map((d) => d['count'] ?? 0).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }

  String _getBottomLabel(Map<String, dynamic> item) {
    if (item.containsKey('date')) {
      final date = DateTime.parse(item['date']);
      return '${date.day}/${date.month}';
    }
    return '';
  }

  String _getTooltipLabel(Map<String, dynamic> item) {
    if (item.containsKey('date')) {
      final date = DateTime.parse(item['date']);
      return '${date.day}/${date.month}/${date.year}';
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
    Key? key,
    required this.data,
    required this.title,
    this.barColor,
    this.showGrid = true,
    this.height,
    this.horizontal = false,
  }) : super(key: key);

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
              child: horizontal ? _buildHorizontalBarChart() : _buildVerticalBarChart(),
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

  Widget _buildVerticalBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: _buildBarTouchData(),
        titlesData: _buildBarTitlesData(),
        borderData: _buildBorderData(),
        barGroups: _buildBarGroups(),
        gridData: showGrid ? _buildGridData(context) : FlGridData(show: false),
      ),
    );
  }

  Widget _buildHorizontalBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: _buildBarTouchData(),
        titlesData: _buildHorizontalBarTitlesData(),
        borderData: _buildBorderData(),
        barGroups: _buildBarGroups(),
        gridData: showGrid ? _buildGridData(context) : FlGridData(show: false),
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
        tooltipBgColor: Colors.black87,
        tooltipRoundedRadius: 8,
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
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  List<BarChartGroupData> _buildBarGroups() {
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
    final maxValue = data.map((d) => d['count'] ?? 0).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }
}

/// Widget for displaying a pie chart
class PieChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final List<Color>? colors;
  final double? height;

  const PieChartWidget({
    Key? key,
    required this.data,
    required this.title,
    this.colors,
    this.height,
  }) : super(key: key);

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
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: _buildPieTouchData(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
                        sections: _buildPieSections(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildLegend(),
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

  PieTouchData _buildPieTouchData() {
    return PieTouchData(
      touchTooltipData: PieTouchTooltipData(
        tooltipBgColor: Colors.black87,
        tooltipRoundedRadius: 8,
        getTooltipItem: (groupIndex, group, rod, rodIndex) {
          final label = data[groupIndex]['label'] ?? 'Item ${groupIndex + 1}';
          final value = data[groupIndex]['count'] ?? 0;
          final total = data.fold<int>(0, (sum, item) => sum + (item['count'] ?? 0));
          final percentage = total > 0 ? ((value / total) * 100).toStringAsFixed(1) : '0.0';
          return PieTooltipItem(
            '$label: $value ($percentage%)',
            const TextStyle(color: Colors.white, fontSize: 12),
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final total = data.fold<int>(0, (sum, item) => sum + (item['count'] ?? 0));
    final defaultColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    return List.generate(data.length, (index) {
      final value = (data[index]['count'] ?? 0).toDouble();
      final percentage = total > 0 ? value / total : 0.0;
      final color = (colors ?? defaultColors)[index % (colors ?? defaultColors).length];

      return PieChartSectionData(
        color: color,
        value: value,
        title: '${(percentage * 100).toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _Badge(
          value.toString(),
          size: 20,
          color: color,
        ),
        badgePositionPercentageOffset: .98,
      );
    });
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(data.length, (index) {
        final label = data[index]['label'] ?? 'Item ${index + 1}';
        final count = data[index]['count'] ?? 0;
        final defaultColors = [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.secondary,
          Theme.of(context).colorScheme.tertiary,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.indigo,
          Colors.pink,
        ];
        final color = (colors ?? defaultColors)[index % (colors ?? defaultColors).length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                count.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color color;

  const _Badge(this.text, {required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.15),
      child: Center(
        child: FittedBox(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

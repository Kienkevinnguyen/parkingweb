import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'trends_api.dart';

class DailyVisitsChart extends StatelessWidget {
  final List<DailyPoint> points;
  final bool showArea;

  const DailyVisitsChart({super.key, required this.points, this.showArea = true});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Text('No chart data.');

    final spots = points
        .map((p) => FlSpot(p.day.toDouble(), p.visits.toDouble()))
        .toList();

    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b) + 2;

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: spots.last.x,
          minY: 0,
          maxY: maxY < 5 ? 5 : maxY,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: showArea),
            ),
          ],
        ),
      ),
    );
  }
}

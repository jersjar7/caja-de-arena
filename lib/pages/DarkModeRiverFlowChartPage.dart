import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import 'package:flutter/material.dart';

class DarkModeRiverFlowChartPage extends StatefulWidget {
  final String stationName;
  final String rivername;

  const DarkModeRiverFlowChartPage({
    super.key,
    required this.stationName,
    required this.rivername,
  });

  @override
  State<DarkModeRiverFlowChartPage> createState() =>
      _DarkModeRiverFlowChartPageState();
}

class _DarkModeRiverFlowChartPageState
    extends State<DarkModeRiverFlowChartPage> {
  bool showReturnPeriods = true;
  bool showForecast = true;
  bool showObserved = true;
  int selectedDays = 7; // 7, 14, 30 days

  // Dark mode color scheme
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSecondaryBackground = Color(0xFF1C1C1E);
  static const Color darkTertiaryBackground = Color(0xFF2C2C2E);
  static const Color darkSeparator = Color(0xFF38383A);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF98989D);

  // Sample data - replace with your actual data models
  List<FlowDataPoint> get observedData => _generateObservedData();
  List<FlowDataPoint> get forecastData => _generateForecastData();
  Map<String, double> get returnPeriods => {
    '2-year': 150.0,
    '5-year': 280.0,
    '10-year': 420.0,
    '25-year': 650.0,
    '100-year': 950.0,
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: darkBackground,
        border: Border(bottom: BorderSide(color: darkSeparator, width: 0.5)),
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.stationName,
              style: const TextStyle(
                fontSize: 17,
                color: darkPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.rivername,
              style: const TextStyle(fontSize: 13, color: darkSecondaryText),
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showChartSettings,
          child: const Icon(
            CupertinoIcons.settings,
            color: CupertinoColors.systemBlue,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Chart controls
            _buildChartControls(),

            // Main chart
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildChart(),
              ),
            ),

            // Legend and stats
            _buildLegendAndStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: darkSecondaryBackground,
        border: Border(bottom: BorderSide(color: darkSeparator, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSlidingSegmentedControl<int>(
              backgroundColor: darkTertiaryBackground,
              thumbColor: darkSecondaryBackground,
              groupValue: selectedDays,
              children: const {
                7: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '7D',
                    style: TextStyle(color: darkPrimaryText, fontSize: 15),
                  ),
                ),
                14: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '14D',
                    style: TextStyle(color: darkPrimaryText, fontSize: 15),
                  ),
                ),
                30: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '30D',
                    style: TextStyle(color: darkPrimaryText, fontSize: 15),
                  ),
                ),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() => selectedDays = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = _getChartSpots();
    final maxY = _getMaxY();
    final minY = _getMinY();

    return Container(
      decoration: BoxDecoration(
        color: darkSecondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkSeparator, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: LineChart(
          LineChartData(
            backgroundColor: Colors.transparent,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: (maxY - minY) / 6,
              verticalInterval: selectedDays / 7,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: darkSeparator, strokeWidth: 1),
              getDrawingVerticalLine: (value) =>
                  FlLine(color: darkSeparator, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: selectedDays / 7,
                  getTitlesWidget: (value, meta) => _buildBottomTitle(value),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (maxY - minY) / 6,
                  reservedSize: 55,
                  getTitlesWidget: (value, meta) => _buildLeftTitle(value),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: selectedDays.toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: _buildLineBarsData(spots),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (LineBarSpot spot) => darkTertiaryBackground,
                tooltipBorder: const BorderSide(color: darkSeparator, width: 1),
                tooltipBorderRadius: BorderRadius.circular(8),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItems: _buildTooltipItems,
              ),
            ),
            extraLinesData: showReturnPeriods
                ? _buildReturnPeriodLines()
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTitle(double value) {
    final date = DateTime.now().subtract(
      Duration(days: selectedDays - value.toInt()),
    );
    final text = '${date.month}/${date.day}';

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Text(
        text,
        style: const TextStyle(
          color: darkSecondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLeftTitle(double value) {
    return Text(
      '${value.toInt()}',
      style: const TextStyle(
        color: darkSecondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  List<LineChartBarData> _buildLineBarsData(Map<String, List<FlSpot>> spots) {
    final bars = <LineChartBarData>[];

    // Observed data - bright blue for dark mode
    if (showObserved && spots['observed']!.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: spots['observed']!,
          isCurved: true,
          curveSmoothness: 0.35,
          color: const Color(0xFF0A84FF), // iOS dark mode blue
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A84FF).withOpacity(0.3),
                const Color(0xFF0A84FF).withOpacity(0.05),
              ],
            ),
          ),
        ),
      );
    }

    // Forecast data - bright orange for dark mode
    if (showForecast && spots['forecast']!.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: spots['forecast']!,
          isCurved: true,
          curveSmoothness: 0.35,
          color: const Color(0xFFFF9F0A), // iOS dark mode orange
          barWidth: 3,
          isStrokeCapRound: true,
          dashArray: [10, 6], // Dashed line for forecast
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFFF9F0A),
                  strokeWidth: 2,
                  strokeColor: darkSecondaryBackground,
                ),
          ),
        ),
      );
    }

    return bars;
  }

  ExtraLinesData _buildReturnPeriodLines() {
    final lines = <HorizontalLine>[];
    // Dark mode friendly colors for return periods
    final colors = [
      const Color(0xFF32D74B), // Green
      const Color(0xFFFFD60A), // Yellow
      const Color(0xFFFF9F0A), // Orange
      const Color(0xFFFF453A), // Red
      const Color(0xFFBF5AF2), // Purple
    ];

    int index = 0;
    for (final entry in returnPeriods.entries) {
      lines.add(
        HorizontalLine(
          y: entry.value,
          color: colors[index % colors.length].withOpacity(0.8),
          strokeWidth: 2,
          dashArray: [12, 6],
          label: HorizontalLineLabel(
            show: true,
            labelResolver: (line) => entry.key,
            style: TextStyle(
              color: colors[index % colors.length],
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                  color: darkBackground.withOpacity(0.8),
                ),
              ],
            ),
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 8, top: 4),
          ),
        ),
      );
      index++;
    }

    return ExtraLinesData(horizontalLines: lines);
  }

  List<LineTooltipItem> _buildTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((LineBarSpot touchedSpot) {
      final date = DateTime.now().subtract(
        Duration(days: selectedDays - touchedSpot.x.toInt()),
      );
      final isObserved = touchedSpot.barIndex == 0;

      return LineTooltipItem(
        '${isObserved ? 'Observed' : 'Forecast'}\n${touchedSpot.y.toInt()} cfs\n${date.month}/${date.day}',
        TextStyle(
          color: isObserved ? const Color(0xFF0A84FF) : const Color(0xFFFF9F0A),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );
    }).toList();
  }

  Widget _buildLegendAndStats() {
    final currentFlow = observedData.isNotEmpty ? observedData.last.flow : 0.0;
    final peakForecast = forecastData.isNotEmpty
        ? forecastData.map((e) => e.flow).reduce(max)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSecondaryBackground,
        border: Border(top: BorderSide(color: darkSeparator, width: 0.5)),
      ),
      child: Column(
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Current Flow',
                '${currentFlow.toInt()} cfs',
                const Color(0xFF0A84FF),
              ),
              _buildStatItem(
                'Peak Forecast',
                '${peakForecast.toInt()} cfs',
                const Color(0xFFFF9F0A),
              ),
              _buildStatItem(
                'Status',
                _getFlowStatus(currentFlow),
                _getStatusColor(currentFlow),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Legend
          Wrap(
            spacing: 24,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (showObserved)
                _buildLegendItem('Observed', const Color(0xFF0A84FF), false),
              if (showForecast)
                _buildLegendItem('Forecast', const Color(0xFFFF9F0A), true),
              if (showReturnPeriods)
                _buildLegendItem('Return Periods', darkSecondaryText, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: darkSecondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(1.5),
            border: isDashed ? Border.all(color: color, width: 2) : null,
          ),
          child: isDashed
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Colors.transparent,
                        color,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.3, 0.7, 1],
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: darkPrimaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showChartSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text(
          'Chart Options',
          style: TextStyle(color: darkPrimaryText),
        ),
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              showObserved ? 'Hide Observed Data' : 'Show Observed Data',
              style: const TextStyle(color: CupertinoColors.systemBlue),
            ),
            onPressed: () {
              setState(() => showObserved = !showObserved);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              showForecast ? 'Hide Forecast Data' : 'Show Forecast Data',
              style: const TextStyle(color: CupertinoColors.systemBlue),
            ),
            onPressed: () {
              setState(() => showForecast = !showForecast);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              showReturnPeriods ? 'Hide Return Periods' : 'Show Return Periods',
              style: const TextStyle(color: CupertinoColors.systemBlue),
            ),
            onPressed: () {
              setState(() => showReturnPeriods = !showReturnPeriods);
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text(
            'Cancel',
            style: TextStyle(color: CupertinoColors.systemBlue),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Helper methods for data processing
  Map<String, List<FlSpot>> _getChartSpots() {
    final observed = <FlSpot>[];
    final forecast = <FlSpot>[];

    // Convert observed data to spots
    for (int i = 0; i < observedData.length && i < selectedDays; i++) {
      observed.add(FlSpot(i.toDouble(), observedData[i].flow));
    }

    // Convert forecast data to spots (starting from observed data end)
    final forecastStart = observedData.length.toDouble();
    for (int i = 0; i < forecastData.length; i++) {
      forecast.add(FlSpot(forecastStart + i, forecastData[i].flow));
    }

    return {'observed': observed, 'forecast': forecast};
  }

  double _getMaxY() {
    final allFlows = [
      ...observedData.map((e) => e.flow),
      ...forecastData.map((e) => e.flow),
    ];
    if (showReturnPeriods && returnPeriods.isNotEmpty) {
      allFlows.addAll(returnPeriods.values);
    }
    final maxFlow = allFlows.isEmpty ? 100.0 : allFlows.reduce(max);
    return maxFlow * 1.15; // Add 15% padding for better visual spacing
  }

  double _getMinY() {
    final allFlows = [
      ...observedData.map((e) => e.flow),
      ...forecastData.map((e) => e.flow),
    ];
    final minFlow = allFlows.isEmpty ? 0.0 : allFlows.reduce(min);
    return max(0, minFlow * 0.85); // Subtract 15% padding, but not below 0
  }

  String _getFlowStatus(double flow) {
    if (flow > returnPeriods['25-year']!) return 'Extreme';
    if (flow > returnPeriods['5-year']!) return 'High';
    if (flow > returnPeriods['2-year']!) return 'Elevated';
    return 'Normal';
  }

  Color _getStatusColor(double flow) {
    if (flow > returnPeriods['25-year']!) return const Color(0xFFFF453A); // Red
    if (flow > returnPeriods['5-year']!)
      return const Color(0xFFFF9F0A); // Orange
    if (flow > returnPeriods['2-year']!)
      return const Color(0xFFFFD60A); // Yellow
    return const Color(0xFF32D74B); // Green
  }

  // Sample data generators - replace with your actual data sources
  List<FlowDataPoint> _generateObservedData() {
    final data = <FlowDataPoint>[];
    final random = Random();
    final baseFlow = 80.0;

    for (int i = selectedDays; i >= 1; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final noise = (random.nextDouble() - 0.5) * 40;
      final seasonalVariation = sin((date.dayOfYear / 365) * 2 * pi) * 30;
      final flow =
          baseFlow + noise + seasonalVariation + (random.nextDouble() * 20);

      data.add(FlowDataPoint(date: date, flow: max(10, flow)));
    }

    return data;
  }

  List<FlowDataPoint> _generateForecastData() {
    final data = <FlowDataPoint>[];
    final random = Random();
    final lastObserved = observedData.isNotEmpty
        ? observedData.last.flow
        : 80.0;

    for (int i = 1; i <= 7; i++) {
      // 7-day forecast
      final date = DateTime.now().add(Duration(days: i));
      final trend = i * 5; // Gradual increase
      final uncertainty =
          (random.nextDouble() - 0.5) * (i * 10); // Increasing uncertainty
      final flow = lastObserved + trend + uncertainty;

      data.add(FlowDataPoint(date: date, flow: max(10, flow)));
    }

    return data;
  }
}

// Data models
class FlowDataPoint {
  final DateTime date;
  final double flow;

  FlowDataPoint({required this.date, required this.flow});
}

// Extension to compute day of year for DateTime
extension DateTimeDayOfYear on DateTime {
  int get dayOfYear {
    final startOfYear = DateTime(year, 1, 1);
    return difference(startOfYear).inDays + 1;
  }
}

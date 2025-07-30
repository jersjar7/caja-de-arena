import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import 'package:flutter/material.dart';

class RiverFlowChartPage extends StatefulWidget {
  final String stationName;
  final String rivername;

  const RiverFlowChartPage({
    super.key,
    required this.stationName,
    required this.rivername,
  });

  @override
  State<RiverFlowChartPage> createState() => _RiverFlowChartPageState();
}

class _RiverFlowChartPageState extends State<RiverFlowChartPage> {
  bool showReturnPeriods = true;
  bool showForecast = true;
  bool showObserved = true;
  int selectedDays = 7; // 7, 14, 30 days

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
      navigationBar: CupertinoNavigationBar(
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.stationName, style: const TextStyle(fontSize: 17)),
            Text(
              widget.rivername,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showChartSettings,
          child: Icon(CupertinoIcons.settings),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: selectedDays,
              children: const {7: Text('7D'), 14: Text('14D'), 30: Text('30D')},
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
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: (maxY - minY) / 6,
              verticalInterval: selectedDays / 7,
              getDrawingHorizontalLine: (value) => FlLine(
                color: CupertinoColors.separator.resolveFrom(context),
                strokeWidth: 0.5,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: CupertinoColors.separator.resolveFrom(context),
                strokeWidth: 0.5,
              ),
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
                  reservedSize: 30,
                  interval: selectedDays / 7,
                  getTitlesWidget: (value, meta) => _buildBottomTitle(value),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (maxY - minY) / 6,
                  reservedSize: 50,
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
                getTooltipColor: (LineBarSpot spot) =>
                    CupertinoColors.systemBackground.resolveFrom(context),
                tooltipBorder: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
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
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLeftTitle(double value) {
    return Text(
      '${value.toInt()}',
      style: TextStyle(
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
        fontSize: 12,
      ),
    );
  }

  List<LineChartBarData> _buildLineBarsData(Map<String, List<FlSpot>> spots) {
    final bars = <LineChartBarData>[];

    // Observed data
    if (showObserved && spots['observed']!.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: spots['observed']!,
          isCurved: true,
          curveSmoothness: 0.3,
          color: CupertinoColors.systemBlue.resolveFrom(context),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: CupertinoColors.systemBlue
                .resolveFrom(context)
                .withOpacity(0.1),
          ),
        ),
      );
    }

    // Forecast data
    if (showForecast && spots['forecast']!.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: spots['forecast']!,
          isCurved: true,
          curveSmoothness: 0.3,
          color: CupertinoColors.systemOrange.resolveFrom(context),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dashArray: [8, 4], // Dashed line for forecast
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 3,
                  color: CupertinoColors.systemOrange.resolveFrom(context),
                  strokeWidth: 1,
                  strokeColor: CupertinoColors.systemBackground.resolveFrom(
                    context,
                  ),
                ),
          ),
        ),
      );
    }

    return bars;
  }

  ExtraLinesData _buildReturnPeriodLines() {
    final lines = <HorizontalLine>[];
    final colors = [
      CupertinoColors.systemGreen,
      CupertinoColors.systemYellow,
      CupertinoColors.systemOrange,
      CupertinoColors.systemRed,
      CupertinoColors.systemPurple,
    ];

    int index = 0;
    for (final entry in returnPeriods.entries) {
      lines.add(
        HorizontalLine(
          y: entry.value,
          color: colors[index % colors.length]
              .resolveFrom(context)
              .withOpacity(0.7),
          strokeWidth: 1.5,
          dashArray: [10, 5],
          label: HorizontalLineLabel(
            show: true,
            labelResolver: (line) => entry.key,
            style: TextStyle(
              color: colors[index % colors.length].resolveFrom(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            alignment: Alignment.topRight,
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
          color: isObserved
              ? CupertinoColors.systemBlue.resolveFrom(context)
              : CupertinoColors.systemOrange.resolveFrom(context),
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
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
                CupertinoColors.systemBlue,
              ),
              _buildStatItem(
                'Peak Forecast',
                '${peakForecast.toInt()} cfs',
                CupertinoColors.systemOrange,
              ),
              _buildStatItem(
                'Status',
                _getFlowStatus(currentFlow),
                _getStatusColor(currentFlow),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (showObserved)
                _buildLegendItem('Observed', CupertinoColors.systemBlue, false),
              if (showForecast)
                _buildLegendItem(
                  'Forecast',
                  CupertinoColors.systemOrange,
                  true,
                ),
              if (showReturnPeriods)
                _buildLegendItem(
                  'Return Periods',
                  CupertinoColors.systemGrey,
                  true,
                ),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
          width: 20,
          height: 2,
          decoration: BoxDecoration(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            borderRadius: BorderRadius.circular(1),
          ),
          child: isDashed
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                      width: 1,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  void _showChartSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Chart Options'),
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              showObserved ? 'Hide Observed Data' : 'Show Observed Data',
            ),
            onPressed: () {
              setState(() => showObserved = !showObserved);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              showForecast ? 'Hide Forecast Data' : 'Show Forecast Data',
            ),
            onPressed: () {
              setState(() => showForecast = !showForecast);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              showReturnPeriods ? 'Hide Return Periods' : 'Show Return Periods',
            ),
            onPressed: () {
              setState(() => showReturnPeriods = !showReturnPeriods);
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
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
    return maxFlow * 1.1; // Add 10% padding
  }

  double _getMinY() {
    final allFlows = [
      ...observedData.map((e) => e.flow),
      ...forecastData.map((e) => e.flow),
    ];
    final minFlow = allFlows.isEmpty ? 0.0 : allFlows.reduce(min);
    return max(0, minFlow * 0.9); // Subtract 10% padding, but not below 0
  }

  String _getFlowStatus(double flow) {
    if (flow > returnPeriods['25-year']!) return 'Extreme';
    if (flow > returnPeriods['5-year']!) return 'High';
    if (flow > returnPeriods['2-year']!) return 'Elevated';
    return 'Normal';
  }

  Color _getStatusColor(double flow) {
    if (flow > returnPeriods['25-year']!) return CupertinoColors.systemRed;
    if (flow > returnPeriods['5-year']!) return CupertinoColors.systemOrange;
    if (flow > returnPeriods['2-year']!) return CupertinoColors.systemYellow;
    return CupertinoColors.systemGreen;
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

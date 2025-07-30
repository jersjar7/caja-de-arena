import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import 'package:flutter/material.dart';

class CupertinoShortRangePage extends StatefulWidget {
  final String reachId;
  final String riverName;
  final String city;
  final String state;

  const CupertinoShortRangePage({
    super.key,
    required this.reachId,
    required this.riverName,
    required this.city,
    required this.state,
  });

  @override
  State<CupertinoShortRangePage> createState() =>
      _CupertinoShortRangePageState();
}

class _CupertinoShortRangePageState extends State<CupertinoShortRangePage> {
  final int _selectedTimeFrame = 2; // 0: 12h, 1: 24h, 2: 72h
  bool _isWaveView = false;
  bool _isRefreshing = false;

  // Sample data - replace with your actual data models
  late List<HourlyForecast> _hourlyForecasts;
  late Map<int, double> _returnPeriods;

  @override
  void initState() {
    super.initState();
    _generateSampleData();
  }

  void _generateSampleData() {
    _returnPeriods = {
      2: 1500.0,
      5: 2200.0,
      10: 2800.0,
      25: 3500.0,
      50: 4000.0,
      100: 4500.0,
    };

    _hourlyForecasts = [];
    final now = DateTime.now();
    final baseFlow = 1250.0;

    for (int i = 0; i < 72; i++) {
      final time = now.add(Duration(hours: i));
      final variation =
          sin(i * 0.2) * 300 + (Random().nextDouble() - 0.5) * 200;
      final flow = (baseFlow + variation).clamp(50.0, 5000.0);

      _hourlyForecasts.add(
        HourlyForecast(
          time: time,
          flow: flow,
          category: _getFlowCategory(flow),
        ),
      );
    }
  }

  String _getFlowCategory(double flow) {
    if (flow > _returnPeriods[10]!) return 'Flood Risk';
    if (flow > _returnPeriods[2]!) return 'Elevated';
    if (flow > 800) return 'Normal';
    return 'Low';
  }

  Color _getCategoryColor(double flow) {
    if (flow > _returnPeriods[10]!) return CupertinoColors.systemRed;
    if (flow > _returnPeriods[2]!) return CupertinoColors.systemOrange;
    if (flow > 800) return CupertinoColors.systemGreen;
    return CupertinoColors.systemBlue;
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);

    if (diff.inMinutes.abs() < 5) return 'Now';
    if (diff.inHours == 0) {
      return diff.inMinutes > 0
          ? '${diff.inMinutes}min'
          : '${-diff.inMinutes}min ago';
    }
    if (diff.inHours.abs() < 24) {
      return diff.inHours > 0 ? '${diff.inHours}hr' : '${-diff.inHours}hr ago';
    }
    return diff.inDays > 0 ? '${diff.inDays}d' : '${-diff.inDays}d ago';
  }

  String _getTrendIcon(int index) {
    if (index <= 0) return '→';

    final current = _hourlyForecasts[index].flow;
    final previous = _hourlyForecasts[index - 1].flow;

    if (current > previous * 1.05) return '↗';
    if (current < previous * 0.95) return '↘';
    return '→';
  }

  Color _getTrendColor(int index) {
    if (index <= 0) return CupertinoColors.systemGrey;

    final current = _hourlyForecasts[index].flow;
    final previous = _hourlyForecasts[index - 1].flow;

    if (current > previous * 1.05) return CupertinoColors.systemOrange;
    if (current < previous * 0.95) return CupertinoColors.systemBlue;
    return CupertinoColors.systemGrey;
  }

  double _getTrendPercentage(int index) {
    if (index <= 0) return 0.0;

    final current = _hourlyForecasts[index].flow;
    final previous = _hourlyForecasts[index - 1].flow;

    return ((current - previous) / previous * 100).abs();
  }

  List<int> _getHoursToShow() {
    switch (_selectedTimeFrame) {
      case 0:
        return List.generate(12, (i) => i);
      case 1:
        return List.generate(24, (i) => i);
      case 2:
        return List.generate(72, (i) => i);
      default:
        return List.generate(24, (i) => i);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    _generateSampleData();

    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentFlow = _hourlyForecasts.isNotEmpty
        ? _hourlyForecasts.first.flow
        : 0.0;
    final hoursToShow = _getHoursToShow();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.back,
            color: CupertinoColors.systemBlue,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Text(
          widget.riverName,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'CFS',
            style: TextStyle(
              color: CupertinoColors.systemBlue,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () {
            // Toggle units
          },
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Location Info Section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.darkColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.location_solid,
                        color: CupertinoColors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.riverName,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.city}, ${widget.state} • Reach ID: ${widget.reachId}',
                            style: TextStyle(
                              color: CupertinoColors.white.withOpacity(0.6),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Current Flow Status Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCategoryColor(currentFlow),
                      _getCategoryColor(currentFlow).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Background decoration
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Flow',
                          style: TextStyle(
                            color: CupertinoColors.white.withOpacity(0.8),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentFlow.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} CFS',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getFlowCategory(currentFlow)} Flow',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Flow Indicator Bar
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: CupertinoColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (currentFlow / _returnPeriods[10]!)
                                .clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Historical comparison
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.chart_bar,
                              color: CupertinoColors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Historical Average: 890 CFS',
                              style: TextStyle(
                                color: CupertinoColors.white.withOpacity(0.8),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Section Header with View Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hourly Forecast',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: CupertinoColors.systemBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: () {
                        setState(() => _isWaveView = !_isWaveView);
                      },
                      child: Text(
                        _isWaveView ? '📊 Card View' : '〰️ Wave View',
                        style: const TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Horizontal Flow Timeline or Wave View
            SliverToBoxAdapter(
              child: _isWaveView
                  ? _buildWaveView(hoursToShow)
                  : _buildCardView(hoursToShow),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Main Hydrograph Chart
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.darkColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '3-Day Hydrograph',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: CupertinoColors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () {
                            // Navigate to full chart page
                          },
                          child: Text(
                            '🔍 Expand',
                            style: TextStyle(
                              color: CupertinoColors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(height: 300, child: _buildMainChart()),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _isRefreshing ? null : _refresh,
                        child: _isRefreshing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CupertinoActivityIndicator(),
                                  SizedBox(width: 8),
                                  Text(
                                    'Refreshing...',
                                    style: TextStyle(
                                      color: CupertinoColors.systemBlue,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                '🔄 Refresh Data',
                                style: TextStyle(
                                  color: CupertinoColors.systemBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          // Add to favorites
                        },
                        child: const Text(
                          '⭐ Add Favorite',
                          style: TextStyle(
                            color: CupertinoColors.systemGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(List<int> hoursToShow) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: hoursToShow.length,
        itemBuilder: (context, index) {
          final forecast = _hourlyForecasts[hoursToShow[index]];
          final color = _getCategoryColor(forecast.flow);
          final trendIcon = _getTrendIcon(hoursToShow[index]);
          final trendColor = _getTrendColor(hoursToShow[index]);
          final trendPercentage = _getTrendPercentage(hoursToShow[index]);

          return Container(
            width: 110,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.darkColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: index == 0
                    ? color
                    : CupertinoColors.white.withOpacity(0.1),
                width: index == 0 ? 2 : 0.5,
              ),
            ),
            child: Column(
              children: [
                // NOW badge for first item
                if (index == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Relative time
                Text(
                  _formatRelativeTime(forecast.time),
                  style: TextStyle(
                    color: CupertinoColors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                // Actual time
                Text(
                  '${forecast.time.hour.toString().padLeft(2, '0')}:${forecast.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: CupertinoColors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 12),

                // Circular flow display
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      forecast.flow > 999
                          ? '${(forecast.flow / 1000).toStringAsFixed(1)}k'
                          : forecast.flow.round().toString(),
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Category
                Text(
                  forecast.category,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // Trend indicator
                if (index > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        trendIcon,
                        style: TextStyle(color: trendColor, fontSize: 12),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${trendPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(color: trendColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveView(List<int> hoursToShow) {
    final chartData = hoursToShow.take(24).map((index) {
      final forecast = _hourlyForecasts[index];
      return FlSpot(index.toDouble(), forecast.flow);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.darkColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: CupertinoColors.white.withOpacity(0.1),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final hour = _hourlyForecasts[value.toInt()].time;
                        return Text(
                          '${hour.hour.toString().padLeft(2, '0')}:00',
                          style: TextStyle(
                            color: CupertinoColors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    color: CupertinoColors.systemBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: CupertinoColors.systemBlue,
                            strokeWidth: 2,
                            strokeColor: CupertinoColors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: CupertinoColors.systemBlue.withOpacity(0.1),
                    ),
                  ),
                ],
                // Return period reference lines
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: _returnPeriods[2]!,
                      color: CupertinoColors.systemOrange,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                    HorizontalLine(
                      y: _returnPeriods[10]!,
                      color: CupertinoColors.systemRed,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Forecast', CupertinoColors.systemBlue, false),
              const SizedBox(width: 16),
              _buildLegendItem('2-Year', CupertinoColors.systemOrange, true),
              const SizedBox(width: 16),
              _buildLegendItem('10-Year', CupertinoColors.systemRed, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: isDashed ? 1 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isDashed ? 0 : 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMainChart() {
    final chartData = _hourlyForecasts.take(72).toList().asMap().entries.map((
      entry,
    ) {
      return FlSpot(entry.key.toDouble(), entry.value.flow);
    }).toList();

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: CupertinoColors.white.withOpacity(0.1),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: CupertinoColors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 12,
              getTitlesWidget: (value, meta) {
                final hours = value.toInt();
                if (hours < _hourlyForecasts.length) {
                  final time = _hourlyForecasts[hours].time;
                  return Text(
                    '${time.month}/${time.day}',
                    style: TextStyle(
                      color: CupertinoColors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: chartData,
            color: CupertinoColors.systemBlue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
        // Return period reference lines
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _returnPeriods[2]!,
              color: CupertinoColors.systemOrange,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
            HorizontalLine(
              y: _returnPeriods[5]!,
              color: CupertinoColors.systemOrange,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
            HorizontalLine(
              y: _returnPeriods[10]!,
              color: CupertinoColors.systemRed,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }
}

// Data models
class HourlyForecast {
  final DateTime time;
  final double flow;
  final String category;

  HourlyForecast({
    required this.time,
    required this.flow,
    required this.category,
  });
}

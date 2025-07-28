// lib/vector_tiles_approach/performance_comparison.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

/// Performance metrics for different data loading approaches
class PerformanceMetrics {
  final String approach;
  final String layerName;
  final int featureCount;
  final Duration loadTime;
  final double dataSizeKB;
  final bool fromCache;
  final DateTime timestamp;
  final Map<String, dynamic> additionalMetrics;

  PerformanceMetrics({
    required this.approach,
    required this.layerName,
    required this.featureCount,
    required this.loadTime,
    required this.dataSizeKB,
    this.fromCache = false,
    required this.timestamp,
    this.additionalMetrics = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'approach': approach,
      'layerName': layerName,
      'featureCount': featureCount,
      'loadTimeMs': loadTime.inMilliseconds,
      'dataSizeKB': dataSizeKB,
      'fromCache': fromCache,
      'timestamp': timestamp.toIso8601String(),
      'additionalMetrics': additionalMetrics,
    };
  }

  static PerformanceMetrics fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      approach: json['approach'],
      layerName: json['layerName'],
      featureCount: json['featureCount'],
      loadTime: Duration(milliseconds: json['loadTimeMs']),
      dataSizeKB: json['dataSizeKB'].toDouble(),
      fromCache: json['fromCache'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      additionalMetrics: json['additionalMetrics'] ?? {},
    );
  }

  String get loadTimeFormatted {
    if (loadTime.inSeconds > 0) {
      return '${(loadTime.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${loadTime.inMilliseconds}ms';
  }

  String get dataSizeFormatted {
    if (dataSizeKB > 1024) {
      return '${(dataSizeKB / 1024).toStringAsFixed(1)}MB';
    }
    return '${dataSizeKB.toStringAsFixed(1)}KB';
  }

  double get featuresPerSecond {
    if (loadTime.inMilliseconds == 0) return 0;
    return featureCount / (loadTime.inMilliseconds / 1000);
  }

  @override
  String toString() {
    return '$approach: $layerName ($featureCount features, $loadTimeFormatted)';
  }
}

/// Service for comparing performance between WFS and Vector Tiles approaches
class PerformanceComparisonService {
  static final PerformanceComparisonService _instance =
      PerformanceComparisonService._internal();
  factory PerformanceComparisonService() => _instance;
  PerformanceComparisonService._internal();

  final List<PerformanceMetrics> _metrics = [];

  /// Record performance metrics for a layer load
  void recordMetrics(PerformanceMetrics metrics) {
    _metrics.add(metrics);
    print('📊 Recorded performance: ${metrics.toString()}');

    // Keep only last 50 entries to prevent memory growth
    if (_metrics.length > 50) {
      _metrics.removeAt(0);
    }
  }

  /// Get all recorded metrics
  List<PerformanceMetrics> get allMetrics => List.unmodifiable(_metrics);

  /// Get metrics for a specific approach
  List<PerformanceMetrics> getMetricsForApproach(String approach) {
    return _metrics.where((m) => m.approach == approach).toList();
  }

  /// Get metrics for a specific layer
  List<PerformanceMetrics> getMetricsForLayer(String layerName) {
    return _metrics.where((m) => m.layerName == layerName).toList();
  }

  /// Generate comparison report
  Map<String, dynamic> generateComparisonReport() {
    if (_metrics.isEmpty) {
      return {'error': 'No performance data available'};
    }

    final wfsMetrics = getMetricsForApproach('WFS');
    final vectorMetrics = getMetricsForApproach('Vector Tiles');

    final report = <String, dynamic>{
      'totalMeasurements': _metrics.length,
      'wfsMeasurements': wfsMetrics.length,
      'vectorMeasurements': vectorMetrics.length,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    if (wfsMetrics.isNotEmpty) {
      report['wfsStats'] = _calculateStats(wfsMetrics);
    }

    if (vectorMetrics.isNotEmpty) {
      report['vectorStats'] = _calculateStats(vectorMetrics);
    }

    if (wfsMetrics.isNotEmpty && vectorMetrics.isNotEmpty) {
      report['comparison'] = _generateComparison(wfsMetrics, vectorMetrics);
    }

    return report;
  }

  Map<String, dynamic> _calculateStats(List<PerformanceMetrics> metrics) {
    final loadTimes = metrics.map((m) => m.loadTime.inMilliseconds).toList();
    final featureCounts = metrics.map((m) => m.featureCount).toList();
    final dataSizes = metrics.map((m) => m.dataSizeKB).toList();
    final featuresPerSecond = metrics.map((m) => m.featuresPerSecond).toList();

    return {
      'count': metrics.length,
      'avgLoadTimeMs': loadTimes.isNotEmpty
          ? loadTimes.reduce((a, b) => a + b) / loadTimes.length
          : 0,
      'minLoadTimeMs': loadTimes.isNotEmpty
          ? loadTimes.reduce((a, b) => a < b ? a : b)
          : 0,
      'maxLoadTimeMs': loadTimes.isNotEmpty
          ? loadTimes.reduce((a, b) => a > b ? a : b)
          : 0,
      'avgFeatureCount': featureCounts.isNotEmpty
          ? featureCounts.reduce((a, b) => a + b) / featureCounts.length
          : 0,
      'avgDataSizeKB': dataSizes.isNotEmpty
          ? dataSizes.reduce((a, b) => a + b) / dataSizes.length
          : 0,
      'avgFeaturesPerSecond': featuresPerSecond.isNotEmpty
          ? featuresPerSecond.reduce((a, b) => a + b) / featuresPerSecond.length
          : 0,
      'cacheHitRate':
          metrics.where((m) => m.fromCache).length / metrics.length * 100,
    };
  }

  Map<String, dynamic> _generateComparison(
    List<PerformanceMetrics> wfsMetrics,
    List<PerformanceMetrics> vectorMetrics,
  ) {
    final wfsStats = _calculateStats(wfsMetrics);
    final vectorStats = _calculateStats(vectorMetrics);

    final loadTimeImprovement =
        (wfsStats['avgLoadTimeMs'] - vectorStats['avgLoadTimeMs']) /
        wfsStats['avgLoadTimeMs'] *
        100;

    final throughputImprovement =
        (vectorStats['avgFeaturesPerSecond'] -
            wfsStats['avgFeaturesPerSecond']) /
        wfsStats['avgFeaturesPerSecond'] *
        100;

    return {
      'loadTimeImprovementPercent': loadTimeImprovement,
      'throughputImprovementPercent': throughputImprovement,
      'vectorTilesBetter': loadTimeImprovement > 0,
      'summary': _generateSummary(loadTimeImprovement, throughputImprovement),
    };
  }

  String _generateSummary(
    double loadTimeImprovement,
    double throughputImprovement,
  ) {
    if (loadTimeImprovement > 20) {
      return 'Vector tiles show significant performance improvement '
          '(${loadTimeImprovement.toStringAsFixed(1)}% faster load times)';
    } else if (loadTimeImprovement > 0) {
      return 'Vector tiles show moderate performance improvement '
          '(${loadTimeImprovement.toStringAsFixed(1)}% faster load times)';
    } else {
      return 'WFS shows better performance in this comparison '
          '(${(-loadTimeImprovement).toStringAsFixed(1)}% faster load times)';
    }
  }

  /// Clear all metrics
  void clearMetrics() {
    _metrics.clear();
    print('🗑️ Performance metrics cleared');
  }

  /// Export metrics as JSON
  String exportMetricsAsJson() {
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalMetrics': _metrics.length,
      'metrics': _metrics.map((m) => m.toJson()).toList(),
      'comparison': generateComparisonReport(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Print performance summary to console
  void printPerformanceSummary() {
    final report = generateComparisonReport();
    print('\n📊 PERFORMANCE COMPARISON SUMMARY:');
    print('Total measurements: ${report['totalMeasurements']}');
    print('WFS measurements: ${report['wfsMeasurements']}');
    print('Vector measurements: ${report['vectorMeasurements']}');

    if (report['wfsStats'] != null) {
      final wfs = report['wfsStats'];
      print('\nWFS Performance:');
      print('  Avg load time: ${wfs['avgLoadTimeMs'].toStringAsFixed(0)}ms');
      print(
        '  Avg features/sec: ${wfs['avgFeaturesPerSecond'].toStringAsFixed(0)}',
      );
      print('  Cache hit rate: ${wfs['cacheHitRate'].toStringAsFixed(1)}%');
    }

    if (report['vectorStats'] != null) {
      final vector = report['vectorStats'];
      print('\nVector Tiles Performance:');
      print('  Avg load time: ${vector['avgLoadTimeMs'].toStringAsFixed(0)}ms');
      print(
        '  Avg features/sec: ${vector['avgFeaturesPerSecond'].toStringAsFixed(0)}',
      );
    }

    if (report['comparison'] != null) {
      final comp = report['comparison'];
      print('\nComparison:');
      print('  ${comp['summary']}');
    }
  }
}

/// Widget to display performance comparison results
class PerformanceComparisonWidget extends StatefulWidget {
  const PerformanceComparisonWidget({super.key});

  @override
  State<PerformanceComparisonWidget> createState() =>
      _PerformanceComparisonWidgetState();
}

class _PerformanceComparisonWidgetState
    extends State<PerformanceComparisonWidget> {
  final _performanceService = PerformanceComparisonService();

  @override
  Widget build(BuildContext context) {
    final report = _performanceService.generateComparisonReport();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Performance Comparison'),
      ),
      child: SafeArea(
        child: report.containsKey('error')
            ? _buildNoDataView(report['error'])
            : _buildComparisonView(report),
      ),
    );
  }

  Widget _buildNoDataView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.chart_bar,
            size: 64,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(
              fontSize: 18,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Load some layers using both WFS and Vector Tiles approaches to see performance comparison',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonView(Map<String, dynamic> report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        _buildSummaryCard(report),
        const SizedBox(height: 16),

        // WFS stats
        if (report['wfsStats'] != null)
          _buildStatsCard(
            'WFS Approach',
            report['wfsStats'],
            CupertinoColors.systemBlue,
          ),
        if (report['wfsStats'] != null) const SizedBox(height: 16),

        // Vector tiles stats
        if (report['vectorStats'] != null)
          _buildStatsCard(
            'Vector Tiles Approach',
            report['vectorStats'],
            CupertinoColors.systemPurple,
          ),
        if (report['vectorStats'] != null) const SizedBox(height: 16),

        // Comparison
        if (report['comparison'] != null)
          _buildComparisonCard(report['comparison']),
        if (report['comparison'] != null) const SizedBox(height: 16),

        // Recent measurements
        _buildRecentMeasurements(),
        const SizedBox(height: 16),

        // Actions
        _buildActions(),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                'Total Tests',
                '${report['totalMeasurements']}',
              ),
              const SizedBox(width: 20),
              _buildSummaryItem('WFS Tests', '${report['wfsMeasurements']}'),
              const SizedBox(width: 20),
              _buildSummaryItem(
                'Vector Tests',
                '${report['vectorMeasurements']}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(
    String title,
    Map<String, dynamic> stats,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Avg Load Time',
                  '${(stats['avgLoadTimeMs'] as double).toStringAsFixed(0)}ms',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Features/Sec',
                  (stats['avgFeaturesPerSecond'] as double).toStringAsFixed(0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Avg Features',
                  (stats['avgFeatureCount'] as double).toStringAsFixed(0),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Cache Hit Rate',
                  '${(stats['cacheHitRate'] as double).toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(Map<String, dynamic> comparison) {
    final isVectorBetter = comparison['vectorTilesBetter'] as bool;
    final improvement = comparison['loadTimeImprovementPercent'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVectorBetter
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVectorBetter
              ? CupertinoColors.systemGreen.withOpacity(0.3)
              : CupertinoColors.systemOrange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVectorBetter
                    ? CupertinoIcons.checkmark_circle
                    : CupertinoIcons.info_circle,
                color: isVectorBetter
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 8),
              const Text(
                'Performance Winner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comparison['summary'] as String,
            style: const TextStyle(fontSize: 14),
          ),
          if (improvement.abs() > 5) ...[
            const SizedBox(height: 8),
            Text(
              '${improvement > 0 ? 'Vector tiles are' : 'WFS is'} ${improvement.abs().toStringAsFixed(1)}% faster',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isVectorBetter
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentMeasurements() {
    final recentMetrics = _performanceService.allMetrics.reversed
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Measurements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (recentMetrics.isEmpty)
            const Text(
              'No measurements yet',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            )
          else
            ...recentMetrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: metric.approach == 'WFS'
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.systemPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${metric.layerName} (${metric.approach})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      metric.loadTimeFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton.filled(
            onPressed: () {
              final json = _performanceService.exportMetricsAsJson();
              // In a real app, you'd save or share this JSON
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Export Complete'),
                  content: const Text('Performance data exported to console'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
              print('📊 Exported performance data:\n$json');
            },
            child: const Text('Export Data'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CupertinoButton(
            onPressed: () {
              _performanceService.clearMetrics();
              setState(() {});
            },
            child: const Text('Clear Data'),
          ),
        ),
      ],
    );
  }
}

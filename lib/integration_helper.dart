// lib/integration_helper.dart
import 'package:flutter/cupertino.dart';
import 'wfs_approach/bounded_wfs_loader.dart';
import 'vector_tiles_approach/performance_comparison.dart';

/// Integration helper to connect WFS and Vector Tiles approaches
/// for performance comparison and unified metrics
class IntegrationHelper {
  static final IntegrationHelper _instance = IntegrationHelper._internal();
  factory IntegrationHelper() => _instance;
  IntegrationHelper._internal();

  final PerformanceComparisonService _performanceService =
      PerformanceComparisonService();

  /// Record WFS performance metrics
  void recordWFSPerformance({
    required String layerName,
    required WFSLoadResult result,
  }) {
    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'WFS',
        layerName: layerName,
        featureCount: result.featureCount,
        loadTime: result.loadTime,
        dataSizeKB: (result.geojsonData.length / 1024),
        fromCache: result.fromCache,
        timestamp: DateTime.now(),
        additionalMetrics: {
          'source': result.source,
          'zoom': result.zoom,
          'bbox_area': _calculateBBoxArea(result.bbox),
        },
      ),
    );

    print(
      '📊 Recorded WFS performance: $layerName (${result.featureCount} features, ${result.loadTime.inMilliseconds}ms)',
    );
  }

  /// Record Vector Tiles performance metrics
  void recordVectorTilesPerformance({
    required String layerName,
    required Duration loadTime,
    required String tilesetId,
    String? sourceLayer,
  }) {
    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'Vector Tiles',
        layerName: layerName,
        featureCount: -1, // Vector tiles don't report exact count
        loadTime: loadTime,
        dataSizeKB: 0, // Vector tiles are streamed
        fromCache: false,
        timestamp: DateTime.now(),
        additionalMetrics: {
          'tilesetId': tilesetId,
          'sourceLayer': sourceLayer ?? 'unknown',
          'streaming': true,
        },
      ),
    );

    print(
      '📊 Recorded Vector Tiles performance: $layerName (${loadTime.inMilliseconds}ms)',
    );
  }

  /// Get comprehensive comparison data
  Map<String, dynamic> getComparisonData() {
    return _performanceService.generateComparisonReport();
  }

  /// Show comparison results in a dialog
  void showComparisonDialog(BuildContext context) {
    final report = getComparisonData();

    if (report.containsKey('error')) {
      _showNoDataDialog(context);
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Performance Comparison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Tests: ${report['totalMeasurements']}'),
            const SizedBox(height: 8),
            if (report['wfsStats'] != null) ...[
              Text(
                'WFS Average: ${(report['wfsStats']['avgLoadTimeMs'] as double).toStringAsFixed(0)}ms',
              ),
            ],
            if (report['vectorStats'] != null) ...[
              Text(
                'Vector Tiles Average: ${(report['vectorStats']['avgLoadTimeMs'] as double).toStringAsFixed(0)}ms',
              ),
            ],
            if (report['comparison'] != null) ...[
              const SizedBox(height: 8),
              Text(
                report['comparison']['summary'] as String,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('View Details'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const PerformanceComparisonWidget(),
                ),
              );
            },
          ),
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showNoDataDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No Performance Data'),
        content: const Text(
          'Load some layers using both WFS and Vector Tiles approaches to see performance comparison.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Generate demo data for presentation
  void generateDemoData() {
    // Simulate WFS performance for different dataset sizes
    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'WFS',
        layerName: 'Small Dataset (Gauges)',
        featureCount: 150,
        loadTime: const Duration(milliseconds: 850),
        dataSizeKB: 45.2,
        fromCache: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );

    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'WFS',
        layerName: 'Medium Dataset (Midpoints)',
        featureCount: 2500,
        loadTime: const Duration(milliseconds: 3200),
        dataSizeKB: 380.5,
        fromCache: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
    );

    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'WFS',
        layerName: 'Large Dataset (Streams)',
        featureCount: 15000,
        loadTime: const Duration(milliseconds: 12500),
        dataSizeKB: 2100.8,
        fromCache: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    );

    // Simulate Vector Tiles performance
    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'Vector Tiles',
        layerName: 'Small Dataset (Cities)',
        featureCount: -1,
        loadTime: const Duration(milliseconds: 120),
        dataSizeKB: 0,
        fromCache: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    );

    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'Vector Tiles',
        layerName: 'Medium Dataset (Waterways)',
        featureCount: -1,
        loadTime: const Duration(milliseconds: 180),
        dataSizeKB: 0,
        fromCache: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    _performanceService.recordMetrics(
      PerformanceMetrics(
        approach: 'Vector Tiles',
        layerName: 'Large Dataset (All Streams)',
        featureCount: -1,
        loadTime: const Duration(milliseconds: 250),
        dataSizeKB: 0,
        fromCache: false,
        timestamp: DateTime.now(),
      ),
    );

    print('📊 Generated demo performance data for presentation');
  }

  /// Clear all performance data
  void clearAllData() {
    _performanceService.clearMetrics();
  }

  /// Export all data for analysis
  String exportAllData() {
    return _performanceService.exportMetricsAsJson();
  }

  /// Get summary for quick presentation
  String getQuickSummary() {
    final report = getComparisonData();

    if (report.containsKey('error')) {
      return 'No performance data available. Load some layers to see comparison.';
    }

    final wfsTests = report['wfsMeasurements'] ?? 0;
    final vectorTests = report['vectorMeasurements'] ?? 0;

    if (wfsTests == 0 || vectorTests == 0) {
      return 'Need data from both approaches for comparison. Tests: WFS($wfsTests), Vector($vectorTests)';
    }

    if (report['comparison'] != null) {
      final improvement =
          report['comparison']['loadTimeImprovementPercent'] as double;
      if (improvement > 10) {
        return 'Vector Tiles are ${improvement.toStringAsFixed(0)}% faster than WFS (${wfsTests + vectorTests} tests)';
      } else if (improvement > 0) {
        return 'Vector Tiles show ${improvement.toStringAsFixed(0)}% improvement over WFS (${wfsTests + vectorTests} tests)';
      } else {
        return 'WFS performed ${(-improvement).toStringAsFixed(0)}% better in this comparison (${wfsTests + vectorTests} tests)';
      }
    }

    return 'Comparison data available for ${wfsTests + vectorTests} tests';
  }

  /// Calculate bbox area for metrics
  double _calculateBBoxArea(dynamic bbox) {
    try {
      if (bbox == null) return 0.0;

      // This is a simplified calculation
      // In a real implementation, you'd use proper geographic calculations
      final sw = bbox.southwest?.coordinates;
      final ne = bbox.northeast?.coordinates;

      if (sw != null && ne != null) {
        final width = (ne.lng - sw.lng).abs();
        final height = (ne.lat - sw.lat).abs();
        return width * height;
      }
    } catch (e) {
      print('Failed to calculate bbox area: $e');
    }
    return 0.0;
  }

  /// Print current status for debugging
  void printStatus() {
    print('\n🔧 INTEGRATION HELPER STATUS:');
    print(getQuickSummary());

    final report = getComparisonData();
    if (!report.containsKey('error')) {
      print('WFS measurements: ${report['wfsMeasurements']}');
      print('Vector measurements: ${report['vectorMeasurements']}');
    }

    _performanceService.printPerformanceSummary();
  }
}

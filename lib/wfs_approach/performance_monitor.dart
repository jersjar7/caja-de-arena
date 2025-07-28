// lib/performance_monitor.dart

class LayerLoadingMetrics {
  final String layerId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? featureCount;
  final bool success;
  final String? errorMessage;
  final Duration? duration;

  LayerLoadingMetrics({
    required this.layerId,
    required this.startTime,
    this.endTime,
    this.featureCount,
    required this.success,
    this.errorMessage,
    this.duration,
  });

  LayerLoadingMetrics copyWith({
    DateTime? endTime,
    int? featureCount,
    bool? success,
    String? errorMessage,
  }) {
    final newEndTime = endTime ?? this.endTime ?? DateTime.now();
    return LayerLoadingMetrics(
      layerId: layerId,
      startTime: startTime,
      endTime: newEndTime,
      featureCount: featureCount ?? this.featureCount,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: newEndTime.difference(startTime),
    );
  }

  @override
  String toString() {
    final durationStr = duration?.inMilliseconds ?? 'Unknown';
    final statusStr = success ? 'SUCCESS' : 'FAILED';
    final featuresStr = featureCount != null
        ? '$featureCount features'
        : 'Unknown features';

    return '[$statusStr] $layerId: ${durationStr}ms ($featuresStr)';
  }
}

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, LayerLoadingMetrics> _activeLoads = {};
  final List<LayerLoadingMetrics> _completedLoads = [];

  // Start tracking a layer load
  void startLayerLoad(String layerId) {
    _activeLoads[layerId] = LayerLoadingMetrics(
      layerId: layerId,
      startTime: DateTime.now(),
      success: false,
    );

    print('🚀 Started loading layer: $layerId');
  }

  // Update progress during load (e.g., when WFS request completes)
  void updateLayerLoad(String layerId, {int? featureCount, String? status}) {
    final current = _activeLoads[layerId];
    if (current != null) {
      final elapsed = DateTime.now()
          .difference(current.startTime)
          .inMilliseconds;
      print(
        '⏱️  Layer $layerId: $status (${elapsed}ms)${featureCount != null ? ' - $featureCount features' : ''}',
      );
    }
  }

  // Complete a layer load (success or failure)
  void completeLayerLoad(
    String layerId, {
    required bool success,
    int? featureCount,
    String? errorMessage,
  }) {
    final current = _activeLoads[layerId];
    if (current != null) {
      final completed = current.copyWith(
        success: success,
        featureCount: featureCount,
        errorMessage: errorMessage,
      );

      _completedLoads.add(completed);
      _activeLoads.remove(layerId);

      final emoji = success ? '✅' : '❌';
      print('$emoji Completed loading layer: ${completed.toString()}');

      if (!success && errorMessage != null) {
        print('   Error: $errorMessage');
      }

      // Performance warnings
      if (completed.duration != null) {
        final seconds = completed.duration!.inSeconds;
        if (seconds > 30) {
          print(
            '⚠️  WARNING: Layer $layerId took ${seconds}s to load - consider using vector tiles or pagination',
          );
        }

        if (featureCount != null && featureCount > 100000) {
          print(
            '⚠️  WARNING: Layer $layerId has $featureCount features - this may cause performance issues',
          );
        }
      }
    } else {
      print('❌ Attempted to complete unknown layer load: $layerId');
    }
  }

  // Get performance summary
  void printPerformanceSummary() {
    print('\n📊 PERFORMANCE SUMMARY:');
    print('Active loads: ${_activeLoads.length}');
    print('Completed loads: ${_completedLoads.length}');

    if (_completedLoads.isNotEmpty) {
      final successful = _completedLoads.where((load) => load.success).length;
      final failed = _completedLoads.length - successful;

      print(
        'Success rate: ${(successful / _completedLoads.length * 100).toStringAsFixed(1)}%',
      );
      print('Successful: $successful, Failed: $failed');

      // Average load time for successful loads
      final successfulLoads = _completedLoads.where(
        (load) => load.success && load.duration != null,
      );
      if (successfulLoads.isNotEmpty) {
        final avgTime =
            successfulLoads
                .map((load) => load.duration!.inMilliseconds)
                .reduce((a, b) => a + b) /
            successfulLoads.length;
        print('Average successful load time: ${avgTime.toStringAsFixed(0)}ms');
      }

      // List recent loads
      print('\nRecent loads:');
      _completedLoads.take(10).forEach((load) => print('  $load'));
    }

    if (_activeLoads.isNotEmpty) {
      print('\nCurrently loading:');
      for (var load in _activeLoads.values) {
        final elapsed = DateTime.now()
            .difference(load.startTime)
            .inMilliseconds;
        print('  ${load.layerId}: ${elapsed}ms (in progress)');
      }
    }
  }

  // Get metrics for a specific layer
  List<LayerLoadingMetrics> getLayerHistory(String layerId) {
    return _completedLoads.where((load) => load.layerId == layerId).toList();
  }

  // Clear old metrics (keep last 50)
  void cleanup() {
    if (_completedLoads.length > 50) {
      _completedLoads.removeRange(0, _completedLoads.length - 50);
    }
  }

  // Check if layer is currently loading
  bool isLayerLoading(String layerId) {
    return _activeLoads.containsKey(layerId);
  }

  // Get current loading layers
  List<String> getLoadingLayers() {
    return _activeLoads.keys.toList();
  }
}

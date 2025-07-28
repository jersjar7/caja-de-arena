// lib/bounded_wfs_loader.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'spatial_utils.dart';
import 'wfs_cache.dart';
import 'performance_monitor.dart';

/// WFS loading result
class WFSLoadResult {
  final String layerId;
  final String geojsonData;
  final int featureCount;
  final CoordinateBounds bbox;
  final double zoom;
  final bool fromCache;
  final Duration loadTime;
  final String source; // 'cache', 'wfs', 'error'

  const WFSLoadResult({
    required this.layerId,
    required this.geojsonData,
    required this.featureCount,
    required this.bbox,
    required this.zoom,
    required this.fromCache,
    required this.loadTime,
    required this.source,
  });

  @override
  String toString() {
    final sizeKB = (geojsonData.length / 1024).toStringAsFixed(1);
    final timeMs = loadTime.inMilliseconds;
    return '$layerId: $featureCount features, ${sizeKB}KB, ${timeMs}ms (${fromCache ? 'cache' : 'WFS'})';
  }
}

/// WFS loading error
class WFSLoadError {
  final String layerId;
  final String message;
  final CoordinateBounds bbox;
  final double zoom;
  final Duration attemptTime;
  final int? statusCode;

  const WFSLoadError({
    required this.layerId,
    required this.message,
    required this.bbox,
    required this.zoom,
    required this.attemptTime,
    this.statusCode,
  });

  @override
  String toString() {
    final timeMs = attemptTime.inMilliseconds;
    return '$layerId: $message (${timeMs}ms)${statusCode != null ? ' [HTTP $statusCode]' : ''}';
  }
}

/// Active WFS request tracking
class ActiveWFSRequest {
  final String requestId;
  final String layerId;
  final CoordinateBounds bbox;
  final double zoom;
  final DateTime startTime;
  final Completer<WFSLoadResult> completer;
  final CancelToken cancelToken;

  ActiveWFSRequest({
    required this.requestId,
    required this.layerId,
    required this.bbox,
    required this.zoom,
    required this.startTime,
    required this.completer,
    required this.cancelToken,
  });

  /// Cancel this request
  void cancel() {
    cancelToken.cancel();
    if (!completer.isCompleted) {
      completer.completeError(
        WFSLoadError(
          layerId: layerId,
          message: 'Request cancelled',
          bbox: bbox,
          zoom: zoom,
          attemptTime: DateTime.now().difference(startTime),
        ),
      );
    }
  }

  /// Check if request matches parameters (for deduplication)
  bool matches(
    String layerId,
    CoordinateBounds bbox,
    double zoom,
    int? maxFeatures,
  ) {
    return this.layerId == layerId &&
        SpatialUtils.doBoxesOverlapSignificantly(
          this.bbox,
          bbox,
          overlapThreshold: 0.9,
        ) &&
        (zoom - this.zoom).abs() < 1.0;
  }
}

/// Simple cancel token for HTTP requests
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Smart WFS loader with viewport-based loading and caching
class BoundedWFSLoader {
  static const String _defaultWfsBaseUrl =
      'https://geoserver.hydroshare.org/geoserver/HS-d4238b41de7f4e59b54ef7ae875cbaa0/wfs';

  final String wfsBaseUrl;
  final PerformanceMonitor performanceMonitor;

  // Request management
  final Map<String, ActiveWFSRequest> _activeRequests = {};
  Timer? _debounceTimer;

  // Statistics
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _wfsRequests = 0;
  int _errors = 0;

  BoundedWFSLoader({
    this.wfsBaseUrl = _defaultWfsBaseUrl,
    PerformanceMonitor? performanceMonitor,
  }) : performanceMonitor = performanceMonitor ?? PerformanceMonitor();

  /// Load WFS data for current viewport with smart caching and bbox filtering
  Future<WFSLoadResult> loadBoundedData({
    required String layerId,
    required MapboxMap mapboxMap,
    int? maxFeatures,
    Duration cacheMaxAge = const Duration(hours: 24),
    Duration debounceDelay = const Duration(milliseconds: 300),
  }) async {
    final startTime = DateTime.now();

    try {
      // Get current viewport bounds and zoom
      final bbox = await SpatialUtils.getBoundingBoxFromCamera(mapboxMap);
      final cameraState = await mapboxMap.getCameraState();
      final zoom = cameraState.zoom;

      // Generate cache key for deduplication
      final cacheKey = SpatialUtils.generateSpatialCacheKey(
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        maxFeatures: maxFeatures,
      );

      // Check for existing request (deduplication)
      final existingRequest = _activeRequests.values
          .where((req) => req.matches(layerId, bbox, zoom, maxFeatures))
          .firstOrNull;

      if (existingRequest != null) {
        print('🔄 Joining existing request for $layerId');
        return await existingRequest.completer.future;
      }

      // Start performance monitoring
      performanceMonitor.startLayerLoad(layerId);
      performanceMonitor.updateLayerLoad(layerId, status: 'Checking cache');

      // Check cache first
      final cached = await WFSCache.getCachedResponse(
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        maxFeatures: maxFeatures,
        maxAge: cacheMaxAge,
      );

      if (cached != null) {
        _cacheHits++;
        performanceMonitor.completeLayerLoad(
          layerId,
          success: true,
          featureCount: cached.featureCount,
        );

        final result = WFSLoadResult(
          layerId: layerId,
          geojsonData: cached.geojsonData,
          featureCount: cached.featureCount,
          bbox: cached.bbox,
          zoom: cached.zoom,
          fromCache: true,
          loadTime: DateTime.now().difference(startTime),
          source: 'cache',
        );

        print('⚡ Cache HIT: ${result.toString()}');
        return result;
      }

      // Cache miss - need to make WFS request
      _totalRequests++;
      performanceMonitor.updateLayerLoad(layerId, status: 'Making WFS request');

      // Create cancel token and active request tracker
      final cancelToken = CancelToken();
      final completer = Completer<WFSLoadResult>();
      final activeRequest = ActiveWFSRequest(
        requestId: cacheKey,
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        startTime: startTime,
        completer: completer,
        cancelToken: cancelToken,
      );

      _activeRequests[cacheKey] = activeRequest;

      // Make WFS request with viewport bounds (don't await - it completes via completer)
      _makeWFSRequest(
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        maxFeatures: maxFeatures,
        cancelToken: cancelToken,
        completer: completer,
        startTime: startTime,
      ).catchError((error) {
        // Handle any errors that aren't caught in _makeWFSRequest
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        _activeRequests.remove(cacheKey);
      });

      return await completer.future;
    } catch (e) {
      _errors++;
      performanceMonitor.completeLayerLoad(
        layerId,
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Load multiple layers for current viewport
  Future<Map<String, WFSLoadResult>> loadMultipleLayers({
    required List<String> layerIds,
    required MapboxMap mapboxMap,
    int? maxFeatures,
    Duration cacheMaxAge = const Duration(hours: 24),
  }) async {
    final results = <String, WFSLoadResult>{};

    // Create futures for all layer loads
    final futures = layerIds.map((layerId) async {
      try {
        final result = await loadBoundedData(
          layerId: layerId,
          mapboxMap: mapboxMap,
          maxFeatures: maxFeatures,
          cacheMaxAge: cacheMaxAge,
        );
        results[layerId] = result;
      } catch (e) {
        print('❌ Failed to load layer $layerId: $e');
        // Don't add to results if failed
      }
    }).toList();

    await Future.wait(futures);
    return results;
  }

  /// Cancel all active requests for a specific layer
  Future<void> cancelLayerRequests(String layerId) async {
    final toCancel = _activeRequests.values
        .where((req) => req.layerId == layerId)
        .toList();

    for (final request in toCancel) {
      request.cancel();
      _activeRequests.remove(request.requestId);
    }

    if (toCancel.isNotEmpty) {
      print('🚫 Cancelled ${toCancel.length} requests for layer: $layerId');
    }
  }

  /// Cancel all active requests
  Future<void> cancelAllRequests() async {
    final requestCount = _activeRequests.length;

    for (final request in _activeRequests.values) {
      request.cancel();
    }

    _activeRequests.clear();

    if (requestCount > 0) {
      print('🚫 Cancelled all $requestCount active requests');
    }
  }

  /// Get loader statistics
  Map<String, dynamic> getStats() {
    final cacheHitRate = _totalRequests > 0
        ? (_cacheHits / _totalRequests) * 100
        : 0.0;

    return {
      'totalRequests': _totalRequests,
      'cacheHits': _cacheHits,
      'wfsRequests': _wfsRequests,
      'errors': _errors,
      'cacheHitRate': cacheHitRate,
      'activeRequests': _activeRequests.length,
      'requestKeys': _activeRequests.keys.toList(),
    };
  }

  /// Print detailed statistics
  void printStats() {
    final stats = getStats();
    print('\n📊 BOUNDED WFS LOADER STATISTICS:');
    print('Total Requests: ${stats['totalRequests']}');
    print(
      'Cache Hits: ${stats['cacheHits']} (${stats['cacheHitRate'].toStringAsFixed(1)}%)',
    );
    print('WFS Requests: ${stats['wfsRequests']}');
    print('Errors: ${stats['errors']}');
    print('Active Requests: ${stats['activeRequests']}');
  }

  /// Reset statistics
  void resetStats() {
    _totalRequests = 0;
    _cacheHits = 0;
    _wfsRequests = 0;
    _errors = 0;
  }

  // Private methods

  Future<void> _makeWFSRequest({
    required String layerId,
    required CoordinateBounds bbox,
    required double zoom,
    required int? maxFeatures,
    required CancelToken cancelToken,
    required Completer<WFSLoadResult> completer,
    required DateTime startTime,
  }) async {
    try {
      // Determine appropriate max features based on zoom if not specified
      final effectiveMaxFeatures =
          maxFeatures ?? SpatialUtils.getMaxFeaturesForZoom(zoom, bbox);

      // Try different output formats for better compatibility
      final outputFormats = ['application/json', 'json'];

      for (final format in outputFormats) {
        if (cancelToken.isCancelled) return;

        final uri = Uri.parse(wfsBaseUrl).replace(
          queryParameters: {
            'service': 'wfs',
            'version': '2.0.0',
            'request': 'GetFeature',
            'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
            'outputFormat': format,
            'maxFeatures': effectiveMaxFeatures.toString(),
            'bbox': SpatialUtils.bboxToWFSString(bbox),
            'srsName': 'EPSG:4326',
          },
        );

        print(
          '🌐 WFS Request: $layerId (bbox, zoom:${zoom.toStringAsFixed(1)}, max:$effectiveMaxFeatures)',
        );

        try {
          final response = await http
              .get(
                uri,
                headers: {
                  'Accept': 'application/json, */*',
                  'User-Agent': 'Flutter-WFS-Client/1.0',
                },
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw TimeoutException(
                  'WFS request timeout',
                  const Duration(seconds: 30),
                ),
              );

          if (cancelToken.isCancelled) return;

          performanceMonitor.updateLayerLoad(
            layerId,
            status: 'WFS response received (${response.statusCode})',
          );

          if (response.statusCode == 200) {
            if (response.body.trim().startsWith('{')) {
              try {
                final data = jsonDecode(response.body);
                final featureCount = data['features']?.length ?? 0;

                _wfsRequests++;

                // Cache the successful response
                await WFSCache.cacheResponse(
                  layerId: layerId,
                  bbox: bbox,
                  geojsonData: response.body,
                  featureCount: featureCount,
                  zoom: zoom,
                  maxFeatures: effectiveMaxFeatures,
                );

                final result = WFSLoadResult(
                  layerId: layerId,
                  geojsonData: response.body,
                  featureCount: featureCount,
                  bbox: bbox,
                  zoom: zoom,
                  fromCache: false,
                  loadTime: DateTime.now().difference(startTime),
                  source: 'wfs',
                );

                performanceMonitor.completeLayerLoad(
                  layerId,
                  success: true,
                  featureCount: featureCount,
                );

                _activeRequests.remove(
                  SpatialUtils.generateSpatialCacheKey(
                    layerId: layerId,
                    bbox: bbox,
                    zoom: zoom,
                    maxFeatures: effectiveMaxFeatures,
                  ),
                );

                if (!completer.isCompleted) {
                  completer.complete(result);
                }

                print('✅ WFS SUCCESS: ${result.toString()}');
                return;
              } catch (e) {
                print('❌ JSON parsing failed for $layerId: $e');
                continue; // Try next format
              }
            } else if (response.body.contains('ExceptionReport')) {
              final errorMessage = _parseWFSException(response.body);
              print('❌ WFS Exception for $layerId: $errorMessage');
              continue; // Try next format
            }
          } else {
            print('❌ HTTP ${response.statusCode} for $layerId');
            continue; // Try next format
          }
        } catch (e) {
          print('❌ Request failed for $layerId with $format: $e');
          continue; // Try next format
        }
      }

      // If we get here, all formats failed
      _errors++;
      final error = WFSLoadError(
        layerId: layerId,
        message: 'All output formats failed',
        bbox: bbox,
        zoom: zoom,
        attemptTime: DateTime.now().difference(startTime),
      );

      performanceMonitor.completeLayerLoad(
        layerId,
        success: false,
        errorMessage: error.message,
      );

      _activeRequests.remove(
        SpatialUtils.generateSpatialCacheKey(
          layerId: layerId,
          bbox: bbox,
          zoom: zoom,
          maxFeatures: maxFeatures,
        ),
      );

      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    } catch (e) {
      _errors++;
      final error = WFSLoadError(
        layerId: layerId,
        message: e.toString(),
        bbox: bbox,
        zoom: zoom,
        attemptTime: DateTime.now().difference(startTime),
      );

      performanceMonitor.completeLayerLoad(
        layerId,
        success: false,
        errorMessage: error.message,
      );

      _activeRequests.remove(
        SpatialUtils.generateSpatialCacheKey(
          layerId: layerId,
          bbox: bbox,
          zoom: zoom,
          maxFeatures: maxFeatures,
        ),
      );

      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  String _parseWFSException(String xmlResponse) {
    try {
      final exceptionStart = xmlResponse.indexOf('<ows:ExceptionText>');
      final exceptionEnd = xmlResponse.indexOf('</ows:ExceptionText>');

      if (exceptionStart != -1 && exceptionEnd != -1) {
        return xmlResponse.substring(exceptionStart + 19, exceptionEnd);
      }

      final codeStart = xmlResponse.indexOf('exceptionCode="');
      if (codeStart != -1) {
        final codeEnd = xmlResponse.indexOf('"', codeStart + 15);
        if (codeEnd != -1) {
          return xmlResponse.substring(codeStart + 15, codeEnd);
        }
      }

      return 'Unknown WFS exception';
    } catch (e) {
      return 'Could not parse exception: $e';
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _debounceTimer?.cancel();
    cancelAllRequests();
  }
}

/// Extension to help with null safety
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

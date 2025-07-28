// lib/wfs_map_service.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'wfs_cache.dart';
import 'bounded_wfs_loader.dart';
import 'spatial_utils.dart';
import 'performance_monitor.dart';
import 'map_layer_styler.dart';

class WFSMapService {
  static const String wfsBaseUrl =
      'https://geoserver.hydroshare.org/geoserver/HS-d4238b41de7f4e59b54ef7ae875cbaa0/wfs';

  late BoundedWFSLoader _wfsLoader;
  late PerformanceMonitor _performanceMonitor;
  late ViewportChangeDetector _viewportDetector;
  late MapLayerStyler _layerStyler;

  MapboxMap? mapboxMap;

  WFSMapService() {
    _performanceMonitor = PerformanceMonitor();
    _viewportDetector = ViewportChangeDetector();
    _wfsLoader = BoundedWFSLoader(
      wfsBaseUrl: wfsBaseUrl,
      performanceMonitor: _performanceMonitor,
    );
    _layerStyler = MapLayerStyler();
  }

  /// Initialize the service
  Future<void> initialize() async {
    await WFSCache.initialize();
    print('✅ WFS Map Service initialized');
  }

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    mapboxMap = map;
    _layerStyler.setMapboxMap(map);
  }

  /// Load a layer with optimizations
  Future<WFSLoadResult?> loadLayer(
    String layerId,
    Map<String, dynamic> layerInfo,
  ) async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    try {
      print('🚀 Loading layer: $layerId (optimized)');

      // Try optimized loading first
      final result = await _wfsLoader.loadBoundedData(
        layerId: layerId,
        mapboxMap: mapboxMap!,
        maxFeatures: null,
        cacheMaxAge: const Duration(hours: 24),
      );

      if (result.featureCount > 0) {
        print('✅ Optimized loading success: ${result.featureCount} features');
        await _addDataToMap(layerId, result, layerInfo);
        return result;
      } else {
        print('⚠️ Optimized loading returned 0 features, trying fallback...');
        return await _loadLayerFallback(layerId, layerInfo);
      }
    } catch (e) {
      print('❌ Optimized loading failed: $e');
      return await _loadLayerFallback(layerId, layerInfo);
    }
  }

  /// Fallback loading method (no bbox restrictions)
  Future<WFSLoadResult?> _loadLayerFallback(
    String layerId,
    Map<String, dynamic> layerInfo,
  ) async {
    try {
      print('🔄 Fallback loading for $layerId...');

      final outputFormats = ['application/json', 'json'];

      for (final format in outputFormats) {
        final uri = Uri.parse(wfsBaseUrl).replace(
          queryParameters: {
            'service': 'wfs',
            'version': '2.0.0',
            'request': 'GetFeature',
            'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
            'outputFormat': format,
            'maxFeatures': '5000',
          },
        );

        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json, application/geo+json, */*',
            'User-Agent': 'Flutter-WFS-Client/1.0',
          },
        );

        if (response.statusCode == 200 &&
            response.body.trim().startsWith('{')) {
          final data = jsonDecode(response.body);
          final featureCount = data['features']?.length ?? 0;

          if (featureCount > 0) {
            print('✅ Fallback success: $featureCount features');

            // Cache the result
            await _cacheResult(layerId, response.body, featureCount);

            // Create result object
            final result = WFSLoadResult(
              layerId: layerId,
              geojsonData: response.body,
              featureCount: featureCount,
              bbox: await SpatialUtils.getBoundingBoxFromCamera(mapboxMap!),
              zoom: (await mapboxMap!.getCameraState()).zoom,
              fromCache: false,
              loadTime: Duration.zero,
              source: 'fallback',
            );

            await _addDataToMap(layerId, result, layerInfo);
            return result;
          }
        }
      }

      throw Exception('All loading methods failed');
    } catch (e) {
      print('❌ Fallback loading failed: $e');
      rethrow;
    }
  }

  /// Add data to map
  Future<void> _addDataToMap(
    String layerId,
    WFSLoadResult result,
    Map<String, dynamic> layerInfo,
  ) async {
    try {
      // Remove existing layers
      await removeLayer(layerId);

      print('🗺️ Adding ${result.featureCount} features to map for $layerId');

      // Add source
      if (layerInfo['type'] == 'point') {
        await mapboxMap!.style.addSource(
          GeoJsonSource(
            id: "${layerId}_source",
            data: result.geojsonData,
            cluster: true,
            clusterMaxZoom: 14,
            clusterRadius: 50,
          ),
        );
      } else {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: "${layerId}_source", data: result.geojsonData),
        );
      }

      // Add styled layers
      await _layerStyler.addStyledLayer(layerId, layerInfo);
    } catch (e) {
      print('❌ Error adding data to map: $e');
      rethrow;
    }
  }

  /// Remove a layer from the map
  Future<void> removeLayer(String layerId) async {
    if (mapboxMap == null) return;

    try {
      final layersToRemove = [
        "${layerId}_clusters",
        "${layerId}_count",
        "${layerId}_unclustered",
        "${layerId}_lines",
      ];

      for (final layerName in layersToRemove) {
        try {
          await mapboxMap!.style.removeStyleLayer(layerName);
        } catch (e) {
          // Layer might not exist
        }
      }

      try {
        await mapboxMap!.style.removeStyleSource("${layerId}_source");
      } catch (e) {
        // Source might not exist
      }
    } catch (e) {
      print('❌ Error removing layer $layerId: $e');
    }
  }

  /// Cache a successful result
  Future<void> _cacheResult(
    String layerId,
    String geojsonData,
    int featureCount,
  ) async {
    try {
      final cameraState = await mapboxMap!.getCameraState();
      final largeBounds = CoordinateBounds(
        southwest: Point(coordinates: Position(-180.0, -90.0)),
        northeast: Point(coordinates: Position(180.0, 90.0)),
        infiniteBounds: false,
      );

      await WFSCache.cacheResponse(
        layerId: layerId,
        bbox: largeBounds,
        geojsonData: geojsonData,
        featureCount: featureCount,
        zoom: cameraState.zoom,
        maxFeatures: 5000,
      );
    } catch (e) {
      print('⚠️ Failed to cache result: $e');
    }
  }

  /// Refresh layers for current viewport
  Future<List<WFSLoadResult>> refreshViewport(
    List<String> layerIds,
    Map<String, Map<String, dynamic>> layerInfo,
  ) async {
    _viewportDetector.reset();
    final results = <WFSLoadResult>[];

    for (final layerId in layerIds) {
      try {
        final result = await loadLayer(layerId, layerInfo[layerId]!);
        if (result != null) {
          results.add(result);
        }
      } catch (e) {
        print('❌ Failed to refresh layer $layerId: $e');
      }
    }

    return results;
  }

  /// Get cache statistics
  Future<WFSCacheStats> getCacheStats() async {
    return await WFSCache.getStats();
  }

  /// Clear cache
  Future<void> clearCache() async {
    await WFSCache.clearAll();
  }

  /// Clear expired cache entries
  Future<int> clearExpiredCache() async {
    return await WFSCache.clearExpired();
  }

  /// Print performance statistics
  void printStats() {
    _performanceMonitor.printPerformanceSummary();
    _wfsLoader.printStats();
  }

  /// Dispose resources
  void dispose() {
    _wfsLoader.dispose();
  }
}

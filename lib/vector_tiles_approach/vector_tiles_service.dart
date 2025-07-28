// lib/vector_tiles_approach/vector_tiles_service.dart
import 'dart:ui';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing Mapbox Vector Tiles
class VectorTilesService {
  MapboxMap? mapboxMap;

  // Track loaded tilesets
  final Set<String> _loadedTilesets = {};

  // Performance metrics
  final Map<String, DateTime> _loadStartTimes = {};
  final Map<String, Duration> _loadDurations = {};
  int _totalTilesLoaded = 0;

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    mapboxMap = map;
    print('✅ Vector Tiles Service ready');
  }

  /// Add a Mapbox Vector Tiles source
  Future<void> addVectorTileSource({
    required String sourceId,
    required String tilesetId,
    required String accessToken,
  }) async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    _loadStartTimes[sourceId] = DateTime.now();

    try {
      // Remove existing source if it exists
      try {
        await mapboxMap!.style.removeStyleSource(sourceId);
      } catch (e) {
        // Source might not exist, that's fine
      }

      // For demonstration, we'll use a sample Mapbox tileset
      // In production, you'd upload your HydroShare data to Mapbox as a tileset
      final tileUrl = 'mapbox://$tilesetId';

      await mapboxMap!.style.addSource(
        VectorSource(id: sourceId, url: tileUrl),
      );

      _loadedTilesets.add(sourceId);
      _loadDurations[sourceId] = DateTime.now().difference(
        _loadStartTimes[sourceId]!,
      );
      _totalTilesLoaded++;

      print('✅ Vector tile source added: $sourceId');
      print('   Tileset: $tilesetId');
      print('   Load time: ${_loadDurations[sourceId]!.inMilliseconds}ms');
    } catch (e) {
      print('❌ Failed to add vector tile source $sourceId: $e');
      rethrow;
    }
  }

  /// Add a vector tile layer for streams
  Future<void> addStreamLayer({
    required String layerId,
    required String sourceId,
    required String sourceLayer,
    Color color = const Color(0xFF0066CC),
    double width = 2.0,
  }) async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    try {
      // Remove existing layer if it exists
      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
      } catch (e) {
        // Layer might not exist
      }

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: layerId,
          sourceId: sourceId,
          sourceLayer: sourceLayer,
          lineColor: color.value,
          lineWidth: width,
          lineOpacity: 0.8,
        ),
      );

      print('✅ Stream vector layer added: $layerId');
    } catch (e) {
      print('❌ Failed to add stream layer $layerId: $e');
      rethrow;
    }
  }

  /// Add a vector tile layer for points (gauges, etc.)
  Future<void> addPointLayer({
    required String layerId,
    required String sourceId,
    required String sourceLayer,
    Color color = const Color(0xFFFF0000),
    double radius = 6.0,
  }) async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    try {
      // Remove existing layer if it exists
      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
      } catch (e) {
        // Layer might not exist
      }

      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: layerId,
          sourceId: sourceId,
          sourceLayer: sourceLayer,
          circleRadius: radius,
          circleColor: color.value,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 1.0,
          circleOpacity: 0.9,
        ),
      );

      print('✅ Point vector layer added: $layerId');
    } catch (e) {
      print('❌ Failed to add point layer $layerId: $e');
      rethrow;
    }
  }

  /// Set layer visibility
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    if (mapboxMap == null) return;

    try {
      await mapboxMap!.style.setStyleLayerProperty(
        layerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
      print('✅ Set visibility for $layerId: $visible');
    } catch (e) {
      print('❌ Failed to set layer visibility: $e');
    }
  }

  /// Update layer color
  Future<void> updateLayerColor(String layerId, Color color) async {
    if (mapboxMap == null) return;

    try {
      // Try as line layer first
      try {
        await mapboxMap!.style.setStyleLayerProperty(
          layerId,
          'line-color',
          color.value,
        );
        return;
      } catch (e) {
        // Not a line layer, try circle
      }

      // Try as circle layer
      await mapboxMap!.style.setStyleLayerProperty(
        layerId,
        'circle-color',
        color.value,
      );

      print('✅ Updated color for $layerId');
    } catch (e) {
      print('❌ Failed to update layer color: $e');
    }
  }

  /// Remove a layer
  Future<void> removeLayer(String layerId) async {
    if (mapboxMap == null) return;

    try {
      await mapboxMap!.style.removeStyleLayer(layerId);
      print('✅ Removed layer: $layerId');
    } catch (e) {
      print('⚠️ Layer $layerId might not exist: $e');
    }
  }

  /// Remove a source (and all its layers)
  Future<void> removeSource(String sourceId) async {
    if (mapboxMap == null) return;

    try {
      await mapboxMap!.style.removeStyleSource(sourceId);
      _loadedTilesets.remove(sourceId);
      print('✅ Removed source: $sourceId');
    } catch (e) {
      print('⚠️ Source $sourceId might not exist: $e');
    }
  }

  /// Query vector tile features at a point
  Future<List<QueriedRenderedFeature?>> queryFeaturesAtPoint({
    required ScreenCoordinate point,
    List<String>? layerIds,
  }) async {
    if (mapboxMap == null) return [];

    try {
      final queryBox = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(x: point.x - 5, y: point.y - 5),
          max: ScreenCoordinate(x: point.x + 5, y: point.y + 5),
        ),
      );

      final features = await mapboxMap!.queryRenderedFeatures(
        queryBox,
        RenderedQueryOptions(layerIds: layerIds),
      );

      return features;
    } catch (e) {
      print('❌ Error querying vector tile features: $e');
      return [];
    }
  }

  /// Add a sample Mapbox Streets tileset source for demonstration
  Future<void> addSampleStreamsSource() async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    try {
      // This uses a built-in Mapbox tileset for demonstration
      // In production, you'd upload your HydroShare streams data to Mapbox
      await mapboxMap!.style.addSource(
        VectorSource(
          id: 'sample-streams-source',
          url: 'mapbox://mapbox.mapbox-streets-v8',
        ),
      );

      // Add a layer using the waterway data from Mapbox Streets
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'sample-streams',
          sourceId: 'sample-streams-source',
          sourceLayer: 'waterway', // This is the layer name within the tileset
          lineColor: 0xFF0066CC,
          lineWidth: 2.0,
          lineOpacity: 0.8,
          filter: [
            'in',
            ['get', 'class'],
            [
              'literal',
              ['river', 'stream', 'canal'],
            ],
          ],
        ),
      );

      _loadedTilesets.add('sample-streams-source');
      print('✅ Sample streams vector layer added using Mapbox Streets');
      print('   This demonstrates vector tile performance with built-in data');
    } catch (e) {
      print('❌ Failed to add sample streams: $e');
      rethrow;
    }
  }

  /// Add a sample point layer for cities (to demonstrate point vector tiles)
  Future<void> addSamplePointsSource() async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    try {
      // Use built-in place labels for demonstration
      await mapboxMap!.style.addSource(
        VectorSource(
          id: 'sample-points-source',
          url: 'mapbox://mapbox.mapbox-streets-v8',
        ),
      );

      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'sample-cities',
          sourceId: 'sample-points-source',
          sourceLayer: 'place_label',
          circleRadius: 8.0,
          circleColor: 0xFFFF6600,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.0,
          circleOpacity: 0.8,
          filter: [
            '==',
            ['get', 'type'],
            'city',
          ],
        ),
      );

      _loadedTilesets.add('sample-points-source');
      print('✅ Sample points vector layer added using Mapbox Streets cities');
    } catch (e) {
      print('❌ Failed to add sample points: $e');
      rethrow;
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final totalLoadTime = _loadDurations.values.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    return {
      'totalTilesets': _loadedTilesets.length,
      'totalTilesLoaded': _totalTilesLoaded,
      'averageLoadTime': _loadDurations.isNotEmpty
          ? totalLoadTime.inMilliseconds / _loadDurations.length
          : 0.0,
      'loadedSources': _loadedTilesets.toList(),
      'loadDurations': _loadDurations.map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
    };
  }

  /// Print performance summary
  void printPerformanceStats() {
    final stats = getPerformanceStats();
    print('\n📊 VECTOR TILES PERFORMANCE STATS:');
    print('Total tilesets: ${stats['totalTilesets']}');
    print('Total tiles loaded: ${stats['totalTilesLoaded']}');
    print('Average load time: ${stats['averageLoadTime']}ms');
    print('Loaded sources: ${stats['loadedSources']}');

    if (_loadDurations.isNotEmpty) {
      print('\nLoad times by source:');
      _loadDurations.forEach((source, duration) {
        print('  $source: ${duration.inMilliseconds}ms');
      });
    }
  }

  /// Check if a source is loaded
  bool isSourceLoaded(String sourceId) {
    return _loadedTilesets.contains(sourceId);
  }

  /// Get list of loaded sources
  List<String> get loadedSources => _loadedTilesets.toList();

  /// Clean up resources
  void dispose() {
    _loadedTilesets.clear();
    _loadStartTimes.clear();
    _loadDurations.clear();
    mapboxMap = null;
  }
}

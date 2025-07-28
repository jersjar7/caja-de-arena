// lib/vector_tiles_approach/vector_tiles_service.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing streams2 Vector Tiles
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
    print('✅ Vector Tiles Service ready for streams2');
  }

  /// Add streams2 vector tiles with stream order styling
  Future<void> addStreams2VectorTiles() async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    final sourceId = 'streams2-source';
    _loadStartTimes[sourceId] = DateTime.now();

    try {
      // Remove existing source and layers if they exist
      await removeStreams2Layers();

      print('🚀 Adding streams2 vector source: jersondevs.dopm8y3j');

      // Add the vector source with your real tileset
      await mapboxMap!.style.addSource(
        VectorSource(
          id: sourceId,
          url: 'mapbox://jersondevs.dopm8y3j', // Your real tileset ID!
        ),
      );

      print('✅ streams2 vector source added, now adding styled layers...');

      // Add multiple layers styled by stream order
      await _addStreamOrderLayers(sourceId);

      _loadedTilesets.add(sourceId);
      _loadDurations[sourceId] = DateTime.now().difference(
        _loadStartTimes[sourceId]!,
      );
      _totalTilesLoaded++;

      print('✅ streams2 vector tiles loaded with stream order styling');
      print('   Features: 364,115 streams');
      print('   Load time: ${_loadDurations[sourceId]!.inMilliseconds}ms');
    } catch (e) {
      print('❌ Failed to add streams2 vector tiles: $e');
      rethrow;
    }
  }

  /// Add multiple layers for different stream orders
  Future<void> _addStreamOrderLayers(String sourceId) async {
    // Layer 1: Stream Order 1-2 (Small streams) - Light blue, thin
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: 'streams2-order-1-2',
        sourceId: sourceId,
        sourceLayer: 'streams2', // This matches your GeoJSON filename
        lineColor: 0xFF87CEEB, // Light blue
        lineWidth: 1.0,
        lineOpacity: 0.8,
        filter: [
          'all',
          [
            '>=',
            ['get', 'streamOrde'],
            1,
          ],
          [
            '<=',
            ['get', 'streamOrde'],
            2,
          ],
        ],
      ),
    );

    // Layer 2: Stream Order 3-4 (Medium streams) - Medium blue, medium width
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: 'streams2-order-3-4',
        sourceId: sourceId,
        sourceLayer: 'streams2',
        lineColor: 0xFF4682B4, // Steel blue
        lineWidth: 2.0,
        lineOpacity: 0.9,
        filter: [
          'all',
          [
            '>=',
            ['get', 'streamOrde'],
            3,
          ],
          [
            '<=',
            ['get', 'streamOrde'],
            4,
          ],
        ],
      ),
    );

    // Layer 3: Stream Order 5+ (Large rivers) - Dark blue, thick
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: 'streams2-order-5-plus',
        sourceId: sourceId,
        sourceLayer: 'streams2',
        lineColor: 0xFF191970, // Midnight blue
        lineWidth: 3.5,
        lineOpacity: 1.0,
        filter: [
          '>=',
          ['get', 'streamOrde'],
          5,
        ],
      ),
    );

    print('✅ Added 3 stream order layers for visual hierarchy');
  }

  /// Remove all streams2 layers and source
  Future<void> removeStreams2Layers() async {
    if (mapboxMap == null) return;

    final layersToRemove = [
      'streams2-order-1-2',
      'streams2-order-3-4',
      'streams2-order-5-plus',
    ];

    // Remove layers
    for (final layerId in layersToRemove) {
      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
        print('✅ Removed layer: $layerId');
      } catch (e) {
        // Layer might not exist, that's fine
      }
    }

    // Remove source
    try {
      await mapboxMap!.style.removeStyleSource('streams2-source');
      _loadedTilesets.remove('streams2-source');
      print('✅ Removed streams2 source');
    } catch (e) {
      // Source might not exist, that's fine
    }
  }

  /// Set streams2 layer visibility
  Future<void> setStreams2Visibility(bool visible) async {
    if (mapboxMap == null) return;

    final visibility = visible ? 'visible' : 'none';
    final layers = [
      'streams2-order-1-2',
      'streams2-order-3-4',
      'streams2-order-5-plus',
    ];

    for (final layerId in layers) {
      try {
        await mapboxMap!.style.setStyleLayerProperty(
          layerId,
          'visibility',
          visibility,
        );
      } catch (e) {
        print('⚠️ Could not set visibility for $layerId: $e');
      }
    }

    print('✅ Set streams2 visibility: $visible');
  }

  /// Query streams2 features at a point
  Future<List<QueriedRenderedFeature?>> queryStreams2AtPoint({
    required ScreenCoordinate point,
  }) async {
    if (mapboxMap == null) return [];

    try {
      final queryBox = RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(x: point.x - 8, y: point.y - 8),
          max: ScreenCoordinate(x: point.x + 8, y: point.y + 8),
        ),
      );

      // Query all streams2 layers
      final layerIds = [
        'streams2-order-1-2',
        'streams2-order-3-4',
        'streams2-order-5-plus',
      ];

      final features = await mapboxMap!.queryRenderedFeatures(
        queryBox,
        RenderedQueryOptions(layerIds: layerIds),
      );

      return features;
    } catch (e) {
      print('❌ Error querying streams2 features: $e');
      return [];
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
      'streams2Loaded': _loadedTilesets.contains('streams2-source'),
    };
  }

  /// Print performance summary
  void printPerformanceStats() {
    final stats = getPerformanceStats();
    print('\n📊 STREAMS2 VECTOR TILES PERFORMANCE:');
    print('streams2 loaded: ${stats['streams2Loaded']}');
    print('Total tilesets: ${stats['totalTilesets']}');
    print('Average load time: ${stats['averageLoadTime']}ms');

    if (stats['streams2Loaded']) {
      print('✅ 364,115 stream features ready for interaction');
      print('✅ 3 layers styled by stream order (1-2, 3-4, 5+)');
    }

    if (_loadDurations.isNotEmpty) {
      print('\nLoad times by source:');
      _loadDurations.forEach((source, duration) {
        print('  $source: ${duration.inMilliseconds}ms');
      });
    }
  }

  /// Check if streams2 is loaded
  bool get isStreams2Loaded => _loadedTilesets.contains('streams2-source');

  /// Get list of loaded sources
  List<String> get loadedSources => _loadedTilesets.toList();

  /// Clean up resources
  void dispose() {
    _loadedTilesets.clear();
    _loadStartTimes.clear();
    _loadDurations.clear();
    mapboxMap = null;
    print('🗑️ Vector tiles service disposed');
  }
}

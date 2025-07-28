// lib/vector_tiles_approach/vector_tiles_service.dart (DEBUG VERSION)
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing streams2 Vector Tiles with debugging
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

  /// Add streams2 vector tiles with debugging
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

      print('✅ streams2 vector source added, now adding DEBUG layers...');

      // STEP 1: Add a simple layer without filters to test basic visibility
      await _addDebugLayer(sourceId);

      _loadedTilesets.add(sourceId);
      _loadDurations[sourceId] = DateTime.now().difference(
        _loadStartTimes[sourceId]!,
      );
      _totalTilesLoaded++;

      print('✅ DEBUG streams2 vector tiles loaded');
      print('   Load time: ${_loadDurations[sourceId]!.inMilliseconds}ms');

      // Wait a moment then try to query the source for debugging
      await Future.delayed(Duration(seconds: 2));
      await _debugTilesetStructure();
    } catch (e) {
      print('❌ Failed to add streams2 vector tiles: $e');
      rethrow;
    }
  }

  /// Add a simple debug layer to test basic visibility
  Future<void> _addDebugLayer(String sourceId) async {
    try {
      // STEP 1: Try without sourceLayer first (this will show if the source loads)
      print('🔧 Adding basic debug layer without sourceLayer...');

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-debug-basic',
          sourceId: sourceId,
          // NO sourceLayer specified - this will try to render any vector data
          lineColor: 0xFFFF0000, // Bright red
          lineWidth: 5.0, // Very thick so it's visible
          lineOpacity: 1.0, // Full opacity
        ),
      );

      print('✅ Added basic debug layer');

      // STEP 2: Try with the sourceLayer we think is correct
      print('🔧 Adding debug layer WITH sourceLayer: streams2...');

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-debug-with-source-layer',
          sourceId: sourceId,
          sourceLayer: 'streams2', // This is what we think the source layer is
          lineColor: 0xFF00FF00, // Bright green
          lineWidth: 3.0, // Thick
          lineOpacity: 1.0, // Full opacity
        ),
      );

      print('✅ Added sourceLayer debug layer');

      // STEP 3: Try with different possible source layer names
      final possibleSourceLayers = [
        'streams2', // What we expect
        'default', // Common default
        'data', // Another common name
        'layer', // Generic name
        '', // Empty string
      ];

      for (int i = 0; i < possibleSourceLayers.length; i++) {
        final layerName = possibleSourceLayers[i];
        try {
          await mapboxMap!.style.addLayer(
            LineLayer(
              id: 'streams2-debug-test-$i',
              sourceId: sourceId,
              sourceLayer: layerName.isEmpty ? null : layerName,
              lineColor: _getDebugColor(i), // Different color for each test
              lineWidth: 2.0,
              lineOpacity: 0.8,
            ),
          );
          print('✅ Added test layer $i with sourceLayer: "$layerName"');
        } catch (e) {
          print(
            '❌ Failed to add test layer $i with sourceLayer "$layerName": $e',
          );
        }
      }
    } catch (e) {
      print('❌ Failed to add debug layers: $e');
      rethrow;
    }
  }

  /// Get different colors for debug layers
  int _getDebugColor(int index) {
    final colors = [
      0xFFFF0000, // Red
      0xFF00FF00, // Green
      0xFF0000FF, // Blue
      0xFFFFFF00, // Yellow
      0xFFFF00FF, // Magenta
      0xFF00FFFF, // Cyan
    ];
    return colors[index % colors.length];
  }

  /// Debug the tileset structure by trying to inspect it
  Future<void> _debugTilesetStructure() async {
    try {
      print('🔍 DEBUGGING TILESET STRUCTURE:');

      // Try to query features to see what's actually in the tileset
      if (mapboxMap != null) {
        print('📊 Attempting to query features from the map...');

        // Get the current camera bounds
        final cameraState = await mapboxMap!.getCameraState();
        print(
          '🎯 Current camera: ${cameraState.center.coordinates.lng}, ${cameraState.center.coordinates.lat} at zoom ${cameraState.zoom}',
        );

        // ZOOM LEVEL DEBUG: Test at multiple zoom levels
        if (cameraState.zoom < 8) {
          print('⚠️  ZOOM TOO LOW! Current zoom: ${cameraState.zoom}');
          print('   Streams typically only visible at zoom 8+');
          print('   Testing by zooming to a stream-rich area...');

          // Zoom to a stream-rich area (St. Louis, Missouri - Mississippi River)
          await mapboxMap!.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(-90.0715, 38.6270)),
              zoom: 10.0,
            ),
          );

          // Wait for the zoom to complete and tiles to load
          await Future.delayed(Duration(seconds: 3));
          print('🎯 Zoomed to Mississippi River area at zoom 10.0');
        }

        // Create a query box in the center of the screen
        final screenCenter = ScreenCoordinate(x: 200, y: 400); // Rough center
        final queryBox = RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(
              x: screenCenter.x - 50,
              y: screenCenter.y - 50,
            ),
            max: ScreenCoordinate(
              x: screenCenter.x + 50,
              y: screenCenter.y + 50,
            ),
          ),
        );

        // Query all our debug layers
        final debugLayerIds = [
          'streams2-debug-basic',
          'streams2-debug-with-source-layer',
          'streams2-debug-test-0',
          'streams2-debug-test-1',
          'streams2-debug-test-2',
          'streams2-debug-test-3',
          'streams2-debug-test-4',
        ];

        bool foundAnyFeatures = false;

        for (final layerId in debugLayerIds) {
          try {
            final features = await mapboxMap!.queryRenderedFeatures(
              queryBox,
              RenderedQueryOptions(layerIds: [layerId]),
            );

            print('🔍 Layer "$layerId": Found ${features.length} features');

            if (features.isNotEmpty && features.first != null) {
              foundAnyFeatures = true;
              final feature = features.first!;
              final properties = feature.queriedFeature.feature['properties'];
              print(
                '   ✅ SUCCESS! Properties keys: ${(properties is Map) ? (properties).keys.toList() : []}',
              );
              if (properties != null &&
                  properties is Map &&
                  properties.isNotEmpty) {
                (properties).forEach((key, value) {
                  print('     $key: $value');
                });
              }

              // If we found features, this layer works!
              print('🎉 WORKING LAYER FOUND: $layerId');
              if (layerId.contains('test-0')) {
                print('   ✅ sourceLayer should be: "streams2"');
              } else if (layerId.contains('test-1')) {
                print('   ✅ sourceLayer should be: "default"');
              } else if (layerId.contains('test-2')) {
                print('   ✅ sourceLayer should be: "data"');
              } else if (layerId.contains('test-3')) {
                print('   ✅ sourceLayer should be: "layer"');
              } else if (layerId.contains('test-4')) {
                print('   ✅ sourceLayer should be: "" (empty)');
              } else if (layerId.contains('basic')) {
                print('   ✅ No sourceLayer needed');
              } else if (layerId.contains('with-source-layer')) {
                print('   ✅ sourceLayer "streams2" works');
              }
            }
          } catch (e) {
            print('❌ Error querying layer "$layerId": $e');
          }
        }

        if (!foundAnyFeatures) {
          print('⚠️  STILL NO FEATURES FOUND AT HIGHER ZOOM');
          print('   This suggests either:');
          print('   1. Wrong tileset ID');
          print('   2. Tileset has no data in this area');
          print('   3. Tileset uses a completely different source layer name');
          print('   4. Tileset might be corrupted or empty');
        }

        // Also try a general query without layer restrictions
        try {
          print('🔍 Querying ALL rendered features...');
          final allFeatures = await mapboxMap!.queryRenderedFeatures(
            queryBox,
            RenderedQueryOptions(),
          );
          print('📊 Total rendered features found: ${allFeatures.length}');

          // Look for any features that might be from our source
          for (final feature in allFeatures) {
            if (feature != null) {
              final source = feature.queriedFeature.source;
              if (source.contains('streams2')) {
                print('🎯 Found streams2 feature in source: $source');
                final layers = feature.layers;
                print('   Rendered in layers: $layers');
              }
            }
          }
        } catch (e) {
          print('❌ Error with general query: $e');
        }
      }
    } catch (e) {
      print('❌ Error debugging tileset structure: $e');
    }
  }

  /// Remove all streams2 layers and source
  Future<void> removeStreams2Layers() async {
    if (mapboxMap == null) return;

    // Remove all debug layers
    final layersToRemove = [
      'streams2-debug-basic',
      'streams2-debug-with-source-layer',
      'streams2-debug-test-0',
      'streams2-debug-test-1',
      'streams2-debug-test-2',
      'streams2-debug-test-3',
      'streams2-debug-test-4',
      'streams2-order-1-2',
      'streams2-order-3-4',
      'streams2-order-5-plus',
    ];

    // Remove layers
    for (final layerId in layersToRemove) {
      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
      } catch (e) {
        // Layer might not exist, that's fine
      }
    }

    // Remove source
    try {
      await mapboxMap!.style.removeStyleSource('streams2-source');
      _loadedTilesets.remove('streams2-source');
      print('✅ Removed streams2 source and debug layers');
    } catch (e) {
      // Source might not exist, that's fine
    }
  }

  /// Set streams2 layer visibility
  Future<void> setStreams2Visibility(bool visible) async {
    if (mapboxMap == null) return;

    final visibility = visible ? 'visible' : 'none';
    final layers = [
      'streams2-debug-basic',
      'streams2-debug-with-source-layer',
      'streams2-debug-test-0',
      'streams2-debug-test-1',
      'streams2-debug-test-2',
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

    print('✅ Set streams2 debug visibility: $visible');
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

      // Query all debug layers
      final layerIds = [
        'streams2-debug-basic',
        'streams2-debug-with-source-layer',
        'streams2-debug-test-0',
        'streams2-debug-test-1',
        'streams2-debug-test-2',
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
    print('\n📊 STREAMS2 VECTOR TILES DEBUG PERFORMANCE:');
    print('streams2 loaded: ${stats['streams2Loaded']}');
    print('Total tilesets: ${stats['totalTilesets']}');
    print('Average load time: ${stats['averageLoadTime']}ms');

    if (stats['streams2Loaded']) {
      print('✅ Debug layers should be visible with bright colors');
      print('✅ Check the map for RED, GREEN, BLUE, YELLOW lines');
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

// lib/vector_tiles_approach/vector_tiles_service.dart (DEBUG VERSION)
import 'dart:convert';

import 'package:http/http.dart' as http;
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
      // STEP 1: Use the CORRECT source layer name from Mapbox Studio
      print('🔧 Adding debug layer with CORRECT sourceLayer: streams2-7jgd8p');

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-debug-correct',
          sourceId: sourceId,
          sourceLayer: 'streams2-7jgd8p', // ✅ CORRECT source layer name!
          lineColor: 0xFFFF0000, // Bright red
          lineWidth: 5.0, // Very thick so it's visible
          lineOpacity: 1.0, // Full opacity
        ),
      );

      print('✅ Added correct debug layer');

      // STEP 2: Also test different stream orders with proper styling
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-1-2',
          sourceId: sourceId,
          sourceLayer: 'streams2-7jgd8p', // ✅ CORRECT source layer name!
          lineColor: 0xFF87CEEB, // Light blue
          lineWidth: 1.0,
          lineOpacity: 0.8,
          filter: [
            "<=",
            ["get", "streamOrde"],
            2,
          ], // Note: it's "streamOrde" not "streamOrder"
        ),
      );

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-3-4',
          sourceId: sourceId,
          sourceLayer: 'streams2-7jgd8p', // ✅ CORRECT source layer name!
          lineColor: 0xFF4682B4, // Steel blue
          lineWidth: 2.0,
          lineOpacity: 0.8,
          filter: [
            "all",
            [
              ">=",
              ["get", "streamOrde"],
              3,
            ],
            [
              "<=",
              ["get", "streamOrde"],
              4,
            ],
          ],
        ),
      );

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'streams2-order-5-plus',
          sourceId: sourceId,
          sourceLayer: 'streams2-7jgd8p', // ✅ CORRECT source layer name!
          lineColor: 0xFF191970, // Midnight blue
          lineWidth: 3.5,
          lineOpacity: 0.9,
          filter: [
            ">=",
            ["get", "streamOrde"],
            5,
          ],
        ),
      );

      print('✅ Added styled stream order layers');
    } catch (e) {
      print('❌ Failed to add debug layers: $e');
      rethrow;
    }
  }

  /// Debug the tileset structure with CORRECT zoom level
  Future<void> _debugTilesetStructure() async {
    try {
      print('🔍 DEBUGGING TILESET STRUCTURE:');

      if (mapboxMap != null) {
        final cameraState = await mapboxMap!.getCameraState();
        print('🎯 Current camera zoom: ${cameraState.zoom}');

        // ✅ ZOOM TO CORRECT LEVEL (7-13 range)
        if (cameraState.zoom < 8) {
          print('⚠️  ZOOM TOO LOW! Current: ${cameraState.zoom}, Required: 7+');
          print('   Zooming to level 9 in stream-rich area...');

          // Zoom to Mississippi River at CORRECT zoom level
          await mapboxMap!.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(-90.0715, 38.6270)),
              zoom: 9.0, // ✅ Within the 7-13 range!
            ),
          );

          // Wait for tiles to load
          await Future.delayed(Duration(seconds: 4));
          print('🎯 Zoomed to zoom level 9.0');
        }

        // Query with the CORRECT layer IDs
        final correctLayerIds = [
          'streams2-debug-correct',
          'streams2-order-1-2',
          'streams2-order-3-4',
          'streams2-order-5-plus',
        ];

        // Create a larger query area
        final queryBox = RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 50, y: 50),
            max: ScreenCoordinate(x: 350, y: 350), // Larger area
          ),
        );

        bool foundFeatures = false;

        for (final layerId in correctLayerIds) {
          try {
            final features = await mapboxMap!.queryRenderedFeatures(
              queryBox,
              RenderedQueryOptions(layerIds: [layerId]),
            );

            print('🔍 Layer "$layerId": Found ${features.length} features');

            if (features.isNotEmpty && features.first != null) {
              foundFeatures = true;
              final feature = features.first!;
              final properties = feature.queriedFeature.feature['properties'];

              print('   🎉 SUCCESS! Found streams2 features!');
              if (properties != null && properties is Map) {
                print('   Properties: ${properties.keys.toList()}');
                print('   streamOrde: ${properties['streamOrde']}');
                print('   station_id: ${properties['station_id']}');
                print('   STATIONID: ${properties['STATIONID']}');
              }
              break; // Found working layer, no need to continue
            }
          } catch (e) {
            print('❌ Error querying layer "$layerId": $e');
          }
        }

        if (foundFeatures) {
          print('🎉 STREAMS2 VECTOR TILES ARE WORKING!');
          print('   ✅ Correct source layer: streams2-7jgd8p');
          print('   ✅ Correct zoom level: 7-13');
          print('   ✅ Features found and accessible');
        } else {
          print('⚠️  Still no features - try zooming in more (zoom 10-12)');
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

  // Add this method to your existing VectorTilesService class

  /// Run comprehensive tileset debugging
  Future<void> runTilesetDiagnostics() async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    print('\n🔬 STARTING COMPREHENSIVE TILESET DIAGNOSTICS');

    // Import the debug helper (you'll need to add the import)
    // await TilesetDebugHelper.runFullDebug(mapboxMap!, 'jersondevs.dopm8y3j');

    // For now, let's do the key checks inline:
    await _checkTilesetAccess();
    await _inspectCurrentMap();
    await _testKnownTileset();
  }

  /// Check if your tileset is accessible
  Future<void> _checkTilesetAccess() async {
    print('\n📡 CHECKING TILESET ACCESS');

    const accessToken =
        'pk.eyJ1IjoiamVyc29uZGV2cyIsImEiOiJjbTkxcGQ1emYwM2d1MnFwcWJ2dmgwYmpuIn0.ca52KhzP9gaK5nYDMv0ZxA';
    const tilesetId = 'jersondevs.dopm8y3j';

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.mapbox.com/v1/$tilesetId?access_token=$accessToken',
        ),
      );

      print('📊 Tileset API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Tileset exists and is accessible!');
        print('   Name: ${data['name']}');
        print('   Type: ${data['type']}');
        print('   Visibility: ${data['visibility']}');

        if (data['vector_layers'] != null) {
          print('   Vector layers found:');
          for (final layer in data['vector_layers']) {
            print('     🎯 Layer ID: "${layer['id']}"');
            print('        Description: ${layer['description']}');
            if (layer['fields'] != null) {
              print('        Fields: ${layer['fields'].keys.toList()}');
            }
          }
        } else {
          print('   ⚠️ No vector_layers metadata found');
        }
      } else if (response.statusCode == 404) {
        print('❌ TILESET NOT FOUND');
        print('   Either the tileset ID is wrong or it doesn\'t exist');
        print('   Double-check: $tilesetId');
      } else if (response.statusCode == 401) {
        print('❌ AUTHENTICATION ERROR');
        print('   Check your access token or tileset permissions');
      } else {
        print('❌ API Error: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Network error: $e');
    }
  }

  /// Inspect what's currently in the map
  Future<void> _inspectCurrentMap() async {
    print('\n🔍 INSPECTING CURRENT MAP STATE');

    try {
      // Query a large area to see all features
      final allFeatures = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 0, y: 0),
            max: ScreenCoordinate(x: 400, y: 800),
          ),
        ),
        RenderedQueryOptions(),
      );

      final sources = <String>{};

      for (final feature in allFeatures) {
        if (feature != null) {
          final source = feature.queriedFeature.source;
          sources.add(source);

          // Look specifically for our source
          if (source.contains('streams2') || source.contains('jersondevs')) {
            print('🎯 FOUND OUR SOURCE: $source');
            print('   Layers: ${feature.layers}');
          }
        }
      }

      print('📊 Total features found: ${allFeatures.length}');
      print('📊 Unique sources: ${sources.length}');
      print('📊 All sources: ${sources.toList()}');

      // Check if our source is loaded but not rendering
      if (sources.any((s) => s.contains('streams2'))) {
        print('✅ streams2 source IS loaded and rendering!');
      } else {
        print('❌ streams2 source is NOT in rendered features');
      }
    } catch (e) {
      print('❌ Error inspecting map: $e');
    }
  }

  /// Test with a known working tileset to verify our code works
  Future<void> _testKnownTileset() async {
    print('\n🧪 TESTING WITH KNOWN WORKING TILESET');

    try {
      // Clean up any existing test
      try {
        await mapboxMap!.style.removeStyleLayer('test-working-layer');
        await mapboxMap!.style.removeStyleSource('test-working-source');
      } catch (e) {
        // Ignore
      }

      // Add Mapbox Streets water layer (this should definitely work)
      await mapboxMap!.style.addSource(
        VectorSource(
          id: 'test-working-source',
          url: 'mapbox://mapbox.mapbox-streets-v8',
        ),
      );

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'test-working-layer',
          sourceId: 'test-working-source',
          sourceLayer: 'waterway', // Known source layer in streets
          lineColor: 0xFF00FF00, // Bright green
          lineWidth: 8.0, // Very thick
        ),
      );

      print('✅ Added known working tileset (Mapbox Streets waterways)');

      // Wait for tiles to load
      await Future.delayed(Duration(seconds: 3));

      // Query for features
      final features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 150, y: 150),
            max: ScreenCoordinate(x: 250, y: 250),
          ),
        ),
        RenderedQueryOptions(layerIds: ['test-working-layer']),
      );

      if (features.isNotEmpty) {
        print('🎉 SUCCESS! Known tileset works - ${features.length} features');
        print('   Your code is correct - issue is with your tileset');
      } else {
        print('⚠️ No features from known tileset either');
        print('   This might indicate a broader issue');
      }
    } catch (e) {
      print('❌ Error testing known tileset: $e');
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

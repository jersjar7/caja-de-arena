// lib/vector_tiles_approach/tileset_debug_helper.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TilesetDebugHelper {
  /// Debug tileset by checking if it exists and is accessible
  static Future<void> debugTilesetAccess(String tilesetId) async {
    print('\n🔍 DEBUGGING TILESET ACCESS: $tilesetId');

    // First, let's check if the tileset exists via Mapbox API
    // Note: This requires your Mapbox access token
    const accessToken =
        'pk.eyJ1IjoiamVyc29uZGV2cyIsImEiOiJjbTkxcGQ1emYwM2d1MnFwcWJ2dmgwYmpuIn0.ca52KhzP9gaK5nYDMv0ZxA';

    try {
      // Check tileset metadata
      final metadataUrl =
          'https://api.mapbox.com/v1/$tilesetId?access_token=$accessToken';
      print('📡 Checking tileset metadata: $metadataUrl');

      final response = await http.get(Uri.parse(metadataUrl));
      print('📊 Metadata response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final metadata = jsonDecode(response.body);
        print('✅ Tileset exists!');
        print('   Name: ${metadata['name']}');
        print('   Description: ${metadata['description']}');
        print('   Type: ${metadata['type']}');
        print('   Visibility: ${metadata['visibility']}');

        // Check if it has vector layers info
        if (metadata['vector_layers'] != null) {
          print('   Vector layers:');
          for (final layer in metadata['vector_layers']) {
            print('     - ${layer['id']}: ${layer['description']}');
            if (layer['fields'] != null) {
              print('       Fields: ${layer['fields'].keys.toList()}');
            }
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ Authentication error: Check your access token');
      } else if (response.statusCode == 404) {
        print('❌ Tileset not found! The tileset ID might be wrong.');
        print('   Double-check: $tilesetId');
        print('   Make sure it\'s in format: username.tilesetid');
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Network error checking tileset: $e');
    }
  }

  /// Test different tileset URL formats
  static Future<void> testTilesetFormats(MapboxMap mapboxMap) async {
    print('\n🧪 TESTING DIFFERENT TILESET URL FORMATS:');

    final testFormats = [
      'mapbox://jersondevs.dopm8y3j', // Current format
      'mapbox://jersondevs.dopm8y3j/streams2', // With source layer
      'https://api.mapbox.com/v4/jersondevs.dopm8y3j.json', // Direct JSON
    ];

    for (int i = 0; i < testFormats.length; i++) {
      final url = testFormats[i];
      print('🔧 Testing format $i: $url');

      try {
        // Remove previous test source
        try {
          await mapboxMap.style.removeStyleSource('test-source-$i');
        } catch (e) {
          // Ignore if doesn't exist
        }

        // Add test source
        await mapboxMap.style.addSource(
          VectorSource(id: 'test-source-$i', url: url),
        );

        // Add a simple layer
        await mapboxMap.style.addLayer(
          LineLayer(
            id: 'test-layer-$i',
            sourceId: 'test-source-$i',
            lineColor: 0xFFFF0000, // Red
            lineWidth: 3.0,
          ),
        );

        print('✅ Format $i added successfully');

        // Wait a moment then test query
        await Future.delayed(Duration(seconds: 2));

        // Query for features
        final features = await mapboxMap.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenBox(
            ScreenBox(
              min: ScreenCoordinate(x: 100, y: 100),
              max: ScreenCoordinate(x: 200, y: 200),
            ),
          ),
          RenderedQueryOptions(layerIds: ['test-layer-$i']),
        );

        if (features.isNotEmpty) {
          print('🎉 SUCCESS! Format $i found ${features.length} features');
          print('   This format works: $url');
        } else {
          print('⚠️ Format $i loaded but no features found');
        }
      } catch (e) {
        print('❌ Format $i failed: $e');
      }
    }
  }

  /// Inspect what sources are actually loaded in the map
  static Future<void> inspectMapSources(MapboxMap mapboxMap) async {
    print('\n🔍 INSPECTING CURRENT MAP SOURCES:');

    try {
      // Try to query all rendered features to see what sources exist
      final allFeatures = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 0, y: 0),
            max: ScreenCoordinate(x: 400, y: 800),
          ),
        ),
        RenderedQueryOptions(),
      );

      final sources = <String>{};
      final layers = <String>{};

      for (final feature in allFeatures) {
        if (feature != null) {
          sources.add(feature.queriedFeature.source);
          layers.addAll(feature.layers.where((l) => l != null).cast<String>());
        }
      }

      print('📊 Found ${allFeatures.length} total features');
      print('📊 Active sources: ${sources.toList()}');
      print('📊 Active layers: ${layers.toList()}');

      // Look for anything that might be our streams2
      for (final source in sources) {
        if (source.toLowerCase().contains('streams') ||
            source.toLowerCase().contains('jerson') ||
            source.toLowerCase().contains('dopm8y3j')) {
          print('🎯 FOUND POTENTIAL STREAMS2 SOURCE: $source');
        }
      }

      for (final layer in layers) {
        if (layer.toLowerCase().contains('streams') ||
            layer.toLowerCase().contains('debug')) {
          print('🎯 FOUND POTENTIAL STREAMS2 LAYER: $layer');
        }
      }
    } catch (e) {
      print('❌ Error inspecting map sources: $e');
    }
  }

  /// Test a completely different known working tileset
  static Future<void> testKnownWorkingTileset(MapboxMap mapboxMap) async {
    print('\n🧪 TESTING KNOWN WORKING TILESET:');

    try {
      // Use Mapbox's example tileset
      const workingTilesetId = 'mapbox.mapbox-streets-v8';

      await mapboxMap.style.addSource(
        VectorSource(
          id: 'working-test-source',
          url: 'mapbox://$workingTilesetId',
        ),
      );

      // Add a simple layer (roads from streets tileset)
      await mapboxMap.style.addLayer(
        LineLayer(
          id: 'working-test-layer',
          sourceId: 'working-test-source',
          sourceLayer: 'road', // Known source layer in streets tileset
          lineColor: 0xFF00FF00, // Green
          lineWidth: 5.0,
        ),
      );

      print('✅ Added known working tileset');

      // Wait then query
      await Future.delayed(Duration(seconds: 2));

      final features = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 150, y: 150),
            max: ScreenCoordinate(x: 250, y: 250),
          ),
        ),
        RenderedQueryOptions(layerIds: ['working-test-layer']),
      );

      if (features.isNotEmpty) {
        print(
          '🎉 SUCCESS! Known tileset works - found ${features.length} features',
        );
        print('   This confirms your code is correct');
        print('   The issue is specifically with jersondevs.dopm8y3j');
      } else {
        print('⚠️ Even known tileset shows no features');
      }
    } catch (e) {
      print('❌ Error testing known tileset: $e');
    }
  }

  /// Full debug sequence
  static Future<void> runFullDebug(
    MapboxMap mapboxMap,
    String tilesetId,
  ) async {
    print('\n🚀 STARTING FULL TILESET DEBUG SEQUENCE');
    print('Target tileset: $tilesetId');

    // Step 1: Check if tileset exists
    await debugTilesetAccess(tilesetId);

    // Step 2: Inspect current map
    await inspectMapSources(mapboxMap);

    // Step 3: Test known working tileset
    await testKnownWorkingTileset(mapboxMap);

    // Step 4: Test different URL formats
    await testTilesetFormats(mapboxMap);

    print('\n✅ DEBUG SEQUENCE COMPLETE');
    print('Check the output above to identify the issue');
  }
}

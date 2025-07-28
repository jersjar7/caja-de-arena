// lib/wfs_debug_helper.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'spatial_utils.dart';

class WFSDebugHelper {
  static const String wfsBaseUrl =
      'https://geoserver.hydroshare.org/geoserver/HS-d4238b41de7f4e59b54ef7ae875cbaa0/wfs';

  /// Debug bbox calculation methods
  static Future<void> debugBboxCalculation(MapboxMap mapboxMap) async {
    try {
      print('\n🔬 DEBUGGING BBOX CALCULATION:');

      final cameraState = await mapboxMap.getCameraState();
      print('Camera state:');
      print(
        '  Center: ${cameraState.center.coordinates.lng}, ${cameraState.center.coordinates.lat}',
      );
      print('  Zoom: ${cameraState.zoom}');
      print('  Bearing: ${cameraState.bearing}');
      print('  Pitch: ${cameraState.pitch}');

      // Test different bbox calculation methods
      print('\nMethod 1: SpatialUtils.getBoundingBoxFromCamera');
      final bounds1 = await SpatialUtils.getBoundingBoxFromCamera(mapboxMap);
      print(
        '  SW: ${bounds1.southwest.coordinates.lng}, ${bounds1.southwest.coordinates.lat}',
      );
      print(
        '  NE: ${bounds1.northeast.coordinates.lng}, ${bounds1.northeast.coordinates.lat}',
      );

      print('\nMethod 2: Manual calculation');
      final center = cameraState.center.coordinates;
      final zoom = cameraState.zoom;
      final degreesPerPixel = 360.0 / (256 * math.pow(2, zoom));
      final viewportDegrees = degreesPerPixel * 400; // Assume ~400px viewport

      final manualBounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            center.lng - viewportDegrees,
            center.lat - viewportDegrees,
          ),
        ),
        northeast: Point(
          coordinates: Position(
            center.lng + viewportDegrees,
            center.lat + viewportDegrees,
          ),
        ),
        infiniteBounds: false,
      );

      print(
        '  SW: ${manualBounds.southwest.coordinates.lng}, ${manualBounds.southwest.coordinates.lat}',
      );
      print(
        '  NE: ${manualBounds.northeast.coordinates.lng}, ${manualBounds.northeast.coordinates.lat}',
      );

      print('\nMethod 3: Continental US bounds (for testing)');
      final usBounds = CoordinateBounds(
        southwest: Point(coordinates: Position(-125.0, 24.0)),
        northeast: Point(coordinates: Position(-66.0, 49.0)),
        infiniteBounds: false,
      );
      print(
        '  SW: ${usBounds.southwest.coordinates.lng}, ${usBounds.southwest.coordinates.lat}',
      );
      print(
        '  NE: ${usBounds.northeast.coordinates.lng}, ${usBounds.northeast.coordinates.lat}',
      );

      // Test queries with each bbox
      await _testBboxWithQuickQuery(
        'usgs_gauges',
        bounds1,
        'SpatialUtils bounds',
      );
      await _testBboxWithQuickQuery(
        'usgs_gauges',
        manualBounds,
        'Manual bounds',
      );
      await _testBboxWithQuickQuery('usgs_gauges', usBounds, 'US bounds');
    } catch (e) {
      print('❌ BBox debug failed: $e');
    }
  }

  /// Test a bbox with a quick WFS query
  static Future<void> _testBboxWithQuickQuery(
    String layerId,
    CoordinateBounds bounds,
    String method,
  ) async {
    try {
      final bboxString =
          '${bounds.southwest.coordinates.lng},${bounds.southwest.coordinates.lat},${bounds.northeast.coordinates.lng},${bounds.northeast.coordinates.lat}';

      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'wfs',
          'version': '2.0.0',
          'request': 'GetFeature',
          'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
          'outputFormat': 'application/json',
          'maxFeatures': '10',
          'bbox': bboxString,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
        final data = jsonDecode(response.body);
        final featureCount = data['features']?.length ?? 0;
        print('  $method: $featureCount features found');
      } else {
        print('  $method: Failed (${response.statusCode})');
      }
    } catch (e) {
      print('  $method: Error - $e');
    }
  }

  /// Test simple WFS query without bbox
  static Future<void> testSimpleWFSQuery(String layerId) async {
    try {
      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'WFS',
          'version': '2.0.0',
          'request': 'GetFeature',
          'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
          'outputFormat': 'application/json',
          'maxFeatures': '10',
        },
      );

      print('🧪 TESTING simple query (no bbox) for $layerId:');
      _logWFSRequest(layerId, uri);

      final response = await http.get(uri);
      print('   Response status: ${response.statusCode}');
      _logWFSResponse(layerId, response.body);
    } catch (e) {
      print('❌ Simple query test failed: $e');
    }
  }

  /// Test WFS GetCapabilities
  static Future<void> testGetCapabilities() async {
    try {
      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {'service': 'WFS', 'request': 'GetCapabilities'},
      );

      print('🧪 TESTING GetCapabilities:');
      _logWFSRequest('capabilities', uri);

      final response = await http.get(uri);
      print('   Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('   ✅ GetCapabilities successful');
        print('   Response length: ${response.body.length}');

        // Look for layer names in capabilities
        if (response.body.contains('usgs_gauges')) {
          print('   ✅ Found usgs_gauges in capabilities');
        } else {
          print('   ❌ usgs_gauges NOT found in capabilities');
        }

        // Check if we can find the available output formats
        if (response.body.contains('application/json')) {
          print('   ✅ JSON output format supported');
        } else {
          print('   ❌ JSON output format not found');
        }
      } else {
        print('   ❌ GetCapabilities failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ GetCapabilities test failed: $e');
    }
  }

  /// Run comprehensive WFS debug
  static Future<void> runComprehensiveDebug() async {
    const testLayer = 'usgs_gauges';

    print('\n🔬 STARTING COMPREHENSIVE WFS DEBUG for $testLayer\n');

    print('=== TEST 1: Simple Query (No BBox) ===');
    await testSimpleWFSQuery(testLayer);

    print('\n=== TEST 2: GetCapabilities ===');
    await testGetCapabilities();

    print('\n🔬 DEBUG COMPLETE\n');
  }

  /// Log WFS request details
  static void _logWFSRequest(String layerId, Uri uri) {
    print('🔍 DEBUGGING WFS REQUEST for $layerId:');
    print('   Full URL: $uri');
    print('   Query Parameters:');
    uri.queryParameters.forEach((key, value) {
      print('     $key: $value');
    });
  }

  /// Log WFS response details
  static void _logWFSResponse(String layerId, String responseBody) {
    print('🔍 DEBUGGING WFS RESPONSE for $layerId:');
    print('   Response length: ${responseBody.length} characters');
    print('   First 500 characters:');
    print(
      '   ${responseBody.substring(0, math.min(500, responseBody.length))}',
    );

    // Check if it's valid JSON
    try {
      final data = jsonDecode(responseBody);
      if (data is Map) {
        print('   Response is valid JSON object');
        print('   Keys: ${data.keys.toList()}');
        if (data.containsKey('features')) {
          print(
            '   Features array length: ${data['features']?.length ?? 'null'}',
          );
        }
        if (data.containsKey('totalFeatures')) {
          print('   Total features: ${data['totalFeatures']}');
        }
        if (data.containsKey('numberMatched')) {
          print('   Number matched: ${data['numberMatched']}');
        }
        if (data.containsKey('numberReturned')) {
          print('   Number returned: ${data['numberReturned']}');
        }
      }
    } catch (e) {
      print('   Response is NOT valid JSON: $e');
      // Check if it's XML (capabilities response)
      if (responseBody.contains('<?xml')) {
        print('   Response appears to be XML');
      }
    }
  }

  /// Check if layers exist on map
  static Future<void> debugMapLayers(MapboxMap mapboxMap) async {
    print('\n🔍 DEBUGGING MAP LAYERS:');

    try {
      // Check current camera position
      final cameraState = await mapboxMap.getCameraState();
      print(
        '📍 Camera: ${cameraState.center.coordinates.lng}, ${cameraState.center.coordinates.lat}',
      );
      print('🔍 Zoom: ${cameraState.zoom}');

      // Try to get style layers (this might not work in all Mapbox versions)
      print('\n📋 Checking for our layers:');

      final layersToCheck = [
        'usgs_gauges_clusters',
        'usgs_gauges_count',
        'usgs_gauges_unclustered',
      ];

      for (final layerName in layersToCheck) {
        try {
          // Try to modify the layer to see if it exists
          await mapboxMap.style.setStyleLayerProperty(
            layerName,
            'visibility',
            'visible',
          );
          print('✅ Layer exists: $layerName');
        } catch (e) {
          print('❌ Layer missing: $layerName - $e');
        }
      }

      // Force map to redraw
      try {
        await mapboxMap.style.setStyleLayerProperty(
          'usgs_gauges_clusters',
          'circle-radius',
          25.0,
        );
        print('🔄 Attempted to force redraw');
      } catch (e) {
        print('⚠️ Could not force redraw: $e');
      }
    } catch (e) {
      print('❌ Debug failed: $e');
    }
  }
}

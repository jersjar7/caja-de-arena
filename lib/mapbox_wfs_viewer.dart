import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class MapboxWFSViewer extends StatefulWidget {
  const MapboxWFSViewer({super.key});

  @override
  State<MapboxWFSViewer> createState() => _MapboxWFSViewerState();
}

class _MapboxWFSViewerState extends State<MapboxWFSViewer> {
  MapboxMap? mapboxMap;
  bool _isLoading = false;
  String _statusMessage = 'Tap a layer to load data';

  // Layer visibility states
  final Map<String, bool> _layerVisibility = {
    'streams3': false,
    'streams2': false,
    'midpoints': false,
    'usgs_gauges': false,
    'MidpointStreams': false,
  };

  // WFS base URL
  static const String wfsBaseUrl =
      'https://geoserver.hydroshare.org/geoserver/HS-d4238b41de7f4e59b54ef7ae875cbaa0/wfs';

  // Layer metadata
  final Map<String, Map<String, dynamic>> _layerInfo = {
    'streams3': {
      'name': 'Stream Network v3',
      'description': 'Main stream/river network',
      'color': Colors.blue.value,
      'type': 'line',
    },
    'streams2': {
      'name': 'Stream Network v2',
      'description': 'Alternative stream network',
      'color': Colors.lightBlue.value,
      'type': 'line',
    },
    'midpoints': {
      'name': 'Stream Midpoints',
      'description': 'Midpoint locations along streams',
      'color': Colors.orange.value,
      'type': 'point',
    },
    'usgs_gauges': {
      'name': 'USGS Gauging Stations',
      'description': 'Water monitoring stations',
      'color': Colors.red.value,
      'type': 'point',
    },
    'MidpointStreams': {
      'name': 'Midpoint Stream Features',
      'description': 'Stream features with midpoint data',
      'color': Colors.purple.value,
      'type': 'line',
    },
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('WFS Data Viewer'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: CupertinoColors.systemGrey6,
            child: Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          // Map
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 20),
                    ),
                  ),
              ],
            ),
          ),

          // Layer controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Layers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // Debug section
                  _buildDebugSection(),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _layerInfo.length,
                      itemBuilder: (context, index) {
                        final layerId = _layerInfo.keys.elementAt(index);
                        final layerData = _layerInfo[layerId]!;
                        final isVisible = _layerVisibility[layerId] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(layerData['color']),
                                shape: layerData['type'] == 'point'
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                              ),
                            ),
                            title: Text(
                              layerData['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              layerData['description'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: CupertinoSwitch(
                              value: isVisible,
                              onChanged: (value) =>
                                  _toggleLayer(layerId, value),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // DEBUG METHODS - ADD THESE NEW METHODS
  // ===========================================

  Widget _buildDebugSection() {
    return Column(
      children: [
        const Text(
          'Debug WFS Issues',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: () async {
                  await _runComprehensiveDebug();
                },
                child: const Text('Debug WFS', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: () async {
                  await _testSimpleWFSQuery('usgs_gauges');
                },
                child: const Text(
                  'Test Simple',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _runComprehensiveDebug() async {
    setState(() {
      _statusMessage = 'Running comprehensive WFS debug...';
    });

    const testLayer = 'usgs_gauges'; // Smallest layer for testing

    print('\n🔬 STARTING COMPREHENSIVE WFS DEBUG for $testLayer\n');

    // Test 1: Simple query without bbox
    print('=== TEST 1: Simple Query (No BBox) ===');
    await _testSimpleWFSQuery(testLayer);

    print('\n=== TEST 2: Different BBox Formats ===');
    await _testBboxFormats(testLayer);

    print('\n=== TEST 3: GetCapabilities ===');
    await _testGetCapabilities();

    print('\n🔬 DEBUG COMPLETE\n');

    setState(() {
      _statusMessage = 'Debug complete - check console output';
    });
  }

  // Test simple query without bounding box
  Future<void> _testSimpleWFSQuery(String layerId) async {
    try {
      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'WFS',
          'version': '2.0.0',
          'request': 'GetFeature',
          'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
          'outputFormat': 'application/json',
          'maxFeatures': '10', // Just get 10 features
          // NO bbox parameter
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

  // Test different bbox formats
  Future<void> _testBboxFormats(String layerId) async {
    // For testing, use fixed Continental US bounds first
    final mapBounds = MapBounds(
      west: -125.0, // US West Coast
      south: 24.0, // US South (Florida Keys)
      east: -66.0, // US East Coast
      north: 49.0, // US North (Canadian border)
    );

    print(
      '🗺️  Using fixed US bounds for testing: W:${mapBounds.west}, S:${mapBounds.south}, E:${mapBounds.east}, N:${mapBounds.north}',
    );

    // Test different bbox formats
    final bboxTests = [
      {
        'name': 'WGS84 format',
        'param': 'bbox',
        'value':
            '${mapBounds.west},${mapBounds.south},${mapBounds.east},${mapBounds.north}',
      },
      {
        'name': 'WGS84 with CRS',
        'param': 'bbox',
        'value':
            '${mapBounds.west},${mapBounds.south},${mapBounds.east},${mapBounds.north},EPSG:4326',
      },
      {
        'name': 'BBOX uppercase',
        'param': 'BBOX',
        'value':
            '${mapBounds.west},${mapBounds.south},${mapBounds.east},${mapBounds.north}',
      },
      {
        'name': 'Wide US bounds',
        'param': 'bbox',
        'value': '-125,24,-66,49', // Continental US
      },
    ];

    for (int i = 0; i < bboxTests.length; i++) {
      final test = bboxTests[i];
      try {
        final uri = Uri.parse(wfsBaseUrl).replace(
          queryParameters: {
            'service': 'WFS',
            'version': '2.0.0',
            'request': 'GetFeature',
            'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
            'outputFormat': 'application/json',
            'maxFeatures': '10',
            test['param']!: test['value']!,
          },
        );

        print('\n🧪 TESTING: ${test['name']}');
        _logWFSRequest(layerId, uri);

        final response = await http.get(uri);
        print('   Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            final featureCount = data['features']?.length ?? 0;
            print('   ✅ SUCCESS: $featureCount features found!');
            if (featureCount > 0) {
              print('   🎉 WORKING BBOX FORMAT FOUND: ${test['name']}!');
              print(
                '   📍 First feature coordinates: ${data['features'][0]['geometry']}',
              );
              return; // Stop testing, we found a working format
            }
          } catch (e) {
            print('   ❌ JSON parse error: $e');
          }
        } else {
          print('   ❌ HTTP error: ${response.statusCode}');
          print(
            '   Response: ${response.body.substring(0, math.min(200, response.body.length))}',
          );
        }
      } catch (e) {
        print('   ❌ Request failed: $e');
      }
    }
  }

  Future<void> _testGetCapabilities() async {
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

  void _logWFSRequest(String layerId, Uri uri) {
    print('🔍 DEBUGGING WFS REQUEST for $layerId:');
    print('   Full URL: $uri');
    print('   Query Parameters:');
    uri.queryParameters.forEach((key, value) {
      print('     $key: $value');
    });
  }

  void _logWFSResponse(String layerId, String responseBody) {
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

  Future<MapBounds?> _getCurrentMapBounds() async {
    if (mapboxMap == null) return null;

    try {
      // Method 1: Try using camera state to calculate visible bounds
      final cameraState = await mapboxMap!.getCameraState();
      final center = cameraState.center;
      final zoom = cameraState.zoom;

      // Calculate approximate bounds based on zoom level and screen size
      // This is a rough approximation - you can adjust the multiplier
      final latitudeDelta =
          360.0 / (2 << zoom.toInt()) * 2; // Rough approximation
      final longitudeDelta = latitudeDelta;

      return MapBounds(
        west: center.coordinates.lng - longitudeDelta / 2,
        south: center.coordinates.lat - latitudeDelta / 2,
        east: center.coordinates.lng + longitudeDelta / 2,
        north: center.coordinates.lat + latitudeDelta / 2,
      );
    } catch (e) {
      print('❌ Failed to get map bounds from camera state: $e');

      // Method 2: Fallback to fixed Continental US bounds for testing
      print('🔄 Using fallback Continental US bounds for testing');
      return MapBounds(
        west: -125.0, // US West Coast
        south: 24.0, // US South (Florida Keys)
        east: -66.0, // US East Coast
        north: 49.0, // US North (Canadian border)
      );
    }
  }

  // ===========================================
  // EXISTING METHODS (keeping your original code)
  // ===========================================

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (mapboxMap == null) return;

    // Set initial camera to continental US
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-98.5795, 39.8283)), // Center of US
        zoom: 4.0,
      ),
    );

    // Set map style
    await mapboxMap!.loadStyleURI(MapboxStyles.MAPBOX_STREETS);

    setState(() {
      _statusMessage = 'Map loaded - Try debugging WFS first';
    });
  }

  Future<void> _testWFSConnection() async {
    try {
      setState(() {
        _statusMessage = 'Testing WFS connection...';
      });

      // Use lowercase 'wfs' - HydroShare has case sensitivity bug
      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'wfs', // lowercase required for HydroShare
          'request': 'GetCapabilities',
        },
      );

      print('Testing capabilities: $uri');

      final response = await http.get(uri);
      print('Capabilities response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.contains('WFS_Capabilities')) {
          setState(() {
            _statusMessage = 'WFS service is working! Try loading layers.';
          });
          print('SUCCESS: WFS capabilities loaded properly');
        } else if (response.body.contains('ExceptionReport')) {
          final errorMessage = _parseWFSException(response.body);
          setState(() {
            _statusMessage = 'WFS Error: $errorMessage';
          });
        } else {
          setState(() {
            _statusMessage = 'Unexpected WFS response format';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'WFS service returned HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'WFS test error: $e';
      });
    }
  }

  Future<void> _testAlternativeWFS() async {
    try {
      setState(() {
        _statusMessage = 'Testing demo WFS service...';
      });

      // Test with a known working WFS service (USGS Water Data)
      const demoWfsUrl =
          'https://waterservices.usgs.gov/nwis/site?format=mapper&seriesCatalogOutput=true&outputDataTypeCd=dv&parameterCd=00060&stateCd=co';

      print('Testing demo service: $demoWfsUrl');

      final response = await http.get(Uri.parse(demoWfsUrl));
      print('Demo response: ${response.statusCode}');
      print('Demo response preview: ${response.body.substring(0, 200)}...');

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage =
              'Demo service works! HydroShare WFS may have issues.';
        });
      } else {
        setState(() {
          _statusMessage =
              'Demo service also failed - check internet connection';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Demo test error: $e';
      });
    }
  }

  String _parseWFSException(String xmlResponse) {
    try {
      // Extract exception text from XML (simple string parsing)
      final exceptionStart = xmlResponse.indexOf('<ows:ExceptionText>');
      final exceptionEnd = xmlResponse.indexOf('</ows:ExceptionText>');

      if (exceptionStart != -1 && exceptionEnd != -1) {
        return xmlResponse.substring(exceptionStart + 19, exceptionEnd);
      }

      // Try alternative format
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

  Future<void> _toggleLayer(String layerId, bool visible) async {
    if (mapboxMap == null) return;

    setState(() {
      _layerVisibility[layerId] = visible;
    });

    if (visible) {
      await _loadLayer(layerId);
    } else {
      await _removeLayer(layerId);
    }
  }

  Future<void> _loadLayer(String layerId) async {
    if (mapboxMap == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading ${_layerInfo[layerId]!['name']}...';
    });

    try {
      // Try different output formats for better compatibility
      final outputFormats = [
        'application/json',
        'json',
        // Removed 'application/geo+json' as it returns 400 error
      ];

      for (final format in outputFormats) {
        // Use lowercase 'wfs' and 'typeNames' (WFS 2.0) - HydroShare quirks
        final uri = Uri.parse(wfsBaseUrl).replace(
          queryParameters: {
            'service': 'wfs', // lowercase required for HydroShare
            'version': '2.0.0',
            'request': 'GetFeature',
            'typeNames':
                'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId', // typeNames not typeName for WFS 2.0
            'outputFormat': format,
            'maxFeatures': '1000',
          },
        );

        print('Trying: $uri');

        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json, application/geo+json, */*',
            'User-Agent': 'Flutter-WFS-Client/1.0',
          },
        );

        print('Response status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body preview: ${response.body.substring(0, 200)}...');

        if (response.statusCode == 200) {
          // Check if response is JSON
          if (response.body.trim().startsWith('{')) {
            try {
              final data = jsonDecode(response.body);
              final featureCount = data['features']?.length ?? 0;

              print('Successfully parsed JSON with $featureCount features');

              await _addDataToMap(layerId, response.body, featureCount);
              return; // Success! Exit the function
            } catch (e) {
              print('JSON parsing failed: $e');
              continue; // Try next format
            }
          } else if (response.body.contains('ExceptionReport')) {
            // Parse the WFS exception for this specific request
            final errorMessage = _parseWFSException(response.body);
            print('WFS Exception for $layerId with $format: $errorMessage');
            print('Full exception response: ${response.body}');
            continue; // Try next format
          } else {
            print('Response is not JSON or exception, trying next format...');
            continue;
          }
        } else {
          print('HTTP error ${response.statusCode}: ${response.body}');
          continue;
        }
      }

      // If we get here, all formats failed
      throw Exception(
        'All output formats failed. Service may be down or require authentication.',
      );
    } catch (e) {
      print('Error loading layer $layerId: $e');
      setState(() {
        _layerVisibility[layerId] = false;
        _statusMessage =
            'Error loading ${_layerInfo[layerId]!['name']}: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addDataToMap(
    String layerId,
    String geojsonData,
    int featureCount,
  ) async {
    try {
      // Remove existing source and layers if they exist
      await _removeLayer(layerId);

      print('🗺️  Adding $featureCount features to map for layer: $layerId');

      // Add source
      if (_layerInfo[layerId]!['type'] == 'point') {
        // For point data, enable clustering
        await mapboxMap!.style.addSource(
          GeoJsonSource(
            id: "${layerId}_source",
            data: geojsonData,
            cluster: true,
            clusterMaxZoom: 14,
            clusterRadius: 50,
          ),
        );
      } else {
        // For line data, no clustering
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: "${layerId}_source", data: geojsonData),
        );
      }

      // Add layer with appropriate styling
      await _addStyledLayer(layerId);

      setState(() {
        _statusMessage =
            'Loaded ${_layerInfo[layerId]!['name']} ($featureCount features)';
      });
    } catch (e) {
      print('Error adding data to map: $e');
      throw Exception('Failed to add data to map: $e');
    }
  }

  Future<void> _addStyledLayer(String layerId) async {
    final layerData = _layerInfo[layerId]!;
    final colorInt = layerData['color'] as int;

    // Convert integer color to hex string format that Mapbox expects
    final colorHex =
        '#${colorInt.toRadixString(16).padLeft(8, '0').substring(2)}';

    print(
      '🎨 Adding styled layer for $layerId with color: $colorHex (from int: $colorInt)',
    );

    if (layerData['type'] == 'point') {
      // Add clustering layers for points

      // 1. Cluster circles
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_clusters",
          sourceId: "${layerId}_source",
          circleRadius: 18.0,
          circleColor: colorInt, // Use int color
          filter: ["has", "point_count"],
        ),
      );

      // 2. Cluster count text
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: "${layerId}_count",
          sourceId: "${layerId}_source",
          textFieldExpression: ["get", "point_count_abbreviated"],
          textSize: 12.0,
          textColor: 0xFFFFFFFF, // Use int color
          filter: ["has", "point_count"],
        ),
      );

      // 3. Unclustered points
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_unclustered",
          sourceId: "${layerId}_source",
          circleRadius: 6.0,
          circleColor: colorInt, // Use int color
          circleStrokeColor: 0xFFFFFFFF, // Use int color
          circleStrokeWidth: 1.0,
          filter: [
            "!",
            ["has", "point_count"],
          ],
        ),
      );
    } else {
      // Add line layer for streams
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: "${layerId}_lines",
          sourceId: "${layerId}_source",
          lineColor: colorInt, // Use int color
          lineWidthExpression: [
            "interpolate",
            ["linear"],
            ["zoom"],
            5,
            1.0,
            10,
            2.0,
            15,
            3.0,
          ],
          lineOpacity: 0.8,
        ),
      );
    }
  }

  Future<void> _removeLayer(String layerId) async {
    if (mapboxMap == null) return;

    try {
      // Remove all possible layer variations
      final layersToRemove = [
        "${layerId}_clusters",
        "${layerId}_count",
        "${layerId}_unclustered",
        "${layerId}_lines",
      ];

      for (final layerName in layersToRemove) {
        try {
          await mapboxMap!.style.removeStyleLayer(layerName);
          print('🗑️  Removed layer: $layerName');
        } catch (e) {
          // Layer might not exist, continue silently
          print('ℹ️  Layer $layerName does not exist (this is normal)');
        }
      }

      // Remove source
      try {
        await mapboxMap!.style.removeStyleSource("${layerId}_source");
        print('🗑️  Removed source: ${layerId}_source');
      } catch (e) {
        // Source might not exist, continue silently
        print('ℹ️  Source ${layerId}_source does not exist (this is normal)');
      }

      // Only update status if this was called from toggle (not from cleanup)
      if (_layerVisibility[layerId] == false) {
        setState(() {
          _statusMessage = 'Removed ${_layerInfo[layerId]!['name']}';
        });
      }
    } catch (e) {
      print('Error removing layer $layerId: $e');
    }
  }
}

// Helper class for map bounds
class MapBounds {
  final double west, south, east, north;

  MapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  @override
  String toString() {
    return 'MapBounds(W:$west, S:$south, E:$east, N:$north)';
  }
}

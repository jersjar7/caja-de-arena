import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

                  // Test connection button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: _testWFSConnection,
                      child: const Text(
                        'Test WFS Connection',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Try alternative WFS button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: _testAlternativeWFS,
                      child: const Text(
                        'Try Demo WFS Service',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
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
      _statusMessage = 'Map loaded - Test WFS connection first';
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
        'application/geo+json',
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
    final color = layerData['color'] as int;

    if (layerData['type'] == 'point') {
      // Add clustering layers for points

      // 1. Cluster circles
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_clusters",
          sourceId: "${layerId}_source",
          circleRadius: 18.0,
          circleColorExpression: [
            "step",
            ["get", "point_count"],
            color,
            100,
            Colors.yellow.value,
            750,
            Colors.pink.value,
          ],
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
          textColor: Colors.white.value,
          filter: ["has", "point_count"],
        ),
      );

      // 3. Unclustered points
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_unclustered",
          sourceId: "${layerId}_source",
          circleRadius: 6.0,
          circleColor: color,
          circleStrokeColor: Colors.white.value,
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
          lineColor: color,
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
        } catch (e) {
          // Layer might not exist, continue
        }
      }

      // Remove source
      await mapboxMap!.style.removeStyleSource("${layerId}_source");

      setState(() {
        _statusMessage = 'Removed ${_layerInfo[layerId]!['name']}';
      });
    } catch (e) {
      print('Error removing layer $layerId: $e');
    }
  }
}

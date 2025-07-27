// lib/mapbox_wfs_viewer.dart (UPDATED WITH SMART LOADING)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'performance_monitor.dart';
import 'spatial_utils.dart';
import 'wfs_cache.dart';
import 'bounded_wfs_loader.dart';

class MapboxWFSViewer extends StatefulWidget {
  const MapboxWFSViewer({super.key});

  @override
  State<MapboxWFSViewer> createState() => _MapboxWFSViewerState();
}

class _MapboxWFSViewerState extends State<MapboxWFSViewer> {
  MapboxMap? mapboxMap;
  bool _isLoading = false;
  String _statusMessage = 'Tap a layer to load data';

  // Smart loading components
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  late final BoundedWFSLoader _wfsLoader;
  final ViewportChangeDetector _viewportDetector = ViewportChangeDetector();

  // Current viewport state
  double? _currentZoom;
  bool _cacheInitialized = false;

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

  // Layer metadata with smart loading info
  final Map<String, Map<String, dynamic>> _layerInfo = {
    'streams3': {
      'name': 'Stream Network v3',
      'description': 'All streams (Viewport-filtered)',
      'color': '#2196F3',
      'type': 'line',
      'estimatedFeatures': 2700000,
      'recommendedMaxZoom': 12, // Don't load at country level
    },
    'streams2': {
      'name': 'Stream Network v2',
      'description': 'Stream Order 4+ (Fast loading)',
      'color': '#03A9F4',
      'type': 'line',
      'estimatedFeatures': 3600,
      'recommendedMaxZoom': 6, // Can load at any zoom
    },
    'midpoints': {
      'name': 'Stream Midpoints',
      'description': 'Point locations (Viewport-filtered)',
      'color': '#FF9800',
      'type': 'point',
      'estimatedFeatures': 2700000,
      'recommendedMaxZoom': 10, // Points work better at higher zoom
    },
    'usgs_gauges': {
      'name': 'USGS Gauging Stations',
      'description': 'Water monitoring (28K points)',
      'color': '#F44336',
      'type': 'point',
      'estimatedFeatures': 28000,
      'recommendedMaxZoom': 6, // Can load at any zoom
    },
    'MidpointStreams': {
      'name': 'Midpoint Stream Features',
      'description': 'Stream features (Viewport-filtered)',
      'color': '#9C27B0',
      'type': 'point',
      'estimatedFeatures': 1000000,
      'recommendedMaxZoom': 10,
    },
  };

  @override
  void initState() {
    super.initState();
    _wfsLoader = BoundedWFSLoader(
      wfsBaseUrl: wfsBaseUrl,
      performanceMonitor: _performanceMonitor,
    );
    _initializeCache();
  }

  @override
  void dispose() {
    _wfsLoader.dispose();
    super.dispose();
  }

  Future<void> _initializeCache() async {
    try {
      await WFSCache.initialize();
      setState(() {
        _cacheInitialized = true;
        _statusMessage = 'Smart loading enabled - Test connection to begin';
      });
      print('✅ Cache initialized successfully');
    } catch (e) {
      print('❌ Cache initialization failed: $e');
      setState(() {
        _statusMessage = 'Cache failed - using direct loading';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Smart WFS Viewer'),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showCacheInfo,
              child: const Icon(CupertinoIcons.memories),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _performanceMonitor.printPerformanceSummary();
                _wfsLoader.printStats();
              },
              child: const Icon(CupertinoIcons.chart_bar),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          // Enhanced status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.systemGrey4,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (_performanceMonitor.getLoadingLayers().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Loading: ${_performanceMonitor.getLoadingLayers().join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemOrange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_currentZoom != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Zoom: ${_currentZoom!.toStringAsFixed(1)} (${SpatialUtils.getScaleDescription(_currentZoom!)})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Map with camera change detection
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                  onCameraChangeListener: _onCameraChanged,
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 20),
                    ),
                  ),
                // Viewport refresh button
                if (!_isLoading && _cacheInitialized)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      color: CupertinoColors.systemBlue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _refreshVisibleLayers,
                      child: const Icon(
                        CupertinoIcons.refresh,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Enhanced layer controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Smart Layers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          if (_cacheInitialized)
                            const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: CupertinoColors.systemGreen,
                              size: 16,
                            ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _showPerformanceInfo,
                            child: const Icon(CupertinoIcons.info),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          onPressed: _testWFSConnection,
                          child: const Text(
                            'Test Connection',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          onPressed: _clearCache,
                          child: const Text(
                            'Clear Cache',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Smart loading info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _cacheInitialized
                          ? '🚀 Smart loading: Only visible area + caching enabled'
                          : '⚠️ Loading full datasets - cache unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        color: _cacheInitialized
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemOrange,
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
                        final isLoading = _performanceMonitor.isLayerLoading(
                          layerId,
                        );
                        final recommendedMaxZoom =
                            layerData['recommendedMaxZoom'] as int;
                        final isOptimalZoom =
                            _currentZoom == null ||
                            _currentZoom! >= recommendedMaxZoom;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: _parseColor(layerData['color']),
                                    shape: layerData['type'] == 'point'
                                        ? BoxShape.circle
                                        : BoxShape.rectangle,
                                  ),
                                ),
                                if (isLoading)
                                  const Positioned.fill(
                                    child: CupertinoActivityIndicator(
                                      radius: 8,
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    layerData['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!isOptimalZoom)
                                  const Icon(
                                    CupertinoIcons.zoom_in,
                                    color: CupertinoColors.systemOrange,
                                    size: 14,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  layerData['description'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  isOptimalZoom
                                      ? 'Ready to load efficiently'
                                      : 'Zoom to level $recommendedMaxZoom+ for optimal loading',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isOptimalZoom
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemOrange,
                                  ),
                                ),
                              ],
                            ),
                            trailing: CupertinoSwitch(
                              value: isVisible,
                              onChanged: isLoading
                                  ? null
                                  : (value) => _toggleLayer(layerId, value),
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

  // Helper methods
  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }
    return Colors.blue;
  }

  // Map initialization and camera handling
  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (mapboxMap == null) return;

    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-98.5795, 39.8283)),
        zoom: 4.0,
      ),
    );

    await mapboxMap!.loadStyleURI(MapboxStyles.MAPBOX_STREETS);

    // Get initial camera state
    final cameraState = await mapboxMap!.getCameraState();
    _currentZoom = cameraState.zoom;

    setState(() {
      _statusMessage = _cacheInitialized
          ? 'Smart loading ready - Test connection to begin'
          : 'Map loaded - Test WFS connection first';
    });
  }

  void _onCameraChanged(CameraChangedEventData eventData) {
    _updateViewportState();
  }

  Future<void> _updateViewportState() async {
    if (mapboxMap == null) return;

    try {
      final newBounds = await SpatialUtils.getBoundingBoxFromCamera(mapboxMap!);
      final cameraState = await mapboxMap!.getCameraState();
      final newZoom = cameraState.zoom;

      // Check if viewport changed significantly
      final hasSignificantChange = _viewportDetector.hasSignificantChange(
        currentBounds: newBounds,
        currentZoom: newZoom,
        moveThreshold: 0.4, // 40% movement triggers reload
        zoomThreshold: 1.5, // 1.5 zoom levels triggers reload
      );

      if (_currentZoom != newZoom) {
        setState(() {
          _currentZoom = newZoom;
        });
      }

      // Auto-refresh visible layers if significant change
      if (hasSignificantChange && _cacheInitialized) {
        final visibleLayers = _layerVisibility.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

        if (visibleLayers.isNotEmpty) {
          print(
            '📍 Significant viewport change detected - refreshing ${visibleLayers.length} layers',
          );
          _refreshLayersQuietly(visibleLayers);
        }
      }
    } catch (e) {
      print('Error updating viewport state: $e');
    }
  }

  // Layer management with smart loading
  Future<void> _toggleLayer(String layerId, bool visible) async {
    if (mapboxMap == null) return;

    setState(() {
      _layerVisibility[layerId] = visible;
    });

    if (visible) {
      await _loadLayerSmart(layerId);
    } else {
      await _removeLayer(layerId);
    }
  }

  Future<void> _loadLayerSmart(String layerId) async {
    if (mapboxMap == null || !_cacheInitialized) {
      await _loadLayerFallback(layerId);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading ${_layerInfo[layerId]!['name']}...';
    });

    try {
      // Remove existing layer first
      await _removeLayerSafely(layerId);

      // Use smart bounded loader
      final result = await _wfsLoader.loadBoundedData(
        layerId: layerId,
        mapboxMap: mapboxMap!,
        cacheMaxAge: const Duration(hours: 24),
      );

      // Add to map
      await _addDataToMap(layerId, result.geojsonData, result.featureCount);

      setState(() {
        _statusMessage =
            '${result.fromCache ? '⚡' : '🌐'} ${_layerInfo[layerId]!['name']}: '
            '${result.featureCount} features (${result.loadTime.inMilliseconds}ms)';
      });

      print('✅ Smart load complete: ${result.toString()}');
    } catch (e) {
      print('❌ Smart load failed for $layerId: $e');
      setState(() {
        _layerVisibility[layerId] = false;
        _statusMessage = 'Error loading ${_layerInfo[layerId]!['name']}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshVisibleLayers() async {
    final visibleLayers = _layerVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (visibleLayers.isEmpty) {
      setState(() {
        _statusMessage = 'No visible layers to refresh';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Refreshing ${visibleLayers.length} visible layers...';
    });

    for (final layerId in visibleLayers) {
      await _loadLayerSmart(layerId);
    }
  }

  Future<void> _refreshLayersQuietly(List<String> layerIds) async {
    // Refresh layers without showing loading UI (for auto-refresh)
    for (final layerId in layerIds) {
      try {
        final result = await _wfsLoader.loadBoundedData(
          layerId: layerId,
          mapboxMap: mapboxMap!,
        );

        if (!result.fromCache) {
          // Only update map if new data was loaded
          await _removeLayerSafely(layerId);
          await _addDataToMap(layerId, result.geojsonData, result.featureCount);
        }
      } catch (e) {
        print('Quiet refresh failed for $layerId: $e');
      }
    }
  }

  // Fallback to old loading method if smart loading fails
  Future<void> _loadLayerFallback(String layerId) async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          'Loading ${_layerInfo[layerId]!['name']} (fallback mode)...';
    });

    try {
      _performanceMonitor.startLayerLoad(layerId);
      await _removeLayerSafely(layerId);

      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'wfs',
          'version': '2.0.0',
          'request': 'GetFeature',
          'typeNames': 'HS-d4238b41de7f4e59b54ef7ae875cbaa0:$layerId',
          'outputFormat': 'application/json',
          'maxFeatures': '5000', // Reasonable limit for fallback
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
        final data = jsonDecode(response.body);
        final featureCount = data['features']?.length ?? 0;

        await _addDataToMap(layerId, response.body, featureCount);

        _performanceMonitor.completeLayerLoad(
          layerId,
          success: true,
          featureCount: featureCount,
        );

        setState(() {
          _statusMessage =
              'Loaded ${_layerInfo[layerId]!['name']} ($featureCount features)';
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      _performanceMonitor.completeLayerLoad(
        layerId,
        success: false,
        errorMessage: e.toString(),
      );
      setState(() {
        _layerVisibility[layerId] = false;
        _statusMessage = 'Error loading ${_layerInfo[layerId]!['name']}: $e';
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
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: "${layerId}_source", data: geojsonData),
        );
      }

      // Add styled layers
      await _addStyledLayer(layerId);
    } catch (e) {
      throw Exception('Failed to add data to map: $e');
    }
  }

  Future<void> _addStyledLayer(String layerId) async {
    final layerData = _layerInfo[layerId]!;
    final colorHex = layerData['color'] as String;
    final colorInt = _parseColor(colorHex).value;

    if (layerData['type'] == 'point') {
      // Point clustering layers
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_clusters",
          sourceId: "${layerId}_source",
          circleRadius: 18.0,
          circleColorExpression: [
            "step",
            ["get", "point_count"],
            colorHex,
            100,
            "#FFD700",
            750,
            "#FF69B4",
          ],
          filter: ["has", "point_count"],
        ),
      );

      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: "${layerId}_count",
          sourceId: "${layerId}_source",
          textFieldExpression: ["get", "point_count_abbreviated"],
          textSize: 12.0,
          textColor: 0xFFFFFFFF,
          filter: ["has", "point_count"],
        ),
      );

      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_unclustered",
          sourceId: "${layerId}_source",
          circleRadius: 6.0,
          circleColor: colorInt,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 1.0,
          filter: [
            "!",
            ["has", "point_count"],
          ],
        ),
      );
    } else {
      // Line layer
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: "${layerId}_lines",
          sourceId: "${layerId}_source",
          lineColor: colorInt,
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
    await _removeLayerSafely(layerId);
    setState(() {
      _statusMessage = 'Removed ${_layerInfo[layerId]!['name']}';
    });
  }

  Future<void> _removeLayerSafely(String layerId) async {
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
      print('Error removing layer $layerId: $e');
    }
  }

  // WFS Connection testing
  Future<void> _testWFSConnection() async {
    try {
      setState(() {
        _statusMessage = 'Testing WFS connection...';
      });

      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {'service': 'wfs', 'request': 'GetCapabilities'},
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.body.contains('WFS_Capabilities')) {
          setState(() {
            _statusMessage = _cacheInitialized
                ? '✅ WFS working! Smart loading ready.'
                : '✅ WFS working! Cache unavailable - using direct loading.';
          });
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

  // Cache management
  Future<void> _clearCache() async {
    try {
      await WFSCache.clearAll();
      setState(() {
        _statusMessage = 'Cache cleared - next loads will be fresh';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to clear cache: $e';
      });
    }
  }

  // Info dialogs
  void _showCacheInfo() async {
    final stats = await WFSCache.getStats();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cache Statistics'),
        content: Text(
          'Entries: ${stats.totalEntries}\n'
          'Size: ${stats.sizeString}\n'
          'Hit Rate: ${stats.hitRate.toStringAsFixed(1)}%\n'
          'Hits: ${stats.hitCount}, Misses: ${stats.missCount}\n\n'
          'Layers:\n${stats.layerCounts.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Clear Cache'),
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
          ),
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showPerformanceInfo() {
    final loaderStats = _wfsLoader.getStats();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Performance Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smart Loading Features:'),
            const Text('✅ Viewport-only loading'),
            const Text('✅ Automatic caching'),
            const Text('✅ Zoom-level optimization'),
            const Text('✅ Request deduplication'),
            const SizedBox(height: 10),
            Text(
              'Cache Hit Rate: ${loaderStats['cacheHitRate'].toStringAsFixed(1)}%',
            ),
            Text('Active Requests: ${loaderStats['activeRequests']}'),
            Text(
              'Current Zoom: ${_currentZoom?.toStringAsFixed(1) ?? 'Unknown'}',
            ),
            if (_currentZoom != null)
              Text('Scale: ${SpatialUtils.getScaleDescription(_currentZoom!)}'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

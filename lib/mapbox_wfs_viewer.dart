// lib/mapbox_wfs_viewer.dart (Clean Version)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Import our modular services
import 'wfs_map_service.dart';
import 'map_layer_styler.dart';
import 'wfs_debug_helper.dart';
import 'wfs_cache.dart';
import 'feature_selection_service.dart';
import 'feature_details_widget.dart';

class MapboxWFSViewer extends StatefulWidget {
  const MapboxWFSViewer({super.key});

  @override
  State<MapboxWFSViewer> createState() => _MapboxWFSViewerState();
}

class _MapboxWFSViewerState extends State<MapboxWFSViewer> {
  MapboxMap? mapboxMap;
  bool _isLoading = false;
  String _statusMessage = 'Tap a layer to load data';

  // Services
  late WFSMapService _wfsService;
  late MapLayerStyler _layerStyler;
  late FeatureSelectionService _featureSelection;

  // Cache stats for display
  WFSCacheStats? _cacheStats;

  // Selected feature for display
  SelectedFeature? _selectedFeature;

  // Layer visibility states
  final Map<String, bool> _layerVisibility = {
    'streams3': false,
    'streams2': false,
    'midpoints': false,
    'usgs_gauges': false,
    'MidpointStreams': false,
  };

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
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _wfsService = WFSMapService();
    _layerStyler = MapLayerStyler();
    _featureSelection = FeatureSelectionService();

    await _wfsService.initialize();
    await _updateCacheStats();

    // Set up feature selection callbacks
    _featureSelection.onFeatureSelected = (feature) {
      setState(() {
        _selectedFeature = feature;
        _statusMessage = 'Selected: ${feature.title}';
      });

      // Show feature details
      showFeatureDetails(
        context,
        feature,
        onPropertySelected: _onPropertySelected,
      );
    };

    _featureSelection.onEmptyTap = (point) {
      setState(() {
        _selectedFeature = null;
        _statusMessage = 'Tapped empty area';
      });
    };

    // Register layer info for feature selection
    for (final entry in _layerInfo.entries) {
      _featureSelection.registerLayer(entry.key, entry.value);
    }

    print('✅ All services initialized');
  }

  Future<void> _updateCacheStats() async {
    _cacheStats = await _wfsService.getCacheStats();
    setState(() {}); // Refresh UI
  }

  @override
  void dispose() {
    _wfsService.dispose();
    _featureSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('WFS Viewer (Interactive)'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: Column(
        children: [
          // Status bar with cache info
          _buildStatusBar(),

          // Map with selected feature overlay and tap listener
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                  onTapListener: (context) {
                    // CORRECT API: Handle taps using onTapListener
                    _featureSelection.handleMapTap(context);
                  },
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 20),
                    ),
                  ),

                // Show selected feature info overlay
                if (_selectedFeature != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: CompactFeatureInfo(
                      feature: _selectedFeature!,
                      onTap: () => showFeatureDetails(
                        context,
                        _selectedFeature!,
                        onPropertySelected: _onPropertySelected,
                      ),
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

                  // Control buttons
                  _buildControlButtons(),
                  const SizedBox(height: 12),

                  // Layer list
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

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.systemGrey6,
      child: Column(
        children: [
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_cacheStats != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cache: ${_cacheStats!.totalEntries} entries, ${_cacheStats!.sizeString}, ${_cacheStats!.hitRate.toStringAsFixed(1)}% hit rate',
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_selectedFeature == null) ...[
            const SizedBox(height: 4),
            const Text(
              'Tap on map features to view their properties',
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.tertiaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: _refreshCurrentViewport,
                child: const Text(
                  'Refresh View',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: _showCacheManager,
                child: const Text(
                  'Cache Manager',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 6),
                onPressed: _showStats,
                child: const Text('Show Stats', style: TextStyle(fontSize: 10)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 6),
                onPressed: _debugBbox,
                child: const Text('Debug BBox', style: TextStyle(fontSize: 10)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 6),
                onPressed: _addTestLayer,
                child: const Text('Test Layer', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _wfsService.setMapboxMap(mapboxMap);
    _layerStyler.setMapboxMap(mapboxMap);
    _featureSelection.setMapboxMap(mapboxMap);
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (mapboxMap == null) return;

    // Set initial camera to continental US
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-98.5795, 39.8283)),
        zoom: 4.0,
      ),
    );

    // Set map style
    await mapboxMap!.loadStyleURI(MapboxStyles.MAPBOX_STREETS);

    setState(() {
      _statusMessage = 'Map loaded - Ready to load layers and select features!';
    });
  }

  Future<void> _toggleLayer(String layerId, bool visible) async {
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
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading ${_layerInfo[layerId]!['name']}...';
    });

    try {
      final result = await _wfsService.loadLayer(layerId, _layerInfo[layerId]!);

      if (result != null) {
        await _updateCacheStats();
        setState(() {
          _statusMessage =
              'Loaded ${_layerInfo[layerId]!['name']} '
              '(${result.featureCount} features, ${result.fromCache ? 'cached' : 'fresh'})';
        });
      } else {
        throw Exception('Failed to load layer');
      }
    } catch (e) {
      print('❌ Layer loading failed: $e');
      setState(() {
        _layerVisibility[layerId] = false;
        _statusMessage =
            'Failed to load ${_layerInfo[layerId]!['name']}: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle when a user selects a property from feature details
  void _onPropertySelected(String propertyKey, dynamic propertyValue) {
    print('🎯 Property selected: $propertyKey = $propertyValue');

    // Show confirmation dialog
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Use Property: $propertyKey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Value: $propertyValue'),
            const SizedBox(height: 16),
            const Text('This value is now available in your app!'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Copy Value'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: propertyValue.toString()));
              Navigator.pop(context);
              setState(() {
                _statusMessage = 'Copied "$propertyKey" value to clipboard';
              });
            },
          ),
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    // You can also store the value for use in your app
    // For example, save to a variable, send to a service, etc.
    setState(() {
      _statusMessage = 'Using property: $propertyKey = $propertyValue';
    });
  }

  Future<void> _removeLayer(String layerId) async {
    await _wfsService.removeLayer(layerId);
    setState(() {
      _statusMessage = 'Removed ${_layerInfo[layerId]!['name']}';
    });
  }

  Future<void> _refreshCurrentViewport() async {
    setState(() {
      _statusMessage = 'Refreshing visible layers...';
    });

    final visibleLayers = _layerVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final results = await _wfsService.refreshViewport(
      visibleLayers,
      _layerInfo,
    );

    await _updateCacheStats();
    setState(() {
      _statusMessage =
          'Refreshed ${results.length} layers for current viewport';
    });
  }

  Future<void> _showCacheManager() async {
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cache Manager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cacheStats != null) ...[
              Text('Total entries: ${_cacheStats!.totalEntries}'),
              Text('Cache size: ${_cacheStats!.sizeString}'),
              Text('Hit rate: ${_cacheStats!.hitRate.toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
            ],
            const Text('Choose an action:'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Clear Expired'),
            onPressed: () async {
              final removed = await _wfsService.clearExpiredCache();
              await _updateCacheStats();
              Navigator.pop(context);
              setState(() {
                _statusMessage = 'Removed $removed expired cache entries';
              });
            },
          ),
          CupertinoDialogAction(
            child: const Text('Clear All'),
            onPressed: () async {
              await _wfsService.clearCache();
              await _updateCacheStats();
              Navigator.pop(context);
              setState(() {
                _statusMessage = 'Cache cleared completely';
              });
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    _wfsService.printStats();
    setState(() {
      _statusMessage = 'Statistics printed to console';
    });
  }

  Future<void> _debugBbox() async {
    if (mapboxMap != null) {
      await WFSDebugHelper.debugBboxCalculation(mapboxMap!);
      setState(() {
        _statusMessage = 'BBox debug completed - check console';
      });
    }
  }

  Future<void> _addTestLayer() async {
    try {
      await _layerStyler.addTestLayer();
      setState(() {
        _statusMessage = 'Test layer added - large red circle at center of US';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Test layer failed: $e';
      });
    }
  }
}

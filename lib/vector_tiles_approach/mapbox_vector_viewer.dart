// lib/vector_tiles_approach/mapbox_vector_viewer.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Import our vector tiles services
import 'vector_tiles_service.dart';
import 'vector_feature_selection.dart';
import 'vector_feature_details_widget.dart';
import 'performance_comparison.dart';

class MapboxVectorViewer extends StatefulWidget {
  const MapboxVectorViewer({super.key});

  @override
  State<MapboxVectorViewer> createState() => _MapboxVectorViewerState();
}

class _MapboxVectorViewerState extends State<MapboxVectorViewer> {
  MapboxMap? mapboxMap;
  bool _isLoading = false;
  String _statusMessage = 'Tap a layer to load vector tiles';

  // Services
  late VectorTilesService _vectorService;
  late VectorFeatureSelectionService _featureSelection;
  late PerformanceComparisonService _performanceService;

  // Selected feature for display
  SelectedVectorFeature? _selectedFeature;

  // Layer visibility states
  final Map<String, bool> _layerVisibility = {
    'sample-streams': false,
    'sample-cities': false,
    'custom-streams': false,
  };

  // Layer metadata with vector tile specific configuration
  final Map<String, Map<String, dynamic>> _layerInfo = {
    'sample-streams': {
      'name': 'Waterways (Vector Demo)',
      'description': 'Rivers and streams from Mapbox Streets',
      'color': Colors.blue.value,
      'type': 'line',
      'sourceId': 'sample-streams-source',
      'sourceLayer': 'waterway',
      'tilesetId': 'mapbox.mapbox-streets-v8',
    },
    'sample-cities': {
      'name': 'Cities (Vector Demo)',
      'description': 'Major cities from Mapbox Streets',
      'color': Colors.orange.value,
      'type': 'point',
      'sourceId': 'sample-points-source',
      'sourceLayer': 'place_label',
      'tilesetId': 'mapbox.mapbox-streets-v8',
    },
    'custom-streams': {
      'name': 'HydroShare Streams (Planned)',
      'description': 'Your 2.7M stream network as vector tiles',
      'color': Colors.green.value,
      'type': 'line',
      'sourceId': 'hydroshare-streams-source',
      'sourceLayer': 'streams3',
      'tilesetId': 'your-username.hydroshare-streams',
      'isPlanned': true,
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _vectorService = VectorTilesService();
    _featureSelection = VectorFeatureSelectionService();
    _performanceService = PerformanceComparisonService();

    // Set up feature selection callbacks
    _featureSelection.onFeatureSelected = (feature) {
      setState(() {
        _selectedFeature = feature;
        _statusMessage = 'Selected: ${feature.title}';
      });

      // Show feature details
      showVectorFeatureDetails(
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
      if (!(entry.value['isPlanned'] ?? false)) {
        _featureSelection.registerLayer(entry.key, entry.value);
      }
    }

    print('✅ Vector tiles services initialized');
  }

  @override
  void dispose() {
    _vectorService.dispose();
    _featureSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Vector Tiles Demo'),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => const PerformanceComparisonWidget(),
            ),
          ),
          child: const Icon(CupertinoIcons.chart_bar),
        ),
      ),
      child: Column(
        children: [
          // Status bar with performance info
          _buildStatusBar(),

          // Map with selected feature overlay and tap listener
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("vectorMapWidget"),
                  onMapCreated: _onMapCreated,
                  onTapListener: (context) {
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

                // Vector tiles badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemPurple.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'VECTOR TILES',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Show selected feature info overlay
                if (_selectedFeature != null)
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 16,
                    child: CompactVectorFeatureInfo(
                      feature: _selectedFeature!,
                      onTap: () => showVectorFeatureDetails(
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
                    'Vector Tile Layers',
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
                        final isPlanned = layerData['isPlanned'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isPlanned
                                ? CupertinoColors.systemGrey6
                                : CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPlanned
                                  ? CupertinoColors.systemGrey4
                                  : CupertinoColors.separator,
                              width: 0.5,
                            ),
                          ),
                          child: CupertinoListTile(
                            leading: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isPlanned
                                    ? CupertinoColors.systemGrey3
                                    : Color(layerData['color']),
                                shape: layerData['type'] == 'point'
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                              ),
                              child: isPlanned
                                  ? const Icon(
                                      CupertinoIcons.clock,
                                      size: 12,
                                      color: CupertinoColors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              layerData['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isPlanned
                                    ? CupertinoColors.secondaryLabel
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              layerData['description'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isPlanned
                                ? const Text(
                                    'Coming Soon',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  )
                                : CupertinoSwitch(
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
    final performanceStats = _vectorService.getPerformanceStats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.systemPurple.withOpacity(0.1),
      child: Column(
        children: [
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Vector Tiles: ${performanceStats['totalTilesets']} sources loaded • '
            'Avg load: ${(performanceStats['averageLoadTime'] as double).toStringAsFixed(0)}ms',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedFeature == null) ...[
            const SizedBox(height: 4),
            const Text(
              'Tap on vector features to view their properties • Better performance with large datasets',
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
                onPressed: _refreshAllLayers,
                child: const Text(
                  'Refresh Tiles',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: _showVectorTileInfo,
                child: const Text('Tile Info', style: TextStyle(fontSize: 12)),
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
                onPressed: _showPerformanceStats,
                child: const Text(
                  'Performance',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 6),
                onPressed: _showHowToUpload,
                child: const Text(
                  'Upload Guide',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 6),
                onPressed: _zoomToStreams,
                child: const Text(
                  'Zoom to Data',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _vectorService.setMapboxMap(mapboxMap);
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
      _statusMessage =
          'Vector tiles ready - Faster performance with large datasets!';
    });
  }

  Future<void> _toggleLayer(String layerId, bool visible) async {
    setState(() {
      _layerVisibility[layerId] = visible;
    });

    if (visible) {
      await _loadVectorLayer(layerId);
    } else {
      await _removeVectorLayer(layerId);
    }
  }

  Future<void> _loadVectorLayer(String layerId) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading ${_layerInfo[layerId]!['name']}...';
    });

    final startTime = DateTime.now();

    try {
      final layerData = _layerInfo[layerId]!;

      if (layerId == 'sample-streams') {
        await _vectorService.addSampleStreamsSource();
      } else if (layerId == 'sample-cities') {
        await _vectorService.addSamplePointsSource();
      } else {
        // For custom layers, you'd call:
        // await _vectorService.addVectorTileSource(
        //   sourceId: layerData['sourceId'],
        //   tilesetId: layerData['tilesetId'],
        //   accessToken: 'your-token',
        // );
        throw Exception('Custom tileset not implemented yet');
      }

      final loadTime = DateTime.now().difference(startTime);

      // Record performance metrics
      _performanceService.recordMetrics(
        PerformanceMetrics(
          approach: 'Vector Tiles',
          layerName: layerData['name'],
          featureCount: -1, // Vector tiles don't report exact feature count
          loadTime: loadTime,
          dataSizeKB: 0, // Vector tiles are streamed, not downloaded in bulk
          fromCache: false,
          timestamp: DateTime.now(),
          additionalMetrics: {
            'tilesetId': layerData['tilesetId'],
            'sourceLayer': layerData['sourceLayer'],
          },
        ),
      );

      setState(() {
        _statusMessage =
            'Loaded ${layerData['name']} vector tiles (${loadTime.inMilliseconds}ms)';
      });
    } catch (e) {
      print('❌ Vector layer loading failed: $e');
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

  Future<void> _removeVectorLayer(String layerId) async {
    final layerData = _layerInfo[layerId]!;

    await _vectorService.removeLayer(layerId);

    setState(() {
      _statusMessage = 'Removed ${layerData['name']}';
    });
  }

  /// Handle when a user selects a property from feature details
  void _onPropertySelected(String propertyKey, dynamic propertyValue) {
    print('🎯 Vector property selected: $propertyKey = $propertyValue');

    // Show confirmation dialog
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Use Vector Property: $propertyKey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Value: $propertyValue'),
            const SizedBox(height: 16),
            const Text(
              'This vector tile property is now available in your app!',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Copy Value'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: propertyValue.toString()));
              Navigator.pop(context);
              setState(() {
                _statusMessage =
                    'Copied vector "$propertyKey" value to clipboard';
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

    setState(() {
      _statusMessage = 'Using vector property: $propertyKey = $propertyValue';
    });
  }

  Future<void> _refreshAllLayers() async {
    setState(() {
      _statusMessage = 'Refreshing vector tile sources...';
    });

    final visibleLayers = _layerVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    for (final layerId in visibleLayers) {
      try {
        await _removeVectorLayer(layerId);
        await Future.delayed(const Duration(milliseconds: 100));
        await _loadVectorLayer(layerId);
      } catch (e) {
        print('❌ Failed to refresh layer $layerId: $e');
      }
    }

    setState(() {
      _statusMessage = 'Refreshed ${visibleLayers.length} vector tile layers';
    });
  }

  void _showVectorTileInfo() {
    final stats = _vectorService.getPerformanceStats();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Vector Tiles Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vector tiles provide:'),
            const SizedBox(height: 8),
            const Text('• Faster rendering for large datasets'),
            const Text('• Better zoom performance'),
            const Text('• Reduced bandwidth usage'),
            const Text('• Server-side optimization'),
            const Text('• Scalable to millions of features'),
            const SizedBox(height: 12),
            Text('Loaded Sources: ${stats['totalTilesets']}'),
            if (stats['averageLoadTime'] > 0)
              Text(
                'Avg Load Time: ${stats['averageLoadTime'].toStringAsFixed(0)}ms',
              ),
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

  void _showPerformanceStats() {
    _vectorService.printPerformanceStats();
    _performanceService.printPerformanceSummary();

    setState(() {
      _statusMessage = 'Performance statistics printed to console';
    });
  }

  void _showHowToUpload() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Upload Your Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To use your 2.7M HydroShare streams:'),
            SizedBox(height: 8),
            Text('1. Export streams3 as GeoJSON'),
            Text('2. Upload to Mapbox Studio'),
            Text('3. Create a tileset'),
            Text('4. Update tilesetId in app'),
            SizedBox(height: 12),
            Text('Benefits: 10-100x faster than WFS for large datasets!'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Learn More'),
            onPressed: () {
              Navigator.pop(context);
              // In a real app, you'd open a URL to Mapbox documentation
              setState(() {
                _statusMessage = 'Check Mapbox Studio for tileset upload';
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
  }

  Future<void> _zoomToStreams() async {
    if (mapboxMap == null) return;

    // Zoom to a region where we know there are streams (around Mississippi River)
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(-90.0715, 29.9511),
        ), // New Orleans area
        zoom: 10.0,
      ),
    );

    setState(() {
      _statusMessage =
          'Zoomed to stream-rich area - notice vector tile performance!';
    });
  }
}

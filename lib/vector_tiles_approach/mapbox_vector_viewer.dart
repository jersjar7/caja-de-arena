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
  String _statusMessage = 'Ready to load streams2 vector tiles';

  // Services
  late VectorTilesService _vectorService;
  late VectorFeatureSelectionService _featureSelection;
  late PerformanceComparisonService _performanceService;

  // Selected feature for display
  SelectedVectorFeature? _selectedFeature;

  // Layer visibility states - focused on streams2
  final Map<String, bool> _layerVisibility = {'streams2': false};

  // Layer metadata with real streams2 configuration
  final Map<String, Map<String, dynamic>> _layerInfo = {
    'streams2': {
      'name': 'HydroShare Streams2 (364K features)',
      'description': 'Stream network with station_id and stream order',
      'color': Colors.blue.value,
      'type': 'line',
      'sourceId': 'streams2-source',
      'sourceLayer': 'streams2',
      'tilesetId': 'jersondevs.dopm8y3j', // Your real tileset ID!
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
        _statusMessage =
            'Selected: ${feature.title} (Stream Order: ${feature.properties['streamOrde'] ?? 'Unknown'})';
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
        _statusMessage =
            'Tapped empty area - 364K streams ready for interaction';
      });
    };

    // Register streams2 for feature selection
    _featureSelection.registerLayer('streams2', _layerInfo['streams2']!);

    print('✅ Vector tiles services initialized for streams2');
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
        middle: const Text('streams2 Vector Tiles'),
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
          // Status bar with streams2 info
          _buildStatusBar(),

          // Map with selected feature overlay and tap listener
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey("streams2VectorMapWidget"),
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
                      'STREAMS2 VECTOR TILES',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Feature count badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '364,115 Features',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 10,
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

          // Simple streams2 controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HydroShare streams2 Layer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Simple on/off toggle for streams2
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CupertinoColors.separator),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            CupertinoIcons.drop_fill,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HydroShare Streams2',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                '364,115 stream features • Styled by stream order',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tileset: jersondevs.dopm8y3j',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: CupertinoColors.tertiaryLabel,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _layerVisibility['streams2'] ?? false,
                          onChanged: (value) => _toggleStreams2(value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick action buttons
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: _zoomToStreams,
                          child: const Text('Zoom to Streams'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: _showStreamOrderLegend,
                          child: const Text('Stream Order Legend'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Performance info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.speedometer,
                          color: CupertinoColors.systemGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vector tiles render 10-100x faster than WFS for large datasets like this',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGreen,
                            ),
                          ),
                        ),
                      ],
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
            'Vector Tiles: ${performanceStats['totalTilesets']} sources • '
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
              'Tap any stream to see station_id and stream order • Zoom in for more detail',
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
          'streams2 vector tiles ready - Toggle the layer to see 364K stream features!';
    });
  }

  Future<void> _toggleStreams2(bool visible) async {
    setState(() {
      _layerVisibility['streams2'] = visible;
    });

    if (visible) {
      await _loadStreams2VectorLayer();
    } else {
      await _removeStreams2Layer();
    }
  }

  Future<void> _loadStreams2VectorLayer() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading streams2 vector tiles (364K features)...';
    });

    final startTime = DateTime.now();

    try {
      // Load the real streams2 tileset
      await _vectorService.addStreams2VectorTiles();

      final loadTime = DateTime.now().difference(startTime);

      // Record performance metrics
      _performanceService.recordMetrics(
        PerformanceMetrics(
          approach: 'Vector Tiles',
          layerName: 'streams2 (364K features)',
          featureCount: 364115,
          loadTime: loadTime,
          dataSizeKB: 0, // Vector tiles are streamed
          fromCache: false,
          timestamp: DateTime.now(),
          additionalMetrics: {
            'tilesetId': 'jersondevs.dopm8y3j',
            'sourceLayer': 'streams2',
            'streamOrdered': true,
          },
        ),
      );

      setState(() {
        _statusMessage =
            '✅ Loaded streams2 vector tiles (${loadTime.inMilliseconds}ms) - Tap streams to explore!';
      });
    } catch (e) {
      print('❌ streams2 vector loading failed: $e');
      setState(() {
        _layerVisibility['streams2'] = false;
        _statusMessage = 'Failed to load streams2: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeStreams2Layer() async {
    await _vectorService.removeStreams2Layers();
    setState(() {
      _statusMessage = 'Removed streams2 vector tiles';
    });
  }

  void _onPropertySelected(String propertyKey, dynamic propertyValue) {
    print('🎯 streams2 property selected: $propertyKey = $propertyValue');

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('streams2 Property: $propertyKey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Value: $propertyValue'),
            const SizedBox(height: 12),
            if (propertyKey == 'streamOrde')
              Text(
                'Stream Order $propertyValue: ${_getStreamOrderDescription(propertyValue)}',
              )
            else if (propertyKey == 'station_id')
              Text('Station ID for this stream segment'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: propertyValue.toString()));
              Navigator.pop(context);
              setState(() {
                _statusMessage = 'Copied $propertyKey: $propertyValue';
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

  String _getStreamOrderDescription(dynamic order) {
    switch (order) {
      case 1:
        return 'Small headwater stream';
      case 2:
        return 'Small tributary';
      case 3:
        return 'Medium tributary';
      case 4:
        return 'Large tributary';
      case 5:
        return 'Small river';
      case 6:
        return 'Medium river';
      case 7:
        return 'Large river';
      default:
        return 'Stream segment';
    }
  }

  Future<void> _zoomToStreams() async {
    if (mapboxMap == null) return;

    // Zoom to a stream-rich area (Mississippi River basin)
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(-90.0715, 38.6270),
        ), // St. Louis area
        zoom: 10.0,
      ),
    );

    setState(() {
      _statusMessage =
          'Zoomed to stream-rich area - Notice the smooth vector tile performance!';
    });
  }

  void _showStreamOrderLegend() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Stream Order Legend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Streams are styled by their order:'),
            const SizedBox(height: 12),
            _buildLegendItem(
              'Order 1-2',
              'Light blue, thin lines',
              'Small streams',
            ),
            _buildLegendItem(
              'Order 3-4',
              'Medium blue, medium lines',
              'Tributaries',
            ),
            _buildLegendItem(
              'Order 5+',
              'Dark blue, thick lines',
              'Major rivers',
            ),
            const SizedBox(height: 12),
            const Text(
              'Higher order = larger, more important waterway',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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

  Widget _buildLegendItem(String order, String style, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: order.contains('1-2')
                  ? Colors.lightBlue
                  : order.contains('3-4')
                  ? Colors.blue
                  : Colors.blueGrey,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$order: $description',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

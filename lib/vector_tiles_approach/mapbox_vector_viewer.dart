// lib/vector_tiles_approach/mapbox_vector_viewer.dart
import 'dart:async';

import 'package:cupertino_showcase/components/mapbox_place_search.dart';
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
  SearchedPlace? _selectedPlace;

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
    _statusMessage =
        'streams2 vector tiles ready (zoom 7-13 only)'; // ✅ Updated
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

                // 🔍 NEW: Search Bar Overlay
                Positioned(
                  top: 60,
                  left: 16,
                  right: 16,
                  child: CompactMapSearchBar(
                    mapboxMap: mapboxMap,
                    onPlaceSelected: _onPlaceSelectedFromSearch,
                    onTap: _showFullSearch,
                  ),
                ),

                // Show selected feature info overlay
                if (_selectedFeature != null)
                  Positioned(
                    top: 120, // Moved down to accommodate search bar
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

                // Show selected place overlay
                if (_selectedPlace != null)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _buildSelectedPlaceInfo(_selectedPlace!),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: _showStreamOrderLegend,
                          child: const Text('Stream Legend'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ), // Smaller padding
                          onPressed: _runTilesetDiagnostics,
                          child: const Text(
                            'Debug Tileset',
                            style: TextStyle(fontSize: 12), // Smaller text
                          ),
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

  /// Handle place selection from search
  void _onPlaceSelectedFromSearch(SearchedPlace place) {
    setState(() {
      _selectedPlace = place;
      _statusMessage = 'Navigated to: ${place.shortName}';
    });

    print('🎯 User searched and selected: ${place.placeName}');

    // Optionally hide the selected place info after a few seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _selectedPlace = null;
        });
      }
    });
  }

  /// Show full search modal
  void _showFullSearch() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Search Places',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

            // Search widget
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MapboxPlaceSearchWidget(
                  mapboxMap: mapboxMap,
                  onPlaceSelected: (place) {
                    _onPlaceSelectedFromSearch(place);
                    Navigator.pop(context);
                  },
                  placeholder: 'Search cities, landmarks, addresses...',
                  showRecentSearches: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build selected place info widget
  Widget _buildSelectedPlaceInfo(SearchedPlace place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              place.categoryIcon,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.shortName,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place.contextString.isNotEmpty)
                  Text(
                    place.contextString,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _selectedPlace = null;
              });
            },
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runTilesetDiagnostics() async {
    setState(() {
      _statusMessage = 'Running tileset diagnostics - check console...';
    });

    try {
      await _vectorService.runTilesetDiagnostics();

      setState(() {
        _statusMessage = 'Diagnostics complete - check console for results';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Diagnostics failed: $e';
      });
    }
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

    // Set camera to correct zoom level
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-90.0715, 38.6270)),
        zoom: 9.0,
      ),
    );

    await mapboxMap!.loadStyleURI(MapboxStyles.MAPBOX_STREETS);

    setState(() {
      _statusMessage =
          '✅ Ready at zoom 9! Toggle streams2 to see 364K features (source: streams2-7jgd8p)';
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
      _statusMessage =
          'Loading streams2 vector tiles (source layer: streams2-7jgd8p)...';
    });

    final startTime = DateTime.now();

    try {
      await _vectorService.addStreams2VectorTiles();
      final loadTime = DateTime.now().difference(startTime);

      // Record performance metrics
      _performanceService.recordMetrics(
        PerformanceMetrics(
          approach: 'Vector Tiles',
          layerName: 'streams2 (364K features)',
          featureCount: 364115,
          loadTime: loadTime,
          dataSizeKB: 0,
          fromCache: false,
          timestamp: DateTime.now(),
          additionalMetrics: {
            'tilesetId': 'jersondevs.dopm8y3j',
            'sourceLayer': 'streams2-7jgd8p', // ✅ Correct source layer
            'zoomExtent': '7-13',
            'streamOrdered': true,
          },
        ),
      );

      setState(() {
        _statusMessage =
            '✅ streams2 loaded (${loadTime.inMilliseconds}ms) - Tap streams to explore! 🌊';
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
            // ✅ Handle correct field names
            if (propertyKey ==
                'streamOrde') // ✅ Note: it's "streamOrde" not "streamOrder"
              Text(
                'Stream Order $propertyValue: ${_getStreamOrderDescription(propertyValue)}',
              )
            else if (propertyKey == 'station_id' || propertyKey == 'STATIONID')
              Text('Station ID for this stream segment')
            else if (propertyKey == 'Shape_Leng')
              Text('Length of this stream segment: $propertyValue'),
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

    // ✅ Zoom to optimal level for streams2 (within 7-13 range)
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(-90.0715, 38.6270),
        ), // St. Louis area
        zoom: 11.0, // ✅ Higher zoom for more detail
      ),
    );

    setState(() {
      _statusMessage =
          'Zoomed to zoom 11 - Perfect level for streams2 vector tiles!';
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

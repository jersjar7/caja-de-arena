// lib/pages/streams2_map_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';

// Import your existing services
import '../vector_tiles_approach/vector_tiles_service.dart';
import '../vector_tiles_approach/vector_feature_selection.dart';
import '../vector_tiles_approach/vector_feature_details_widget.dart';
import '../components/mapbox_place_search.dart';

class Streams2MapPage extends StatefulWidget {
  const Streams2MapPage({super.key});

  @override
  State<Streams2MapPage> createState() => _Streams2MapPageState();
}

class _Streams2MapPageState extends State<Streams2MapPage> {
  MapboxMap? mapboxMap;
  bool _isLoading = false;
  String _statusMessage = 'Loading streams2 map...';

  // Services
  late VectorTilesService _vectorService;
  late VectorFeatureSelectionService _featureSelection;

  // Selected features
  SelectedVectorFeature? _selectedFeature;
  SearchedPlace? _selectedPlace;

  // Map state
  bool _streams2Loaded = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _vectorService = VectorTilesService();
    _featureSelection = VectorFeatureSelectionService();

    // Set up feature selection callbacks
    _featureSelection.onFeatureSelected = (feature) {
      setState(() {
        _selectedFeature = feature;
        _selectedPlace = null; // Clear place selection when feature is selected
        _statusMessage = 'Selected: ${feature.title}';
      });

      // Auto-hide feature info after 8 seconds
      Timer(const Duration(seconds: 8), () {
        if (mounted && _selectedFeature == feature) {
          setState(() {
            _selectedFeature = null;
            _statusMessage =
                'Tap streams to explore • Search places to navigate';
          });
        }
      });
    };

    _featureSelection.onEmptyTap = (point) {
      setState(() {
        _selectedFeature = null;
        _statusMessage = 'Tap streams to explore • Search places to navigate';
      });
    };

    // Register streams2 for feature selection
    _featureSelection.registerLayer('streams2', {
      'name': 'HydroShare Streams2',
      'description': 'Stream network with 364K features',
      'color': Colors.blue.value,
      'type': 'line',
      'sourceId': 'streams2-source',
      'sourceLayer': 'streams2-7jgd8p',
      'tilesetId': 'jersondevs.dopm8y3j',
    });

    print('✅ Streams2 map services initialized');
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
        middle: const Text('streams2 Explorer'),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showMapInfo,
          child: const Icon(CupertinoIcons.info_circle),
        ),
      ),
      child: Stack(
        children: [
          // Main map
          MapWidget(
            key: const ValueKey("streams2ExplorerMap"),
            onMapCreated: _onMapCreated,
            onTapListener: (context) {
              _featureSelection.handleMapTap(context);
            },
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 20),
                    SizedBox(height: 16),
                    Text(
                      'Loading 364K stream features...',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: CompactMapSearchBar(
              mapboxMap: mapboxMap,
              onPlaceSelected: _onPlaceSelected,
              onTap: _showFullSearch,
            ),
          ),

          // Streams2 info badge
          Positioned(
            top: 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _streams2Loaded
                    ? CupertinoColors.systemGreen.withOpacity(0.9)
                    : CupertinoColors.systemGrey.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _streams2Loaded
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: CupertinoColors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _streams2Loaded ? '364K Streams' : 'Loading...',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected feature overlay
          if (_selectedFeature != null)
            Positioned(
              bottom: _selectedPlace != null ? 140 : 80,
              left: 16,
              right: 16,
              child: CompactVectorFeatureInfo(
                feature: _selectedFeature!,
                onTap: () =>
                    showVectorFeatureDetails(context, _selectedFeature!),
              ),
            ),

          // Selected place overlay
          if (_selectedPlace != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildSelectedPlaceInfo(_selectedPlace!),
            ),

          // Status bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
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

    setState(() {
      _isLoading = true;
      _statusMessage = 'Setting up map...';
    });

    try {
      // Set initial camera to optimal level for streams2 (zoom 7-13)
      await mapboxMap!.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(-95.7129, 37.0902),
          ), // Center of US
          zoom: 8.0, // Good level to see streams
        ),
      );

      // Set map style
      await mapboxMap!.loadStyleURI(MapboxStyles.MAPBOX_STREETS);

      // Wait a moment for style to load
      await Future.delayed(const Duration(seconds: 1));

      // Load streams2 automatically
      await _loadStreams2();

      setState(() {
        _statusMessage =
            'Ready! Search places to navigate • Tap streams to explore';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Map setup failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStreams2() async {
    setState(() {
      _statusMessage = 'Loading 364K stream features...';
    });

    try {
      await _vectorService.addStreams2VectorTiles();

      setState(() {
        _streams2Loaded = true;
        _statusMessage =
            '✅ streams2 loaded! Search places or tap streams to explore';
      });

      print('✅ streams2 vector tiles loaded successfully');
    } catch (e) {
      setState(() {
        _streams2Loaded = false;
        _statusMessage = 'Failed to load streams2: ${e.toString()}';
      });
      print('❌ streams2 loading failed: $e');
    }
  }

  void _onPlaceSelected(SearchedPlace place) {
    setState(() {
      _selectedPlace = place;
      _selectedFeature = null; // Clear feature selection when place is selected
      _statusMessage = 'Navigated to: ${place.shortName}';
    });

    print('🎯 User navigated to: ${place.placeName}');

    // Auto-hide place info after 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (mounted && _selectedPlace == place) {
        setState(() {
          _selectedPlace = null;
          _statusMessage = 'Search places to navigate • Tap streams to explore';
        });
      }
    });
  }

  void _showFullSearch() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                    _onPlaceSelected(place);
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

  Widget _buildSelectedPlaceInfo(SearchedPlace place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.95),
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
              color: CupertinoColors.systemBlue,
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

  void _showMapInfo() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('streams2 Explorer'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This map shows 364,115 stream features from HydroShare using Mapbox Vector Tiles.',
            ),
            SizedBox(height: 12),
            Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('🔍 Search any place worldwide'),
            Text('🌊 Tap streams to see details'),
            Text('📍 Smooth map navigation'),
            Text('⚡ Fast vector tile rendering'),
            SizedBox(height: 8),
            Text(
              'Data visible at zoom levels 7-13',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Got it!'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

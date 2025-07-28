// lib/vector_tiles_approach/vector_feature_selection.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';

/// Represents a selected vector tile feature
class SelectedVectorFeature {
  final String layerId;
  final String sourceLayer;
  final String featureId;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> geometry;
  final Point tapLocation;
  final String sourceId;

  const SelectedVectorFeature({
    required this.layerId,
    required this.sourceLayer,
    required this.featureId,
    required this.properties,
    required this.geometry,
    required this.tapLocation,
    required this.sourceId,
  });

  /// Get a human-readable title for the feature (optimized for streams2)
  String get title {
    // For streams2, create meaningful titles
    final stationId = properties['station_id'];
    final streamOrder = properties['streamOrde'];

    if (stationId != null && streamOrder != null) {
      return 'Stream ${_formatStationId(stationId)} (Order $streamOrder)';
    } else if (stationId != null) {
      return 'Stream Station $stationId';
    } else if (streamOrder != null) {
      return 'Stream Order $streamOrder';
    }

    // Fallback to layer identification
    return 'streams2 Feature';
  }

  /// Get feature type description (optimized for streams2)
  String get typeDescription {
    final streamOrder = properties['streamOrde'];

    if (streamOrder != null) {
      return _getStreamOrderDescription(streamOrder);
    }

    return 'Stream segment';
  }

  /// Format station ID for display
  String _formatStationId(dynamic stationId) {
    if (stationId == null) return 'Unknown';
    final id = stationId.toString();
    // Add formatting if needed (e.g., add commas for large numbers)
    if (id.length > 3) {
      return id.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return id;
  }

  /// Get stream order description
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
        return 'Stream segment (Order $order)';
    }
  }

  /// Get coordinates as a readable string
  String get coordinatesString {
    try {
      if (geometry['type'] == 'Point') {
        final coords = geometry['coordinates'] as List;
        final lng = (coords[0] as num).toStringAsFixed(6);
        final lat = (coords[1] as num).toStringAsFixed(6);
        return 'Lat: $lat, Lng: $lng';
      } else if (geometry['type'] == 'LineString') {
        final coords = geometry['coordinates'] as List;
        return 'Line with ${coords.length} points';
      } else if (geometry['type'] == 'MultiLineString') {
        final coords = geometry['coordinates'] as List;
        int totalPoints = 0;
        for (final line in coords) {
          if (line is List) totalPoints += line.length;
        }
        return 'Multi-line with $totalPoints total points';
      } else if (geometry['type'] == 'Polygon') {
        return 'Polygon geometry';
      }
      return 'Complex geometry';
    } catch (e) {
      return 'Unknown coordinates';
    }
  }

  /// Get all properties as formatted key-value pairs
  List<MapEntry<String, String>> get formattedProperties {
    return properties.entries.where((entry) => entry.value != null).map((
      entry,
    ) {
      final key = _formatPropertyKey(entry.key);
      final value = _formatPropertyValue(entry.value);
      return MapEntry(key, value);
    }).toList();
  }

  String _formatPropertyKey(String key) {
    // Convert snake_case or camelCase to readable format
    return key
        .replaceAll('_', ' ')
        .replaceAll(':', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }

  String _formatPropertyValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is String) return value;
    if (value is num) {
      // Format numbers nicely
      if (value is double && value != value.toInt()) {
        return value.toStringAsFixed(3);
      }
      return value.toString();
    }
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  @override
  String toString() {
    return 'SelectedVectorFeature(layer: $layerId, sourceLayer: $sourceLayer, title: $title)';
  }
}

/// Service for handling vector tile feature selection
class VectorFeatureSelectionService {
  MapboxMap? mapboxMap;

  // Callback for when a feature is selected
  Function(SelectedVectorFeature)? onFeatureSelected;

  // Callback for when no feature is found at tap location
  Function(Point)? onEmptyTap;

  // Currently selected feature
  SelectedVectorFeature? _selectedFeature;

  // Available layers for querying
  final Map<String, Map<String, dynamic>> _layerInfo = {};

  /// Set the MapboxMap instance
  void setMapboxMap(MapboxMap map) {
    mapboxMap = map;
    print('✅ Vector feature selection service ready for streams2');
  }

  /// Register layer information for selection
  void registerLayer(String layerId, Map<String, dynamic> layerInfo) {
    _layerInfo[layerId] = layerInfo;
    print('📝 Registered vector layer: $layerId');
  }

  /// Handle map tap for vector tiles
  Future<void> handleMapTap(MapContentGestureContext context) async {
    if (mapboxMap == null) return;

    try {
      final tapPoint = context.point;
      final touchPosition = context.touchPosition;

      print(
        '🎯 Vector map tapped at: ${tapPoint.coordinates.lng}, ${tapPoint.coordinates.lat}',
      );

      // Query vector tile features at the tap point
      final features = await _queryVectorFeaturesAtPoint(
        tapPoint,
        touchPosition,
      );

      if (features.isNotEmpty) {
        final feature = features.first; // Will be the closest/topmost feature
        print('✅ Vector feature selected: ${feature.title}');

        _selectedFeature = feature;
        onFeatureSelected?.call(feature);
      } else {
        print('ℹ️ No vector features found at tap location');
        onEmptyTap?.call(tapPoint);
      }
    } catch (e) {
      print('❌ Error handling vector map tap: $e');
    }
  }

  /// Query vector tile features at a specific point (optimized for streams2)
  Future<List<SelectedVectorFeature>> _queryVectorFeaturesAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (mapboxMap == null) return [];

    final selectedFeatures = <SelectedVectorFeature>[];

    // Create a query area around the tap point (larger for line features)
    final queryBox = RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(x: touchPosition.x - 8, y: touchPosition.y - 8),
        max: ScreenCoordinate(x: touchPosition.x + 8, y: touchPosition.y + 8),
      ),
    );

    // Query streams2 layers specifically
    final streams2LayerIds = [
      'streams2-order-1-2',
      'streams2-order-3-4',
      'streams2-order-5-plus',
    ];

    try {
      // Query streams2 vector layers
      final List<QueriedRenderedFeature?> queryResult = await mapboxMap!
          .queryRenderedFeatures(
            queryBox,
            RenderedQueryOptions(layerIds: streams2LayerIds),
          );

      print('📊 Found ${queryResult.length} streams2 features in query');

      // Process each found feature
      for (final queriedRenderedFeature in queryResult) {
        if (queriedRenderedFeature != null) {
          try {
            final selectedFeature = _processQueriedVectorFeature(
              queriedRenderedFeature,
              tapPoint,
            );
            if (selectedFeature != null) {
              selectedFeatures.add(selectedFeature);
            }
          } catch (e) {
            print('⚠️ Error processing streams2 feature: $e');
          }
        }
      }

      print('📊 Processed ${selectedFeatures.length} valid streams2 features');

      // Return the first feature (streams are already ordered by importance)
      if (selectedFeatures.isNotEmpty) {
        return [selectedFeatures.first];
      }
    } catch (e) {
      print('⚠️ Error querying streams2 features: $e');
    }

    return [];
  }

  /// Process a queried vector tile feature
  SelectedVectorFeature? _processQueriedVectorFeature(
    QueriedRenderedFeature queriedRenderedFeature,
    Point tapLocation,
  ) {
    try {
      // Get feature data from the query result
      final feature = queriedRenderedFeature.queriedFeature.feature;

      // FIXED: More defensive null handling for layers
      final layerIds = queriedRenderedFeature.layers;
      String layerId = 'unknown-layer';

      if (layerIds.isNotEmpty) {
        // Find first non-null layer ID
        for (final id in layerIds) {
          if (id != null && id.isNotEmpty) {
            layerId = id;
            break;
          }
        }
      }

      // FIXED: More defensive null handling for source
      String sourceId = 'streams2-source';
      final source = queriedRenderedFeature.queriedFeature.source;
      if (source.isNotEmpty) {
        sourceId = source;
      }

      print(
        '🔍 Processing streams2 feature from layers: $layerIds, source: $sourceId',
      );

      // Safe type casting for vector tile properties
      final properties = feature['properties'] != null
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};
      final geometry = feature['geometry'] != null
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : <String, dynamic>{};

      // For streams2, the source layer is always 'streams2'
      final sourceLayer = 'streams2';

      final featureId =
          feature['id']?.toString() ??
          properties['station_id']?.toString() ??
          'streams2_${DateTime.now().millisecondsSinceEpoch}';

      // Log the properties for debugging
      print('🔍 streams2 properties: ${properties.keys.toList()}');
      if (properties.containsKey('station_id')) {
        print('   station_id: ${properties['station_id']}');
      }
      if (properties.containsKey('streamOrde')) {
        print('   streamOrde: ${properties['streamOrde']}');
      }

      return SelectedVectorFeature(
        layerId: layerId, // Now guaranteed to be non-null String
        sourceLayer: sourceLayer,
        featureId: featureId,
        properties: properties,
        geometry: geometry,
        tapLocation: tapLocation,
        sourceId: sourceId, // Now guaranteed to be non-null String
      );
    } catch (e) {
      print('❌ Error processing streams2 vector feature: $e');
      return null;
    }
  }

  /// Get the currently selected feature
  SelectedVectorFeature? get selectedFeature => _selectedFeature;

  /// Clear the current selection
  void clearSelection() {
    _selectedFeature = null;
  }

  /// Export feature data as JSON string
  String exportFeatureAsJson(SelectedVectorFeature feature) {
    final exportData = {
      'layerId': feature.layerId,
      'sourceLayer': feature.sourceLayer,
      'sourceId': feature.sourceId,
      'featureId': feature.featureId,
      'title': feature.title,
      'type': feature.typeDescription,
      'coordinates': feature.coordinatesString,
      'properties': feature.properties,
      'geometry': feature.geometry,
      'selectedAt': DateTime.now().toIso8601String(),
      'approach': 'vector_tiles',
      'tileset_id': 'jersondevs.dopm8y3j',
      'dataset_info': {
        'name': 'HydroShare streams2',
        'total_features': 364115,
        'source': 'HydroShare WFS converted to vector tiles',
      },
    };

    return jsonEncode(exportData);
  }

  /// Get specific property value from selected feature
  T? getPropertyValue<T>(String propertyKey) {
    if (_selectedFeature == null) return null;

    final value = _selectedFeature!.properties[propertyKey];
    if (value is T) return value;

    // Try to convert
    if (T == String) return value?.toString() as T?;
    if (T == double && value is num) return value.toDouble() as T?;
    if (T == int && value is num) return value.toInt() as T?;

    return null;
  }

  /// Check if a property exists in the selected feature
  bool hasProperty(String propertyKey) {
    return _selectedFeature?.properties.containsKey(propertyKey) ?? false;
  }

  /// Get all property keys from the selected feature
  List<String> get availableProperties {
    return _selectedFeature?.properties.keys.toList() ?? [];
  }

  /// Get feature selection statistics
  Map<String, dynamic> getSelectionStats() {
    return {
      'registeredLayers': _layerInfo.length,
      'layerIds': _layerInfo.keys.toList(),
      'hasSelectedFeature': _selectedFeature != null,
      'selectedFeatureType': _selectedFeature?.typeDescription,
      'selectedSourceLayer': _selectedFeature?.sourceLayer,
      'streams2Optimized': true,
      'supportedProperties': ['station_id', 'streamOrde'],
    };
  }

  /// Print selection statistics
  void printSelectionStats() {
    final stats = getSelectionStats();
    print('\n📊 STREAMS2 VECTOR FEATURE SELECTION STATS:');
    print('Registered layers: ${stats['registeredLayers']}');
    print('Layer IDs: ${stats['layerIds']}');
    print('Has selected feature: ${stats['hasSelectedFeature']}');
    if (stats['hasSelectedFeature']) {
      print('Selected feature type: ${stats['selectedFeatureType']}');
      print('Selected source layer: ${stats['selectedSourceLayer']}');
      if (_selectedFeature != null) {
        print('Station ID: ${_selectedFeature!.properties['station_id']}');
        print('Stream Order: ${_selectedFeature!.properties['streamOrde']}');
      }
    }
    print('streams2 optimized: ${stats['streams2Optimized']}');
    print('Supported properties: ${stats['supportedProperties']}');
  }

  /// Dispose resources
  void dispose() {
    mapboxMap = null;
    onFeatureSelected = null;
    onEmptyTap = null;
    _selectedFeature = null;
    _layerInfo.clear();
    print('🗑️ Vector feature selection service disposed');
  }
}

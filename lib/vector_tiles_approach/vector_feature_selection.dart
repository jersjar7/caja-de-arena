// lib/vector_tiles_approach/vector_feature_selection.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;

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

  /// Get a human-readable title for the feature
  String get title {
    // Try common title fields for vector tiles
    final titleFields = [
      'name',
      'name_en',
      'name:en',
      'class',
      'type',
      'subclass',
      'ref',
      'id',
    ];

    for (final field in titleFields) {
      if (properties.containsKey(field) && properties[field] != null) {
        final value = properties[field].toString();
        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    // Fallback to layer identification
    if (sourceLayer.isNotEmpty) {
      return '${sourceLayer.toUpperCase()} Feature';
    }

    return 'Vector Feature';
  }

  /// Get feature type description
  String get typeDescription {
    final geometryType = geometry['type'] as String?;
    final featureClass = properties['class'] as String?;
    final featureType = properties['type'] as String?;

    if (featureClass != null && featureType != null) {
      return '$featureClass ($featureType)';
    } else if (featureClass != null) {
      return featureClass;
    } else if (featureType != null) {
      return featureType;
    } else if (geometryType != null) {
      return geometryType;
    }

    return 'Unknown';
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
    print('✅ Vector feature selection service ready');
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

  /// Query vector tile features at a specific point
  Future<List<SelectedVectorFeature>> _queryVectorFeaturesAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (mapboxMap == null) return [];

    final selectedFeatures = <SelectedVectorFeature>[];

    // Create a query area around the tap point
    final queryBox = RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(x: touchPosition.x - 5, y: touchPosition.y - 5),
        max: ScreenCoordinate(x: touchPosition.x + 5, y: touchPosition.y + 5),
      ),
    );

    // Get all registered layer IDs for querying
    final layerIds = _layerInfo.keys.toList();

    if (layerIds.isEmpty) {
      print('⚠️ No vector layers registered for selection');
      return [];
    }

    try {
      // Query all registered vector layers
      final List<QueriedRenderedFeature?> queryResult = await mapboxMap!
          .queryRenderedFeatures(
            queryBox,
            RenderedQueryOptions(layerIds: layerIds),
          );

      print('📊 Found ${queryResult.length} vector features in query');

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
            print('⚠️ Error processing vector feature: $e');
          }
        }
      }

      print('📊 Processed ${selectedFeatures.length} valid vector features');

      // Return topmost feature (vector tiles are already ordered by rendering priority)
      if (selectedFeatures.isNotEmpty) {
        return [selectedFeatures.first];
      }
    } catch (e) {
      print('⚠️ Error querying vector features: $e');
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
      final layerId = queriedRenderedFeature.queriedFeature.layerId;
      final sourceId = queriedRenderedFeature.queriedFeature.source;

      print(
        '🔍 Processing vector feature from layer: $layerId, source: $sourceId',
      );

      // Safe type casting for vector tile properties
      final properties = feature['properties'] != null
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};
      final geometry = feature['geometry'] != null
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : <String, dynamic>{};

      // Extract source layer from the feature or layer metadata
      String sourceLayer = '';
      if (_layerInfo.containsKey(layerId)) {
        sourceLayer = _layerInfo[layerId]!['sourceLayer'] as String? ?? '';
      }

      // Try to get source layer from properties if not found
      if (sourceLayer.isEmpty) {
        sourceLayer =
            properties['layer'] as String? ??
            properties['source-layer'] as String? ??
            layerId;
      }

      final featureId =
          feature['id']?.toString() ??
          properties['id']?.toString() ??
          properties['osm_id']?.toString() ??
          'unknown_${DateTime.now().millisecondsSinceEpoch}';

      return SelectedVectorFeature(
        layerId: layerId,
        sourceLayer: sourceLayer,
        featureId: featureId,
        properties: properties,
        geometry: geometry,
        tapLocation: tapLocation,
        sourceId: sourceId,
      );
    } catch (e) {
      print('❌ Error processing vector feature: $e');
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
    };
  }

  /// Print selection statistics
  void printSelectionStats() {
    final stats = getSelectionStats();
    print('\n📊 VECTOR FEATURE SELECTION STATS:');
    print('Registered layers: ${stats['registeredLayers']}');
    print('Layer IDs: ${stats['layerIds']}');
    print('Has selected feature: ${stats['hasSelectedFeature']}');
    if (stats['hasSelectedFeature']) {
      print('Selected feature type: ${stats['selectedFeatureType']}');
      print('Selected source layer: ${stats['selectedSourceLayer']}');
    }
  }

  /// Dispose resources
  void dispose() {
    mapboxMap = null;
    onFeatureSelected = null;
    onEmptyTap = null;
    _selectedFeature = null;
    _layerInfo.clear();
  }
}

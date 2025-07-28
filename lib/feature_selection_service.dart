// lib/feature_selection_service.dart (CORRECTED VERSION)
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';

/// Represents a selected map feature with its properties
class SelectedFeature {
  final String layerId;
  final String layerName;
  final String featureId;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> geometry;
  final Point tapLocation;

  const SelectedFeature({
    required this.layerId,
    required this.layerName,
    required this.featureId,
    required this.properties,
    required this.geometry,
    required this.tapLocation,
  });

  /// Get a human-readable title for the feature
  String get title {
    // Try common title fields
    final titleFields = ['name', 'title', 'station_name', 'site_name', 'id'];
    for (final field in titleFields) {
      if (properties.containsKey(field) && properties[field] != null) {
        return properties[field].toString();
      }
    }
    return 'Feature from $layerName';
  }

  /// Get coordinates as a readable string
  String get coordinatesString {
    try {
      if (geometry['type'] == 'Point') {
        final coords = geometry['coordinates'] as List;
        final lng = (coords[0] as num).toStringAsFixed(6);
        final lat = (coords[1] as num).toStringAsFixed(6);
        return 'Lat: $lat, Lng: $lng';
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
    return 'SelectedFeature(layerId: $layerId, title: $title, properties: ${properties.length})';
  }
}

/// Service for handling feature selection and interaction
class FeatureSelectionService {
  MapboxMap? mapboxMap;

  // Callback for when a feature is selected
  Function(SelectedFeature)? onFeatureSelected;

  // Callback for when no feature is found at tap location
  Function(Point)? onEmptyTap;

  // Currently selected feature
  SelectedFeature? _selectedFeature;

  // Available layers for querying
  final Map<String, Map<String, dynamic>> _layerInfo = {};

  /// Set the MapboxMap instance and setup tap listener
  void setMapboxMap(MapboxMap map) {
    mapboxMap = map;
    // Note: We will handle taps via MapWidget.onTapListener instead of here
    print('✅ Feature selection service ready');
  }

  /// Register layer information for selection
  void registerLayer(String layerId, Map<String, dynamic> layerInfo) {
    _layerInfo[layerId] = layerInfo;
  }

  /// Handle map tap (called from MapWidget.onTapListener)
  Future<void> handleMapTap(MapContentGestureContext context) async {
    if (mapboxMap == null) return;

    try {
      final tapPoint = context.point;
      final touchPosition = context.touchPosition;

      print(
        '🎯 Map tapped at: ${tapPoint.coordinates.lng}, ${tapPoint.coordinates.lat}',
      );

      // Query rendered features at the tap point
      final features = await _queryFeaturesAtPoint(tapPoint, touchPosition);

      if (features.isNotEmpty) {
        final feature = features.first;
        print('✅ Feature selected: ${feature.title}');

        _selectedFeature = feature;
        onFeatureSelected?.call(feature);
      } else {
        print('ℹ️ No features found at tap location');
        onEmptyTap?.call(tapPoint);
      }
    } catch (e) {
      print('❌ Error handling map tap: $e');
    }
  }

  /// Query features at a specific point using the correct API
  Future<List<SelectedFeature>> _queryFeaturesAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (mapboxMap == null) return [];

    final selectedFeatures = <SelectedFeature>[];

    // Create a small rectangular area around the tap point for querying
    final queryBox = RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(
          x: touchPosition.x - 10, // 10 pixel radius
          y: touchPosition.y - 10,
        ),
        max: ScreenCoordinate(x: touchPosition.x + 10, y: touchPosition.y + 10),
      ),
    );

    // Query each of our WFS layers
    for (final layerId in _layerInfo.keys) {
      final layerInfo = _layerInfo[layerId]!;
      final layerType = layerInfo['type'] as String;

      // Determine which layer names to query based on type
      List<String> layerNamesToQuery = [];
      if (layerType == 'point') {
        layerNamesToQuery = ["${layerId}_clusters", "${layerId}_unclustered"];
      } else if (layerType == 'line') {
        layerNamesToQuery = ["${layerId}_lines"];
      }

      for (final layerName in layerNamesToQuery) {
        try {
          // CORRECT API USAGE: queryRenderedFeatures returns List<QueriedRenderedFeature?>
          final List<QueriedRenderedFeature?> queryResult = await mapboxMap!
              .queryRenderedFeatures(
                queryBox,
                RenderedQueryOptions(layerIds: [layerName]),
              );

          // Process each found feature (handling nullable QueriedRenderedFeature?)
          for (final queriedRenderedFeature in queryResult) {
            if (queriedRenderedFeature != null) {
              // Handle nullable type
              try {
                final selectedFeature = _processQueriedFeature(
                  queriedRenderedFeature, // Now non-null
                  layerId,
                  layerInfo['name'] as String,
                  tapPoint,
                );
                if (selectedFeature != null) {
                  selectedFeatures.add(selectedFeature);
                }
              } catch (e) {
                print('⚠️ Error processing feature: $e');
              }
            }
          }
        } catch (e) {
          print('⚠️ Error querying layer $layerName: $e');
          // Continue with other layers
        }
      }
    }

    print('📊 Found ${selectedFeatures.length} selectable features');
    return selectedFeatures;
  }

  /// Process a queried feature into a SelectedFeature
  SelectedFeature? _processQueriedFeature(
    QueriedRenderedFeature queriedRenderedFeature, // Non-null now
    String layerId,
    String layerName,
    Point tapLocation,
  ) {
    try {
      // CORRECT API USAGE: Access through queriedFeature.feature
      final feature = queriedRenderedFeature.queriedFeature.feature;
      final featureJson = jsonEncode(feature);

      print('🔍 Processing feature: ${featureJson.substring(0, 200)}...');

      // Parse the feature JSON
      final featureData = feature;

      final properties =
          featureData['properties'] as Map<String, dynamic>? ?? {};
      final geometry = featureData['geometry'] as Map<String, dynamic>? ?? {};
      final featureId =
          featureData['id']?.toString() ??
          properties['id']?.toString() ??
          'unknown_${DateTime.now().millisecondsSinceEpoch}';

      return SelectedFeature(
        layerId: layerId,
        layerName: layerName,
        featureId: featureId,
        properties: properties,
        geometry: geometry,
        tapLocation: tapLocation,
      );
    } catch (e) {
      print('❌ Error processing queried feature: $e');
      return null;
    }
  }

  /// Get the currently selected feature
  SelectedFeature? get selectedFeature => _selectedFeature;

  /// Clear the current selection
  void clearSelection() {
    _selectedFeature = null;
  }

  /// Export feature data as JSON string
  String exportFeatureAsJson(SelectedFeature feature) {
    final exportData = {
      'layerId': feature.layerId,
      'layerName': feature.layerName,
      'featureId': feature.featureId,
      'coordinates': feature.coordinatesString,
      'properties': feature.properties,
      'geometry': feature.geometry,
      'selectedAt': DateTime.now().toIso8601String(),
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

  /// Dispose resources
  void dispose() {
    mapboxMap = null;
    onFeatureSelected = null;
    onEmptyTap = null;
    _selectedFeature = null;
    _layerInfo.clear();
  }
}

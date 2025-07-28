// lib/feature_selection_service.dart (UPDATED VERSION - Closest Feature Only)
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;

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
        final feature = features.first; // Will be the closest feature
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

  /// Query features at a specific point and return only the closest one
  Future<List<SelectedFeature>> _queryFeaturesAtPoint(
    Point tapPoint,
    ScreenCoordinate touchPosition,
  ) async {
    if (mapboxMap == null) return [];

    final selectedFeatures = <SelectedFeature>[];

    // Create a smaller rectangular area around the tap point for querying
    final queryBox = RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(
          x: touchPosition.x - 5, // Reduced from 10 to 5 pixel radius
          y: touchPosition.y - 5,
        ),
        max: ScreenCoordinate(x: touchPosition.x + 5, y: touchPosition.y + 5),
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

    print('📊 Found ${selectedFeatures.length} total features');

    // NEW: Find only the closest feature
    if (selectedFeatures.isNotEmpty) {
      final closestFeature = _findClosestFeature(selectedFeatures, tapPoint);
      if (closestFeature != null) {
        print('🎯 Selected closest feature: ${closestFeature.title}');
        return [closestFeature];
      }
    }

    return [];
  }

  /// NEW: Find the closest feature to the tap location
  SelectedFeature? _findClosestFeature(
    List<SelectedFeature> features,
    Point tapLocation,
  ) {
    if (features.isEmpty) return null;

    SelectedFeature? closest;
    double minDistance = double.infinity;

    for (final feature in features) {
      try {
        final geometry = feature.geometry;
        final coordinates = geometry['coordinates'];

        double distance;
        if (geometry['type'] == 'Point') {
          final coords = coordinates as List;
          final featureLng = (coords[0] as num).toDouble();
          final featureLat = (coords[1] as num).toDouble();
          distance = _calculateDistance(
            tapLocation.coordinates.lat.toDouble(),
            tapLocation.coordinates.lng.toDouble(),
            featureLat,
            featureLng,
          );
        } else if (geometry['type'] == 'LineString') {
          // For lines, find closest point on the line
          distance = _distanceToLineString(tapLocation, coordinates as List);
        } else {
          continue; // Skip other geometry types
        }

        if (distance < minDistance) {
          minDistance = distance;
          closest = feature;
        }
      } catch (e) {
        print('⚠️ Error calculating distance for feature: $e');
        continue;
      }
    }

    print('📏 Closest feature distance: ${minDistance.toStringAsFixed(2)}m');
    return closest;
  }

  /// NEW: Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// NEW: Calculate distance to a line string
  double _distanceToLineString(Point tapLocation, List coordinates) {
    double minDistance = double.infinity;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final p1 = coordinates[i] as List;
      final p2 = coordinates[i + 1] as List;

      final distance = _distanceToLineSegment(
        tapLocation.coordinates.lat.toDouble(),
        tapLocation.coordinates.lng.toDouble(),
        (p1[1] as num).toDouble(),
        (p1[0] as num).toDouble(),
        (p2[1] as num).toDouble(),
        (p2[0] as num).toDouble(),
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// NEW: Calculate distance from point to line segment
  double _distanceToLineSegment(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx != 0 || dy != 0) {
      final t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);

      if (t > 1) {
        return _calculateDistance(px, py, x2, y2);
      } else if (t > 0) {
        return _calculateDistance(px, py, x1 + dx * t, y1 + dy * t);
      }
    }

    return _calculateDistance(px, py, x1, y1);
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

      print(
        '🔍 Processing feature: ${featureJson.substring(0, math.min(200, featureJson.length))}...',
      );

      // Parse the feature JSON
      final featureData = feature;

      // FIXED: Safe type casting to prevent the _Map<Object?, Object?> error
      final properties = featureData['properties'] != null
          ? Map<String, dynamic>.from(featureData['properties'] as Map)
          : <String, dynamic>{};
      final geometry = featureData['geometry'] != null
          ? Map<String, dynamic>.from(featureData['geometry'] as Map)
          : <String, dynamic>{};

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

// lib/spatial_utils.dart
import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Utility class for spatial calculations and viewport management
class SpatialUtils {
  /// Earth's radius in meters (WGS84)
  static const double earthRadiusMeters = 6378137.0;

  /// Degrees to radians conversion factor
  static const double degreesToRadians = math.pi / 180.0;

  /// Radians to degrees conversion factor
  static const double radiansToDegrees = 180.0 / math.pi;

  /// Calculate bounding box from map viewport with optional padding
  static Future<CoordinateBounds> getBoundingBoxFromCamera(
    MapboxMap mapboxMap, {
    double paddingPercent = 0.1, // 10% padding by default
  }) async {
    try {
      // Get current camera state and calculate bounds from it
      final cameraState = await mapboxMap.getCameraState();
      final bounds = await mapboxMap.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          pitch: cameraState.pitch,
          bearing: cameraState.bearing,
        ),
      );

      // Calculate padding in degrees
      final latRange =
          bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat;
      final lngRange =
          bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng;

      final latPadding = latRange * paddingPercent;
      final lngPadding = lngRange * paddingPercent;

      return CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            bounds.southwest.coordinates.lng - lngPadding,
            bounds.southwest.coordinates.lat - latPadding,
          ),
        ),
        northeast: Point(
          coordinates: Position(
            bounds.northeast.coordinates.lng + lngPadding,
            bounds.northeast.coordinates.lat + latPadding,
          ),
        ),
        infiniteBounds: false,
      );
    } catch (e) {
      // Fallback to continental US if bounds calculation fails
      return CoordinateBoundsExtensions.continentalUS();
    }
  }

  /// Calculate distance between two geographic points in meters using Haversine formula
  static double calculateDistance(Position point1, Position point2) {
    final lat1Rad = point1.lat * degreesToRadians;
    final lat2Rad = point2.lat * degreesToRadians;
    final deltaLatRad = (point2.lat - point1.lat) * degreesToRadians;
    final deltaLngRad = (point2.lng - point1.lng) * degreesToRadians;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calculate the area of a bounding box in square kilometers
  static double calculateBoundingBoxArea(CoordinateBounds bbox) {
    final southwest = bbox.southwest.coordinates;
    final northeast = bbox.northeast.coordinates;

    // Calculate width and height in meters
    final width = calculateDistance(
      Position(southwest.lng, southwest.lat),
      Position(northeast.lng, southwest.lat),
    );

    final height = calculateDistance(
      Position(southwest.lng, southwest.lat),
      Position(southwest.lng, northeast.lat),
    );

    // Convert to square kilometers
    return (width * height) / 1000000;
  }

  /// Determine appropriate maximum features based on zoom level and viewport
  static int getMaxFeaturesForZoom(double zoom, CoordinateBounds bbox) {
    final area = calculateBoundingBoxArea(bbox);

    if (zoom >= 15) {
      // Very close zoom - show all details
      return (50000 * math.min(area / 100, 1.0)).round();
    } else if (zoom >= 12) {
      // City level - moderate detail
      return (20000 * math.min(area / 500, 1.0)).round();
    } else if (zoom >= 9) {
      // Regional level - reduced detail
      return (10000 * math.min(area / 1000, 1.0)).round();
    } else if (zoom >= 6) {
      // State level - major features only
      return (5000 * math.min(area / 5000, 1.0)).round();
    } else {
      // Country level - very limited features
      return math.min(1000, (1000 * area / 10000).round());
    }
  }

  /// Get appropriate layer suffix based on zoom level for progressive loading
  static String getLayerSuffixForZoom(double zoom) {
    if (zoom >= 12) {
      return '_detailed'; // All features
    } else if (zoom >= 8) {
      return '_medium'; // Medium-importance features
    } else {
      return '_major'; // Major features only
    }
  }

  /// Check if two bounding boxes overlap significantly
  static bool doBoxesOverlapSignificantly(
    CoordinateBounds box1,
    CoordinateBounds box2, {
    double overlapThreshold = 0.7,
  }) {
    // Calculate intersection
    final intersectionSW = Position(
      math.max(box1.southwest.coordinates.lng, box2.southwest.coordinates.lng),
      math.max(box1.southwest.coordinates.lat, box2.southwest.coordinates.lat),
    );

    final intersectionNE = Position(
      math.min(box1.northeast.coordinates.lng, box2.northeast.coordinates.lng),
      math.min(box1.northeast.coordinates.lat, box2.northeast.coordinates.lat),
    );

    // Check if there's a valid intersection
    if (intersectionSW.lng >= intersectionNE.lng ||
        intersectionSW.lat >= intersectionNE.lat) {
      return false;
    }

    final intersection = CoordinateBounds(
      southwest: Point(coordinates: intersectionSW),
      northeast: Point(coordinates: intersectionNE),
      infiniteBounds: false,
    );

    final intersectionArea = calculateBoundingBoxArea(intersection);
    final box1Area = calculateBoundingBoxArea(box1);

    return (intersectionArea / box1Area) >= overlapThreshold;
  }

  /// Expand bounding box by a percentage
  static CoordinateBounds expandBoundingBox(
    CoordinateBounds bbox,
    double expansionPercent,
  ) {
    final latRange =
        bbox.northeast.coordinates.lat - bbox.southwest.coordinates.lat;
    final lngRange =
        bbox.northeast.coordinates.lng - bbox.southwest.coordinates.lng;

    final latExpansion = latRange * expansionPercent;
    final lngExpansion = lngRange * expansionPercent;

    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(
          bbox.southwest.coordinates.lng - lngExpansion,
          bbox.southwest.coordinates.lat - latExpansion,
        ),
      ),
      northeast: Point(
        coordinates: Position(
          bbox.northeast.coordinates.lng + lngExpansion,
          bbox.northeast.coordinates.lat + latExpansion,
        ),
      ),
      infiniteBounds: false,
    );
  }

  /// Convert bounding box to WFS BBOX parameter string
  static String bboxToWFSString(CoordinateBounds bbox) {
    return '${bbox.southwest.coordinates.lng},${bbox.southwest.coordinates.lat},${bbox.northeast.coordinates.lng},${bbox.northeast.coordinates.lat}';
  }

  /// Calculate appropriate grid cell size for spatial indexing
  static double getGridCellSize(double zoom) {
    if (zoom >= 15) return 0.001; // ~100m cells
    if (zoom >= 12) return 0.005; // ~500m cells
    if (zoom >= 9) return 0.01; // ~1km cells
    if (zoom >= 6) return 0.05; // ~5km cells
    return 0.1; // ~10km cells
  }

  /// Check if a coordinate is within a bounding box
  static bool isPointInBounds(Position point, CoordinateBounds bbox) {
    return point.lng >= bbox.southwest.coordinates.lng &&
        point.lng <= bbox.northeast.coordinates.lng &&
        point.lat >= bbox.southwest.coordinates.lat &&
        point.lat <= bbox.northeast.coordinates.lat;
  }

  /// Calculate the center point of a bounding box
  static Position getBoundingBoxCenter(CoordinateBounds bbox) {
    return Position(
      (bbox.southwest.coordinates.lng + bbox.northeast.coordinates.lng) / 2,
      (bbox.southwest.coordinates.lat + bbox.northeast.coordinates.lat) / 2,
    );
  }

  /// Determine if zoom level change is significant enough to trigger reload
  static bool isZoomChangeSignificant(double oldZoom, double newZoom) {
    // Trigger reload if crossing major zoom thresholds
    const zoomThresholds = [6, 9, 12, 15];

    for (final threshold in zoomThresholds) {
      if ((oldZoom < threshold && newZoom >= threshold) ||
          (oldZoom >= threshold && newZoom < threshold)) {
        return true;
      }
    }

    // Also trigger if zoom change is very large (>2 levels)
    return (newZoom - oldZoom).abs() > 2.0;
  }

  /// Calculate viewport diagonal distance in meters
  static double getViewportDiagonalDistance(CoordinateBounds bbox) {
    return calculateDistance(
      bbox.southwest.coordinates,
      bbox.northeast.coordinates,
    );
  }

  /// Get human-readable scale description for current zoom
  static String getScaleDescription(double zoom) {
    if (zoom >= 15) return 'Street Level';
    if (zoom >= 12) return 'Neighborhood';
    if (zoom >= 9) return 'City Level';
    if (zoom >= 6) return 'Regional';
    return 'State/Country';
  }

  /// Calculate appropriate cache key for spatial data
  static String generateSpatialCacheKey({
    required String layerId,
    required CoordinateBounds bbox,
    required double zoom,
    int? maxFeatures,
  }) {
    // Round coordinates to appropriate precision to improve cache hits
    final precision = zoom >= 12 ? 4 : (zoom >= 9 ? 3 : 2);

    final swLng = double.parse(
      bbox.southwest.coordinates.lng.toStringAsFixed(precision),
    );
    final swLat = double.parse(
      bbox.southwest.coordinates.lat.toStringAsFixed(precision),
    );
    final neLng = double.parse(
      bbox.northeast.coordinates.lng.toStringAsFixed(precision),
    );
    final neLat = double.parse(
      bbox.northeast.coordinates.lat.toStringAsFixed(precision),
    );

    final zoomLevel = (zoom / 2).round() * 2; // Round to nearest 2 zoom levels

    return '${layerId}_${swLng}_${swLat}_${neLng}_${neLat}_z${zoomLevel}_f${maxFeatures ?? 'all'}';
  }
}

/// Extended CoordinateBounds class with additional functionality
class CoordinateBoundsExtensions {
  /// Create a bounding box covering the continental United States
  static CoordinateBounds continentalUS() {
    return CoordinateBounds(
      southwest: Point(coordinates: Position(-125.0, 25.0)), // Southwest corner
      northeast: Point(coordinates: Position(-66.0, 49.0)), // Northeast corner
      infiniteBounds: false,
    );
  }

  /// Create a bounding box covering a specific region
  static CoordinateBounds forRegion(String region) {
    switch (region.toLowerCase()) {
      case 'california':
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-124.5, 32.5)),
          northeast: Point(coordinates: Position(-114.0, 42.0)),
          infiniteBounds: false,
        );
      case 'texas':
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-106.5, 25.8)),
          northeast: Point(coordinates: Position(-93.5, 36.5)),
          infiniteBounds: false,
        );
      case 'florida':
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-87.6, 24.5)),
          northeast: Point(coordinates: Position(-80.0, 31.0)),
          infiniteBounds: false,
        );
      case 'newyork':
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-79.8, 40.5)),
          northeast: Point(coordinates: Position(-71.8, 45.0)),
          infiniteBounds: false,
        );
      default:
        return continentalUS();
    }
  }

  /// Convert to a more compact string representation
  static String toCompactString(CoordinateBounds bbox) {
    return '${bbox.southwest.coordinates.lng.toStringAsFixed(3)},${bbox.southwest.coordinates.lat.toStringAsFixed(3)},'
        '${bbox.northeast.coordinates.lng.toStringAsFixed(3)},${bbox.northeast.coordinates.lat.toStringAsFixed(3)}';
  }

  /// Check if this bounding box is valid
  static bool isValid(CoordinateBounds bbox) {
    return bbox.southwest.coordinates.lng < bbox.northeast.coordinates.lng &&
        bbox.southwest.coordinates.lat < bbox.northeast.coordinates.lat;
  }

  /// Get the width of the bounding box in degrees
  static double getWidthDegrees(CoordinateBounds bbox) =>
      bbox.northeast.coordinates.lng.toDouble() -
      bbox.southwest.coordinates.lng.toDouble();

  /// Get the height of the bounding box in degrees
  static double getHeightDegrees(CoordinateBounds bbox) =>
      bbox.northeast.coordinates.lat.toDouble() -
      bbox.southwest.coordinates.lat.toDouble();
}

/// Viewport change detector for efficient map update triggering
class ViewportChangeDetector {
  CoordinateBounds? _lastBounds;
  double? _lastZoom;
  DateTime? _lastUpdate;

  /// Minimum time between updates to prevent excessive triggering
  static const Duration _minUpdateInterval = Duration(milliseconds: 500);

  /// Check if viewport has changed significantly
  bool hasSignificantChange({
    required CoordinateBounds currentBounds,
    required double currentZoom,
    double moveThreshold = 0.3, // 30% viewport movement
    double zoomThreshold = 1.0, // 1 zoom level change
  }) {
    final now = DateTime.now();

    // Throttle updates
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < _minUpdateInterval) {
      return false;
    }

    // First time - always significant
    if (_lastBounds == null || _lastZoom == null) {
      _updateLast(currentBounds, currentZoom, now);
      return true;
    }

    // Check zoom change
    if ((currentZoom - _lastZoom!).abs() >= zoomThreshold) {
      _updateLast(currentBounds, currentZoom, now);
      return true;
    }

    // Check if viewport moved significantly
    final viewportDistance = SpatialUtils.getViewportDiagonalDistance(
      _lastBounds!,
    );
    final centerDistance = SpatialUtils.calculateDistance(
      SpatialUtils.getBoundingBoxCenter(_lastBounds!),
      SpatialUtils.getBoundingBoxCenter(currentBounds),
    );

    if (centerDistance > (viewportDistance * moveThreshold)) {
      _updateLast(currentBounds, currentZoom, now);
      return true;
    }

    return false;
  }

  void _updateLast(CoordinateBounds bounds, double zoom, DateTime time) {
    _lastBounds = bounds;
    _lastZoom = zoom;
    _lastUpdate = time;
  }

  /// Reset the detector (useful when changing layers)
  void reset() {
    _lastBounds = null;
    _lastZoom = null;
    _lastUpdate = null;
  }

  /// Get information about the last viewport state
  Map<String, dynamic> getLastState() {
    return {
      'lastBounds': _lastBounds != null
          ? CoordinateBoundsExtensions.toCompactString(_lastBounds!)
          : null,
      'lastZoom': _lastZoom,
      'lastUpdate': _lastUpdate?.toIso8601String(),
    };
  }
}

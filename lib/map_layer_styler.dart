// lib/map_layer_styler.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapLayerStyler {
  MapboxMap? mapboxMap;

  void setMapboxMap(MapboxMap map) {
    mapboxMap = map;
  }

  /// Add styled layer based on layer type and configuration
  Future<void> addStyledLayer(
    String layerId,
    Map<String, dynamic> layerInfo,
  ) async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    final layerType = layerInfo['type'] as String;
    final colorInt = layerInfo['color'] as int;

    print('🎨 Adding styled layer for $layerId (type: $layerType)');

    if (layerType == 'point') {
      await _addPointLayers(layerId, colorInt);
    } else if (layerType == 'line') {
      await _addLineLayers(layerId, colorInt);
    } else {
      throw Exception('Unsupported layer type: $layerType');
    }
  }

  /// Add point layers with clustering
  Future<void> _addPointLayers(String layerId, int colorInt) async {
    try {
      // 1. Cluster circles
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_clusters",
          sourceId: "${layerId}_source",
          circleRadius: 20.0,
          circleColor: 0xFFFF0000, // Bright red for visibility
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.0,
          filter: ["has", "point_count"],
        ),
      );

      // 2. Cluster count text
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: "${layerId}_count",
          sourceId: "${layerId}_source",
          textField: "{point_count_abbreviated}",
          textSize: 14.0,
          textColor: 0xFFFFFFFF,
          textHaloColor: 0xFF000000,
          textHaloWidth: 1.0,
          filter: ["has", "point_count"],
        ),
      );

      // 3. Unclustered points
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "${layerId}_unclustered",
          sourceId: "${layerId}_source",
          circleRadius: 8.0,
          circleColor: 0xFFFF0000, // Bright red for visibility
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.0,
          filter: [
            "!",
            ["has", "point_count"],
          ],
        ),
      );

      print('✅ Added point layers for $layerId');
    } catch (e) {
      print('❌ Failed to add point layers: $e');
      rethrow;
    }
  }

  /// Add line layers
  Future<void> _addLineLayers(String layerId, int colorInt) async {
    try {
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: "${layerId}_lines",
          sourceId: "${layerId}_source",
          lineColor: 0xFF0000FF, // Bright blue for visibility
          lineWidth: 3.0,
          lineOpacity: 0.8,
        ),
      );

      print('✅ Added line layer for $layerId');
    } catch (e) {
      print('❌ Failed to add line layer: $e');
      rethrow;
    }
  }

  /// Add test layer for debugging
  Future<void> addTestLayer() async {
    if (mapboxMap == null) throw Exception('MapboxMap not set');

    const testGeoJson = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [-98.5795, 39.8283]
          },
          "properties": {
            "name": "Center of US"
          }
        }
      ]
    }
    ''';

    try {
      // Remove existing test layer
      try {
        await mapboxMap!.style.removeStyleLayer('test_points');
        await mapboxMap!.style.removeStyleSource('test_source');
      } catch (e) {
        // Ignore if they don't exist
      }

      // Add test source
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: 'test_source', data: testGeoJson),
      );

      // Add test layer
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'test_points',
          sourceId: 'test_source',
          circleRadius: 30.0,
          circleColor: 0xFFFF0000,
          circleStrokeColor: 0xFFFFFF00,
          circleStrokeWidth: 5.0,
        ),
      );

      // Move camera to test point
      await mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(-98.5795, 39.8283)),
          zoom: 4.0,
        ),
      );

      print('✅ Test layer added');
    } catch (e) {
      print('❌ Failed to add test layer: $e');
      rethrow;
    }
  }

  /// Update layer color (for dynamic styling)
  Future<void> updateLayerColor(
    String layerId,
    String layerType,
    int newColor,
  ) async {
    if (mapboxMap == null) return;

    try {
      if (layerType == 'point') {
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_clusters",
          'circle-color',
          newColor,
        );
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_unclustered",
          'circle-color',
          newColor,
        );
      } else if (layerType == 'line') {
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_lines",
          'line-color',
          newColor,
        );
      }
      print('✅ Updated color for $layerId');
    } catch (e) {
      print('❌ Failed to update layer color: $e');
    }
  }

  /// Set layer visibility
  Future<void> setLayerVisibility(
    String layerId,
    String layerType,
    bool visible,
  ) async {
    if (mapboxMap == null) return;

    final visibility = visible ? 'visible' : 'none';

    try {
      if (layerType == 'point') {
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_clusters",
          'visibility',
          visibility,
        );
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_count",
          'visibility',
          visibility,
        );
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_unclustered",
          'visibility',
          visibility,
        );
      } else if (layerType == 'line') {
        await mapboxMap!.style.setStyleLayerProperty(
          "${layerId}_lines",
          'visibility',
          visibility,
        );
      }
      print('✅ Set visibility for $layerId: $visible');
    } catch (e) {
      print('❌ Failed to set layer visibility: $e');
    }
  }
}

// lib/vector_tiles_approach/vector_feature_details_widget.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'vector_feature_selection.dart';

/// Widget to display vector tile feature details in a bottom sheet
class VectorFeatureDetailsWidget extends StatefulWidget {
  final SelectedVectorFeature feature;
  final VoidCallback? onClose;
  final Function(String, dynamic)? onPropertySelected;

  const VectorFeatureDetailsWidget({
    super.key,
    required this.feature,
    this.onClose,
    this.onPropertySelected,
  });

  @override
  State<VectorFeatureDetailsWidget> createState() =>
      _VectorFeatureDetailsWidgetState();
}

class _VectorFeatureDetailsWidgetState
    extends State<VectorFeatureDetailsWidget> {
  bool _showRawData = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          _buildHeader(),

          // Content
          Flexible(
            child: _showRawData ? _buildRawDataView() : _buildPropertiesView(),
          ),

          // Bottom actions
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final streamOrder =
        widget.feature.properties['streamOrde']; // ✅ Correct field name
    final stationId =
        widget.feature.properties['station_id'] ??
        widget.feature.properties['STATIONID']; // ✅ Check both field names

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Feature icon based on stream order
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStreamOrderColor(streamOrder).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFeatureIcon(),
              color: _getStreamOrderColor(streamOrder),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Feature info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.feature.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'STREAMS2 VECTOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (streamOrder != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStreamOrderColor(
                            streamOrder,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ORDER $streamOrder',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getStreamOrderColor(streamOrder),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.feature.typeDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.feature.coordinatesString,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
                if (stationId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Station ID: $stationId',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.tertiaryLabel,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Close button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: widget.onClose,
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemGrey3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesView() {
    final properties = widget.feature.formattedProperties;

    if (properties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.drop_fill,
              size: 48,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'No additional properties for this stream feature',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'From tileset: jersondevs.dopm8y3j',
              style: const TextStyle(
                color: CupertinoColors.tertiaryLabel,
                fontSize: 14,
                fontFamily: 'Courier',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: properties.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final property = properties[index];
        return _buildPropertyTile(property.key, property.value);
      },
    );
  }

  Widget _buildPropertyTile(String key, String value) {
    final isImportantProperty =
        key.toLowerCase().contains('station') ||
        key.toLowerCase().contains('stream') ||
        key.toLowerCase().contains('order');

    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(vertical: 8),
      title: Row(
        children: [
          if (isImportantProperty)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              key,
              style: TextStyle(
                fontWeight: isImportantProperty
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        value,
        style: const TextStyle(color: CupertinoColors.secondaryLabel),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _copyToClipboard(value),
            child: const Icon(
              CupertinoIcons.doc_on_doc,
              size: 20,
              color: CupertinoColors.systemPurple,
            ),
          ),

          // Use button (if callback provided)
          if (widget.onPropertySelected != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => widget.onPropertySelected!(key, value),
              child: const Icon(
                CupertinoIcons.square_arrow_up,
                size: 20,
                color: CupertinoColors.systemGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRawDataView() {
    final streamOrder = widget.feature.properties['streamOrde'];
    final stationId = widget.feature.properties['station_id'];

    final rawData = {
      'feature_id': widget.feature.featureId,
      'layer_id': widget.feature.layerId,
      'source_layer': widget.feature.sourceLayer,
      'source_id': widget.feature.sourceId,
      'title': widget.feature.title,
      'type': widget.feature.typeDescription,
      'coordinates': widget.feature.coordinatesString,
      'properties': widget.feature.properties,
      'geometry': widget.feature.geometry,
      'approach': 'vector_tiles',
      'tileset_info': {
        'id': 'jersondevs.dopm8y3j',
        'dataset': 'HydroShare streams2',
        'total_features': 364115,
      },
      'streams2_specific': {
        'station_id': stationId,
        'stream_order': streamOrder,
        'stream_description': streamOrder != null
            ? _getStreamOrderDescription(streamOrder)
            : 'Unknown',
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(rawData);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Raw streams2 Feature Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _copyToClipboard(jsonString),
                child: const Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 20,
                  color: CupertinoColors.systemPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'From tileset: jersondevs.dopm8y3j',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Courier',
                color: CupertinoColors.systemPurple,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  jsonString,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    color: CupertinoColors.label,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.systemGrey4, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Toggle raw data view
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () {
                setState(() {
                  _showRawData = !_showRawData;
                });
              },
              child: Text(
                _showRawData ? 'Show Properties' : 'Show Raw Data',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Export feature button
          Expanded(
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _exportFeature,
              child: const Text(
                'Export Stream',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for streams2-specific functionality

  IconData _getFeatureIcon() {
    // For streams2, always show water/stream icons based on stream order
    final streamOrder = widget.feature.properties['streamOrde'];

    if (streamOrder != null) {
      final order = streamOrder as int;
      if (order >= 5) {
        return CupertinoIcons.drop_fill; // Large rivers
      } else if (order >= 3) {
        return CupertinoIcons.drop; // Medium streams
      } else {
        return CupertinoIcons.minus; // Small streams
      }
    }

    // Default for streams2
    return CupertinoIcons.drop_fill;
  }

  Color _getStreamOrderColor(dynamic streamOrder) {
    if (streamOrder == null) return CupertinoColors.systemBlue;

    final order = streamOrder as int;
    if (order >= 5) {
      return CupertinoColors.systemIndigo; // Large rivers - dark blue
    } else if (order >= 3) {
      return CupertinoColors.systemBlue; // Medium streams - blue
    } else {
      return CupertinoColors.systemTeal; // Small streams - light blue
    }
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
        return 'Stream segment (Order $order)';
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));

    // Show success feedback
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Copied!'),
        content: const Text('Stream data copied to clipboard'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _exportFeature() {
    final streamOrder = widget.feature.properties['streamOrde'];
    final stationId = widget.feature.properties['station_id'];

    final exportData = {
      'feature_id': widget.feature.featureId,
      'layer_id': widget.feature.layerId,
      'source_layer': widget.feature.sourceLayer,
      'source_id': widget.feature.sourceId,
      'title': widget.feature.title,
      'type': widget.feature.typeDescription,
      'coordinates': widget.feature.coordinatesString,
      'properties': widget.feature.properties,
      'geometry': widget.feature.geometry,
      'exported_at': DateTime.now().toIso8601String(),
      'approach': 'vector_tiles',
      'tileset_id': 'jersondevs.dopm8y3j',
      'dataset_info': {
        'name': 'HydroShare streams2',
        'total_features': 364115,
        'source': 'HydroShare WFS converted to vector tiles',
        'uploaded_by': 'jersondevs',
      },
      'streams2_specific': {
        'station_id': stationId,
        'stream_order': streamOrder,
        'stream_description': streamOrder != null
            ? _getStreamOrderDescription(streamOrder)
            : 'Unknown',
        'visual_style': _getVisualStyleInfo(streamOrder),
      },
      'performance_benefits': [
        'Faster rendering than WFS',
        'Better zoom performance',
        'Reduced bandwidth usage',
        'Server-side optimization',
        'Handles 364K features smoothly',
        'Stream order-based styling',
      ],
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    _copyToClipboard(jsonString);
  }

  Map<String, dynamic> _getVisualStyleInfo(dynamic streamOrder) {
    if (streamOrder == null) return {'layer': 'unknown', 'style': 'default'};

    final order = streamOrder as int;
    if (order >= 5) {
      return {
        'layer': 'streams2-order-5-plus',
        'color': 'midnight_blue',
        'width': 3.5,
        'description': 'Major rivers - thick dark blue lines',
      };
    } else if (order >= 3) {
      return {
        'layer': 'streams2-order-3-4',
        'color': 'steel_blue',
        'width': 2.0,
        'description': 'Tributaries - medium blue lines',
      };
    } else {
      return {
        'layer': 'streams2-order-1-2',
        'color': 'light_blue',
        'width': 1.0,
        'description': 'Small streams - thin light blue lines',
      };
    }
  }
}

/// Show vector feature details in a modal bottom sheet
void showVectorFeatureDetails(
  BuildContext context,
  SelectedVectorFeature feature, {
  Function(String, dynamic)? onPropertySelected,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: VectorFeatureDetailsWidget(
        feature: feature,
        onClose: () => Navigator.pop(context),
        onPropertySelected: onPropertySelected,
      ),
    ),
  );
}

/// Compact vector feature info widget for embedding in other UIs
class CompactVectorFeatureInfo extends StatelessWidget {
  final SelectedVectorFeature feature;
  final VoidCallback? onTap;

  const CompactVectorFeatureInfo({
    super.key,
    required this.feature,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final streamOrder = feature.properties['streamOrde'];

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              _getStreamIcon(streamOrder),
              color: _getStreamColor(streamOrder),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          feature.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'VECTOR',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'streams2 • ${feature.typeDescription}',
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey3,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStreamIcon(dynamic streamOrder) {
    if (streamOrder == null) return CupertinoIcons.drop_fill;

    final order = streamOrder as int;
    if (order >= 5) return CupertinoIcons.drop_fill;
    if (order >= 3) return CupertinoIcons.drop;
    return CupertinoIcons.minus;
  }

  Color _getStreamColor(dynamic streamOrder) {
    if (streamOrder == null) return CupertinoColors.systemBlue;

    final order = streamOrder as int;
    if (order >= 5) return CupertinoColors.systemIndigo;
    if (order >= 3) return CupertinoColors.systemBlue;
    return CupertinoColors.systemTeal;
  }
}

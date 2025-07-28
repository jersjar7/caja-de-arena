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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Feature icon based on geometry type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFeatureIcon(),
              color: CupertinoColors.systemPurple,
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
                      child: Text(
                        'VECTOR TILES',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.feature.sourceLayer,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.feature.typeDescription,
                  style: const TextStyle(
                    fontSize: 12,
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
            const Icon(
              CupertinoIcons.cube_box,
              size: 48,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            const Text(
              'No properties available for this vector feature',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Source Layer: ${widget.feature.sourceLayer}',
              style: const TextStyle(
                color: CupertinoColors.tertiaryLabel,
                fontSize: 14,
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
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                'Raw Vector Feature Data',
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
                'Export Feature',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon() {
    final geometry = widget.feature.geometry['type'] as String?;
    final featureClass = widget.feature.properties['class'] as String?;

    // Vector tile specific icons based on common classes
    if (featureClass != null) {
      switch (featureClass.toLowerCase()) {
        case 'river':
        case 'stream':
        case 'canal':
          return CupertinoIcons.snow;
        case 'primary':
        case 'secondary':
        case 'trunk':
          return CupertinoIcons.car_detailed;
        case 'city':
        case 'town':
          return CupertinoIcons.building_2_fill;
        case 'country':
          return CupertinoIcons.globe;
        default:
          break;
      }
    }

    // Fallback to geometry type
    switch (geometry) {
      case 'Point':
        return CupertinoIcons.location_circle_fill;
      case 'LineString':
      case 'MultiLineString':
        return CupertinoIcons.minus_slash_plus;
      case 'Polygon':
      case 'MultiPolygon':
        return CupertinoIcons.square_fill;
      default:
        return CupertinoIcons.cube_box;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));

    // Show success feedback
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Copied!'),
        content: const Text('Value copied to clipboard'),
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
      'performance_benefits': [
        'Faster rendering',
        'Better zoom performance',
        'Reduced bandwidth usage',
        'Server-side optimization',
      ],
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    _copyToClipboard(jsonString);
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
              CupertinoIcons.cube_box_fill,
              color: CupertinoColors.systemPurple,
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
                    '${feature.sourceLayer} • ${feature.typeDescription}',
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
}

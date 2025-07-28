// lib/feature_details_widget.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'feature_selection_service.dart';

/// Widget to display feature details in a bottom sheet
class FeatureDetailsWidget extends StatefulWidget {
  final SelectedFeature feature;
  final VoidCallback? onClose;
  final Function(String, dynamic)? onPropertySelected;

  const FeatureDetailsWidget({
    super.key,
    required this.feature,
    this.onClose,
    this.onPropertySelected,
  });

  @override
  State<FeatureDetailsWidget> createState() => _FeatureDetailsWidgetState();
}

class _FeatureDetailsWidgetState extends State<FeatureDetailsWidget> {
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
          // Feature icon based on layer type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFeatureIcon(),
              color: CupertinoColors.systemBlue,
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
                Text(
                  widget.feature.layerName,
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
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.info_circle,
              size: 48,
              color: CupertinoColors.systemGrey3,
            ),
            SizedBox(height: 16),
            Text(
              'No properties available for this feature',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 16,
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
              color: CupertinoColors.systemBlue,
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
      'layer_name': widget.feature.layerName,
      'coordinates': widget.feature.coordinatesString,
      'properties': widget.feature.properties,
      'geometry': widget.feature.geometry,
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
                'Raw Feature Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _copyToClipboard(jsonString),
                child: const Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 20,
                  color: CupertinoColors.systemBlue,
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
    // You could extend this to show different icons based on feature type
    final geometry = widget.feature.geometry['type'] as String?;
    switch (geometry) {
      case 'Point':
        return CupertinoIcons.location_fill;
      case 'LineString':
      case 'MultiLineString':
        return CupertinoIcons.location_north_line;
      case 'Polygon':
      case 'MultiPolygon':
        return CupertinoIcons.square_fill;
      default:
        return CupertinoIcons.location;
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
      'layer_name': widget.feature.layerName,
      'title': widget.feature.title,
      'coordinates': widget.feature.coordinatesString,
      'properties': widget.feature.properties,
      'geometry': widget.feature.geometry,
      'exported_at': DateTime.now().toIso8601String(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    _copyToClipboard(jsonString);
  }
}

/// Show feature details in a modal bottom sheet
void showFeatureDetails(
  BuildContext context,
  SelectedFeature feature, {
  Function(String, dynamic)? onPropertySelected,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: FeatureDetailsWidget(
        feature: feature,
        onClose: () => Navigator.pop(context),
        onPropertySelected: onPropertySelected,
      ),
    ),
  );
}

/// Compact feature info widget for embedding in other UIs
class CompactFeatureInfo extends StatelessWidget {
  final SelectedFeature feature;
  final VoidCallback? onTap;

  const CompactFeatureInfo({super.key, required this.feature, this.onTap});

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
        // FIXED: Changed from InkWell to GestureDetector
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.location_fill,
              color: CupertinoColors.systemBlue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature.layerName,
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

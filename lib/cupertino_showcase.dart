// lib/cupertino_showcase.dart (UPDATED with both approaches)
import 'package:flutter/cupertino.dart';
import 'wfs_approach/mapbox_wfs_viewer.dart';
import 'vector_tiles_approach/mapbox_vector_viewer.dart';
import 'vector_tiles_approach/performance_comparison.dart';

class CupertinoShowcase extends StatefulWidget {
  const CupertinoShowcase({super.key});

  @override
  State<CupertinoShowcase> createState() => _CupertinoShowcaseState();
}

class _CupertinoShowcaseState extends State<CupertinoShowcase> {
  bool _switchValue = false;
  double _sliderValue = 0.5;
  int _segmentedValue = 0;
  final TextEditingController _textController = TextEditingController();

  void _showActionSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Choose an option'),
        message: const Text('Select one of the options below'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Option 1'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Option 2'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAlert() {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Alert'),
        content: const Text('This is a Cupertino alert dialog'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Cupertino Widgets'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Segmented Control
            const Text(
              'Segmented Control',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CupertinoSegmentedControl<int>(
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('First'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Second'),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Third'),
                ),
              },
              onValueChanged: (int value) {
                setState(() {
                  _segmentedValue = value;
                });
              },
              groupValue: _segmentedValue,
            ),
            const SizedBox(height: 24),

            // Buttons
            const Text(
              'Buttons',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(onPressed: () {}, child: const Text('Default')),
                CupertinoButton.filled(
                  onPressed: () {},
                  child: const Text('Filled'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Text Field
            const Text(
              'Text Field',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _textController,
              placeholder: 'Enter some text',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 24),

            // List Section
            const Text(
              'List Section',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('Switch Control'),
                  trailing: CupertinoSwitch(
                    value: _switchValue,
                    onChanged: (bool value) {
                      setState(() {
                        _switchValue = value;
                      });
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Slider Control'),
                  subtitle: Text('Value: ${_sliderValue.toStringAsFixed(2)}'),
                  trailing: SizedBox(
                    width: 100,
                    child: CupertinoSlider(
                      value: _sliderValue,
                      onChanged: (double value) {
                        setState(() {
                          _sliderValue = value;
                        });
                      },
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Navigation Example'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (BuildContext context) {
                          return const SecondPage();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Sheet and Alert
            const Text(
              'Dialogs & Sheets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton.filled(
                  onPressed: _showActionSheet,
                  child: const Text('Action Sheet'),
                ),
                CupertinoButton.filled(
                  onPressed: _showAlert,
                  child: const Text('Alert Dialog'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // NEW: Map Integration Section with both approaches
            const Text(
              'Geospatial Data Integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              children: [
                // WFS Approach
                CupertinoListTile(
                  title: const Text('WFS Data Viewer'),
                  subtitle: const Text(
                    'Load hydrology data via Web Feature Service (WFS)',
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      CupertinoIcons.cloud_download,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'WFS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CupertinoListTileChevron(),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (BuildContext context) {
                          return const MapboxWFSViewer();
                        },
                      ),
                    );
                  },
                ),

                // Vector Tiles Approach
                CupertinoListTile(
                  title: const Text('Vector Tiles Viewer'),
                  subtitle: const Text(
                    'High-performance rendering with Mapbox Vector Tiles',
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemPurple,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      CupertinoIcons.cube_box,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
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
                          'VECTOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CupertinoListTileChevron(),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (BuildContext context) {
                          return const MapboxVectorViewer();
                        },
                      ),
                    );
                  },
                ),

                // Performance Comparison
                CupertinoListTile(
                  title: const Text('Performance Comparison'),
                  subtitle: const Text(
                    'Compare WFS vs Vector Tiles performance metrics',
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      CupertinoIcons.chart_bar,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ANALYSIS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CupertinoListTileChevron(),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (BuildContext context) {
                          return const PerformanceComparisonWidget();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // NEW: Approach comparison info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.info_circle,
                        color: CupertinoColors.systemBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Data Loading Approaches',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This app demonstrates two different approaches for loading geospatial data:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• WFS: Real-time data loading from HydroShare servers',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Vector Tiles: Pre-processed tiles for optimal performance',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Compare their performance with large datasets!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Second Page')),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 100,
              color: CupertinoColors.systemGreen,
            ),
            SizedBox(height: 16),
            Text('You navigated successfully!', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Notice how the back button automatically appeared',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

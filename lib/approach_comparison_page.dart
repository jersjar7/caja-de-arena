// lib/approach_comparison_page.dart
import 'package:flutter/cupertino.dart';
import 'wfs_approach/mapbox_wfs_viewer.dart';
import 'vector_tiles_approach/mapbox_vector_viewer.dart';
import 'vector_tiles_approach/performance_comparison.dart';

class ApproachComparisonPage extends StatelessWidget {
  const ApproachComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('WFS vs Vector Tiles'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Introduction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.lightbulb,
                        color: CupertinoColors.systemBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Geospatial Data Loading Comparison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This app demonstrates two different approaches for loading and displaying large geospatial datasets from HydroShare. Each approach has distinct advantages depending on your use case.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // WFS Approach Card
            _buildApproachCard(
              context,
              title: 'Web Feature Service (WFS)',
              subtitle: 'Real-time data loading from servers',
              description:
                  'Loads data directly from HydroShare WFS endpoints. Best for dynamic data that changes frequently.',
              color: CupertinoColors.systemBlue,
              icon: CupertinoIcons.cloud_download,
              pros: [
                'Real-time data access',
                'No preprocessing required',
                'Direct server queries',
                'Flexible filtering',
                'Works with any WFS server',
              ],
              cons: [
                'Slower for large datasets',
                'Network dependent',
                'Server load increases',
                'Limited by WFS capabilities',
                'Potential timeouts',
              ],
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const MapboxWFSViewer(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vector Tiles Approach Card
            _buildApproachCard(
              context,
              title: 'Mapbox Vector Tiles',
              subtitle: 'Pre-processed tiles for optimal performance',
              description:
                  'Uses pre-processed vector tiles stored on Mapbox servers. Optimized for fast rendering of large datasets.',
              color: CupertinoColors.systemPurple,
              icon: CupertinoIcons.cube_box,
              pros: [
                '10-100x faster rendering',
                'Scales to millions of features',
                'Optimized for zoom levels',
                'Reduced bandwidth usage',
                'Better user experience',
              ],
              cons: [
                'Requires preprocessing',
                'Static data (until re-uploaded)',
                'Upload/processing time',
                'Storage costs',
                'Less flexible querying',
              ],
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const MapboxVectorViewer(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Performance Comparison Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.chart_bar,
                        color: CupertinoColors.systemGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Performance Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Test both approaches and compare their performance metrics. The app tracks load times, feature counts, and user experience.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) =>
                              const PerformanceComparisonWidget(),
                        ),
                      ),
                      child: const Text('View Performance Comparison'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Use Case Recommendations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemYellow.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.star,
                        color: CupertinoColors.systemYellow,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'When to Use Each Approach',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildUseCase('Use WFS When:', [
                    'Data changes frequently',
                    'Small to medium datasets (<10K features)',
                    'Need real-time server queries',
                    'Prototyping or development',
                    'Custom filtering requirements',
                  ], CupertinoColors.systemBlue),
                  const SizedBox(height: 16),
                  _buildUseCase('Use Vector Tiles When:', [
                    'Large datasets (>100K features)',
                    'Performance is critical',
                    'Data is relatively static',
                    'Production applications',
                    'Need to scale to many users',
                  ], CupertinoColors.systemPurple),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // HydroShare Context
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemIndigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemIndigo.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.drop,
                        color: CupertinoColors.systemIndigo,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'HydroShare Integration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your streams3 layer contains 2.7 million stream features from HydroShare. This demonstrates the performance difference between approaches:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• WFS: Would take 30+ seconds to load all features',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Vector Tiles: Renders instantly at any zoom level',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The vector tiles approach is ideal for datasets of this scale.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemIndigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproachCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required IconData icon,
    required List<String> pros,
    required List<String> cons,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: CupertinoColors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Try Demo',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pros
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_circle,
                                color: CupertinoColors.systemGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Advantages',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...pros.map(
                            (pro) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $pro',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Cons
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.xmark_circle,
                                color: CupertinoColors.systemRed,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Limitations',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...cons.map(
                            (con) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $con',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUseCase(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

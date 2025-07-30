import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class CupertinoRiverFavoritesPage extends StatefulWidget {
  const CupertinoRiverFavoritesPage({super.key});

  @override
  State<CupertinoRiverFavoritesPage> createState() =>
      _CupertinoRiverFavoritesPageState();
}

class _CupertinoRiverFavoritesPageState
    extends State<CupertinoRiverFavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<RiverStation> _favoriteStations = [];
  List<RiverStation> _filteredStations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStations();
    _searchController.addListener(_filterStations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFavoriteStations() {
    setState(() => _isLoading = true);

    // Simulate loading - replace with actual data loading
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _favoriteStations = _generateSampleStations();
        _filteredStations = _favoriteStations;
        _isLoading = false;
      });
    });
  }

  void _filterStations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStations = _favoriteStations.where((station) {
        return station.name.toLowerCase().contains(query) ||
            station.riverName.toLowerCase().contains(query) ||
            station.location.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleFavorite(RiverStation station) {
    setState(() {
      _favoriteStations.removeWhere((s) => s.id == station.id);
      _filterStations();
    });

    // Show confirmation
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Removed from Favorites'),
        content: Text('${station.name} has been removed from your favorites.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Undo'),
            onPressed: () {
              setState(() {
                _favoriteStations.add(station);
                _filterStations();
              });
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    _loadFavoriteStations();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Favorite Stations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredStations.isEmpty
                  ? _buildEmptyState()
                  : _buildStationsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search stations or rivers...',
        style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CupertinoActivityIndicator(radius: 16));
  }

  Widget _buildEmptyState() {
    final isEmpty = _favoriteStations.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEmpty ? CupertinoIcons.heart : CupertinoIcons.search,
              size: 64,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              isEmpty ? 'No Favorite Stations' : 'No Results Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEmpty
                  ? 'Add stations to your favorites to see them here. Tap the heart icon on any station to save it.'
                  : 'Try adjusting your search terms or clear the search to see all favorites.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (isEmpty) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('Browse Stations'),
                onPressed: () {
                  // Navigate to stations browser
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationsList() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _handleRefresh),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildStationCard(_filteredStations[index]),
              );
            }, childCount: _filteredStations.length),
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard(RiverStation station) {
    return GestureDetector(
      onTap: () => _navigateToStationDetail(station),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey
                  .resolveFrom(context)
                  .withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and favorite button
            _buildCardHeader(station),

            // Station info
            _buildCardContent(station),

            // Status and flow info
            _buildCardFooter(station),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(RiverStation station) {
    return Stack(
      children: [
        // River image
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: station.gradientColors,
              ),
            ),
            child: Stack(
              children: [
                // Simulate water pattern with overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: WaterPatternPainter(station.flowRate),
                  ),
                ),
                // River name overlay
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.riverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        station.location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Favorite button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => _toggleFavorite(station),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                // backdropFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              ),
              child: const Icon(
                CupertinoIcons.heart_fill,
                color: CupertinoColors.systemRed,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(RiverStation station) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Station ID: ${station.id}',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(RiverStation station) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Flow rate
          Expanded(
            child: _buildInfoItem(
              icon: CupertinoIcons.drop,
              label: 'Flow',
              value: '${station.flowRate.toInt()} cfs',
              color: CupertinoColors.systemBlue,
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: CupertinoColors.separator.resolveFrom(context),
          ),

          // Status
          Expanded(
            child: _buildInfoItem(
              icon: _getStatusIcon(station.status),
              label: 'Status',
              value: station.status,
              color: _getStatusColor(station.status),
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: CupertinoColors.separator.resolveFrom(context),
          ),

          // Last updated
          Expanded(
            child: _buildInfoItem(
              icon: CupertinoIcons.clock,
              label: 'Updated',
              value: _formatUpdateTime(station.lastUpdated),
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  void _navigateToStationDetail(RiverStation station) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(station.name)),
          body: Center(child: Text('Station Detail for ${station.name}')),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return CupertinoIcons.checkmark_circle;
      case 'elevated':
        return CupertinoIcons.exclamationmark_triangle;
      case 'high':
        return CupertinoIcons.exclamationmark_circle;
      case 'extreme':
        return CupertinoIcons.xmark_octagon;
      default:
        return CupertinoIcons.question_circle_fill;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return CupertinoColors.systemGreen;
      case 'elevated':
        return CupertinoColors.systemYellow;
      case 'high':
        return CupertinoColors.systemOrange;
      case 'extreme':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatUpdateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  List<RiverStation> _generateSampleStations() {
    final random = Random();
    final riverNames = [
      'Colorado River',
      'Snake River',
      'Green River',
      'Provo River',
      'Weber River',
      'Bear River',
      'Sevier River',
      'Virgin River',
    ];
    final locations = [
      'Near Moab, UT',
      'Near Jackson, WY',
      'Near Green River, UT',
      'Near Provo, UT',
      'Near Ogden, UT',
      'Near Logan, UT',
      'Near Richfield, UT',
      'Near St. George, UT',
    ];
    final statuses = ['Normal', 'Elevated', 'High', 'Normal', 'Normal'];

    return List.generate(8, (index) {
      final flowRate = 50 + random.nextDouble() * 500;
      return RiverStation(
        id: 'USGS${09000000 + index * 1000}',
        name:
            '${riverNames[index]} at ${locations[index].split(',')[0].replaceAll('Near ', '')}',
        riverName: riverNames[index],
        location: locations[index],
        flowRate: flowRate,
        status: statuses[random.nextInt(statuses.length)],
        lastUpdated: DateTime.now().subtract(
          Duration(minutes: random.nextInt(120)),
        ),
        gradientColors: _getGradientColors(index),
      );
    });
  }

  List<Color> _getGradientColors(int index) {
    final gradients = [
      [const Color(0xFF4A90E2), const Color(0xFF7BB3F2)], // Blue
      [const Color(0xFF50C878), const Color(0xFF7DD87F)], // Green
      [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)], // Red
      [const Color(0xFFFFB347), const Color(0xFFFFCC70)], // Orange
      [const Color(0xFF9B59B6), const Color(0xFFB576D1)], // Purple
      [const Color(0xFF3498DB), const Color(0xFF5DADE2)], // Light Blue
      [const Color(0xFF2ECC71), const Color(0xFF58D68D)], // Emerald
      [const Color(0xFFE74C3C), const Color(0xFFEC7063)], // Crimson
    ];
    return gradients[index % gradients.length];
  }
}

// Custom painter for water pattern effect
class WaterPatternPainter extends CustomPainter {
  final double flowRate;

  WaterPatternPainter(this.flowRate);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    final waveHeight = (flowRate / 500) * 20 + 10;

    for (double x = 0; x < size.width; x++) {
      final y = size.height * 0.7 + sin((x / size.width) * 4 * pi) * waveHeight;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Data model
class RiverStation {
  final String id;
  final String name;
  final String riverName;
  final String location;
  final double flowRate;
  final String status;
  final DateTime lastUpdated;
  final List<Color> gradientColors;

  RiverStation({
    required this.id,
    required this.name,
    required this.riverName,
    required this.location,
    required this.flowRate,
    required this.status,
    required this.lastUpdated,
    required this.gradientColors,
  });
}

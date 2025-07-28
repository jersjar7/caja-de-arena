// lib/components/mapbox_place_search.dart (FIXED - Overflow Issue)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Represents a place from Mapbox Geocoding API
class SearchedPlace {
  final String placeName;
  final String shortName;
  final double longitude;
  final double latitude;
  final String? category;
  final String? address;
  final List<String> context;

  const SearchedPlace({
    required this.placeName,
    required this.shortName,
    required this.longitude,
    required this.latitude,
    this.category,
    this.address,
    this.context = const [],
  });

  factory SearchedPlace.fromJson(Map<String, dynamic> json) {
    final coordinates = json['center'] as List;
    final context = <String>[];

    // Extract context (country, region, etc.)
    if (json['context'] != null) {
      for (final ctx in json['context']) {
        context.add(ctx['text'] as String);
      }
    }

    return SearchedPlace(
      placeName: json['place_name'] as String,
      shortName: json['text'] as String,
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
      category: json['properties']?['category'] as String?,
      address: json['properties']?['address'] as String?,
      context: context,
    );
  }

  /// Get category icon
  IconData get categoryIcon {
    switch (category?.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return CupertinoIcons.ant_circle;
      case 'hotel':
      case 'lodging':
        return CupertinoIcons.bed_double;
      case 'gas':
      case 'fuel':
        return CupertinoIcons.car;
      case 'hospital':
      case 'medical':
        return CupertinoIcons.heart;
      case 'school':
      case 'education':
        return CupertinoIcons.book;
      case 'park':
      case 'recreation':
        return CupertinoIcons.tree;
      case 'shopping':
        return CupertinoIcons.bag;
      default:
        return CupertinoIcons.location;
    }
  }

  /// Get context string (country, state, etc.)
  String get contextString {
    if (context.isEmpty) return '';
    return context.join(', ');
  }

  @override
  String toString() {
    return 'SearchedPlace(name: $shortName, location: $latitude, $longitude)';
  }
}

/// Mapbox place search service
class MapboxSearchService {
  static const String _baseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _accessToken =
      'pk.eyJ1IjoiamVyc29uZGV2cyIsImEiOiJjbTkxcGQ1emYwM2d1MnFwcWJ2dmgwYmpuIn0.ca52KhzP9gaK5nYDMv0ZxA';

  /// Search for places using Mapbox Geocoding API
  static Future<List<SearchedPlace>> searchPlaces({
    required String query,
    int limit = 10,
    String? country,
    List<String>? types,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/${Uri.encodeComponent(query)}.json')
          .replace(
            queryParameters: {
              'access_token': _accessToken,
              'limit': limit.toString(),
              'autocomplete': 'true',
              if (country != null) 'country': country,
              if (types != null) 'types': types.join(','),
            },
          );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;

        return features
            .map((feature) => SearchedPlace.fromJson(feature))
            .toList();
      } else {
        print('❌ Geocoding API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }
}

/// Cupertino-styled place search widget
class MapboxPlaceSearchWidget extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final Function(SearchedPlace)? onPlaceSelected;
  final Function(String)? onSearchChanged;
  final String placeholder;
  final bool showRecentSearches;

  const MapboxPlaceSearchWidget({
    super.key,
    this.mapboxMap,
    this.onPlaceSelected,
    this.onSearchChanged,
    this.placeholder = 'Search places...',
    this.showRecentSearches = true,
  });

  @override
  State<MapboxPlaceSearchWidget> createState() =>
      _MapboxPlaceSearchWidgetState();
}

class _MapboxPlaceSearchWidgetState extends State<MapboxPlaceSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchedPlace> _searchResults = [];
  List<SearchedPlace> _recentSearches = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;
    widget.onSearchChanged?.call(query);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showResults = _focusNode.hasFocus;
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await MapboxSearchService.searchPlaces(
        query: query,
        limit: 8,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectPlace(SearchedPlace place) {
    // Add to recent searches
    _recentSearches.removeWhere((p) => p.placeName == place.placeName);
    _recentSearches.insert(0, place);
    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.take(5).toList();
    }

    // Update search field
    _searchController.text = place.shortName;
    _focusNode.unfocus();

    // Fly to location if map is available
    if (widget.mapboxMap != null) {
      _flyToPlace(place);
    }

    // Notify parent
    widget.onPlaceSelected?.call(place);

    setState(() {
      _showResults = false;
    });
  }

  Future<void> _flyToPlace(SearchedPlace place) async {
    try {
      await widget.mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(place.longitude, place.latitude)),
          zoom: 10.0,
        ),
        MapAnimationOptions(duration: 4000),
      );

      print('🎯 Flew to: ${place.shortName}');
    } catch (e) {
      print('❌ Error flying to place: $e');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.search,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  placeholder: widget.placeholder,
                  decoration: null,
                  style: const TextStyle(fontSize: 16),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && _searchResults.isNotEmpty) {
                      _selectPlace(_searchResults.first);
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemGrey3,
                    size: 20,
                  ),
                ),
              ],
              if (_isSearching) ...[
                const SizedBox(width: 8),
                const CupertinoActivityIndicator(radius: 8),
              ],
            ],
          ),
        ),

        // Results - FIXED: Added proper constraints and scrolling
        if (_showResults) ...[
          const SizedBox(height: 8),
          Expanded(child: _buildSearchResults()), // ✅ FIXED: Use Expanded
        ],
      ],
    );
  }

  // ✅ FIXED: Completely rebuilt search results to handle overflow
  Widget _buildSearchResults() {
    final hasSearchResults = _searchResults.isNotEmpty;
    final hasRecentSearches =
        widget.showRecentSearches && _recentSearches.isNotEmpty;
    final showingResults = _searchController.text.trim().isNotEmpty;

    if (!hasSearchResults && !hasRecentSearches) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.location_circle,
              size: 48,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 12),
            Text(
              showingResults ? 'No places found' : 'Start typing to search',
              style: const TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ FIXED: Use proper scrollable structure
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomScrollView(
          slivers: [
            // Search results section
            if (hasSearchResults) ...[
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    showingResults ? 'Search Results' : 'Places',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildPlaceListTile(_searchResults[index], false);
                }, childCount: _searchResults.length),
              ),
            ],

            // Recent searches section
            if (!showingResults && hasRecentSearches) ...[
              if (hasSearchResults)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: const Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildPlaceListTile(_recentSearches[index], true);
                }, childCount: _recentSearches.length),
              ),
            ],

            // Add bottom padding to ensure content doesn't get cut off
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ IMPROVED: Better styled list tiles
  Widget _buildPlaceListTile(SearchedPlace place, bool isRecent) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isRecent
                ? CupertinoColors.systemGrey5
                : CupertinoColors.systemBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isRecent ? CupertinoIcons.clock : place.categoryIcon,
            size: 18,
            color: isRecent
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemBlue,
          ),
        ),
        title: Text(
          place.shortName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.address != null)
              Text(
                place.address!,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (place.contextString.isNotEmpty)
              Text(
                place.contextString,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Icon(
          CupertinoIcons.location,
          size: 16,
          color: CupertinoColors.systemGrey2,
        ),
        onTap: () => _selectPlace(place),
      ),
    );
  }
}

/// Compact search bar for overlay on map
class CompactMapSearchBar extends StatelessWidget {
  final MapboxMap? mapboxMap;
  final Function(SearchedPlace)? onPlaceSelected;
  final VoidCallback? onTap;

  const CompactMapSearchBar({
    super.key,
    this.mapboxMap,
    this.onPlaceSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text(
              'Search places...',
              style: TextStyle(
                color: CupertinoColors.placeholderText,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(
              CupertinoIcons.location,
              color: CupertinoColors.systemBlue,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

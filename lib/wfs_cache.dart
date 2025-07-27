// lib/wfs_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'spatial_utils.dart';

/// Cached WFS response data structure
class CachedWFSResponse {
  final String layerId;
  final CoordinateBounds bbox;
  final String geojsonData;
  final int featureCount;
  final DateTime timestamp;
  final double zoom;
  final int? maxFeatures;
  final String cacheKey;

  const CachedWFSResponse({
    required this.layerId,
    required this.bbox,
    required this.geojsonData,
    required this.featureCount,
    required this.timestamp,
    required this.zoom,
    this.maxFeatures,
    required this.cacheKey,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'layerId': layerId,
      'bbox': {
        'southwest': {
          'lng': bbox.southwest.coordinates.lng,
          'lat': bbox.southwest.coordinates.lat,
        },
        'northeast': {
          'lng': bbox.northeast.coordinates.lng,
          'lat': bbox.northeast.coordinates.lat,
        },
      },
      'geojsonData': geojsonData,
      'featureCount': featureCount,
      'timestamp': timestamp.toIso8601String(),
      'zoom': zoom,
      'maxFeatures': maxFeatures,
      'cacheKey': cacheKey,
    };
  }

  /// Create from JSON
  factory CachedWFSResponse.fromJson(Map<String, dynamic> json) {
    final bboxData = json['bbox'] as Map<String, dynamic>;
    final sw = bboxData['southwest'] as Map<String, dynamic>;
    final ne = bboxData['northeast'] as Map<String, dynamic>;

    return CachedWFSResponse(
      layerId: json['layerId'] as String,
      bbox: CoordinateBounds(
        southwest: Point(
          coordinates: Position(sw['lng'] as double, sw['lat'] as double),
        ),
        northeast: Point(
          coordinates: Position(ne['lng'] as double, ne['lat'] as double),
        ),
        infiniteBounds: false,
      ),
      geojsonData: json['geojsonData'] as String,
      featureCount: json['featureCount'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      zoom: json['zoom'] as double,
      maxFeatures: json['maxFeatures'] as int?,
      cacheKey: json['cacheKey'] as String,
    );
  }

  /// Check if cache entry is expired
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  /// Get human-readable age string
  String getAgeString() {
    final age = DateTime.now().difference(timestamp);
    if (age.inMinutes < 1) {
      return 'Just now';
    } else if (age.inHours < 1) {
      return '${age.inMinutes}m ago';
    } else if (age.inDays < 1) {
      return '${age.inHours}h ago';
    } else {
      return '${age.inDays}d ago';
    }
  }

  /// Get cache entry size in bytes (approximate)
  int getSizeBytes() {
    return geojsonData.length * 2; // Rough UTF-16 estimation
  }
}

/// WFS Cache statistics
class WFSCacheStats {
  final int totalEntries;
  final int totalSizeBytes;
  final int hitCount;
  final int missCount;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;
  final Map<String, int> layerCounts;

  const WFSCacheStats({
    required this.totalEntries,
    required this.totalSizeBytes,
    required this.hitCount,
    required this.missCount,
    this.oldestEntry,
    this.newestEntry,
    required this.layerCounts,
  });

  /// Get cache hit rate as percentage
  double get hitRate {
    final total = hitCount + missCount;
    return total > 0 ? (hitCount / total) * 100 : 0.0;
  }

  /// Get human-readable size string
  String get sizeString {
    if (totalSizeBytes < 1024) {
      return '${totalSizeBytes}B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

/// WFS caching system with automatic expiry and size management
class WFSCache {
  static const String _keyPrefix = 'wfs_cache_';
  static const String _statsKey = 'wfs_cache_stats';

  /// Default cache expiry time
  static const Duration _defaultMaxAge = Duration(hours: 24);

  /// Maximum cache size in bytes (50MB default)
  static const int _maxCacheSizeBytes = 50 * 1024 * 1024;

  /// Maximum number of cache entries
  static const int _maxCacheEntries = 1000;

  static SharedPreferences? _prefs;
  static int _hitCount = 0;
  static int _missCount = 0;

  /// Initialize the cache system
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadStats();
      print('✅ WFS Cache initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize WFS Cache: $e');
    }
  }

  /// Get cached WFS response for a specific layer and bounding box
  static Future<CachedWFSResponse?> getCachedResponse({
    required String layerId,
    required CoordinateBounds bbox,
    required double zoom,
    int? maxFeatures,
    Duration maxAge = _defaultMaxAge,
  }) async {
    try {
      await _ensureInitialized();

      // Generate cache key using spatial utils
      final cacheKey = SpatialUtils.generateSpatialCacheKey(
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        maxFeatures: maxFeatures,
      );

      final key = '$_keyPrefix$cacheKey';
      final cachedJson = _prefs!.getString(key);

      if (cachedJson == null) {
        _missCount++;
        await _saveStats();
        return null;
      }

      try {
        final cachedData = CachedWFSResponse.fromJson(jsonDecode(cachedJson));

        // Check if expired
        if (cachedData.isExpired(maxAge)) {
          print(
            '🕒 Cache entry expired for $layerId: ${cachedData.getAgeString()}',
          );
          await _removeEntry(key);
          _missCount++;
          await _saveStats();
          return null;
        }

        _hitCount++;
        await _saveStats();
        print(
          '✅ Cache HIT for $layerId: ${cachedData.getAgeString()}, ${cachedData.featureCount} features',
        );
        return cachedData;
      } catch (e) {
        print('❌ Failed to parse cached data for $layerId: $e');
        await _removeEntry(key);
        _missCount++;
        await _saveStats();
        return null;
      }
    } catch (e) {
      print('❌ Cache get error: $e');
      _missCount++;
      return null;
    }
  }

  /// Cache a WFS response
  static Future<void> cacheResponse({
    required String layerId,
    required CoordinateBounds bbox,
    required String geojsonData,
    required int featureCount,
    required double zoom,
    int? maxFeatures,
  }) async {
    try {
      await _ensureInitialized();

      // Generate cache key
      final cacheKey = SpatialUtils.generateSpatialCacheKey(
        layerId: layerId,
        bbox: bbox,
        zoom: zoom,
        maxFeatures: maxFeatures,
      );

      final cachedResponse = CachedWFSResponse(
        layerId: layerId,
        bbox: bbox,
        geojsonData: geojsonData,
        featureCount: featureCount,
        timestamp: DateTime.now(),
        zoom: zoom,
        maxFeatures: maxFeatures,
        cacheKey: cacheKey,
      );

      // Check cache size limits before adding
      await _enforceStorageLimits();

      // Store the response
      final key = '$_keyPrefix$cacheKey';
      await _prefs!.setString(key, jsonEncode(cachedResponse.toJson()));

      print(
        '💾 Cached WFS response for $layerId: $featureCount features, ${(geojsonData.length / 1024).toStringAsFixed(1)}KB',
      );
    } catch (e) {
      print('❌ Failed to cache response for $layerId: $e');
    }
  }

  /// Check if a response exists in cache (without retrieving it)
  static Future<bool> hasResponse({
    required String layerId,
    required CoordinateBounds bbox,
    required double zoom,
    int? maxFeatures,
    Duration maxAge = _defaultMaxAge,
  }) async {
    final cached = await getCachedResponse(
      layerId: layerId,
      bbox: bbox,
      zoom: zoom,
      maxFeatures: maxFeatures,
      maxAge: maxAge,
    );
    return cached != null;
  }

  /// Get cache statistics
  static Future<WFSCacheStats> getStats() async {
    await _ensureInitialized();

    final allKeys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    int totalSize = 0;
    DateTime? oldest;
    DateTime? newest;
    final layerCounts = <String, int>{};

    for (final key in allKeys) {
      try {
        final cachedJson = _prefs!.getString(key);
        if (cachedJson != null) {
          final cached = CachedWFSResponse.fromJson(jsonDecode(cachedJson));

          totalSize += cached.getSizeBytes();

          if (oldest == null || cached.timestamp.isBefore(oldest)) {
            oldest = cached.timestamp;
          }
          if (newest == null || cached.timestamp.isAfter(newest)) {
            newest = cached.timestamp;
          }

          layerCounts[cached.layerId] = (layerCounts[cached.layerId] ?? 0) + 1;
        }
      } catch (e) {
        // Skip corrupted entries
        continue;
      }
    }

    return WFSCacheStats(
      totalEntries: allKeys.length,
      totalSizeBytes: totalSize,
      hitCount: _hitCount,
      missCount: _missCount,
      oldestEntry: oldest,
      newestEntry: newest,
      layerCounts: layerCounts,
    );
  }

  /// Clear all cached responses for a specific layer
  static Future<void> clearLayer(String layerId) async {
    await _ensureInitialized();

    final keysToRemove = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .where((key) {
          try {
            final cachedJson = _prefs!.getString(key);
            if (cachedJson != null) {
              final cached = CachedWFSResponse.fromJson(jsonDecode(cachedJson));
              return cached.layerId == layerId;
            }
          } catch (e) {
            // Remove corrupted entries too
            return true;
          }
          return false;
        })
        .toList();

    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }

    print(
      '🗑️ Cleared ${keysToRemove.length} cache entries for layer: $layerId',
    );
  }

  /// Clear all cached responses
  static Future<void> clearAll() async {
    await _ensureInitialized();

    final keysToRemove = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }

    _hitCount = 0;
    _missCount = 0;
    await _saveStats();

    print(
      '🗑️ Cleared all cache entries: ${keysToRemove.length} entries removed',
    );
  }

  /// Remove expired cache entries
  static Future<int> clearExpired({Duration maxAge = _defaultMaxAge}) async {
    await _ensureInitialized();

    final expiredKeys = <String>[];
    final allKeys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    for (final key in allKeys) {
      try {
        final cachedJson = _prefs!.getString(key);
        if (cachedJson != null) {
          final cached = CachedWFSResponse.fromJson(jsonDecode(cachedJson));
          if (cached.isExpired(maxAge)) {
            expiredKeys.add(key);
          }
        }
      } catch (e) {
        // Mark corrupted entries for removal
        expiredKeys.add(key);
      }
    }

    for (final key in expiredKeys) {
      await _prefs!.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      print('🕒 Removed ${expiredKeys.length} expired cache entries');
    }

    return expiredKeys.length;
  }

  /// Get all cached responses for debugging
  static Future<List<CachedWFSResponse>> getAllCachedResponses() async {
    await _ensureInitialized();

    final responses = <CachedWFSResponse>[];
    final allKeys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    for (final key in allKeys) {
      try {
        final cachedJson = _prefs!.getString(key);
        if (cachedJson != null) {
          final cached = CachedWFSResponse.fromJson(jsonDecode(cachedJson));
          responses.add(cached);
        }
      } catch (e) {
        // Skip corrupted entries
        continue;
      }
    }

    // Sort by timestamp (newest first)
    responses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return responses;
  }

  /// Print detailed cache information
  static Future<void> printCacheInfo() async {
    final stats = await getStats();
    print('\n📊 WFS CACHE STATISTICS:');
    print('Entries: ${stats.totalEntries}');
    print('Size: ${stats.sizeString}');
    print('Hit Rate: ${stats.hitRate.toStringAsFixed(1)}%');
    print('Hits: ${stats.hitCount}, Misses: ${stats.missCount}');

    if (stats.oldestEntry != null) {
      final oldestAge = DateTime.now().difference(stats.oldestEntry!);
      print('Oldest: ${oldestAge.inHours}h ago');
    }

    print('\nBy Layer:');
    stats.layerCounts.forEach((layer, count) {
      print('  $layer: $count entries');
    });
  }

  // Private helper methods

  static Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  static Future<void> _enforceStorageLimits() async {
    // Check entry count limit
    final allKeys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList();

    if (allKeys.length >= _maxCacheEntries) {
      await _removeOldestEntries(
        allKeys.length - _maxCacheEntries + 100,
      ); // Remove 100 extra for buffer
    }

    // Check size limit
    final stats = await getStats();
    if (stats.totalSizeBytes > _maxCacheSizeBytes) {
      await _removeOldestEntries(100); // Remove oldest 100 entries
    }
  }

  static Future<void> _removeOldestEntries(int countToRemove) async {
    final responses = await getAllCachedResponses();

    // Sort by timestamp (oldest first)
    responses.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final toRemove = responses.take(countToRemove);
    for (final response in toRemove) {
      await _removeEntry('$_keyPrefix${response.cacheKey}');
    }

    print(
      '🗑️ Removed $countToRemove oldest cache entries to enforce storage limits',
    );
  }

  static Future<void> _removeEntry(String key) async {
    await _prefs!.remove(key);
  }

  static Future<void> _loadStats() async {
    final statsJson = _prefs!.getString(_statsKey);
    if (statsJson != null) {
      try {
        final stats = jsonDecode(statsJson);
        _hitCount = stats['hitCount'] ?? 0;
        _missCount = stats['missCount'] ?? 0;
      } catch (e) {
        print('Failed to load cache stats: $e');
      }
    }
  }

  static Future<void> _saveStats() async {
    try {
      await _prefs!.setString(
        _statsKey,
        jsonEncode({
          'hitCount': _hitCount,
          'missCount': _missCount,
          'lastUpdate': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Failed to save cache stats: $e');
    }
  }
}

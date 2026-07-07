import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores and retrieves recently watched media using Hive.
class RecentlyWatchedService {
  static const String boxName = 'recently_watched';
  static const int _maxItems = 20;

  Box get _box => Hive.box(boxName);

  /// All recently watched items sorted newest-first.
  List<Map<String, dynamic>> getRecentlyWatched() {
    final items = _box.values
        .map((raw) {
          try {
            if (raw is String) return json.decode(raw) as Map<String, dynamic>;
            if (raw is Map) return Map<String, dynamic>.from(raw);
          } catch (_) {}
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    items.sort(
      (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
    );
    return items;
  }

  /// Adds or updates a recently watched item.
  Future<void> addItem({
    required String id,
    required String title,
    String? posterUrl,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final item = {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'mediaType': mediaType,
      'season': season,
      'episode': episode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(id, json.encode(item));

    // Prune if over limit
    if (_box.length > _maxItems) {
      final sorted = getRecentlyWatched();
      for (final old in sorted.skip(_maxItems)) {
        await _box.delete(old['id']);
      }
    }
  }

  Future<void> removeItem(String id) => _box.delete(id);

  Future<void> clearAll() => _box.clear();
}

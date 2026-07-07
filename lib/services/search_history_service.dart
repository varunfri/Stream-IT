import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores and retrieves recent search history using Hive.
/// Call [SearchHistoryService.init] once at app startup (before runApp).
class SearchHistoryService {
  static const String boxName = 'search_history';
  static const int _maxItems = 20;

  // Box is pre-opened in main(); no async init needed at call sites.
  Box get _box => Hive.box(boxName);

  /// All history items sorted newest-first.
  List<Map<String, dynamic>> getHistory() {
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

  /// Adds (or refreshes) an item. Keeps the list within [_maxItems].
  Future<void> addItem({
    required String id,
    required String title,
    String? posterUrl,
    required String mediaType,
  }) async {
    final item = {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'mediaType': mediaType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(id, json.encode(item));

    // Prune if over limit
    if (_box.length > _maxItems) {
      final sorted = getHistory();
      for (final old in sorted.skip(_maxItems)) {
        await _box.delete(old['id']);
      }
    }
  }

  Future<void> removeItem(String id) => _box.delete(id);

  Future<void> clearAll() => _box.clear();
}

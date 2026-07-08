import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' show parse;
import '../utils/custom_dns_adapter.dart';

final speedPornServiceProvider = Provider<SpeedPornService>((ref) {
  return SpeedPornService();
});

class SpeedPornService {
  static const String baseUrl = String.fromEnvironment('SPEED_URI');
  final Dio _dio;

  SpeedPornService() : _dio = Dio() {
    // Configure with custom DNS over HTTPS adapter to bypass network blocks
    CustomDnsAdapter().configure(_dio);
  }

  /// Scrapes the details page of a speedporn post to extract embed server urls
  Future<List<Map<String, String>>> fetchEmbedServers(String title) async {
    if (title.isEmpty) return [];

    String videoPageUrl = '';
    
    // 1. Try to search SpeedPorn for the title first to avoid slug collisions
    try {
      final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(title)}';
      debugPrint('SpeedPornService: Searching $searchUrl');
      final searchResponse = await _dio.get(
        searchUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (searchResponse.statusCode == 200) {
        final document = parse(searchResponse.data);
        final anchors = document.querySelectorAll('a');
        final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();

        for (var a in anchors) {
          final href = a.attributes['href'] ?? '';
          final text = a.text.trim();
          
          if (href.startsWith('http') &&
              href.contains('speedporn.net/') &&
              !href.contains('?s=')) {
            final cleanText = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
            if (cleanText == cleanTitle) {
              videoPageUrl = href;
              debugPrint('SpeedPornService: Search matched: "$text" -> $videoPageUrl');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SpeedPornService: Search query failed: $e');
    }

    // 2. Fallback to default slug generation if no search match was found
    if (videoPageUrl.isEmpty) {
      final slug = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');
      videoPageUrl = '$baseUrl/$slug/';
      debugPrint('SpeedPornService: Fallback to slug URL: $videoPageUrl');
    }

    try {
      final response = await _dio.get(
        videoPageUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = parse(response.data);
        final List<Map<String, String>> servers = [];
        final seenUrls = <String>{};

        // Try extracting server list elements
        final serverElements = document.querySelectorAll('a[id="#iframe"]');
        for (var el in serverElements) {
          final name = el.text.trim();
          final embedUrl = el.attributes['href'] ?? '';
          final iconUrl = el.querySelector('img')?.attributes['src'] ?? '';
          if (embedUrl.isNotEmpty &&
              !seenUrls.contains(embedUrl) &&
              !embedUrl.contains('lulustream')) {
            servers.add({
              'name': name,
              'embedUrl': embedUrl,
              'iconUrl': iconUrl,
            });
            seenUrls.add(embedUrl);
          }
        }

        // Fallback: Look for inline iframes
        if (servers.isEmpty) {
          final iframes = document.querySelectorAll('iframe');
          for (var iframe in iframes) {
            var src = iframe.attributes['src'] ?? '';
            if (src.isNotEmpty && !seenUrls.contains(src)) {
              if (src.contains('google') ||
                  src.contains('ads') ||
                  src.contains('analytics') ||
                  src.contains('doubleclick')) {
                continue;
              }
              servers.add({
                'name': 'Server (Auto)',
                'embedUrl': src,
                'iconUrl': '',
              });
              seenUrls.add(src);
            }
          }
        }
        return servers;
      }
    } catch (e) {
      debugPrint('SpeedPornService details scrape error: $e');
    }
    return [];
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' show parse;

final uiiUMovieServiceProvider = Provider<UiiUMovieService>((ref) {
  return UiiUMovieService();
});

class UiiUMovieService {
  static const String baseUrl = String.fromEnvironment('UIIU_URI');

  final Dio _dio;

  UiiUMovieService() : _dio = Dio();

  /// Scrapes the details page of a uiiumovie post to extract embed server urls
  String _normalizeEmbedUrl(String url) {
    var embed = url;
    if (embed.contains('streamtape.com/v/')) {
      embed = embed.replaceAll('streamtape.com/v/', 'streamtape.com/e/');
    } else if (embed.contains('mixdrop.co/f/')) {
      embed = embed.replaceAll('mixdrop.co/f/', 'mixdrop.co/e/');
    } else if (embed.contains('mxdrop.sx/f/')) {
      embed = embed.replaceAll('mxdrop.sx/f/', 'mxdrop.sx/e/');
    } else if (embed.contains('mixdrop.to/f/')) {
      embed = embed.replaceAll('mixdrop.to/f/', 'mixdrop.to/e/');
    } else if (embed.contains('hgcloud.to/')) {
      if (!embed.contains('hgcloud.to/e/')) {
        embed = embed.replaceAll('hgcloud.to/', 'hgcloud.to/e/');
      }
    }
    return embed;
  }

  /// Scrapes the details page of a uiiumovie post to extract embed server urls
  Future<List<Map<String, String>>> fetchEmbedServers(
    String titleSlug,
    String year,
  ) async {
    final List<Map<String, String>> servers = [];
    if (year.isEmpty) return servers;

    final slug = '$titleSlug-$year';
    final pageUrl = '$baseUrl/$slug/';
    debugPrint('UiiUMovieService: Fetching main page $pageUrl');

    try {
      final response = await _dio.get(
        pageUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = parse(response.data);

        // Find all player subpage links and direct stream links
        final anchors = document.querySelectorAll('a');
        final List<String> playerUrls = [];
        final seenPlayerUrls = <String>{};

        final streamKeywords = [
          'hgcloud',
          'mixdrop',
          'mxdrop',
          'streamtape',
          'terabox',
          'terasharefile',
          'jodwish',
          'dood',
          'voe',
          '1fichier',
          'streamvid',
          'vidoza',
          'filemoon',
          'vidguard',
        ];

        for (var a in anchors) {
          var href = a.attributes['href'] ?? '';
          final text = a.text.trim();

          if (href.contains('?player=')) {
            // Convert relative urls to absolute if needed
            if (!href.startsWith('http')) {
              if (href.startsWith('/')) {
                href = '$baseUrl$href';
              } else {
                href = '$baseUrl/$slug/$href';
              }
            }
            if (!seenPlayerUrls.contains(href)) {
              playerUrls.add(href);
              seenPlayerUrls.add(href);
            }
          } else {
            final lowerHref = href.toLowerCase();
            final lowerText = text.toLowerCase();

            bool isStream = false;
            for (var kw in streamKeywords) {
              if (lowerHref.contains(kw) || lowerText.contains(kw)) {
                isStream = true;
                break;
              }
            }

            if (isStream && !seenPlayerUrls.contains(href)) {
              seenPlayerUrls.add(href);

              // Normalize URL to embed format
              final normalizedUrl = _normalizeEmbedUrl(href);

              // Determine name from text or domain
              String serverName = text.isNotEmpty ? text : 'Server';
              // Clean up serverName to make it look premium
              if (serverName.toLowerCase().contains('terabox')) {
                serverName = 'TERABOX';
              } else if (serverName.toLowerCase().contains('streamhg') ||
                  serverName.toLowerCase().contains('hgcloud')) {
                serverName = 'STREAMHG';
              } else if (serverName.toLowerCase().contains('mixdrop')) {
                serverName = 'MIXDROP';
              } else if (serverName.toLowerCase().contains('streamtape')) {
                serverName = 'STREAMTAPE';
              } else if (serverName.toLowerCase().contains('1fichier')) {
                serverName = '1FICHIER';
              } else {
                serverName = serverName.toUpperCase();
              }

              if (text.toLowerCase().contains('720p')) {
                serverName += ' 720p';
              } else if (text.toLowerCase().contains('480p')) {
                serverName += ' 480p';
              } else if (text.toLowerCase().contains('1080p')) {
                serverName += ' 1080p';
              }

              final uri = Uri.tryParse(normalizedUrl);
              final iconUrl =
                  'https://www.google.com/s2/favicons?sz=16&domain=${uri?.host ?? ""}';

              servers.add({
                'name': serverName,
                'embedUrl': normalizedUrl,
                'iconUrl': iconUrl,
              });
            }
          }
        }

        debugPrint('UiiUMovieService: Found player subpage URLs: $playerUrls');

        // Parallel fetch player subpages
        final futures = playerUrls.map(
          (url) => _fetchIframeFromPlayerPage(url),
        );
        final results = await Future.wait(futures);

        for (int i = 0; i < results.length; i++) {
          final embedUrl = results[i];
          if (embedUrl != null && embedUrl.isNotEmpty) {
            // Extract domain name as host/server name
            String serverName = 'Server ${i + 1}';
            final uri = Uri.tryParse(embedUrl);
            if (uri != null && uri.host.isNotEmpty) {
              final hostParts = uri.host.split('.');
              if (hostParts.length >= 2) {
                serverName = hostParts[hostParts.length - 2].toUpperCase();
              } else {
                serverName = uri.host.toUpperCase();
              }
            }

            // Get favicon using Google s2 favicons
            final iconUrl =
                'https://www.google.com/s2/favicons?sz=16&domain=${uri?.host ?? ""}';

            servers.add({
              'name': serverName,
              'embedUrl': embedUrl,
              'iconUrl': iconUrl,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('UiiUMovieService details scrape error: $e');
    }
    return servers;
  }

  Future<String?> _fetchIframeFromPlayerPage(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      if (response.statusCode == 200) {
        final document = parse(response.data);
        final iframes = document.querySelectorAll('iframe');
        for (var iframe in iframes) {
          final src = iframe.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            // Skip known ads and tsyndicate
            if (src.contains('google') ||
                src.contains('ads') ||
                src.contains('analytics') ||
                src.contains('doubleclick') ||
                src.contains('tsyndicate')) {
              continue;
            }
            // Normalize protocol
            if (src.startsWith('//')) {
              return 'https:$src';
            }
            return src;
          }
        }
      }
    } catch (e) {
      debugPrint('UiiUMovieService error fetching player page $url: $e');
    }
    return null;
  }
}

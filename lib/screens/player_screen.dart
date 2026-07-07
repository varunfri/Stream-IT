import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tmdb_service.dart';
import '../services/recently_watched_service.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String type; // 'movie' or 'tv'
  final String id;
  final int season;
  final int episode;

  const PlayerScreen({
    super.key,
    required this.type,
    required this.id,
    this.season = 1,
    this.episode = 1,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  late final String _embedUrl;

  // JavaScript injected after each page load:
  // 1. Kills window.open() – prevents popup tabs from ever opening.
  // 2. Traps document-level clicks – swallows clicks on <a> tags pointing
  //    outside of vaplayer.ru before the browser can navigate.
  // 3. Overrides window.location setter – silently drops JS-driven redirects.
  static const String _adBlockJs = r"""
(function() {
  // 1. Kill popup windows
  window.open = function() { return null; };

  // 2. Block <a> clicks to external domains
  document.addEventListener('click', function(e) {
    var el = e.target;
    while (el && el.tagName !== 'A') { el = el.parentElement; }
    if (el && el.href &&
        !el.href.includes('vaplayer.ru') &&
        !el.href.startsWith('about:') &&
        !el.href.startsWith('javascript:')) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);

  // 3. Intercept window.location = '...' assignments
  try {
    var _origLocation = window.location;
    Object.defineProperty(window, 'location', {
      get: function() { return _origLocation; },
      set: function(v) {
        var s = String(v);
        if (s.includes('vaplayer.ru') || s.startsWith('about:') || s.startsWith('javascript:')) {
          _origLocation.href = s;
        }
        // Otherwise silently drop the redirect
      },
      configurable: true
    });
  } catch(e) {}
})();
""";

  @override
  void initState() {
    super.initState();
    _saveToRecentlyWatched();

    if (widget.type == 'movie') {
      _embedUrl =
          'https://vaplayer.ru/embed/movie/${widget.id}?primaryColor=%23E50914';
    } else {
      if (widget.id.startsWith('tt')) {
        _embedUrl =
            'https://vaplayer.ru/embed/tv/${widget.id}?primaryColor=%23E50914';
      } else {
        _embedUrl =
            'https://vaplayer.ru/embed/tv/${widget.id}/${widget.season}/${widget.episode}?primaryColor=%23E50914';
      }
    }

    // ── Screen awake + landscape ─────────────────────────────────────────
    WakelockPlus.enable(); // prevent screen sleep
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky, // hide status bar & nav bar
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Allow only the streaming domain and internal browser pages
            if (url.contains('vaplayer.ru') ||
                url.startsWith('about:') ||
                url.startsWith('javascript:')) {
              return NavigationDecision.navigate;
            }
            // DNS-style block: silently drop everything else —
            // no back(), no reload(), no restart of the video.
            debugPrint('PlayerScreen [BLOCKED]: $url');
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            debugPrint('PlayerScreen: Page started → $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            debugPrint('PlayerScreen: Page finished → $url');
            if (mounted) setState(() => _isLoading = false);
            // Inject ad-block JS every time a page finishes loading
            _controller.runJavaScript(_adBlockJs);
          },
          onWebResourceError: (error) {
            debugPrint(
              'PlayerScreen: Resource error [${error.errorCode}]: ${error.description}',
            );
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_embedUrl));
  }

  @override
  void dispose() {
    // ── Restore to portrait + re-enable system UI ────────────────────────
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _saveToRecentlyWatched() async {
    try {
      final service = ref.read(tmdbServiceProvider);
      final details = await service.getContentDetails(widget.id, widget.type);
      if (details != null) {
        final title = details['title'] ?? details['name'] ?? 'Unknown';
        final posterPath = details['poster_path'];
        final posterUrl = posterPath != null
            ? (posterPath.startsWith('http')
                  ? posterPath
                  : 'https://image.tmdb.org/t/p/w342$posterPath')
            : null;

        await RecentlyWatchedService().addItem(
          id: widget.id,
          title: title,
          posterUrl: posterUrl,
          mediaType: widget.type,
          season: widget.type == 'tv' ? widget.season : null,
          episode: widget.type == 'tv' ? widget.episode : null,
        );
      }
    } catch (e) {
      debugPrint('Error saving recently watched: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full-screen webview — no SafeArea so it truly fills the landscape display
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
          // Minimal back button in top-left
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

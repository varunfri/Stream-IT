import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tmdb_service.dart';
import '../services/recently_watched_service.dart';
import '../services/speed_service.dart';
import '../services/uiiu_service.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
// ignore: implementation_imports
import 'package:adblocker_webview/src/block_resource_loading.dart';
// ignore: implementation_imports
import 'package:adblocker_webview/src/elem_hide.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String type; // 'movie' or 'tv'
  final String id;
  final int season;
  final int episode;
  final String? embedUrl;

  const PlayerScreen({
    super.key,
    required this.type,
    required this.id,
    this.season = 1,
    this.episode = 1,
    this.embedUrl,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _pipChannel = MethodChannel('com.example.vid_api/pip');
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isInPipMode = false;
  String? _embedUrl;

  // JavaScript injected after each page load:
  // Kills window.open() – prevents popup tabs from ever opening.
  static const String _adBlockJs = r"""
(function() {
  window.open = function() { return null; };
})();
""";

  @override
  void initState() {
    super.initState();
    _saveToRecentlyWatched();
    _enablePip();

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final bool inPip = call.arguments as bool;
        if (mounted) {
          setState(() {
            _isInPipMode = inPip;
          });
        }
      }
    });

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

            // Check if EasyList blocks the resource URL first
            if (AdBlockerWebviewController.instance.shouldBlockResource(url)) {
              debugPrint('PlayerScreen [EASYLIST BLOCKED]: $url');
              return NavigationDecision.prevent;
            }

            final lowerUrl = url.toLowerCase();
            final allowedKeywords = [
              'vaplayer.ru',
              'speedporn.net',
              'uiiumovie.in',
              'mixdrop',
              'mxdrop',
              'miiixdrop',
              'streamtape',
              'terabox',
              'terasharefile',
              'jodwish',
              'dood',
              'voe.sx',
              'voe.sh',
              '1fichier',
              'streamvid',
              'vidoza',
              'filemoon',
              'vidguard',
              'hgcloud',
              'hanerix',
            ];

            bool isAllowed = false;
            for (var kw in allowedKeywords) {
              if (lowerUrl.contains(kw)) {
                isAllowed = true;
                break;
              }
            }

            if (isAllowed ||
                url.startsWith('about:') ||
                url.startsWith('javascript:')) {
              return NavigationDecision.navigate;
            }
            // DNS-style block: silently drop everything else
            debugPrint('PlayerScreen [BLOCKED]: $url');
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            debugPrint('PlayerScreen: Page started → $url');
            if (mounted) setState(() => _isLoading = true);

            // Inject EasyList resource blocker script as early as possible
            final rules = AdBlockerWebviewController.instance.allResourceRules;
            _controller.runJavaScript(getResourceLoadingBlockerScript(rules));

            // Apply element hiding after page load starts
            final cssRules = AdBlockerWebviewController.instance
                .getCssRulesForWebsite(url);
            _controller.runJavaScript(generateHidingScript(cssRules));
          },
          onPageFinished: (url) {
            debugPrint('PlayerScreen: Page finished → $url');
            if (mounted) setState(() => _isLoading = false);

            // Apply element hiding after page load finishes
            final cssRules = AdBlockerWebviewController.instance
                .getCssRulesForWebsite(url);
            _controller.runJavaScript(generateHidingScript(cssRules));

            // Inject our custom click/redirect blocker
            _controller.runJavaScript(_adBlockJs);
          },
          onWebResourceError: (error) {
            debugPrint(
              'PlayerScreen: Resource error [${error.errorCode}]: ${error.description}',
            );
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    _loadPlayerUrl();
  }

  Future<void> _loadPlayerUrl() async {
    try {
      String? resolvedUrl = widget.embedUrl;

      // If not passed from outside, do default resolution
      if (resolvedUrl == null) {
        final tmdbService = ref.read(tmdbServiceProvider);
        final speedPornService = ref.read(speedPornServiceProvider);

        // 1. Fetch details to check if there is a SpeedPorn or UiiUMovie match (by title slug)
        final details = await tmdbService.getContentDetails(
          widget.id,
          widget.type,
        );
        if (details != null) {
          final title = details['title'] ?? details['name'] ?? '';
          final year =
              details['release_date']?.toString().split('-').first ?? '';

          if (title.isNotEmpty) {
            final slug = title
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
                .trim()
                .replaceAll(RegExp(r'\s+'), '-');

            final servers = await speedPornService.fetchEmbedServers(slug);
            if (servers.isNotEmpty) {
              resolvedUrl = servers.first['embedUrl'];
              debugPrint(
                'PlayerScreen: Resolved SpeedPorn server: $resolvedUrl',
              );
            } else if (year.isNotEmpty) {
              final uiiuServers = await ref
                  .read(uiiUMovieServiceProvider)
                  .fetchEmbedServers(slug, year);
              if (uiiuServers.isNotEmpty) {
                resolvedUrl = uiiuServers.first['embedUrl'];
                debugPrint(
                  'PlayerScreen: Resolved UiiUMovie server: $resolvedUrl',
                );
              }
            }
          }
        }

        // 2. Default fallback to vaplayer.ru if no SpeedPorn servers are resolved
        if (resolvedUrl == null) {
          if (widget.type == 'movie') {
            resolvedUrl =
                'https://vaplayer.ru/embed/movie/${widget.id}?primaryColor=%23E50914';
          } else {
            if (widget.id.startsWith('tt')) {
              resolvedUrl =
                  'https://vaplayer.ru/embed/tv/${widget.id}?primaryColor=%23E50914';
            } else {
              resolvedUrl =
                  'https://vaplayer.ru/embed/tv/${widget.id}/${widget.season}/${widget.episode}?primaryColor=%23E50914';
            }
          }
          debugPrint('PlayerScreen: Resolved default vaplayer: $resolvedUrl');
        }
      }

      if (mounted) {
        setState(() {
          _embedUrl = resolvedUrl;
        });
        await _controller.loadRequest(Uri.parse(resolvedUrl));
      }
    } catch (e) {
      debugPrint('Error loading player url: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _disablePip();
    _pipChannel.setMethodCallHandler(null);
    // ── Restore to portrait + re-enable system UI ────────────────────────
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _enablePip() async {
    try {
      await _pipChannel.invokeMethod('enablePip');
    } catch (e) {
      debugPrint('Error enabling PiP: $e');
    }
  }

  Future<void> _disablePip() async {
    try {
      await _pipChannel.invokeMethod('disablePip');
    } catch (e) {
      debugPrint('Error disabling PiP: $e');
    }
  }

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (e) {
      debugPrint('Error entering PiP: $e');
    }
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
    if (_isInPipMode) {
      return _embedUrl != null
          ? WebViewWidget(controller: _controller)
          : const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full-screen webview — no SafeArea so it truly fills the landscape display
          if (_embedUrl != null) WebViewWidget(controller: _controller),
          if (_isLoading || _embedUrl == null)
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
                    decoration: const BoxDecoration(
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
          // Minimal PiP button in top-right
          Positioned(
            bottom: 8,
            left: MediaQuery.of(context).size.width * 0.43,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _enterPip,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.picture_in_picture_alt,
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

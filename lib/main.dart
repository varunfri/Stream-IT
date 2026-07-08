import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/search_history_service.dart';
import 'services/recently_watched_service.dart';
import 'services/settings_service.dart';
import 'screens/main_screen.dart';
import 'screens/details_screen.dart';
import 'screens/player_screen.dart';
import 'screens/company_screen.dart';
import 'screens/person_screen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive & open the search history box
  await Hive.initFlutter();
  await Hive.openBox(SearchHistoryService.boxName);
  await Hive.openBox(RecentlyWatchedService.boxName);
  await SettingsService().init();
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await windowManager.ensureInitialized();
  }

  // Initialize AdBlocker filter lists
  try {
    await AdBlockerWebviewController.instance.initialize(
      FilterConfig(
        filterTypes: [FilterType.easyList, FilterType.adGuard],
        blockedDomains: const [
          'adexchangerapid.com',
          'skimosaglet.shop',
          'indoneviler.rest',
        ],
      ),
    );
  } catch (e) {
    debugPrint("Could not initialize AdBlockerWebviewController: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Router Configuration
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/details/:type/:id',
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'movie';
          final id = state.pathParameters['id']!;
          return DetailsScreen(type: type, id: id);
        },
      ),
      GoRoute(
        path: '/company/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CompanyScreen(companyId: id);
        },
      ),
      GoRoute(
        path: '/person/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PersonScreen(personId: id);
        },
      ),
      GoRoute(
        path: '/player/:type/:id',
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'movie';
          final id = state.pathParameters['id']!;
          final season =
              int.tryParse(state.uri.queryParameters['season'] ?? '1') ?? 1;
          final episode =
              int.tryParse(state.uri.queryParameters['episode'] ?? '1') ?? 1;
          final embedUrl = state.uri.queryParameters['url'];
          return PlayerScreen(
            type: type,
            id: id,
            season: season,
            episode: episode,
            embedUrl: embedUrl,
          );
        },
      ),
    ],
  );
});

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Register a low-level key handler for macOS — this fires regardless of
    // which native view (e.g. WKWebView) currently holds OS-level focus.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      HardwareKeyboard.instance.addHandler(_handleMacOSKey);
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      HardwareKeyboard.instance.removeHandler(_handleMacOSKey);
    }
    super.dispose();
  }

  bool _handleMacOSKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;

    // Esc → go back
    // Esc → go back (Global block for GoRouter)
    if (key == LogicalKeyboardKey.escape) {
      final NavigatorState? navState = rootNavigatorKey.currentState;

      // Check if the router navigation stack actually has routes to pop
      if (navState != null && navState.canPop()) {
        navState.pop(); // Pops the top contextual page from the screen stack
        return true; // Keyboard event consumed
      }
    }

    // Cmd+F → toggle full screen
    if (meta && key == LogicalKeyboardKey.keyF) {
      windowManager.isFullScreen().then((isFull) {
        windowManager.setFullScreen(!isFull);
      });
      return true;
    }

    return false; // not consumed, let the event propagate
  }

  @override
  Widget build(BuildContext context) {
    _router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Stream IT',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
        ),
        useMaterial3: true,
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/search_history_service.dart';
import 'services/recently_watched_service.dart';
import 'screens/main_screen.dart';
import 'screens/details_screen.dart';
import 'screens/player_screen.dart';
import 'screens/company_screen.dart';
import 'screens/person_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive & open the search history box
  await Hive.initFlutter();
  await Hive.openBox(SearchHistoryService.boxName);
  await Hive.openBox(RecentlyWatchedService.boxName);

  // Initialize AdBlocker filter lists
  try {
    await AdBlockerWebviewController.instance.initialize(
      FilterConfig(
        filterTypes: [FilterType.easyList, FilterType.adGuard],
        blockedDomains: const ['adexchangerapid.com'],
      ),
    );
  } catch (e) {
    debugPrint("Could not initialize AdBlockerWebviewController: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

// Router Configuration
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Stream IT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414), // Netflix dark
        primaryColor: const Color(0xFFE50914), // Netflix red
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

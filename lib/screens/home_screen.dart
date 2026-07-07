import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/tmdb_service.dart';
import '../services/vidapi_service.dart';
import '../services/recently_watched_service.dart';
import '../widgets/content_carousel.dart';
import '../widgets/poster_card.dart';

final heroBannerProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return service.getHeroBannerContent();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroAsync = ref.watch(heroBannerProvider);
    final moviesAsync = ref.watch(latestMoviesProvider);
    final tvShowsAsync = ref.watch(latestTvShowsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            heroAsync.when(
              data: (item) {
                if (item == null) return const SizedBox(height: 100);
                final backdropPath = item['backdrop_path'];
                final backdropUrl = backdropPath != null
                    ? (backdropPath.startsWith('http')
                          ? backdropPath
                          : 'https://image.tmdb.org/t/p/w1280$backdropPath')
                    : null;
                final title = item['title'] ?? item['name'] ?? 'Featured';
                final overview = item['overview'] ?? '';
                final id = item['id'].toString();
                final mediaType = item['media_type'] ?? 'movie';

                return Stack(
                  children: [
                    Container(
                      height: 480,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: backdropUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(backdropUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: Colors.grey[900],
                      ),
                    ),
                    Container(
                      height: 480,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Color(0xFF141414),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Color(0xCC000000),
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            overview,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  blurRadius: 5.0,
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  'Play',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  context.push('/player/$mediaType/$id');
                                },
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('Info'),
                                onPressed: () {
                                  context.push('/details/$mediaType/$id');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 480,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                ),
              ),
              error: (e, st) => const SizedBox(
                height: 480,
                child: Center(child: Text('Error loading featured content')),
              ),
            ),

            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: Hive.box(
                RecentlyWatchedService.boxName,
              ).listenable(),
              builder: (context, Box box, child) {
                final items = RecentlyWatchedService().getRecentlyWatched();
                if (items.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecentlyWatchedSection(context, items),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            _buildSection(context, 'Latest Movies', moviesAsync, 'movie'),
            const SizedBox(height: 24),
            _buildSection(context, 'Latest TV Shows', tvShowsAsync, 'tv'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyWatchedSection(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Recently Watched',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item['id'].toString();
              final title = (item['title'] ?? 'Unknown').toString();
              final posterUrl = item['posterUrl'] as String?;
              final mediaType = (item['mediaType'] ?? 'movie').toString();

              return PosterCard(
                posterUrl: posterUrl,
                title: title,
                id: id,
                mediaType: mediaType,
                width: 120,
                height: 180,
                onDelete: () async {
                  await RecentlyWatchedService().removeItem(id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    AsyncValue asyncValue,
    String type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        asyncValue.when(
          data: (items) => ContentCarousel(items: items),
          loading: () => const SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
          ),
          error: (e, st) => SizedBox(
            height: 220,
            child: Center(child: Text('Error loading: $e')),
          ),
        ),
      ],
    );
  }
}

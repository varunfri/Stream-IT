import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tmdb_service.dart';
import '../services/vidapi_service.dart';
import '../widgets/shelf_section.dart';
import '../widgets/poster_card.dart';

class TVShowsScreen extends ConsumerWidget {
  const TVShowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestTvShowsProvider);
    final popularAsync = ref.watch(popularTvProvider);
    final topRatedAsync = ref.watch(topRatedTvProvider);
    final airingTodayAsync = ref.watch(airingTodayTvProvider);
    final onAirAsync = ref.watch(onAirTvProvider);
    final animeAsync = ref.watch(animeTvProvider);

    Widget buildShelf(
      String title,
      AsyncValue<List<Map<String, dynamic>>> async,
    ) {
      return async.when(
        data: (items) =>
            ShelfSection(title: title, items: items, mediaType: 'tv'),
        loading: () => ShelfLoading(title: title),
        error: (_, _) => const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF141414),
            floating: true,
            snap: true,
            title: const Text(
              'TV Shows',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TV SHOWS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // ── Latest (VidAPI) ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: latestAsync.when(
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        _RedBar(),
                        SizedBox(width: 8),
                        Text(
                          'Latest Episodes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 195,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return PosterCard(
                          posterUrl: item.posterUrl,
                          title: item.title,
                          id: item.playbackId,
                          mediaType: 'tv',
                          year: item.year,
                        );
                      },
                    ),
                  ),
                ],
              ),
              loading: () => const ShelfLoading(title: 'Latest Episodes'),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),

          // ── TMDB Shelves ─────────────────────────────────────────────
          SliverToBoxAdapter(child: buildShelf('Popular', popularAsync)),
          SliverToBoxAdapter(child: buildShelf('Top Rated', topRatedAsync)),
          SliverToBoxAdapter(
            child: buildShelf('Airing Today', airingTodayAsync),
          ),
          SliverToBoxAdapter(child: buildShelf('Currently On Air', onAirAsync)),
          SliverToBoxAdapter(child: buildShelf('Anime', animeAsync)),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _RedBar extends StatelessWidget {
  const _RedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

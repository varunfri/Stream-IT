import 'package:flutter/material.dart';
import '../widgets/poster_card.dart';

/// A horizontal scrolling shelf with a title header.
/// [items] should be TMDB result maps containing [poster_path], [id],
/// [title] or [name], and optionally [release_date] / [first_air_date].
class ShelfSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String mediaType; // 'movie' or 'tv'
  final bool showTitle;

  const ShelfSection({
    super.key,
    required this.title,
    required this.items,
    required this.mediaType,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
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
              final posterPath = item['poster_path'];
              final posterUrl = posterPath != null
                  ? (posterPath.startsWith('http')
                        ? posterPath
                        : 'https://image.tmdb.org/t/p/w342$posterPath')
                  : null;
              final id = item['id']?.toString() ?? '';
              final itemTitle = (item['title'] ?? item['name'] ?? 'Unknown')
                  .toString();
              final releaseDate =
                  (item['release_date'] ?? item['first_air_date'] ?? '')
                      .toString();
              final year = releaseDate.length >= 4
                  ? releaseDate.substring(0, 4)
                  : null;

              return PosterCard(
                posterUrl: posterUrl,
                title: itemTitle,
                id: id,
                mediaType: mediaType,
                year: year,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Loading placeholder for a shelf
class ShelfLoading extends StatelessWidget {
  final String title;

  const ShelfLoading({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
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
            itemCount: 6,
            itemBuilder: (_, _) => Container(
              width: 120,
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

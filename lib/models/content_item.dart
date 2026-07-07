class ContentItem {
  final String? tmdbId;
  final String? imdbId;
  final String title;
  final String? year;
  final String? posterUrl;
  final String? rating;
  final String? genre;
  final String type; // 'movie' or 'tv'
  final String embedUrl;

  ContentItem({
    this.tmdbId,
    this.imdbId,
    required this.title,
    this.year,
    this.posterUrl,
    this.rating,
    this.genre,
    required this.type,
    required this.embedUrl,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      tmdbId: json['tmdb_id']?.toString(),
      imdbId: json['imdb_id']?.toString(),
      title: json['title'] ?? 'Unknown',
      year: json['year']?.toString(),
      posterUrl: json['poster_url'],
      rating: json['rating']?.toString(),
      genre: json['genre'],
      type: json['type'] ?? 'movie',
      embedUrl: json['embed_url'] ?? '',
    );
  }

  // Helper to get the best ID to use for routing/playback
  String get playbackId => imdbId ?? tmdbId ?? '';
}

class PaginatedResponse {
  final int page;
  final int totalPages;
  final List<ContentItem> items;

  PaginatedResponse({
    required this.page,
    required this.totalPages,
    required this.items,
  });

  factory PaginatedResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedResponse(
      page: json['page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => ContentItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_item.dart';
import '../utils/custom_dns_adapter.dart';
import 'tmdb_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://vidapi.ru/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Apply custom DNS resolution mapping (e.g. mapping vidapi.ru to a custom IP)
  final dnsAdapter = CustomDnsAdapter(
    dnsMap: {
      // Example: 'vidapi.ru': '104.21.23.230',
    },
  );
  dnsAdapter.configure(dio);

  return dio;
});

final vidApiService = Provider<VidApiService>((ref) {
  return VidApiService(ref.watch(dioProvider));
});

// Future Providers for UI state with fallback to TMDB Popular lists
final latestMoviesProvider = FutureProvider<List<ContentItem>>((ref) async {
  try {
    final service = ref.watch(vidApiService);
    return await service.getLatestMovies();
  } catch (e) {
    debugPrint("Failed to load latest movies from vidapi.ru: $e. Falling back to TMDB popular movies...");
    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final popularList = await tmdbService.getSection('/movie/popular');
      return popularList.map((item) {
        final year = item['release_date']?.toString().split('-').first;
        final posterPath = item['poster_path'];
        final posterUrl = posterPath != null
            ? (posterPath.startsWith('http')
                ? posterPath
                : 'https://image.tmdb.org/t/p/w500$posterPath')
            : null;
        return ContentItem(
          tmdbId: item['id']?.toString(),
          title: item['title'] ?? 'Unknown',
          year: year,
          posterUrl: posterUrl,
          rating: item['vote_average']?.toString(),
          type: 'movie',
          embedUrl: '',
        );
      }).toList();
    } catch (fallbackError) {
      debugPrint("TMDB fallback failed: $fallbackError");
      rethrow;
    }
  }
});

final latestTvShowsProvider = FutureProvider<List<ContentItem>>((ref) async {
  try {
    final service = ref.watch(vidApiService);
    return await service.getLatestTvShows();
  } catch (e) {
    debugPrint("Failed to load latest TV shows from vidapi.ru: $e. Falling back to TMDB popular TV shows...");
    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final popularList = await tmdbService.getSection('/tv/popular');
      return popularList.map((item) {
        final year = item['first_air_date']?.toString().split('-').first;
        final posterPath = item['poster_path'];
        final posterUrl = posterPath != null
            ? (posterPath.startsWith('http')
                ? posterPath
                : 'https://image.tmdb.org/t/p/w500$posterPath')
            : null;
        return ContentItem(
          tmdbId: item['id']?.toString(),
          title: item['name'] ?? 'Unknown',
          year: year,
          posterUrl: posterUrl,
          rating: item['vote_average']?.toString(),
          type: 'tv',
          embedUrl: '',
        );
      }).toList();
    } catch (fallbackError) {
      debugPrint("TMDB fallback failed: $fallbackError");
      rethrow;
    }
  }
});

class VidApiService {
  final Dio _dio;

  VidApiService(this._dio);

  Future<List<ContentItem>> getLatestMovies({int page = 1}) async {
    try {
      final response = await _dio.get('movies/latest/page-$page.json');
      if (response.statusCode == 200) {
        final paginated = PaginatedResponse.fromJson(response.data);
        return paginated.items;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load movies: $e');
    }
  }

  Future<List<ContentItem>> getLatestTvShows({int page = 1}) async {
    try {
      final response = await _dio.get('tvshows/latest/page-$page.json');
      if (response.statusCode == 200) {
        final paginated = PaginatedResponse.fromJson(response.data);
        return paginated.items;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load TV shows: $e');
    }
  }
}

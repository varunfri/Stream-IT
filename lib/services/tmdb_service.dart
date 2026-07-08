import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_service.dart';

final tmdbDioProvider = Provider<Dio>((ref) {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');
  const baseUrl = String.fromEnvironment('TMDB_BASE_URL');

  assert(
    apiKey.isNotEmpty,
    'TMDB_API_KEY is not defined. Compile with --dart-define-from-file=config/dev.json',
  );
  assert(
    baseUrl.isNotEmpty,
    'TMDB_BASE_URL is not defined. Compile with --dart-define-from-file=config/dev.json',
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      queryParameters: {'api_key': apiKey, 'language': 'en-US'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  return dio;
});

final tmdbServiceProvider = Provider<TMDBService>((ref) {
  return TMDBService(ref.watch(tmdbDioProvider));
});

// ────────────────────────────────────────────────
// Movie Section Providers
// ────────────────────────────────────────────────
final popularMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/movie/popular');
});

final topRatedMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/movie/top_rated');
});

final nowPlayingMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/movie/now_playing');
});

final upcomingMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/movie/upcoming');
});

final actionMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  // genre id 28 = Action
  return ref
      .watch(tmdbServiceProvider)
      .getSection('/discover/movie', extraParams: {'with_genres': '28'});
});

final comedyMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  // genre id 35 = Comedy
  return ref
      .watch(tmdbServiceProvider)
      .getSection('/discover/movie', extraParams: {'with_genres': '35'});
});

// ────────────────────────────────────────────────
// TV Show Section Providers
// ────────────────────────────────────────────────
final popularTvProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/tv/popular');
});

final topRatedTvProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/tv/top_rated');
});

final airingTodayTvProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(tmdbServiceProvider).getSection('/tv/airing_today');
});

final onAirTvProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(tmdbServiceProvider).getSection('/tv/on_the_air');
});

final animeTvProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // genre id 16 = Animation
  return ref
      .watch(tmdbServiceProvider)
      .getSection('/discover/tv', extraParams: {'with_genres': '16'});
});

// ────────────────────────────────────────────────
// TMDBService
// ────────────────────────────────────────────────
class TMDBService {
  final Dio _dio;

  TMDBService(this._dio);

  // Generic section fetcher used by all section providers above
  Future<List<Map<String, dynamic>>> getSection(
    String endpoint, {
    Map<String, dynamic>? extraParams,
  }) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: extraParams);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['results'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Search movies and TV shows
  Future<List<Map<String, dynamic>>> searchContent(String query) async {
    try {
      if (query.isEmpty) return [];
      final response = await _dio.get(
        '/search/multi',
        queryParameters: {
          'query': query,
          'include_adult': SettingsService().includeAllInSearch,
        },
      );
      if (response.statusCode == 200) {
        final results = List<Map<String, dynamic>>.from(
          response.data['results'],
        );
        return results.where((item) {
          final mediaType = item['media_type'];
          return (mediaType == 'movie' || mediaType == 'tv') &&
              item['poster_path'] != null;
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Get trending content for Hero banner
  Future<Map<String, dynamic>?> getHeroBannerContent() async {
    try {
      final response = await _dio.get('/trending/all/week');
      if (response.statusCode == 200) {
        final List results = response.data['results'];
        if (results.isNotEmpty) {
          return results.firstWhere(
            (item) => item['backdrop_path'] != null,
            orElse: () => results.first,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fetch detailed info for Movie or TV Show (handles TMDB ID and IMDb ID starting with 'tt')
  Future<Map<String, dynamic>?> getContentDetails(
    String id,
    String type,
  ) async {
    try {
      if (id.startsWith('tt')) {
        final response = await _dio.get(
          '/find/$id',
          queryParameters: {'external_source': 'imdb_id'},
        );
        if (response.statusCode == 200) {
          final results = response.data;
          final List movies = results['movie_results'] ?? [];
          final List tvs = results['tv_results'] ?? [];
          if (type == 'movie' && movies.isNotEmpty) {
            return Map<String, dynamic>.from(movies.first);
          } else if (type == 'tv' && tvs.isNotEmpty) {
            return Map<String, dynamic>.from(tvs.first);
          } else if (movies.isNotEmpty) {
            return Map<String, dynamic>.from(movies.first);
          } else if (tvs.isNotEmpty) {
            return Map<String, dynamic>.from(tvs.first);
          }
        }
        return null;
      }

      final response = await _dio.get('/$type/$id');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fetch season episodes
  Future<List<Map<String, dynamic>>> getSeasonEpisodes(
    String tvId,
    int seasonNumber,
  ) async {
    try {
      final response = await _dio.get('/tv/$tvId/season/$seasonNumber');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['episodes']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Fetch watch providers for a movie or TV show
  Future<Map<String, dynamic>?> getWatchProviders(
    String id,
    String type,
  ) async {
    try {
      final response = await _dio.get('/$type/$id/watch/providers');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data['results'] ?? {});
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Search for companies
  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    try {
      if (query.isEmpty) return [];
      final response = await _dio.get(
        '/search/company',
        queryParameters: {'query': query},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['results'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Fetch detailed info for a Company
  Future<Map<String, dynamic>?> getCompanyDetails(String companyId) async {
    try {
      final response = await _dio.get('/company/$companyId');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fetch combined Movie & TV Show content produced by a company (upfront fetch for all pages)
  Future<List<Map<String, dynamic>>> getCompanyContent(String companyId) async {
    final cleanId = companyId.trim();
    final List<Map<String, dynamic>> combined = [];

    Future<List<Map<String, dynamic>>> fetchAllPages(
      String endpoint,
      String mediaType,
    ) async {
      final List<Map<String, dynamic>> results = [];
      try {
        final response = await _dio.get(
          endpoint,
          queryParameters: {
            'with_companies': cleanId,
            'page': 1,
            'include_adult': SettingsService().includeAllInSearch,
          },
        );

        if (response.statusCode == 200) {
          final List page1Results = response.data['results'] ?? [];
          results.addAll(
            page1Results.map((item) {
              final map = Map<String, dynamic>.from(item);
              map['media_type'] = mediaType;
              return map;
            }),
          );

          final totalPages = response.data['total_pages'] ?? 1;

          if (totalPages > 1) {
            final maxPages = totalPages > 25 ? 25 : totalPages;
            final futures = <Future<Response>>[];
            for (int p = 2; p <= maxPages; p++) {
              futures.add(
                _dio.get(
                  endpoint,
                  queryParameters: {
                    'with_companies': cleanId,
                    'page': p,
                    'include_adult': SettingsService().includeAllInSearch,
                  },
                ),
              );
            }

            final responses = await Future.wait(futures);
            for (var resp in responses) {
              if (resp.statusCode == 200) {
                final List pageResults = resp.data['results'] ?? [];
                results.addAll(
                  pageResults.map((item) {
                    final map = Map<String, dynamic>.from(item);
                    map['media_type'] = mediaType;
                    return map;
                  }),
                );
              }
            }
          }
        }
      } catch (e, s) {
        debugPrint('Error fetching all pages for $endpoint: $e');
        debugPrint(s.toString());
      }
      return results;
    }

    final movieResultsFuture = fetchAllPages('/discover/movie', 'movie');
    final tvResultsFuture = fetchAllPages('/discover/tv', 'tv');

    try {
      final outcomes = await Future.wait([movieResultsFuture, tvResultsFuture]);
      combined.addAll(outcomes[0]);
      combined.addAll(outcomes[1]);
    } catch (e, s) {
      debugPrint('Error merging outcomes: $e');
      debugPrint(s.toString());
    }

    return combined;
  }

  // Fetch credits (cast & crew) for movie or TV show
  Future<List<Map<String, dynamic>>> getCredits(String id, String type) async {
    try {
      final response = await _dio.get('/$type/$id/credits');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['cast'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Fetch detailed info for a Person (actor/director)
  Future<Map<String, dynamic>?> getPersonDetails(String personId) async {
    try {
      final response = await _dio.get('/person/$personId');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fetch combined credits (movie + TV) for a Person
  Future<List<Map<String, dynamic>>> getPersonCredits(String personId) async {
    try {
      final response = await _dio.get('/person/$personId/combined_credits');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['cast'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_item.dart';
import '../utils/custom_dns_adapter.dart';

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

// Future Providers for UI state
final latestMoviesProvider = FutureProvider<List<ContentItem>>((ref) async {
  final service = ref.watch(vidApiService);
  return service.getLatestMovies();
});

final latestTvShowsProvider = FutureProvider<List<ContentItem>>((ref) async {
  final service = ref.watch(vidApiService);
  return service.getLatestTvShows();
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

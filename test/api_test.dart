// ignore_for_file: avoid_print
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vid_api/services/tmdb_service.dart';

void main() {
  test('test company content sorting', () async {
    await dotenv.load(fileName: ".env");
    final container = ProviderContainer();
    final service = container.read(tmdbServiceProvider);
    
    final results = await service.getCompanyContent('420'); // Marvel Studios
    print('Before sorting: ${results.length} items');
    
    try {
      results.sort((a, b) {
        final dateA = a['media_type'] == 'movie'
            ? (a['release_date'] ?? '')
            : (a['first_air_date'] ?? '');
        final dateB = b['media_type'] == 'movie'
            ? (b['release_date'] ?? '')
            : (b['first_air_date'] ?? '');

        if (dateA.isEmpty && dateB.isEmpty) return 0;
        if (dateA.isEmpty) return 1;
        if (dateB.isEmpty) return -1;

        return dateB.compareTo(dateA);
      });
      print('Sorted successfully!');
      for (var r in results.take(5)) {
        final date = r['media_type'] == 'movie' ? r['release_date'] : r['first_air_date'];
        print('- ${r['title'] ?? r['name']} ($date)');
      }
    } catch (e, s) {
      print('Sort Error: $e');
      print(s);
    }
  });
}

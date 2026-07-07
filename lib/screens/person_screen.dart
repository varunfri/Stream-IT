import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/tmdb_service.dart';
import '../widgets/poster_card.dart';

class PersonScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends ConsumerState<PersonScreen> {
  Map<String, dynamic>? _personDetails;
  List<Map<String, dynamic>> _credits = [];
  bool _isLoading = true;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchPersonData();
  }

  Future<void> _fetchPersonData() async {
    final service = ref.read(tmdbServiceProvider);
    
    // Fetch details and credits in parallel
    final detailsFuture = service.getPersonDetails(widget.personId);
    final creditsFuture = service.getPersonCredits(widget.personId);
    
    final results = await Future.wait([detailsFuture, creditsFuture]);
    
    if (mounted) {
      setState(() {
        _personDetails = results[0] as Map<String, dynamic>?;
        _credits = List<Map<String, dynamic>>.from(results[1] as List);
        
        // Filter out credits that lack a poster path or title/name, and remove duplicates by ID
        final Map<String, Map<String, dynamic>> uniqueCredits = {};
        for (var item in _credits) {
          final id = item['id']?.toString();
          if (id != null && item['poster_path'] != null) {
            uniqueCredits[id] = item;
          }
        }
        _credits = uniqueCredits.values.toList();
        
        // Sort by popularity/vote count or releasing year (default: popularity/vote_count or releasing date descending)
        _credits.sort((a, b) {
          final dateA = a['media_type'] == 'movie'
              ? (a['release_date'] ?? '')
              : (a['first_air_date'] ?? '');
          final dateB = b['media_type'] == 'movie'
              ? (b['release_date'] ?? '')
              : (b['first_air_date'] ?? '');

          if (dateA.isEmpty && dateB.isEmpty) return 0;
          if (dateA.isEmpty) return 1;
          if (dateB.isEmpty) return -1;

          return dateB.compareTo(dateA); // Newest first
        });
        
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (_personDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF141414),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text(
            'Could not load actor details.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final name = _personDetails!['name'] ?? 'Unknown Actor';
    final profilePath = _personDetails!['profile_path'];
    final profileUrl = profilePath != null ? 'https://image.tmdb.org/t/p/h632$profilePath' : null;
    final biography = _personDetails!['biography'] ?? '';
    final birthday = _personDetails!['birthday'] ?? '';
    final placeOfBirth = _personDetails!['place_of_birth'] ?? '';
    final knownFor = _personDetails!['known_for_department'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Actor Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 110,
                          height: 160,
                          color: const Color(0xFF2A2A2A),
                          child: profileUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: profileUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE50914)),
                                  ),
                                  errorWidget: (c, u, e) => const Icon(Icons.person, size: 50, color: Colors.grey),
                                )
                              : const Icon(Icons.person, size: 50, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Meta details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (knownFor.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Role: $knownFor',
                                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                            if (birthday.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Born: $birthday',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                            if (placeOfBirth.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'From: $placeOfBirth',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (biography.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Biography',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isBioExpanded = !_isBioExpanded;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            biography,
                            maxLines: _isBioExpanded ? null : 4,
                            overflow: _isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isBioExpanded ? 'Read Less' : 'Read More',
                            style: const TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Known For',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Combined credits grid
          _credits.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No content found for this actor',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _credits[index];
                        final id = item['id'].toString();
                        final mediaType = item['media_type'] ?? 'movie';
                        final posterPath = item['poster_path'];
                        final posterUrl = posterPath != null
                            ? (posterPath.startsWith('http')
                                ? posterPath
                                : 'https://image.tmdb.org/t/p/w342$posterPath')
                            : null;
                        final title = (item['title'] ?? item['name'] ?? 'Unknown').toString();
                        final releaseDate = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
                        final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;

                        return PosterCard(
                          posterUrl: posterUrl,
                          title: title,
                          id: id,
                          mediaType: mediaType,
                          year: year,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                      childCount: _credits.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }
}

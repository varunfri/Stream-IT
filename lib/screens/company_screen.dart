import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/tmdb_service.dart';
import '../widgets/poster_card.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  final String companyId;

  const CompanyScreen({super.key, required this.companyId});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  Map<String, dynamic>? _companyDetails;
  List<Map<String, dynamic>> _content = [];
  bool _isLoading = true;
  bool _isDescending = true; // Default: Newest first

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
  }

  Future<void> _fetchCompanyData() async {
    final service = ref.read(tmdbServiceProvider);
    
    // Fetch details and content in parallel
    final detailsFuture = service.getCompanyDetails(widget.companyId);
    final contentFuture = service.getCompanyContent(widget.companyId);
    
    final results = await Future.wait([detailsFuture, contentFuture]);
    
    if (mounted) {
      setState(() {
        _companyDetails = results[0] as Map<String, dynamic>?;
        _content = List<Map<String, dynamic>>.from(results[1] as List);
        _sortContent();
        _isLoading = false;
      });
    }
  }

  void _sortContent() {
    _content.sort((a, b) {
      final dateA = a['media_type'] == 'movie'
          ? (a['release_date'] ?? '')
          : (a['first_air_date'] ?? '');
      final dateB = b['media_type'] == 'movie'
          ? (b['release_date'] ?? '')
          : (b['first_air_date'] ?? '');

      if (dateA.isEmpty && dateB.isEmpty) return 0;
      if (dateA.isEmpty) return 1;
      if (dateB.isEmpty) return -1;

      return _isDescending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });
  }

  void _toggleSort() {
    setState(() {
      _isDescending = !_isDescending;
      _sortContent();
    });
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

    if (_companyDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF141414),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text(
            'Could not load company details.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final name = _companyDetails!['name'] ?? 'Unknown Company';
    final logoPath = _companyDetails!['logo_path'];
    final logoUrl = logoPath != null ? 'https://image.tmdb.org/t/p/w300$logoPath' : null;
    final headquarters = _companyDetails!['headquarters'] ?? '';
    final originCountry = _companyDetails!['origin_country'] ?? '';

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
          // Company info header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo container
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: logoUrl != null ? Colors.white : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: logoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.contain,
                                errorWidget: (c, u, e) => const Icon(Icons.business, size: 40, color: Colors.grey),
                              )
                            : const Icon(Icons.business, size: 40, color: Colors.white70),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (originCountry.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Origin Country: $originCountry',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                            if (headquarters.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'HQ: $headquarters',
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Content (${_content.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      // Sort Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: Icon(
                          _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                        ),
                        label: Text(
                          'Year: ${_isDescending ? "Newest" : "Oldest"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _toggleSort,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Content grid
          _content.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No content found for this company',
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
                        final item = _content[index];
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
                      childCount: _content.length,
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

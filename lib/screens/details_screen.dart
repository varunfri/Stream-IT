import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../services/speed_service.dart';
import '../services/uiiu_service.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String type; // 'movie' or 'tv'
  final String id;

  const DetailsScreen({super.key, required this.type, required this.id});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _watchProviders = [];
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, String>> _speedPornServers = [];
  List<Map<String, String>> _uiiUMovieServers = [];
  bool _isLoading = true;
  bool _isSpeedPornAvailable = false;
  bool _isUiiUMovieAvailable = false;
  bool _areStreamersExpanded = false;
  int _selectedSeason = 1;
  int _numberOfSeasons = 1;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final service = ref.read(tmdbServiceProvider);
    final details = await service.getContentDetails(widget.id, widget.type);

    if (details != null) {
      final tmdbId = details['id']?.toString() ?? widget.id;

      // Parallel fetch credits, watch providers, SpeedPorn and UiiUMovie availability
      final creditsFuture = service.getCredits(tmdbId, widget.type);
      final providersFuture = service.getWatchProviders(tmdbId, widget.type);

      final title = details['title'] ?? details['name'] ?? '';
      final year = details['release_date']?.toString().split('-').first ?? '';

      Future<List<Map<String, String>>> speedPornFuture = Future.value([]);
      Future<List<Map<String, String>>> uiiumovieFuture = Future.value([]);

      if (title.isNotEmpty) {
        final slug = title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), '-');
        speedPornFuture = ref
            .read(speedPornServiceProvider)
            .fetchEmbedServers(title);

        if (year.isNotEmpty) {
          uiiumovieFuture = ref
              .read(uiiUMovieServiceProvider)
              .fetchEmbedServers(slug, year);
        }
      }

      final results = await Future.wait([
        creditsFuture,
        providersFuture,
        speedPornFuture,
        uiiumovieFuture,
      ]);
      final credits = results[0] as List<Map<String, dynamic>>;
      final providersData = results[1] as Map<String, dynamic>?;
      final speedPornServers = results[2] as List<Map<String, String>>;
      final uiiumovieServers = results[3] as List<Map<String, String>>;

      if (mounted) {
        setState(() {
          _cast = credits;
          _speedPornServers = speedPornServers;
          _uiiUMovieServers = uiiumovieServers;
          _isSpeedPornAvailable = speedPornServers.isNotEmpty;
          _isUiiUMovieAvailable = uiiumovieServers.isNotEmpty;
        });
      }

      if (providersData != null) {
        final List<Map<String, dynamic>> platforms = [];
        Map<String, dynamic>? regionData;
        if (providersData.containsKey('US')) {
          regionData = providersData['US'];
        } else if (providersData.isNotEmpty) {
          regionData = providersData.values.first;
        }

        if (regionData != null) {
          final flatrate = regionData['flatrate'] as List?;
          if (flatrate != null) {
            platforms.addAll(flatrate.map((e) => Map<String, dynamic>.from(e)));
          }
          final free = regionData['free'] as List?;
          if (free != null) {
            platforms.addAll(free.map((e) => Map<String, dynamic>.from(e)));
          }
        }

        if (mounted) {
          setState(() {
            _watchProviders = platforms;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
        if (widget.type == 'tv' && details != null) {
          _numberOfSeasons = details['number_of_seasons'] ?? 1;
          _fetchEpisodes(1);
        }
      });
    }
  }

  Future<void> _fetchEpisodes(int seasonNum) async {
    final service = ref.read(tmdbServiceProvider);
    final episodes = await service.getSeasonEpisodes(widget.id, seasonNum);
    if (mounted) {
      setState(() {
        _episodes = episodes;
      });
    }
  }

  void _showEnlargedBackdrop(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 60),
                  ),
                ),
              ),
              Positioned(
                top: -16,
                right: -16,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (_details == null) {
      // Fallback UI if TMDB details fails
      return Scaffold(
        appBar: AppBar(title: const Text('Back')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not fetch details from TMDB.'),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                ),
                onPressed: () =>
                    context.push('/player/${widget.type}/${widget.id}'),
                child: const Text('Play Directly'),
              ),
            ],
          ),
        ),
      );
    }

    final backdropPath = _details!['backdrop_path'];
    final backdropUrl = backdropPath != null
        ? (backdropPath.startsWith('http')
              ? backdropPath
              : 'https://image.tmdb.org/t/p/w1280$backdropPath')
        : null;
    final title = _details!['title'] ?? _details!['name'] ?? 'Unknown';
    final releaseDate =
        _details!['release_date'] ?? _details!['first_air_date'] ?? '';
    final year = releaseDate.isNotEmpty ? releaseDate.substring(0, 4) : '';
    final rating = _details!['vote_average']?.toStringAsFixed(1) ?? 'N/A';
    final overview = _details!['overview'] ?? '';
    final genresList = List.from(_details!['genres'] ?? []);
    final genres = genresList.map((g) => g['name']).join(', ');

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backdrop and Title
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (backdropUrl != null) {
                      _showEnlargedBackdrop(
                        context,
                        backdropUrl,
                        title.toString(),
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: backdropUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    backdropUrl,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey[900],
                        ),
                      ),
                      Container(
                        height: 300,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF141414)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),

            // Content details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (year.isNotEmpty) ...[
                        Text(
                          year,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.type == 'movie' ? 'MOVIE' : 'TV SHOW',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isSpeedPornAvailable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPEEDPORN AVAILABLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (_isUiiUMovieAvailable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'UIIUMOVIE AVAILABLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.type == 'movie') ...[
                    const Text(
                      'Streamers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(() {
                      final List<Map<String, String>> streamers = [];
                      for (var s in _speedPornServers) {
                        streamers.add({
                          'name': s['name'] ?? 'SpeedPorn Server',
                          'url': s['embedUrl']!,
                          'icon': s['iconUrl'] ?? '',
                        });
                      }
                      for (var s in _uiiUMovieServers) {
                        streamers.add({
                          'name': s['name'] ?? 'UiiUMovie Server',
                          'url': s['embedUrl']!,
                          'icon': s['iconUrl'] ?? '',
                        });
                      }
                      final mainServer = {
                        'name': 'Main Server',
                        'url':
                            'https://vaplayer.ru/embed/movie/${widget.id}?primaryColor=%23E50914',
                        'icon': 'asset',
                      };

                      if (streamers.length >= 2) {
                        streamers.add(mainServer);
                      } else {
                        streamers.insert(0, mainServer);
                      }

                      final showExpandButton = streamers.length > 2;
                      final visibleStreamers =
                          (showExpandButton && !_areStreamersExpanded)
                          ? streamers.take(2).toList()
                          : streamers;

                      final List<Widget> children = [];
                      for (var s in visibleStreamers) {
                        children.add(
                          GestureDetector(
                            onTap: () {
                              final encodedUrl = Uri.encodeComponent(s['url']!);
                              context.push(
                                '/player/movie/${widget.id}?url=$encodedUrl',
                              );
                            },
                            child: Column(
                              crossAxisAlignment: .center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1A1A1A),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: s['icon'] == 'asset'
                                        ? Image.asset(
                                            'assets/app_icon.png',
                                            fit: BoxFit.cover,
                                          )
                                        : (s['icon'] != null &&
                                              s['icon']!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: s['icon']!,
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) =>
                                                const Icon(
                                                  Icons.play_arrow,
                                                  color: Color(0xFFE50914),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                                      Icons.play_arrow,
                                                      color: Color(0xFFE50914),
                                                    ),
                                          )
                                        : const Icon(
                                            Icons.play_arrow,
                                            color: Color(0xFFE50914),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    s['name']!,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (showExpandButton) {
                        children.add(
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _areStreamersExpanded = !_areStreamersExpanded;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: .center,
                              crossAxisAlignment: .center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1A1A1A),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    _areStreamersExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.more_horiz,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    _areStreamersExpanded ? 'Less' : 'More',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return [
                        Wrap(spacing: 14, runSpacing: 14, children: children),
                      ];
                    })(),
                    const SizedBox(height: 16),
                  ],
                  if (genres.isNotEmpty) ...[
                    Text(
                      genres,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    overview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_watchProviders.isNotEmpty) ...[
                    const Text(
                      'Available to Stream On',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _watchProviders.length,
                        itemBuilder: (context, index) {
                          final provider = _watchProviders[index];
                          final logoPath = provider['logo_path'];
                          final logoUrl = logoPath != null
                              ? 'https://image.tmdb.org/t/p/w154$logoPath'
                              : null;
                          final providerName = provider['provider_name'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Tooltip(
                              message: providerName,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  image: logoUrl != null
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            logoUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: logoUrl == null
                                    ? Center(
                                        child: Text(
                                          providerName.isNotEmpty
                                              ? providerName[0]
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_cast.isNotEmpty) ...[
                    const Text(
                      'Cast',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cast.length,
                        itemBuilder: (context, index) {
                          final actor = _cast[index];
                          final profilePath = actor['profile_path'];
                          final profileUrl = profilePath != null
                              ? 'https://image.tmdb.org/t/p/w185$profilePath'
                              : null;
                          final actorName = actor['name'] ?? '';
                          final characterName = actor['character'] ?? '';
                          final actorId = actor['id'].toString();

                          return GestureDetector(
                            onTap: () => context.push('/person/$actorId'),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              width: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF2A2A2A),
                                      border: Border.all(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                      image: profileUrl != null
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                profileUrl,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: profileUrl == null
                                        ? const Center(
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white70,
                                              size: 24,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    actorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    characterName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_details != null &&
                      _details!['production_companies'] != null &&
                      (_details!['production_companies'] as List)
                          .isNotEmpty) ...[
                    const Text(
                      'Production Companies',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            (_details!['production_companies'] as List).length,
                        itemBuilder: (context, index) {
                          final company =
                              _details!['production_companies'][index];
                          final logoPath = company['logo_path'];
                          final logoUrl = logoPath != null
                              ? 'https://image.tmdb.org/t/p/w154$logoPath'
                              : null;
                          final companyName = company['name'] ?? '';
                          final companyId = company['id'].toString();

                          return InkWell(
                            onTap: () => context.push('/company/$companyId'),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Tooltip(
                                message: companyName,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: logoUrl != null
                                        ? Colors.white
                                        : const Color(0xFF2A2A2A),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    image: logoUrl != null
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                              logoUrl,
                                            ),
                                            fit: BoxFit.contain,
                                          )
                                        : null,
                                  ),
                                  child: logoUrl == null
                                      ? Center(
                                          child: Text(
                                            companyName.isNotEmpty
                                                ? companyName[0]
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // If TV Show, show Season selector and Episodes list
                  if (widget.type == 'tv') ...[
                    Row(
                      children: [
                        const Text(
                          'Season: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<int>(
                          value: _selectedSeason,
                          dropdownColor: const Color(0xFF141414),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          items:
                              List.generate(
                                    _numberOfSeasons,
                                    (index) => index + 1,
                                  )
                                  .map(
                                    (season) => DropdownMenuItem(
                                      value: season,
                                      child: Text('Season $season'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSeason = val;
                              });
                              _fetchEpisodes(val);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _episodes.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE50914),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _episodes.length,
                            separatorBuilder: (context, index) =>
                                const Divider(color: Colors.grey),
                            itemBuilder: (context, index) {
                              final ep = _episodes[index];
                              final epNum = ep['episode_number'];
                              final epTitle = ep['name'] ?? 'Episode $epNum';
                              final epOverview = ep['overview'] ?? '';
                              final stillPath = ep['still_path'];
                              final stillUrl = stillPath != null
                                  ? (stillPath.startsWith('http')
                                        ? stillPath
                                        : 'https://image.tmdb.org/t/p/w300$stillPath')
                                  : null;

                              return InkWell(
                                onTap: () {
                                  // Navigate to player with season & episode in route parameters or query params.
                                  // We can handle dynamic season and episode numbers.
                                  context.push(
                                    '/player/tv/${widget.id}?season=$_selectedSeason&episode=$epNum',
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          image: stillUrl != null
                                              ? DecorationImage(
                                                  image:
                                                      CachedNetworkImageProvider(
                                                        stillUrl,
                                                      ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                          color: Colors.grey[900],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: stillUrl == null
                                            ? const Icon(
                                                Icons.play_circle_outline,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$epNum. $epTitle',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              epOverview,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

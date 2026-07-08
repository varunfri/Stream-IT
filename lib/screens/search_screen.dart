import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/tmdb_service.dart';
import '../services/search_history_service.dart';
import '../services/settings_service.dart';
import '../widgets/poster_card.dart';
import 'package:local_auth/local_auth.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchHistoryService _historyService = SearchHistoryService();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _companyResults = [];
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = _historyService.getHistory();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
          _companyResults = [];
          _isLoading = false;
        });
        return;
      }
      setState(() => _isLoading = true);
      final service = ref.read(tmdbServiceProvider);
      final contentFuture = service.searchContent(query);
      final companiesFuture = service.searchCompanies(query);
      final results = await Future.wait([contentFuture, companiesFuture]);
      if (mounted) {
        setState(() {
          _searchResults = results[0];
          _companyResults = results[1];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _deleteHistoryItem(String id) async {
    await _historyService.removeItem(id);
    _loadHistory();
  }

  Future<void> _clearAllHistory() async {
    await _historyService.clearAll();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search result grid ─────────────────────────────────────────────────
  Widget _buildResultsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final posterPath = item['poster_path'];
        final posterUrl = posterPath != null
            ? (posterPath.startsWith('http')
                  ? posterPath
                  : 'https://image.tmdb.org/t/p/w342$posterPath')
            : null;
        final mediaType = item['media_type'] ?? 'movie';
        final id = item['id'].toString();
        final title = (item['title'] ?? item['name'] ?? 'Unknown').toString();
        final releaseDate =
            (item['release_date'] ?? item['first_air_date'] ?? '').toString();
        final year = releaseDate.length >= 4
            ? releaseDate.substring(0, 4)
            : null;

        return PosterCard(
          posterUrl: posterUrl,
          title: title,
          id: id,
          mediaType: mediaType,
          year: year,
          width: double.infinity,
          height: double.infinity,
          onTap: () async {
            await _historyService.addItem(
              id: id,
              title: title,
              posterUrl: posterUrl,
              mediaType: mediaType,
            );
            _loadHistory();
          },
        );
      },
    );
  }

  // ── Recent searches panel ──────────────────────────────────────────────
  Widget _buildHistoryPanel() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 72, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Search for movies or TV shows',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
          child: Row(
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllHistory,
                child: const Text(
                  'Clear all',
                  style: TextStyle(color: Color(0xFFE50914), fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Horizontal poster strip
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final h = _history[index];
              final posterUrl = h['posterUrl'] as String?;
              final id = h['id'] as String;
              final title = (h['title'] ?? '').toString();
              final mediaType = (h['mediaType'] ?? 'movie').toString();

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/details/$mediaType/$id'),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (_, _) => Container(
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                      errorWidget: (_, _, _) => Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: const Icon(Icons.movie),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF1E1E1E),
                                      child: const Icon(Icons.movie),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Delete button
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _deleteHistoryItem(id),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE50914),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // List of recent search titles
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'History',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final h = _history[index];
              final id = h['id'] as String;
              final title = (h['title'] ?? '').toString();
              final mediaType = (h['mediaType'] ?? 'movie').toString();
              final posterUrl = h['posterUrl'] as String?;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 40,
                    height: 56,
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF1E1E1E),
                            child: const Icon(Icons.movie, size: 20),
                          ),
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  mediaType == 'tv' ? 'TV Show' : 'Movie',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: () => context.push('/details/$mediaType/$id'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _companyResults.length,
      itemBuilder: (context, index) {
        final company = _companyResults[index];
        final logoPath = company['logo_path'];
        final logoUrl = logoPath != null
            ? 'https://image.tmdb.org/t/p/w300$logoPath'
            : null;
        final name = company['name'] ?? 'Unknown Company';
        final id = company['id'].toString();

        return InkWell(
          onTap: () => context.push('/company/$id'),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: logoUrl != null
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: logoUrl,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.business,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.business,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final settings = SettingsService();

            Future<void> handleLockToggle(bool value) async {
              final auth = LocalAuthentication();
              try {
                final bool canAuthenticateWithBiometrics =
                    await auth.canCheckBiometrics;
                final bool canAuthenticate =
                    canAuthenticateWithBiometrics ||
                    await auth.isDeviceSupported();

                if (!canAuthenticate) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Device security / lock not set up or supported.',
                        ),
                      ),
                    );
                  }
                  return;
                }

                final bool didAuthenticate = await auth.authenticate(
                  localizedReason: value
                      ? 'Authenticate to enable app lock'
                      : 'Authenticate to disable app lock',
                  biometricOnly: false,
                );

                if (didAuthenticate) {
                  settings.isLockEnabled = value;
                  setDialogState(() {});
                }
              } catch (e) {
                debugPrint('LocalAuth error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Not able to Authenticate.')),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFFE50914)),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFE50914),
                      title: const Text(
                        'Include Adult Content',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Include adult (18+) movies/shows in search results',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      value: settings.includeAllInSearch,
                      onChanged: (val) {
                        settings.includeAllInSearch = val;
                        setDialogState(() {});
                      },
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFE50914),
                      title: const Text(
                        'Use Custom Connection Adapter',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Enable DoH and static bypasses for blocked endpoints',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      value: settings.useCustomAdapter,
                      onChanged: (val) {
                        settings.useCustomAdapter = val;
                        setDialogState(() {});
                      },
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFFE50914),
                      title: const Text(
                        'Screen Lock Protection',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Require fingerprint/PIN/pattern to access the app',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      value: settings.isLockEnabled,
                      onChanged: (val) {
                        handleLockToggle(val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Color(0xFFE50914),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        titleSpacing: 0,
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search movies, TV shows…',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              // prefixIcon: IconButton(
              //   icon: const Icon(Icons.settings, color: Colors.grey),
              //   onPressed: () => _showSettingsDialog(context),
              // ),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        setState(() {
                          _selectedTabIndex = 0;
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.settings, color: Colors.grey),
                      onPressed: () => _showSettingsDialog(context),
                    ),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) {
              _onSearchChanged(v);
              setState(() {});
            },
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : isSearching
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        0,
                        'Movies & TV (${_searchResults.length})',
                      ),
                      const SizedBox(width: 16),
                      _buildTabButton(
                        1,
                        'Companies (${_companyResults.length})',
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: _selectedTabIndex == 0
                      ? (_searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  'No results found',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : _buildResultsGrid())
                      : (_companyResults.isEmpty
                            ? Center(
                                child: Text(
                                  'No companies found',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : _buildCompanyGrid()),
                ),
              ],
            )
          : _buildHistoryPanel(),
    );
  }
}

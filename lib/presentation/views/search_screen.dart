import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';
import 'package:cinemax_seat_booking/presentation/views/movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _allMovies = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAllMovies();
  }

  Future<void> _loadAllMovies() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final popular = await TmdbService.getPopularMovies();
      final nowPlaying = await TmdbService.getNowPlaying();
      _allMovies = [...popular, ...nowPlaying];
      // Remove duplicates by ID
      final seen = <int>{};
      _allMovies = _allMovies.where((m) => seen.add(m['id'])).toList();
    } catch (e) {
      print('Error loading movies: $e');
      _allMovies = [];
      _loadError = 'Failed to load movies from API.';
    }
    setState(() => _isLoading = false);
  }

  void _searchMovies(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _hasSearched = true;
      _searchResults = _allMovies.where((movie) {
        final title = (movie['title'] ?? '').toString().toLowerCase();
        return title.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.42;
    final cardHeight = cardWidth * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Movies',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchMovies,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by movie name...',
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchMovies('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE50914)),
                    )
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _loadError!,
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadAllMovies,
                                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE50914)),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                  : _hasSearched && _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                color: Colors.grey.withOpacity(0.5),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No movies found',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : !_hasSearched
                          ? _buildTrendingSection(cardWidth, cardHeight)
                          : _buildSearchResults(cardWidth, cardHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection(double cardWidth, double cardHeight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight + 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _allMovies.take(10).length,
              itemBuilder: (context, index) {
                final movie = _allMovies[index];
                return _movieCard(
                  imageUrl: movie['poster_path'] != null
                      ? TmdbService.getImageUrl(movie['poster_path'])
                      : '',
                  title: movie['title'] ?? 'Unknown',
                  rating: (movie['vote_average'] as num? ?? 0.0).toStringAsFixed(1),
                  movie: movie,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(double cardWidth, double cardHeight) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardWidth / (cardHeight + 65),
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        return _movieCard(
          imageUrl: movie['poster_path'] != null
              ? TmdbService.getImageUrl(movie['poster_path'])
              : '',
          title: movie['title'] ?? 'Unknown',
          rating: (movie['vote_average'] as num? ?? 0.0).toStringAsFixed(1),
          movie: movie,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
        );
      },
    );
  }

  Widget _movieCard({
    required String imageUrl,
    required String title,
    required String rating,
    required Map<String, dynamic> movie,
    required double cardWidth,
    required double cardHeight,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(
              movie: movie,
              preselectedCinema: null,
            ),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: cardHeight,
                width: cardWidth,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: cardHeight,
                    width: cardWidth,
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: cardHeight,
                  width: cardWidth,
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 3),
                Text(
                  rating,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
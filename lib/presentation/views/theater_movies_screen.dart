import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/presentation/views/movie_detail_screen.dart';

class TheaterMoviesScreen extends StatefulWidget {
  final String cinemaName;
  final String cinemaImage;

  const TheaterMoviesScreen({
    super.key,
    required this.cinemaName,
    required this.cinemaImage,
  });

  @override
  State<TheaterMoviesScreen> createState() => _TheaterMoviesScreenState();
}

class _TheaterMoviesScreenState extends State<TheaterMoviesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _movies = [];

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('movies')
          .where('cinemaName', isEqualTo: widget.cinemaName)
          .where('status', isEqualTo: 'active')
          .get();

      _movies = snapshot.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      print('DEBUG: Loaded ${_movies.length} movies for ${widget.cinemaName}');
    } catch (e) {
      print('Error loading movies: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.42;
    final cardHeight = cardWidth * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          widget.cinemaName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cinema Header
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: AssetImage(widget.cinemaImage),
                        fit: BoxFit.cover,
                        opacity: 0.6,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cinemaName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_movies.length} Movie${_movies.length != 1 ? 's' : ''} Showing',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Movies Grid — EXACTLY like home screen cards
                  if (_movies.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.movie_outlined, color: Colors.grey, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'No movies currently showing',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Check back later!',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: cardHeight + 80, // Extra space for text below
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _movies.length,
                        itemBuilder: (context, index) {
                          final movie = _movies[index];
                          return _movieCard(
                            imageUrl: movie['posterUrl'] ?? '',
                            title: movie['movieName'] ?? 'Unknown',
                            rating: '${movie['rating'] ?? '-'}',
                            duration: movie['duration'] ?? '',
                            showTimes: List<String>.from(movie['showTimes'] ?? []),
                            movie: movie,
                            context: context,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // EXACT same style as home screen movie card
  Widget _movieCard({
    required String imageUrl,
    required String title,
    required String rating,
    required String duration,
    required List<String> showTimes,
    required Map<String, dynamic> movie,
    required BuildContext context,
    required double cardWidth,
    required double cardHeight,
  }) {
    return GestureDetector(
      onTap: () {
        // Build TMDB-compatible movie object
        final tmdbMovie = {
          'id': movie['movieId'],
          'title': movie['movieName'],
          'poster_path': movie['posterUrl']?.replaceAll(
            'https://image.tmdb.org/t/p/w500',
            '',
          ),
          'backdrop_path': movie['backdropUrl']?.replaceAll(
            'https://image.tmdb.org/t/p/w500',
            '',
          ),
          'vote_average': movie['rating'],
          'overview': '',
          'release_date': movie['releaseDate'],
          'duration': movie['duration'],
          'showTimes': movie['showTimes'],
        };

        // Navigate DIRECTLY to showtime selection, skip MovieDetailScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(
              movie: tmdbMovie,
              preselectedCinema: widget.cinemaName,
              preselectedShowTimes: showTimes,
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
            // Poster
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
            // Title
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
            // Rating and Duration row
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 3),
                Text(
                  rating,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.schedule, color: Colors.grey, size: 11),
                const SizedBox(width: 3),
                Text(
                  duration,
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
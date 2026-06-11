import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';
import 'package:cinemax_seat_booking/presentation/views/movie_detail_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/notification_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/theater_movies_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _notificationCount = 0;

  // Available movies loaded from Firestore (admin-curated per theater, deduped) for "Now Playing In Theaters"
  List<Map<String, dynamic>> _availableMovies = [];
  bool _isLoadingAvailable = true;
  String? _availableMoviesError;

  // Trending movies from TMDB API
  List<dynamic> _trendingMovies = [];
  bool _isLoadingTrending = true;

  static const List<Map<String, String>> _theaters = [
    {
      'name': 'Archana Cinema',
      'image': 'assets/images/theaters/archana.jfif',
      'location': 'Akkaraipattu',
    },
    {
      'name': 'GK Cinemax',
      'image': 'assets/images/theaters/gk.jfif',
      'location': 'Kalmunai',
    },
    {
      'name': 'PCA Cinemas',
      'image': 'assets/images/theaters/pca.jfif',
      'location': 'Kattankudy',
    },
    {
      'name': 'Shanthi Cinema',
      'image': 'assets/images/theaters/shanthi.jpeg',
      'location': 'Batticaloa',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _loadAvailableMovies();
    _loadTrendingMovies();
  }

  Future<void> _loadNotificationCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _notificationCount = 0);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewedStr = prefs.getString('last_notification_viewed');
      final lastViewed = lastViewedStr != null
          ? DateTime.parse(lastViewedStr)
          : DateTime.fromMillisecondsSinceEpoch(0);

      // Count only bookings created after last view (unread notifications)
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastViewed))
          .get();
      setState(() => _notificationCount = snap.docs.length);
    } catch (e) {
      print('Error loading notification count: $e');
      setState(() => _notificationCount = 0);
    }
  }

  Future<void> _loadAvailableMovies() async {
    setState(() {
      _isLoadingAvailable = true;
      _availableMoviesError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('movies')
          .where('status', isEqualTo: 'active')
          .get();

      final Map<dynamic, Future<Map<String, dynamic>>> enrichFutures = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final mid = data['movieId'];
        if (mid != null && !enrichFutures.containsKey(mid)) {
          enrichFutures[mid] = _enrichMovieWithTmdbDetails(data);
        }
      }

      final results = await Future.wait(enrichFutures.values);
      _availableMovies = results;
    } catch (e) {
      print('Error loading available movies for Home: $e');
      _availableMovies = [];
      _availableMoviesError = e.toString().contains('unavailable')
          ? 'Could not load movies (connection issue). Tap retry.'
          : 'Failed to load available movies.';
    }
    if (mounted) setState(() => _isLoadingAvailable = false);
  }

  Future<Map<String, dynamic>> _enrichMovieWithTmdbDetails(Map<String, dynamic> dbData) async {
    final mid = dbData['movieId'];
    final movie = {
      'id': mid,
      'title': dbData['movieName'] ?? 'Unknown',
      'poster_path': (dbData['posterUrl'] as String?)?.replaceAll(
          'https://image.tmdb.org/t/p/w500', ''),
      'backdrop_path': (dbData['backdropUrl'] as String?)?.replaceAll(
          'https://image.tmdb.org/t/p/w500', ''),
      'vote_average': dbData['rating'] ?? 0.0,
      'overview': '',
      'duration': dbData['duration'] ?? '',
      'release_date': dbData['releaseDate'] ?? '',
      'showTimes': dbData['showTimes'] ?? [],
    };

    if (mid != null) {
      try {
        final movieIdInt = mid is int ? mid : int.tryParse(mid.toString());
        if (movieIdInt != null) {
          final details = await TmdbService.getMovieDetails(movieIdInt);
          if (details != null) {
            movie['overview'] = details['overview'] ?? '';
          }
        }
      } catch (e) {
        print('Error fetching TMDB details for movie $mid: $e');
      }
    }
    return movie;
  }

  Future<void> _loadTrendingMovies() async {
    setState(() => _isLoadingTrending = true);
    try {
      _trendingMovies = await TmdbService.getPopularMovies();
    } catch (e) {
      print('Error loading trending movies: $e');
      _trendingMovies = [];
    }
    if (mounted) setState(() => _isLoadingTrending = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'User';
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.36;
    final cardHeight = cardWidth * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello $name!',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationScreen(),
                              ),
                            );
                            _loadNotificationCount(); // Refresh badge on return
                          },
                          icon: const Icon(
                            Icons.notifications,
                            size: 26,
                            color: Colors.grey,
                          ),
                        ),
                        if (_notificationCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE50914),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _notificationCount > 9 ? '9+' : '$_notificationCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text(
                  'Nearby Theaters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _theaters.length,
                    itemBuilder: (context, index) {
                      final theater = _theaters[index];
                      return _theaterCard(
                        screenWidth: screenWidth,
                        imagePath: theater['image']!,
                        name: theater['name']!,
                        location: theater['location']!,
                        context: context,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Trending Movies',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: cardHeight + 65,
                  child: _isLoadingTrending
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : _trendingMovies.isEmpty
                          ? Center(
                              child: Text(
                                'No trending movies available',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _trendingMovies.length,
                              itemBuilder: (context, index) {
                                final movie = _trendingMovies[index];
                                return _movieCard(
                                  imageUrl: movie['poster_path'] != null
                                      ? TmdbService.getImageUrl(movie['poster_path'])
                                      : '',
                                  title: movie['title'] ?? 'Unknown',
                                  rating: (movie['vote_average'] as num? ?? 0.0)
                                      .toStringAsFixed(1),
                                  movie: movie,
                                  context: context,
                                  cardWidth: cardWidth,
                                  cardHeight: cardHeight,
                                );
                              },
                            ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Now Playing in Theaters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: cardHeight + 65,
                  child: _isLoadingAvailable
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : _availableMoviesError != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _availableMoviesError!,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _loadAvailableMovies,
                                    child: const Text('Retry', style: TextStyle(color: Color(0xFFE50914))),
                                  ),
                                ],
                              ),
                            )
                      : _availableMovies.isEmpty
                          ? Center(
                              child: Text(
                                'No movies currently available',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _availableMovies.length,
                              itemBuilder: (context, index) {
                                final movie = _availableMovies[index];
                                final posterPath = movie['poster_path']?.toString();
                                final imageUrl = (posterPath != null && posterPath.isNotEmpty)
                                    ? TmdbService.getImageUrl(posterPath)
                                    : '';
                                return _movieCard(
                                  imageUrl: imageUrl,
                                  title: movie['title'] ?? 'Unknown',
                                  rating: (movie['vote_average'] as num? ?? 0.0)
                                      .toStringAsFixed(1),
                                  movie: movie,
                                  context: context,
                                  cardWidth: cardWidth,
                                  cardHeight: cardHeight,
                                );
                              },
                            ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _theaterCard({
    required double screenWidth,
    required String imagePath,
    required String name,
    required String location,
    required BuildContext context,
  }) {
    final cardWidth = screenWidth * 0.40;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TheaterMoviesScreen(
            cinemaName: name,
            cinemaImage: imagePath,
          ),
        ),
      ),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                imagePath,
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 90,
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.grey, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _movieCard({
    required String imageUrl,
    required String title,
    required String rating,
    required Map<String, dynamic> movie,
    required BuildContext context,
    required double cardWidth,
    required double cardHeight,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            movie: movie,
            preselectedCinema: null,
          ),
        ),
      ),
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
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: cardHeight,
                    width: cardWidth,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
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
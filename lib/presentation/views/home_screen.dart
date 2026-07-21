import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cinemax_seat_booking/presentation/viewmodels/home/home_view_model.dart';
import 'package:cinemax_seat_booking/presentation/views/movie_detail_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/notification_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/theater_movies_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    // Delegate data loading to ViewModel
    Future.microtask(() {
      ref.read(homeViewModelProvider.notifier).loadData();
      // Notification count can also be moved to a separate usecase/VM in full refactor
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'User';
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.36;
    final cardHeight = cardWidth * 1.5;

    // For simplicity in this refactor, notification count is still managed locally in the old way.
    // In a full MVVM, it would be part of HomeState or a separate NotificationViewModel.
    final notificationCount = homeState.notificationCount; // Will be 0 until implemented in VM

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
                            // In full MVVM, the VM would handle refreshing notification state
                          },
                          icon: const Icon(
                            Icons.notifications,
                            size: 26,
                            color: Colors.grey,
                          ),
                        ),
                        if (notificationCount > 0)
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
                                  notificationCount > 9 ? '9+' : '$notificationCount',
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
                  child: homeState.isLoadingTrending
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : homeState.errorTrending != null
                          ? Center(
                              child: Text(
                                homeState.errorTrending!,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : homeState.trendingMovies.isEmpty
                              ? Center(
                                  child: Text(
                                    'No trending movies available',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: homeState.trendingMovies.length,
                                  itemBuilder: (context, index) {
                                    final movie = homeState.trendingMovies[index];
                                    final posterPath = movie.posterPath;
                                    final imageUrl = (posterPath != null && posterPath.isNotEmpty)
                                        ? 'https://image.tmdb.org/t/p/w500$posterPath'
                                        : '';
                                    return _movieCard(
                                      imageUrl: imageUrl,
                                      title: movie.title,
                                      rating: movie.rating.toStringAsFixed(1),
                                      movie: {
                                        'id': movie.id,
                                        'title': movie.title,
                                        'poster_path': movie.posterPath,
                                        'backdrop_path': movie.backdropPath,
                                        'vote_average': movie.rating,
                                        'overview': movie.overview,
                                        'duration': movie.duration,
                                        'release_date': movie.releaseDate,
                                      },
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
                  child: homeState.isLoadingNowPlaying
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : homeState.errorNowPlaying != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    homeState.errorNowPlaying!,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => ref.read(homeViewModelProvider.notifier).loadNowPlayingMovies(),
                                    child: const Text('Retry', style: TextStyle(color: Color(0xFFE50914))),
                                  ),
                                ],
                              ),
                            )
                      : homeState.nowPlayingMovies.isEmpty
                          ? Center(
                              child: Text(
                                'No movies currently available',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: homeState.nowPlayingMovies.length,
                              itemBuilder: (context, index) {
                                final movie = homeState.nowPlayingMovies[index];
                                final posterPath = movie.posterPath;
                                final imageUrl = (posterPath != null && posterPath.isNotEmpty)
                                    ? 'https://image.tmdb.org/t/p/w500$posterPath'
                                    : '';
                                return _movieCard(
                                  imageUrl: imageUrl,
                                  title: movie.title,
                                  rating: movie.rating.toStringAsFixed(1),
                                  movie: {
                                    'id': movie.id,
                                    'title': movie.title,
                                    'poster_path': movie.posterPath,
                                    'backdrop_path': movie.backdropPath,
                                    'vote_average': movie.rating,
                                    'overview': movie.overview,
                                    'duration': movie.duration,
                                    'release_date': movie.releaseDate,
                                    'showTimes': movie.showTimes,
                                    'cinemaName': movie.cinemaName,
                                  },
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
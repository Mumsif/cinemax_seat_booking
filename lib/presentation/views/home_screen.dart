import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';
import 'package:cinemax_seat_booking/presentation/views/movie_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                      "Hello $name!",
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications,
                        size: 26,
                        color: Colors.grey,
                      ),
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
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _theaterCard(screenWidth);
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
                  child: FutureBuilder(
                    future: TmdbService.getPopularMovies(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final movies = snapshot.data!;

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: movies.length,
                        itemBuilder: (context, index) {
                          final movie = movies[index];
                          return _movieCard(
                            imageUrl: movie['poster_path'] != null 
                                ? TmdbService.getImageUrl(movie['poster_path']) 
                                : '',
                            title: movie['title'] ?? 'Unknown',
                            rating: (movie['vote_average'] as num? ?? 0.0).toStringAsFixed(1),
                            movie: movie,
                            context: context,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Currently Showing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: cardHeight + 65,
                  child: FutureBuilder(
                    future: TmdbService.getNowPlaying(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final movies = snapshot.data!;

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: movies.length,
                        itemBuilder: (context, index) {
                          final movie = movies[index];
                          return _movieCard(
                            imageUrl: movie['poster_path'] != null 
                                ? TmdbService.getImageUrl(movie['poster_path']) 
                                : '',
                            title: movie['title'] ?? 'Unknown',
                            rating: (movie['vote_average'] as num? ?? 0.0).toStringAsFixed(1),
                            movie: movie,
                            context: context,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          );
                        },
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

  Widget _theaterCard(double screenWidth) {
    final cardWidth = screenWidth * 0.40;
    return GestureDetector(
      onTap: () {},
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
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: cardWidth * 0.7, color: Colors.grey),
                  const SizedBox(height: 6),
                  Container(height: 10, width: cardWidth * 0.5, color: Colors.grey),
                  const SizedBox(height: 6),
                  Container(height: 10, width: cardWidth * 0.4, color: Colors.grey),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
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
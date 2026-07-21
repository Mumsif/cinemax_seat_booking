import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';

abstract class MovieRepository {
  /// Fetch trending/popular movies from external API (TMDB)
  Future<List<MovieEntity>> getTrendingMovies();

  /// Fetch movies currently scheduled in theaters (from Firestore, active status)
  /// Returns deduplicated list across cinemas, enriched with descriptions
  Future<List<MovieEntity>> getNowPlayingInTheaters();

  /// Get detailed info for a specific movie (used for enrichment or details screen)
  Future<MovieEntity?> getMovieDetails(int movieId);

  /// Get theaters/cinemas where a specific movie is currently active/scheduled
  Future<List<String>> getTheatersForMovie(int movieId);
}

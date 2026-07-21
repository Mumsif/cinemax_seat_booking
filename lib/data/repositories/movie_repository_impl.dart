import 'package:cinemax_seat_booking/data/datasources/remote/firebase_movie_datasource.dart';
import 'package:cinemax_seat_booking/data/datasources/remote/tmdb_datasource.dart';
import 'package:cinemax_seat_booking/data/models/movie_model.dart';
import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';
import 'package:cinemax_seat_booking/domain/repositories/movie_repository.dart';

class MovieRepositoryImpl implements MovieRepository {
  final TmdbDatasource _tmdbDatasource;
  final FirebaseMovieDatasource _firebaseDatasource;

  MovieRepositoryImpl(this._tmdbDatasource, this._firebaseDatasource);

  @override
  Future<List<MovieEntity>> getTrendingMovies() async {
    final results = await _tmdbDatasource.getPopularMovies();
    return results.map((json) => MovieModel.fromTmdb(json).toEntity()).toList();
  }

  @override
  Future<List<MovieEntity>> getNowPlayingInTheaters() async {
    final dbMovies = await _firebaseDatasource.getActiveMovies();

    final Map<dynamic, MovieEntity> uniqueMovies = {};

    for (final data in dbMovies) {
      final mid = data['movieId'];
      if (mid != null && !uniqueMovies.containsKey(mid)) {
        // Enrich with TMDB for description etc. (or rely on details screen fetch)
        final enriched = await _fetchAndEnrich(data);
        uniqueMovies[mid] = enriched;
      }
    }

    return uniqueMovies.values.toList();
  }

  Future<MovieEntity> _fetchAndEnrich(Map<String, dynamic> dbData) async {
    final mid = dbData['movieId'];
    final base = MovieModel.fromFirestore(dbData, tmdbId: mid is int ? mid : null);

    if (mid != null) {
      final movieIdInt = mid is int ? mid : int.tryParse(mid.toString());
      if (movieIdInt != null) {
        final details = await _tmdbDatasource.getMovieDetails(movieIdInt);
        if (details != null) {
          // Create new entity with enriched data
          return MovieEntity(
            id: base.id,
            title: base.title,
            posterPath: base.posterPath,
            backdropPath: base.backdropPath,
            rating: base.rating,
            overview: details['overview'] ?? base.overview,
            duration: base.duration,
            releaseDate: base.releaseDate,
            showTimes: base.showTimes,
            cinemaName: base.cinemaName,
            docId: base.docId,
          );
        }
      }
    }
    return base.toEntity();
  }

  @override
  Future<MovieEntity?> getMovieDetails(int movieId) async {
    final details = await _tmdbDatasource.getMovieDetails(movieId);
    if (details != null) {
      return MovieModel.fromTmdb(details).toEntity();
    }
    return null;
  }

  @override
  Future<List<String>> getTheatersForMovie(int movieId) async {
    return await _firebaseDatasource.getTheatersForMovie(movieId);
  }
}

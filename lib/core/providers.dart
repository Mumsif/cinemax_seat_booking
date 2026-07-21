import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemax_seat_booking/data/datasources/remote/firebase_movie_datasource.dart';
import 'package:cinemax_seat_booking/data/datasources/remote/tmdb_datasource.dart';
import 'package:cinemax_seat_booking/data/repositories/movie_repository_impl.dart';
import 'package:cinemax_seat_booking/domain/repositories/movie_repository.dart';
import 'package:cinemax_seat_booking/domain/usecases/home/get_now_playing_movies.dart';
import 'package:cinemax_seat_booking/domain/usecases/home/get_trending_movies.dart';

// Datasources
final tmdbDatasourceProvider = Provider((ref) => TmdbDatasource());
final firebaseMovieDatasourceProvider = Provider((ref) => FirebaseMovieDatasource());

// Repository
final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  final tmdb = ref.watch(tmdbDatasourceProvider);
  final firebase = ref.watch(firebaseMovieDatasourceProvider);
  return MovieRepositoryImpl(tmdb, firebase);
});

// Use Cases
final getTrendingMoviesProvider = Provider((ref) {
  final repo = ref.watch(movieRepositoryProvider);
  return GetTrendingMovies(repo);
});

final getNowPlayingMoviesProvider = Provider((ref) {
  final repo = ref.watch(movieRepositoryProvider);
  return GetNowPlayingMovies(repo);
});

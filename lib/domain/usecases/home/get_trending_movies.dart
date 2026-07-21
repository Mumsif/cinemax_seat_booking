import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';
import 'package:cinemax_seat_booking/domain/repositories/movie_repository.dart';

class GetTrendingMovies {
  final MovieRepository repository;

  GetTrendingMovies(this.repository);

  Future<List<MovieEntity>> call() async {
    return await repository.getTrendingMovies();
  }
}

import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';
import 'package:cinemax_seat_booking/domain/repositories/movie_repository.dart';

class GetNowPlayingMovies {
  final MovieRepository repository;

  GetNowPlayingMovies(this.repository);

  Future<List<MovieEntity>> call() async {
    return await repository.getNowPlayingInTheaters();
  }
}

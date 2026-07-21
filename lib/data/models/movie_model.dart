import 'package:cinemax_seat_booking/domain/entities/movie_entity.dart';

class MovieModel extends MovieEntity {
  const MovieModel({
    required super.id,
    required super.title,
    super.posterPath,
    super.backdropPath,
    required super.rating,
    super.overview,
    super.duration,
    super.releaseDate,
    super.showTimes,
    super.cinemaName,
    super.docId,
  });

  factory MovieModel.fromTmdb(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as int,
      title: json['title'] ?? 'Unknown',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: json['overview'],
      releaseDate: json['release_date'],
    );
  }

  factory MovieModel.fromFirestore(Map<String, dynamic> data, {int? tmdbId}) {
    return MovieModel(
      id: tmdbId ?? (data['movieId'] as int? ?? 0),
      title: data['movieName'] ?? data['title'] ?? 'Unknown',
      posterPath: data['posterUrl'] ?? data['poster_path'],
      backdropPath: data['backdropUrl'] ?? data['backdrop_path'],
      rating: (data['rating'] as num?)?.toDouble() ?? (data['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: data['overview'],
      duration: data['duration'],
      releaseDate: data['releaseDate'],
      showTimes: List<String>.from(data['showTimes'] ?? []),
      cinemaName: data['cinemaName'],
      docId: data['docId'],
    );
  }

  MovieEntity toEntity() {
    return MovieEntity(
      id: id,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      rating: rating,
      overview: overview,
      duration: duration,
      releaseDate: releaseDate,
      showTimes: showTimes,
      cinemaName: cinemaName,
      docId: docId,
    );
  }
}

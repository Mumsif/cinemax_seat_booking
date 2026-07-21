class MovieEntity {
  final int id; // TMDB movie ID or local ID
  final String title;
  final String? posterPath; // relative or full URL
  final String? backdropPath;
  final double rating;
  final String? overview;
  final String? duration;
  final String? releaseDate;
  final List<String> showTimes;
  final String? cinemaName; // for scheduled movies from Firestore
  final String? docId; // Firestore doc if applicable

  const MovieEntity({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.rating,
    this.overview,
    this.duration,
    this.releaseDate,
    this.showTimes = const [],
    this.cinemaName,
    this.docId,
  });

  // Factory for from TMDB API response (simplified)
  factory MovieEntity.fromTmdb(Map<String, dynamic> json) {
    return MovieEntity(
      id: json['id'] as int,
      title: json['title'] ?? 'Unknown',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: json['overview'],
      releaseDate: json['release_date'],
    );
  }

  // Factory for from Firestore 'movies' doc + enriched TMDB
  factory MovieEntity.fromFirestore(Map<String, dynamic> data, {int? tmdbId}) {
    return MovieEntity(
      id: tmdbId ?? data['movieId'] as int? ?? 0,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'rating': rating,
      'overview': overview,
      'duration': duration,
      'releaseDate': releaseDate,
      'showTimes': showTimes,
      'cinemaName': cinemaName,
    };
  }
}
